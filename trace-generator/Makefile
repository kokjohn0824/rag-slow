.PHONY: help check-deps install-deps fmt vet test build build-local run docker-build docker-run up down restart logs ps clean deploy

# Variables
APP_NAME := trace-generator
DOCKER_IMAGE := $(APP_NAME)
DOCKER_TAG := latest
COMPOSE_FILE := docker-compose-deploy.yml
COMPOSE := $(shell command -v docker-compose >/dev/null 2>&1 && echo docker-compose || echo "docker compose")

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

.DEFAULT_GOAL := help

## help: show available commands
help:
	@echo "$(BLUE)=============================$(NC)"
	@echo "$(BLUE) Trace Generator - Makefile$(NC)"
	@echo "$(BLUE)=============================$(NC)"
	@echo ""
	@echo "$(GREEN)Available commands:$(NC)"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  $(YELLOW)/' | sed 's/:/ $(NC)-/' | column -t -s '-'
	@echo ""
	@echo "$(GREEN)Compose file:$(NC) $(COMPOSE_FILE)"
	@echo ""

## check-deps: verify required tools
check-deps:
	@echo "$(BLUE)Checking dependencies...$(NC)"
	@command -v go >/dev/null 2>&1 || { echo "$(RED)Error: Go is required$(NC)"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)Error: Docker is required$(NC)"; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1 || { echo "$(RED)Error: Docker Compose is required$(NC)"; exit 1; }
	@echo "$(GREEN)✓ All dependencies available$(NC)"

## install-deps: download Go modules
install-deps:
	@echo "$(BLUE)Downloading Go modules...$(NC)"
	go mod download
	go mod verify
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

## fmt: format Go code
fmt:
	@echo "$(BLUE)Formatting code...$(NC)"
	go fmt ./...
	@echo "$(GREEN)✓ Format complete$(NC)"

## vet: run go vet
vet:
	@echo "$(BLUE)Running vet...$(NC)"
	go vet ./...
	@echo "$(GREEN)✓ Vet passed$(NC)"

## test: run unit tests
test:
	@echo "$(BLUE)Running tests...$(NC)"
	go test -v ./...
	@echo "$(GREEN)✓ Tests completed$(NC)"

## build: build linux binary
build: fmt vet
	@echo "$(BLUE)Building linux binary...$(NC)"
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/$(APP_NAME) .
	@echo "$(GREEN)✓ Built: bin/$(APP_NAME)$(NC)"

## build-local: build binary for current OS
build-local: fmt vet
	@echo "$(BLUE)Building local binary...$(NC)"
	go build -o bin/$(APP_NAME)-local .
	@echo "$(GREEN)✓ Built: bin/$(APP_NAME)-local$(NC)"

## run: run locally with env vars
run:
	@echo "$(BLUE)Running locally...$(NC)"
	@echo "$(YELLOW)Set TARGET_URL, INTERVAL_SECONDS, LOG_PATH if needed$(NC)"
	go run main.go

## docker-build: build docker image
docker-build:
	@echo "$(BLUE)Building Docker image...$(NC)"
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .
	@echo "$(GREEN)✓ Image built: $(DOCKER_IMAGE):$(DOCKER_TAG)$(NC)"

## docker-run: run docker container locally
docker-run: docker-build
	@echo "$(BLUE)Running Docker container...$(NC)"
	@docker network inspect tempo-network >/dev/null 2>&1 || docker network create tempo-network
	@mkdir -p logs
	docker run -d \
	  --name trace-generator \
	  --network tempo-network \
	  -e TARGET_URL=$${TARGET_URL:-http://trace-demo-app:8080} \
	  -e INTERVAL_SECONDS=$${INTERVAL_SECONDS:-30} \
	  -e LOG_PATH=$${LOG_PATH:-/logs/trace-generator.log} \
	  -e ENABLED_APIS=$${ENABLED_APIS:-order,user,report,search,batch,simulate} \
	  -e TIMEOUT_SECONDS=$${TIMEOUT_SECONDS:-30} \
	  -v $$(pwd)/logs:/logs \
	  $(DOCKER_IMAGE):$(DOCKER_TAG)
	@echo "$(GREEN)✓ Container started$(NC)"

## up: start services with docker compose
up: check-deps
	@echo "$(BLUE)Starting services...$(NC)"
	@docker network inspect tempo-network >/dev/null 2>&1 || docker network create tempo-network
	@mkdir -p logs
	$(COMPOSE) -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)✓ Services started$(NC)"

## down: stop services with docker compose
down:
	@echo "$(BLUE)Stopping services...$(NC)"
	$(COMPOSE) -f $(COMPOSE_FILE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

## restart: restart services
restart: down up

## logs: follow trace-generator logs
logs:
	$(COMPOSE) -f $(COMPOSE_FILE) logs -f trace-generator

## ps: show compose service status
ps:
	$(COMPOSE) -f $(COMPOSE_FILE) ps

## clean: remove build artifacts
clean:
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	rm -rf bin/
	@echo "$(GREEN)✓ Clean complete$(NC)"

## deploy: build and start via compose (includes image build)
deploy: check-deps
	@echo "$(BLUE)Deploying trace-generator...$(NC)"
	@docker network inspect tempo-network >/dev/null 2>&1 || docker network create tempo-network
	@mkdir -p logs
	$(COMPOSE) -f $(COMPOSE_FILE) up -d --build trace-generator
	@echo "$(GREEN)✓ Deploy complete$(NC)"
