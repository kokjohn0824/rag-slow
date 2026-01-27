.PHONY: help build test clean run dev up down logs restart deploy test-apis fmt lint vet docker-build docker-push health check-deps install-deps \
	image-save deploy-image deploy-compose deploy-mappings deploy-full

# 變數定義
APP_NAME := trace-demo-app
DOCKER_IMAGE := $(APP_NAME)
DOCKER_TAG := latest
DOCKER_REGISTRY ?= 
GO_FILES := $(shell find . -type f -name '*.go' -not -path "./vendor/*")
BASE_URL ?= http://localhost:8080
PORT ?= 8080

# Remote deployment settings
REMOTE_HOST ?= 192.168.4.208
REMOTE_USER ?= root
REMOTE_PATH ?= /root/trace-demo
REMOTE_IMAGE_PATH ?= $(REMOTE_PATH)/images
REMOTE_COMPOSE_DIR ?= $(REMOTE_PATH)
REMOTE_SERVICE_NAME ?= trace-demo-app
ARCH ?= amd64
PLATFORM ?= linux/$(ARCH)

# 顏色輸出
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# 預設目標
.DEFAULT_GOAL := help

## help: 顯示此幫助訊息
help:
	@echo "$(BLUE)=======================================$(NC)"
	@echo "$(BLUE)  Tempo OTLP Trace Demo - Makefile$(NC)"
	@echo "$(BLUE)=======================================$(NC)"
	@echo ""
	@echo "$(GREEN)可用的指令:$(NC)"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  $(YELLOW)/' | sed 's/:/ $(NC)-/' | column -t -s '-'
	@echo ""
	@echo "$(GREEN)遠端部署:$(NC)"
	@echo "  $(YELLOW)image-save$(NC)      - 建立並儲存 Docker image 為 tar 檔案"
	@echo "  $(YELLOW)deploy-image$(NC)    - 建立、儲存並部署 Docker image 到遠端伺服器"
	@echo "  $(YELLOW)deploy-compose$(NC)  - 部署 docker-compose.yml 到遠端伺服器"
	@echo "  $(YELLOW)deploy-mappings$(NC) - 部署 source_code_mappings.json 到遠端伺服器"
	@echo "  $(YELLOW)deploy-full$(NC)     - 完整部署 (image + compose + mappings + restart)"
	@echo ""
	@echo "$(GREEN)變數 (使用 VAR=value 覆寫):$(NC)"
	@echo "  REMOTE_HOST=$(REMOTE_HOST)"
	@echo "  REMOTE_USER=$(REMOTE_USER)"
	@echo "  REMOTE_PATH=$(REMOTE_PATH)"
	@echo "  ARCH=$(ARCH) (amd64 或 arm64)"
	@echo ""

## check-deps: 檢查必要的依賴工具
check-deps:
	@echo "$(BLUE)檢查依賴工具...$(NC)"
	@command -v go >/dev/null 2>&1 || { echo "$(RED)錯誤: 需要安裝 Go$(NC)"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)錯誤: 需要安裝 Docker$(NC)"; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || command -v docker compose >/dev/null 2>&1 || { echo "$(RED)錯誤: 需要安裝 Docker Compose$(NC)"; exit 1; }
	@echo "$(GREEN)✓ 所有依賴工具已安裝$(NC)"

## install-deps: 安裝 Go 依賴
install-deps:
	@echo "$(BLUE)安裝 Go 依賴...$(NC)"
	go mod download
	go mod verify
	@echo "$(GREEN)✓ 依賴安裝完成$(NC)"

## install-swag: 安裝 swag CLI 工具
install-swag:
	@echo "$(BLUE)安裝 swag CLI 工具...$(NC)"
	@if command -v swag >/dev/null 2>&1; then \
		echo "$(GREEN)✓ swag 已安裝$(NC)"; \
	else \
		go install github.com/swaggo/swag/cmd/swag@latest; \
		echo "$(GREEN)✓ swag 安裝完成$(NC)"; \
	fi

