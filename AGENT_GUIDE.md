# Coding Agent 參考指南

本文檔為 AI coding agents 提供專案結構和 API 參考。

## 專案概述

**目的**: 分散式追蹤效能分析系統，自動識別效能瓶頸並映射到原始碼。

**技術棧**: Go, Docker, Grafana Tempo, OpenTelemetry, Swagger

## 服務架構

```
┌─────────────────────────────────────────────────────────┐
│ tempo-latency-anomaly-service (Port 8081)               │
│ - 查詢 Tempo traces                                      │
│ - 分析效能異常                                            │
│ - 提供 span 詳細資訊                                      │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
                  ┌───────────────┐
                  │ Grafana Tempo │
                  │ (Port 3200)   │
                  └───────────────┘
                          ▲
                          │
┌─────────────────────────────────────────────────────────┐
│ tempo-otlp-trace-demo (Port 8080)                       │
│ - 產生測試 traces                                        │
│ - Span name → 原始碼映射                                 │
│ - 提供 Swagger UI                                        │
└─────────────────────────────────────────────────────────┘
```

## API 端點總覽

### Anomaly Service (http://localhost:8081)

| 方法 | 端點 | 說明 | 請求 | 回應 |
|------|------|------|------|------|
| GET | `/v1/available` | 查詢可用 endpoints | - | `{endpoints: [...]}` |
| GET | `/v1/traces` | 搜尋 traces | `?service=&endpoint=&start=&end=&limit=` | `{traces: [...]}` |
| GET | `/v1/traces/{traceId}/longest-span` | 獲取最慢 span | - | `{traceID, spanId, spanName, durationMs}` |
| POST | `/v1/traces/child-spans` | 獲取 child spans | `{traceId, spanId}` | `{parentSpan, children: [...]}` |
| GET | `/health` | 健康檢查 | - | `OK` |
| GET | `/swagger/` | Swagger UI | - | HTML |

### Trace Demo (http://localhost:8080)

| 方法 | 端點 | 說明 | 請求 | 回應 |
|------|------|------|------|------|
| GET | `/api/span-names` | 列出所有 span names | - | `{span_names: [...], count}` |
| POST | `/api/source-code` | 獲取原始碼 | `{spanName}` | `{span_name, file_path, source_code, ...}` |
| GET | `/api/mappings` | 獲取所有映射 | - | `{mappings: [...]}` |
| POST | `/api/mappings` | 更新映射 | `{mappings: [...]}` | `{status, message, count}` |
| POST | `/api/order/create` | 產生測試 trace | - | Order response |
| GET | `/health` | 健康檢查 | - | `OK` |
| GET | `/swagger/` | Swagger UI | - | HTML |

## 資料結構

### SpanSummary
```json
{
  "spanId": "string",
  "name": "string",
  "service": "string",
  "durationMs": 123,
  "startTime": "2026-01-21T10:00:00Z",
  "endTime": "2026-01-21T10:00:01Z",
  "parentSpanId": "string"
}
```

### SourceCodeMapping
```json
{
  "span_name": "POST /api/order/create",
  "file_path": "handlers/order.go",
  "function_name": "CreateOrder",
  "start_line": 21,
  "end_line": 85,
  "description": "處理訂單建立"
}
```

## 典型工作流程

### 1. 效能分析流程

```python
# 1. 查詢可用 endpoints
GET /v1/available
→ 選擇要分析的 endpoint

# 2. 搜尋該 endpoint 的 traces
GET /v1/traces?service=X&endpoint=Y&start=T1&end=T2
→ 獲取 traceId

# 3. 獲取最慢的 span
GET /v1/traces/{traceId}/longest-span
→ 獲取 spanId 和 spanName

# 4. 獲取 child spans（可選）
POST /v1/traces/child-spans
Body: {traceId, spanId}
→ 獲取所有子操作的效能資料

# 5. 獲取原始碼
POST /api/source-code
Body: {spanName}
→ 獲取對應的程式碼
```

### 2. 新增 Span 映射

```python
# 1. 查看現有映射
GET /api/mappings

# 2. 新增新映射
POST /api/mappings
Body: {
  "mappings": [
    {
      "span_name": "new-operation",
      "file_path": "handlers/new.go",
      "function_name": "NewHandler",
      "start_line": 10,
      "end_line": 50,
      "description": "新功能"
    }
  ]
}

# 3. 驗證
GET /api/span-names
```

## 檔案結構

