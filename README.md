# RAG-Slow: 分散式追蹤效能分析系統

[![Anomaly Service](https://img.shields.io/badge/GitHub-Anomaly_Service-blue?logo=github)](https://github.com/kokjohn0824/tempo-latency-anomaly-service)
[![Trace Demo](https://img.shields.io/badge/GitHub-Trace_Demo-blue?logo=github)](https://github.com/kokjohn0824/tempo-otlp-trace-demo)
[![Go Version](https://img.shields.io/badge/Go-1.24+-00ADD8?logo=go)](https://go.dev/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

基於 Grafana Tempo 的分散式追蹤效能分析系統，自動識別效能瓶頸並提供原始碼層級的分析。

## 🎯 系統功能

- **自動效能分析**：識別延遲異常的 API 端點
- **原始碼映射**：將效能問題對應到具體程式碼
- **完整追蹤鏈**：分析 parent/child spans 找出瓶頸
- **Swagger UI**：互動式 API 文檔和測試

## 📦 系統組成

### 1. Tempo Latency Anomaly Service (Port 8081)
效能異常檢測服務，負責：
- 查詢 Grafana Tempo 的 trace 資料
- 分析 API 延遲和效能異常
- 提供 trace 和 span 的詳細資訊

**主要 API**：
- `GET /v1/available` - 查詢可用的 endpoints
- `GET /v1/traces` - 搜尋 traces
- `GET /v1/traces/{traceId}/longest-span` - 獲取最慢的 span
- `POST /v1/traces/child-spans` - 獲取 child spans

**連結**：
- 📖 [專案文檔](tempo-latency-anomaly-service/README.md)
- 🔗 [GitHub Repository](https://github.com/kokjohn0824/tempo-latency-anomaly-service)

### 2. Tempo OTLP Trace Demo (Port 8080)
原始碼映射服務，負責：
- 產生測試 traces
- 將 span name 映射到原始碼
- 提供原始碼查詢 API

**主要 API**：
- `GET /api/span-names` - 列出所有可追蹤的 span names
- `POST /api/source-code` - 根據 span name 獲取原始碼
- `GET /swagger/` - Swagger UI 文檔

**連結**：
- 📖 [專案文檔](tempo-otlp-trace-demo/README.md)
- 🔗 [GitHub Repository](https://github.com/kokjohn0824/tempo-otlp-trace-demo)

## 🚀 快速開始

### 前置需求

- Docker & Docker Compose
- curl & jq（用於測試）

### 啟動系統

```bash
# 1. 啟動 Anomaly Service
cd tempo-latency-anomaly-service
docker-compose up -d

# 2. 啟動 Trace Demo Service
cd ../tempo-otlp-trace-demo
docker-compose up -d

# 3. 等待服務就緒（約 10 秒）
sleep 10
```

### 驗證服務

```bash
# 檢查 Anomaly Service
curl http://localhost:8081/health

# 檢查 Trace Demo Service
curl http://localhost:8080/health

# 檢查 Grafana Tempo
curl http://localhost:3200/ready
```

### 執行整合測試

```bash
# 在主資料夾執行
./test-integration.sh
```

## 📖 使用流程

### 1. 產生測試資料

```bash
# 產生一些 traces
curl -X POST http://localhost:8080/api/order/create
curl -X POST http://localhost:8080/api/report/generate
curl http://localhost:8080/api/search?q=test
```

### 2. 查詢可用的 Endpoints

```bash
curl http://localhost:8081/v1/available | jq '.'
```

### 3. 搜尋特定 Endpoint 的 Traces

```bash
END_TIME=$(date +%s)
START_TIME=$((END_TIME - 300))

curl "http://localhost:8081/v1/traces?service=trace-demo-service&endpoint=POST%20/api/order/create&start=${START_TIME}&end=${END_TIME}&limit=5" | jq '.'
```

### 4. 分析最慢的 Span

```bash
# 使用上一步獲取的 traceId
TRACE_ID="your-trace-id"

curl "http://localhost:8081/v1/traces/${TRACE_ID}/longest-span" | jq '.'
```

### 5. 獲取 Child Spans

```bash
curl -X POST http://localhost:8081/v1/traces/child-spans \
  -H "Content-Type: application/json" \
  -d '{"traceId":"your-trace-id","spanId":"your-span-id"}' | jq '.'
```

### 6. 獲取原始碼

```bash
curl -X POST http://localhost:8080/api/source-code \
  -H "Content-Type: application/json" \
  -d '{"spanName":"POST /api/order/create"}' | jq '.'
```

## 🔍 Swagger UI

兩個服務都提供 Swagger UI 進行 API 測試：

- **Anomaly Service**: http://localhost:8081/swagger/
- **Trace Demo**: http://localhost:8080/swagger/

## 🏗️ 系統架構

```
┌─────────────────────────────────────────────────────────┐
│                        使用者                           │
└────────────────┬────────────────────────────────────────┘
                 │
                 ├──────────────────┬─────────────────────┐
                 │                  │                     │
                 ▼                  ▼                     ▼
    ┌────────────────────┐ ┌────────────────┐ ┌─────────────────┐
    │ Anomaly Service    │ │ Trace Demo     │ │ Grafana UI      │
    │ (Port 8081)        │ │ (Port 8080)    │ │ (Port 3000)     │
    │                    │ │                │ │                 │
    │ - Trace 查詢       │ │ - 產生 Traces  │ │ - 視覺化        │
    │ - 效能分析         │ │ - 原始碼映射   │ │ - 查詢介面      │
    │ - Span 分析        │ │ - Swagger UI   │ │                 │
    └────────┬───────────┘ └────────┬───────┘ └────────┬────────┘
             │                      │                  │
             │                      ▼                  │
             │            ┌─────────────────┐          │
             │            │ OTEL Collector  │          │
             │            │ (Port 4317)     │          │
             │            └────────┬────────┘          │
             │                     │                   │
             └─────────────────────┼───────────────────┘
                                   ▼
                         ┌──────────────────┐
                         │ Grafana Tempo    │
                         │ (Port 3200)      │
                         │                  │
                         │ - Trace 儲存     │
                         │ - 查詢 API       │
                         └──────────────────┘
```

## 📁 專案結構

```
rag-slow/
├── README.md                           # 本文檔
├── test-integration.sh                 # 整合測試腳本
│
├── tempo-latency-anomaly-service/      # 效能分析服務
│   ├── README.md                       # 服務文檔
│   ├── docker-compose.yml              # Docker 配置
│   └── docs/                           # 詳細文檔
│
└── tempo-otlp-trace-demo/              # 追蹤產生與原始碼映射服務
    ├── README.md                       # 服務文檔
    ├── docker-compose.yml              # Docker 配置
    ├── source_code_mappings.json       # Span 到原始碼的映射
    └── docs/                           # Swagger 文檔
```

## 🛠️ 常用指令

### 服務管理

```bash
# 啟動所有服務
cd tempo-latency-anomaly-service && docker-compose up -d
cd ../tempo-otlp-trace-demo && docker-compose up -d

# 停止所有服務
cd tempo-latency-anomaly-service && docker-compose down
cd ../tempo-otlp-trace-demo && docker-compose down

# 查看日誌
docker-compose logs -f [service-name]

# 重啟服務
docker-compose restart [service-name]
```

### 測試

```bash
# 執行整合測試
./test-integration.sh

# 測試 Anomaly Service API
cd tempo-latency-anomaly-service
./scripts/test-apis.sh

# 測試 Trace Demo API
cd tempo-otlp-trace-demo
./scripts/test-span-names.sh
```

## 🔧 配置

### 環境變數

**Anomaly Service**:
- `TEMPO_URL`: Tempo API URL（預設：`http://tempo-server:3200`）
- `PORT`: 服務埠號（預設：`8081`）

**Trace Demo**:
- `OTEL_EXPORTER_OTLP_ENDPOINT`: OTEL Collector 端點（預設：`otel-collector:4317`）
- `PORT`: 服務埠號（預設：`8080`）

### 修改 Span 映射

編輯 `tempo-otlp-trace-demo/source_code_mappings.json`：

```json
{
  "mappings": [
    {
      "span_name": "POST /api/order/create",
      "file_path": "handlers/order.go",
      "function_name": "CreateOrder",
      "start_line": 21,
      "end_line": 85,
      "description": "處理訂單建立"
    }
  ]
}
```

## 🐛 故障排除

### 服務無法啟動

```bash
# 檢查埠號是否被佔用
lsof -i :8080
lsof -i :8081
lsof -i :3200

# 檢查 Docker 容器狀態
docker ps -a

# 查看錯誤日誌
docker-compose logs [service-name]
```

### 找不到 Traces

```bash
# 1. 確認 Tempo 正常運作
curl http://localhost:3200/ready

# 2. 產生一些測試 traces
curl -X POST http://localhost:8080/api/order/create

# 3. 等待資料寫入（約 5 秒）
sleep 5

# 4. 重新查詢
curl http://localhost:8081/v1/available
```

### API 回傳 404

```bash
# 檢查服務健康狀態
curl http://localhost:8081/health
curl http://localhost:8080/health

# 重啟服務
docker-compose restart
```

## 📚 延伸閱讀

- [Anomaly Service 詳細文檔](tempo-latency-anomaly-service/README.md)
- [Trace Demo 詳細文檔](tempo-otlp-trace-demo/README.md)
- [Grafana Tempo 文檔](https://grafana.com/docs/tempo/latest/)
- [OpenTelemetry 文檔](https://opentelemetry.io/docs/)

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request。

## 📄 授權

MIT License