## swagger: 生成 Swagger 文檔
swagger: install-swag
	@echo "$(BLUE)生成 Swagger 文檔...$(NC)"
	swag init -g main.go --output ./docs
	@echo "$(GREEN)✓ Swagger 文檔已生成$(NC)"
	@echo "$(YELLOW)訪問 http://localhost:8080/swagger/ 查看 API 文檔$(NC)"

## tidy: 整理 Go 依賴
tidy:
	@echo "$(BLUE)整理 Go 依賴...$(NC)"
	go mod tidy
	@echo "$(GREEN)✓ 依賴整理完成$(NC)"

## fmt: 格式化 Go 程式碼
fmt:
	@echo "$(BLUE)格式化程式碼...$(NC)"
	go fmt ./...
	@echo "$(GREEN)✓ 格式化完成$(NC)"

## vet: 執行 Go vet 檢查
vet:
	@echo "$(BLUE)執行 vet 檢查...$(NC)"
	go vet ./...
	@echo "$(GREEN)✓ Vet 檢查通過$(NC)"

## lint: 執行 golangci-lint (需要先安裝)
lint:
	@echo "$(BLUE)執行 lint 檢查...$(NC)"
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
		echo "$(GREEN)✓ Lint 檢查完成$(NC)"; \
	else \
		echo "$(YELLOW)警告: golangci-lint 未安裝，跳過 lint 檢查$(NC)"; \
		echo "安裝方式: brew install golangci-lint 或參考 https://golangci-lint.run/usage/install/"; \
	fi

## build: 編譯 Go 應用程式
build: fmt vet
	@echo "$(BLUE)編譯應用程式...$(NC)"
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/$(APP_NAME) .
	@echo "$(GREEN)✓ 編譯完成: bin/$(APP_NAME)$(NC)"

## build-local: 編譯本地版本 (適用於當前作業系統)
build-local: fmt vet
	@echo "$(BLUE)編譯本地版本...$(NC)"
	go build -o bin/$(APP_NAME)-local .
	@echo "$(GREEN)✓ 編譯完成: bin/$(APP_NAME)-local$(NC)"

## run: 在本地執行應用程式 (不使用 Docker)
run: build-local
	@echo "$(BLUE)啟動應用程式...$(NC)"
	@echo "$(YELLOW)注意: 確保 OTEL Collector、Tempo 和 Grafana 已在 Docker 中運行$(NC)"
	@echo "$(YELLOW)如果尚未啟動，請執行: make infra-up$(NC)"
	OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4317 \
	OTEL_SERVICE_NAME=trace-demo-service \
	PORT=$(PORT) \
	./bin/$(APP_NAME)-local

## infra-up: 啟動基礎設施 (不含應用程式)
infra-up:
	@echo "$(BLUE)啟動基礎設施 (OTel Collector, Tempo, Grafana)...$(NC)"
	docker-compose up -d otel-collector tempo-server grafana
	@echo "$(GREEN)✓ 基礎設施已啟動$(NC)"
	@echo "$(YELLOW)等待服務就緒...$(NC)"
	@sleep 5
	@make health

## dev: 開發模式 - 啟動基礎設施並在本地運行應用程式
dev: infra-up
	@echo "$(BLUE)開發模式啟動...$(NC)"
	@make run

## docker-build: 建立 Docker 映像
docker-build:
	@echo "$(BLUE)建立 Docker 映像...$(NC)"
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .
	@if [ -n "$(DOCKER_REGISTRY)" ]; then \
		docker tag $(DOCKER_IMAGE):$(DOCKER_TAG) $(DOCKER_REGISTRY)/$(DOCKER_IMAGE):$(DOCKER_TAG); \
		echo "$(GREEN)✓ 映像已標記: $(DOCKER_REGISTRY)/$(DOCKER_IMAGE):$(DOCKER_TAG)$(NC)"; \
	fi
	@echo "$(GREEN)✓ Docker 映像建立完成$(NC)"