```
rag-slow/
├── README.md                    # 主文檔
├── QUICKSTART.md                # 快速開始
├── AGENT_GUIDE.md               # 本文檔
├── test-integration.sh          # 整合測試腳本
│
├── tempo-latency-anomaly-service/
│   ├── cmd/server/main.go       # 服務入口
│   ├── internal/
│   │   ├── api/                 # API handlers
│   │   ├── domain/              # 資料模型
│   │   └── tempo/               # Tempo 客戶端
│   ├── docker-compose.yml       # 包含 Tempo, Grafana
│   └── README.md
│
└── tempo-otlp-trace-demo/
    ├── main.go                  # 服務入口
    ├── handlers/                # API handlers
    │   ├── order.go
    │   ├── sourcecode.go
    │   └── spannames.go
    ├── models/                  # 資料模型
    ├── source_code_mappings.json # Span 映射配置
    ├── docker-compose.yml
    └── README.md
```

## 開發指南

### 新增 API 端點

**Anomaly Service**:
1. 在 `internal/api/handlers/` 新增 handler
2. 在 `internal/api/router.go` 註冊路由
3. 新增 Swagger 註解
4. 執行 `make swagger` 生成文檔

**Trace Demo**:
1. 在 `handlers/` 新增 handler
2. 在 `main.go` 註冊路由
3. 新增 Swagger 註解
4. 執行 `make swagger` 生成文檔

### 修改 Span 映射

編輯 `tempo-otlp-trace-demo/source_code_mappings.json`：

```json
{
  "mappings": [
    {
      "span_name": "操作名稱",
      "file_path": "相對路徑",
      "function_name": "函數名稱",
      "start_line": 起始行,
      "end_line": 結束行,
      "description": "說明"
    }
  ]
}
```

### 測試

```bash
# 整合測試
./test-integration.sh

# 單一服務測試
cd tempo-latency-anomaly-service
./scripts/test-apis.sh

cd tempo-otlp-trace-demo
./scripts/test-span-names.sh
```

### 重新編譯

```bash
# Anomaly Service
cd tempo-latency-anomaly-service
docker-compose build --no-cache anomaly-service
docker-compose restart anomaly-service

# Trace Demo
cd tempo-otlp-trace-demo
docker-compose build --no-cache trace-demo-app
docker-compose restart trace-demo-app
```

## 常見任務

### 任務 1: 查詢特定時間範圍的 traces

```bash
START_TIME=$(date -d "5 minutes ago" +%s)
END_TIME=$(date +%s)

curl "http://localhost:8081/v1/traces?service=trace-demo-service&endpoint=POST%20/api/order/create&start=${START_TIME}&end=${END_TIME}&limit=10"
```

### 任務 2: 批次產生測試資料

```bash
for i in {1..10}; do
  curl -X POST http://localhost:8080/api/order/create
  curl -X POST http://localhost:8080/api/report/generate
  sleep 1
done
```

### 任務 3: 匯出所有 span 映射

```bash
curl http://localhost:8080/api/mappings | jq '.mappings' > mappings_backup.json
```

### 任務 4: 批次匯入 span 映射

```bash
curl -X POST http://localhost:8080/api/mappings \
  -H "Content-Type: application/json" \
  -d @mappings_backup.json
```

## 環境變數

### Anomaly Service
- `TEMPO_URL`: Tempo API URL（預設：`http://tempo-server:3200`）
- `PORT`: 服務埠號（預設：`8081`）

### Trace Demo
- `OTEL_EXPORTER_OTLP_ENDPOINT`: OTEL Collector 端點（預設：`otel-collector:4317`）
- `OTEL_SERVICE_NAME`: 服務名稱（預設：`trace-demo-service`）
- `PORT`: 服務埠號（預設：`8080`）

## 錯誤處理

### 常見錯誤碼

| 狀態碼 | 說明 | 解決方式 |
|--------|------|----------|
| 404 | 資源不存在 | 檢查 traceId/spanId 是否正確 |
| 400 | 請求格式錯誤 | 檢查 JSON 格式和必要欄位 |
| 500 | 伺服器錯誤 | 查看服務日誌 |
| 503 | 服務不可用 | 檢查 Tempo 是否正常運作 |

### 除錯指令

```bash
# 查看服務日誌
docker-compose logs -f [service-name]

# 檢查服務狀態
docker-compose ps

# 重啟服務
docker-compose restart [service-name]

# 完全重建
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## 效能考量

- **Tempo 查詢**: 限制時間範圍和結果數量
- **Span 映射**: 從記憶體讀取，速度快
- **原始碼讀取**: 快取檔案內容可提升效能
- **並發**: 兩個服務都支援高並發請求

## 安全注意事項

- Swagger UI 在生產環境應該關閉或加上認證
- 原始碼 API 只能讀取預定義的檔案
- 所有輸入都經過驗證
- 不暴露內部錯誤細節給客戶端

## 參考資源

- **Swagger UI**: 
  - Anomaly Service: http://localhost:8081/swagger/
  - Trace Demo: http://localhost:8080/swagger/
- **Grafana**: http://localhost:3000 (admin/admin)
- **Tempo API**: http://localhost:3200
- **詳細文檔**: 
  - [Anomaly Service](tempo-latency-anomaly-service/README.md)
  - [Trace Demo](tempo-otlp-trace-demo/README.md)
