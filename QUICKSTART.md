# 快速開始指南

## 5 分鐘快速上手

### 1. 啟動服務（2 分鐘）

```bash
# 啟動 Anomaly Service（包含 Tempo 和 Grafana）
cd tempo-latency-anomaly-service
docker-compose up -d

# 啟動 Trace Demo Service
cd ../tempo-otlp-trace-demo
docker-compose up -d

# 等待服務就緒
sleep 10
```

### 2. 驗證服務（30 秒）

```bash
# 檢查所有服務
curl http://localhost:8081/health  # Anomaly Service
curl http://localhost:8080/health  # Trace Demo
curl http://localhost:3200/ready   # Tempo
```

### 3. 產生測試資料（30 秒）

```bash
# 產生一些 traces
for i in {1..5}; do
  curl -X POST http://localhost:8080/api/order/create
  sleep 1
done
```

### 4. 執行分析（1 分鐘）

```bash
# 方式 1: 使用自動化測試腳本
cd /path/to/rag-slow
./test-integration.sh

# 方式 2: 手動執行
# 查詢可用 endpoints
curl http://localhost:8081/v1/available | jq '.'

# 搜尋 traces
END_TIME=$(date +%s)
START_TIME=$((END_TIME - 300))
curl "http://localhost:8081/v1/traces?service=trace-demo-service&endpoint=POST%20/api/order/create&start=${START_TIME}&end=${END_TIME}&limit=5" | jq '.'

# 分析最慢的 span（使用上一步的 traceId）
curl "http://localhost:8081/v1/traces/{traceId}/longest-span" | jq '.'

# 獲取原始碼
curl -X POST http://localhost:8080/api/source-code \
  -H "Content-Type: application/json" \
  -d '{"spanName":"POST /api/order/create"}' | jq '.'
```

### 5. 使用 Swagger UI（1 分鐘）

開啟瀏覽器訪問：

- **Anomaly Service API**: http://localhost:8081/swagger/
- **Trace Demo API**: http://localhost:8080/swagger/
- **Grafana UI**: http://localhost:3000 (admin/admin)

## 常見使用場景

### 場景 1: 找出最慢的 API 端點

```bash
# 1. 查詢所有可用 endpoints
curl http://localhost:8081/v1/available | jq '.endpoints[] | {name, avgDuration, p95Duration}'

# 2. 選擇最慢的 endpoint 進行分析
```

### 場景 2: 分析特定 API 的效能瓶頸

```bash
# 1. 搜尋該 API 的 traces
curl "http://localhost:8081/v1/traces?service=trace-demo-service&endpoint=POST%20/api/order/create&limit=10" | jq '.'

# 2. 選擇最慢的 trace
TRACE_ID=$(curl -s "..." | jq -r '.traces[0].traceID')

# 3. 獲取 longest span
RESULT=$(curl -s "http://localhost:8081/v1/traces/${TRACE_ID}/longest-span")
SPAN_ID=$(echo "$RESULT" | jq -r '.spanId')
SPAN_NAME=$(echo "$RESULT" | jq -r '.spanName')

# 4. 獲取 child spans
curl -X POST http://localhost:8081/v1/traces/child-spans \
  -H "Content-Type: application/json" \
  -d "{\"traceId\":\"${TRACE_ID}\",\"spanId\":\"${SPAN_ID}\"}" | jq '.'

# 5. 查看原始碼
curl -X POST http://localhost:8080/api/source-code \
  -H "Content-Type: application/json" \
  -d "{\"spanName\":\"${SPAN_NAME}\"}" | jq '.source_code'
```

### 場景 3: 查看所有可追蹤的操作

```bash
# 列出所有 span names
curl http://localhost:8080/api/span-names | jq '.span_names[] | {span_name, function_name, file_path}'
```

## 停止服務

```bash
# 停止 Trace Demo
cd tempo-otlp-trace-demo
docker-compose down

# 停止 Anomaly Service
cd ../tempo-latency-anomaly-service
docker-compose down
```

## 下一步

- 閱讀 [README.md](README.md) 了解系統架構
- 查看 [API 文檔](http://localhost:8081/swagger/)
- 探索 [Grafana UI](http://localhost:3000)