## docker-push: 推送 Docker 映像到 Registry
docker-push: docker-build
	@if [ -z "$(DOCKER_REGISTRY)" ]; then \
		echo "$(RED)錯誤: 請設定 DOCKER_REGISTRY 變數$(NC)"; \
		echo "範例: make docker-push DOCKER_REGISTRY=your-registry.com"; \
		exit 1; \
	fi
	@echo "$(BLUE)推送 Docker 映像到 $(DOCKER_REGISTRY)...$(NC)"
	docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE):$(DOCKER_TAG)
	@echo "$(GREEN)✓ Docker 映像推送完成$(NC)"

## up: 啟動所有服務 (使用 Docker Compose)
up: check-deps
	@echo "$(BLUE)啟動所有服務...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)✓ 所有服務已啟動$(NC)"
	@echo "$(YELLOW)等待服務就緒...$(NC)"
	@sleep 10
	@make health

## down: 停止所有服務
down:
	@echo "$(BLUE)停止所有服務...$(NC)"
	docker-compose down
	@echo "$(GREEN)✓ 所有服務已停止$(NC)"

## down-volumes: 停止所有服務並刪除 volumes
down-volumes:
	@echo "$(BLUE)停止所有服務並刪除 volumes...$(NC)"
	@echo "$(RED)警告: 這將刪除所有儲存的資料！$(NC)"
	@read -p "確定要繼續嗎? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		echo "$(GREEN)✓ 所有服務已停止，volumes 已刪除$(NC)"; \
	else \
		echo "$(YELLOW)操作已取消$(NC)"; \
	fi

## restart: 重啟所有服務
restart: down up

## logs: 查看所有服務的日誌
logs:
	docker-compose logs -f

## logs-app: 查看應用程式日誌
logs-app:
	docker-compose logs -f trace-demo-app

## logs-collector: 查看 OTel Collector 日誌
logs-collector:
	docker-compose logs -f otel-collector

## logs-tempo: 查看 Tempo 日誌
logs-tempo:
	docker-compose logs -f tempo-server

## logs-grafana: 查看 Grafana 日誌
logs-grafana:
	docker-compose logs -f grafana

## ps: 查看服務狀態
ps:
	@echo "$(BLUE)服務狀態:$(NC)"
	docker-compose ps

## health: 檢查所有服務健康狀態
health:
	@echo "$(BLUE)檢查服務健康狀態...$(NC)"
	@echo ""
	@echo "$(YELLOW)應用程式 (port 8080):$(NC)"
	@curl -s http://localhost:8080/health && echo " $(GREEN)✓ OK$(NC)" || echo " $(RED)✗ Failed$(NC)"
	@echo ""
	@echo "$(YELLOW)OTel Collector (port 13133):$(NC)"
	@curl -s http://localhost:13133/ >/dev/null && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Failed$(NC)"
	@echo ""
	@echo "$(YELLOW)Tempo (port 3200):$(NC)"
	@curl -s http://localhost:3200/ready && echo " $(GREEN)✓ OK$(NC)" || echo " $(RED)✗ Failed$(NC)"
	@echo ""
	@echo "$(YELLOW)Grafana (port 3000):$(NC)"
	@curl -s http://localhost:3000/api/health >/dev/null && echo "$(GREEN)✓ OK$(NC)" || echo "$(RED)✗ Failed$(NC)"
	@echo ""

## test-apis: 執行 API 測試腳本
test-apis:
	@echo "$(BLUE)執行 API 測試...$(NC)"
	@chmod +x scripts/test-apis.sh
	BASE_URL=$(BASE_URL) ./scripts/test-apis.sh

## test-quick: 快速測試 (減少等待時間)
test-quick:
	@echo "$(BLUE)執行快速測試...$(NC)"
	@chmod +x scripts/test-apis.sh
	BASE_URL=$(BASE_URL) SLEEP_BETWEEN_CALLS=0.5 ./scripts/test-apis.sh

## test: 執行 Go 單元測試
test:
	@echo "$(BLUE)執行單元測試...$(NC)"
	go test -v -race -coverprofile=coverage.out ./...
	@echo "$(GREEN)✓ 測試完成$(NC)"

## test-coverage: 執行測試並生成覆蓋率報告
test-coverage: test
	@echo "$(BLUE)生成覆蓋率報告...$(NC)"
	go tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)✓ 覆蓋率報告已生成: coverage.html$(NC)"

## bench: 執行效能測試
bench:
	@echo "$(BLUE)執行效能測試...$(NC)"
	go test -bench=. -benchmem ./...

## clean: 清理編譯產物和暫存檔
clean:
	@echo "$(BLUE)清理編譯產物...$(NC)"
	rm -rf bin/
	rm -f coverage.out coverage.html
	go clean
	@echo "$(GREEN)✓ 清理完成$(NC)"

## clean-all: 清理所有產物 (包含 Docker)
clean-all: clean
	@echo "$(BLUE)清理 Docker 資源...$(NC)"
	docker-compose down -v --remove-orphans
	docker rmi $(DOCKER_IMAGE):$(DOCKER_TAG) 2>/dev/null || true
	@echo "$(GREEN)✓ 完全清理完成$(NC)"

## deploy: 部署到生產環境 (建立映像並推送)
deploy: docker-build docker-push
	@echo "$(GREEN)✓ 部署完成$(NC)"
	@echo "$(YELLOW)下一步: 在目標環境執行 docker-compose up -d$(NC)"

## open-grafana: 在瀏覽器中開啟 Grafana
open-grafana:
	@echo "$(BLUE)開啟 Grafana...$(NC)"
	@command -v open >/dev/null 2>&1 && open http://localhost:3000 || \
	command -v xdg-open >/dev/null 2>&1 && xdg-open http://localhost:3000 || \
	echo "請手動開啟: http://localhost:3000"

## open-app: 在瀏覽器中開啟應用程式
open-app:
	@echo "$(BLUE)開啟應用程式...$(NC)"
	@command -v open >/dev/null 2>&1 && open http://localhost:8080 || \
	command -v xdg-open >/dev/null 2>&1 && xdg-open http://localhost:8080 || \
	echo "請手動開啟: http://localhost:8080"

## open-swagger: 在瀏覽器中開啟 Swagger UI
open-swagger:
	@echo "$(BLUE)開啟 Swagger UI...$(NC)"
	@command -v open >/dev/null 2>&1 && open http://localhost:8080/swagger/ || \
	command -v xdg-open >/dev/null 2>&1 && xdg-open http://localhost:8080/swagger/ || \
	echo "請手動開啟: http://localhost:8080/swagger/"

## ci: CI/CD 流程 (格式化、檢查、測試、建立)
ci: fmt vet test docker-build
	@echo "$(GREEN)✓ CI 流程完成$(NC)"

## all: 完整流程 (清理、安裝依賴、測試、建立)
all: clean install-deps test build docker-build
	@echo "$(GREEN)✓ 完整建立流程完成$(NC)"

## image-save: 建立並儲存 Docker image 為 tar 檔案
image-save:
	@echo "$(BLUE)建立 Docker image for $(PLATFORM)...$(NC)"
	docker buildx build --platform=$(PLATFORM) --load -t $(DOCKER_IMAGE):$(ARCH) .
	@echo "$(BLUE)儲存 Docker image 為 tar 檔案...$(NC)"
	docker save $(DOCKER_IMAGE):$(ARCH) -o $(DOCKER_IMAGE)-$(ARCH).tar
	@echo "$(GREEN)✓ Image 已儲存: $(DOCKER_IMAGE)-$(ARCH).tar$(NC)"

## deploy-image: 建立、儲存並部署 Docker image 到遠端伺服器
deploy-image: image-save
	@echo "$(BLUE)部署 Docker image 到 $(REMOTE_USER)@$(REMOTE_HOST)...$(NC)"
	@echo "$(YELLOW)建立遠端目錄...$(NC)"
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "mkdir -p $(REMOTE_IMAGE_PATH)"
	@echo "$(YELLOW)上傳 image 檔案...$(NC)"
	@echo "put $(DOCKER_IMAGE)-$(ARCH).tar $(REMOTE_IMAGE_PATH)/" | sftp $(REMOTE_USER)@$(REMOTE_HOST)
	@echo "$(YELLOW)在遠端主機載入 Docker image...$(NC)"
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "docker load -i $(REMOTE_IMAGE_PATH)/$(DOCKER_IMAGE)-$(ARCH).tar"
	@echo "$(GREEN)✓ Image 部署完成！$(NC)"
	@echo "  - Image: $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_IMAGE_PATH)/$(DOCKER_IMAGE)-$(ARCH).tar"

## deploy-compose: 部署 docker-compose.yml 到遠端伺服器
deploy-compose:
	@echo "$(BLUE)部署 docker-compose 配置到 $(REMOTE_USER)@$(REMOTE_HOST)...$(NC)"
	@echo "$(YELLOW)建立遠端目錄...$(NC)"
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "mkdir -p $(REMOTE_COMPOSE_DIR)"
	@echo "$(YELLOW)上傳 docker-compose.yml...$(NC)"
	@echo "put docker-compose.yml $(REMOTE_COMPOSE_DIR)/" | sftp $(REMOTE_USER)@$(REMOTE_HOST)
	@echo "$(YELLOW)上傳配置檔案...$(NC)"
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "mkdir -p $(REMOTE_COMPOSE_DIR)/configs"
	@echo "put otel-collector.yaml $(REMOTE_COMPOSE_DIR)/" | sftp $(REMOTE_USER)@$(REMOTE_HOST) || true
	@echo "put tempo.yaml $(REMOTE_COMPOSE_DIR)/" | sftp $(REMOTE_USER)@$(REMOTE_HOST) || true
	@echo "put grafana-datasources.yaml $(REMOTE_COMPOSE_DIR)/" | sftp $(REMOTE_USER)@$(REMOTE_HOST) || true
	@echo "$(GREEN)✓ 配置部署完成！$(NC)"

## deploy-mappings: 部署 source_code_mappings.json 到遠端伺服器
deploy-mappings:
	@echo "$(BLUE)部署 source code mappings 到 $(REMOTE_USER)@$(REMOTE_HOST)...$(NC)"
	@echo "$(YELLOW)上傳 source_code_mappings.json...$(NC)"
	@echo "put source_code_mappings.json $(REMOTE_COMPOSE_DIR)/" | sftp $(REMOTE_USER)@$(REMOTE_HOST)
	@echo "$(YELLOW)上傳 handlers 目錄...$(NC)"
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "mkdir -p $(REMOTE_COMPOSE_DIR)/handlers"
	@echo "put -r handlers $(REMOTE_COMPOSE_DIR)/" | sftp $(REMOTE_USER)@$(REMOTE_HOST)
	@echo "$(GREEN)✓ Mappings 部署完成！$(NC)"

## deploy-full: 完整部署 (image + compose + mappings + restart)
deploy-full: deploy-image deploy-compose deploy-mappings
	@echo "$(BLUE)在遠端主機重啟服務...$(NC)"
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "cd $(REMOTE_COMPOSE_DIR) && docker compose down && docker compose up -d"
	@echo "$(YELLOW)等待服務啟動...$(NC)"
	@sleep 10
	@echo "$(YELLOW)檢查服務健康狀態...$(NC)"
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "curl -s http://localhost:8080/health" && echo "$(GREEN)✓ 服務正常運作！$(NC)" || echo "$(RED)⚠ 服務健康檢查失敗$(NC)"
	@echo ""
	@echo "$(GREEN)✓ 完整部署成功完成！$(NC)"
	@echo "  - 主機: $(REMOTE_USER)@$(REMOTE_HOST)"
	@echo "  - 路徑: $(REMOTE_COMPOSE_DIR)"
	@echo "  - 服務: $(REMOTE_SERVICE_NAME)"
	@echo ""
	@echo "$(YELLOW)訪問服務:$(NC)"
	@echo "  - API: http://$(REMOTE_HOST):8080"
	@echo "  - Swagger: http://$(REMOTE_HOST):8080/swagger/"
	@echo "  - Health: http://$(REMOTE_HOST):8080/health"
	@echo "  - Grafana: http://$(REMOTE_HOST):3000"
