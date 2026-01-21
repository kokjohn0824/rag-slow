# 整合測試結果

## 測試時間
2026-01-20 18:11

## 測試環境
- tempo-latency-anomaly-service: Port 8081
- tempo-otlp-trace-demo: Port 8080
- Grafana Tempo: Port 3200

## 測試流程

### 1. 查詢可用的 Endpoints

```bash
curl http://localhost:8081/v1/available | jq .
```

**結果**: 
```json
{
  "totalServices": 0,
  "totalEndpoints": 0,
  "services": []
}
```

**問題**: 沒有可用的 endpoints，需要先產生測試資料。

### 2. 產生測試 Traces

```bash
for i in {1..10}; do 
  curl -X POST http://localhost:8080/api/order/create \
    -H "Content-Type: application/json" \
    -d '{"user_id":"user_'$i'","product_id":"prod_123","quantity":1,"price":99.99}'
  sleep 2
done
```

**結果**: 成功產生 10 個 traces

### 3. 從 Tempo 搜尋 Traces

```bash
END_TIME=$(date +%s)
START_TIME=$((END_TIME - 3600))
curl "http://localhost:3200/api/search?tags=service.name=trace-demo-service&start=${START_TIME}&end=${END_TIME}&limit=10" | jq .
```

**結果**: 找到 10 個 traces，包括：
- TraceID: `9349e0c8151ffd8298dee998308c27d`
- Operation: `POST /api/order/create`
- Duration: 1064ms

### 4. 獲取 Trace 詳細資訊

```bash
TRACE_ID="9349e0c8151ffd8298dee998308c27d"
curl "http://localhost:3200/api/traces/${TRACE_ID}" | jq -r '.batches[0].scopeSpans[0].spans[] | select(.name == "POST /api/order/create") | {spanId, name}'
```

**結果**:
```json
{
  "spanId": "q3c6Uaob+cQ=",
  "name": "POST /api/order/create"
}
```

### 5. 使用原始碼 API 獲取分析資料

```bash
TRACE_ID="9349e0c8151ffd8298dee998308c27d"
SPAN_ID="q3c6Uaob%2BcQ%3D"  # URL encoded
curl "http://localhost:8080/api/source-code?span_id=${SPAN_ID}&trace_id=${TRACE_ID}" | jq .
```

**結果**:
```json
{
  "span_name": "POST /api/order/create",
  "file_path": "handlers/order.go",
  "function_name": "CreateOrder",
  "duration": "1.06s",
  "child_spans_count": 7
}
```

## 遇到的問題與解決方案

### 問題 1: Port 衝突
- **症狀**: 兩個服務都使用 8080 port
- **解決**: anomaly service 使用 8081，trace-demo 使用 8080

### 問題 2: tempo-otlp-trace-demo 期望 Jaeger 格式但 Tempo 返回 OTLP 格式
- **症狀**: 原始碼 API 無法解析 Tempo 返回的 trace
- **解決**: 修改 `tracing/tempo.go` 添加 OTLP 格式支援和轉換邏輯

### 問題 3: Docker 容器內無法連接 localhost:3200
- **症狀**: `dial tcp [::1]:3200: connect: connection refused`
- **解決**: 在 docker-compose.yml 中添加 `TEMPO_URL=http://tempo-server:3200`

### 問題 4: URL 參數中的 + 被解碼成空格
- **症狀**: Span ID `q3c6Uaob+cQ=` 變成 `q3c6Uaob cQ=`
- **解決**: 使用 URL 編碼 `q3c6Uaob%2BcQ%3D`

### 問題 5: OTLP 結構定義錯誤
- **症狀**: `json: cannot unmarshal string into Go struct field OTLPSpan.kind of type int`
- **解決**: 修改 `kind` 和 `status.code` 從 int 改為 string

### 問題 6: Docker 容器內缺少映射檔案
- **症狀**: `No source code mapping found for span`
- **解決**: 修改 Dockerfile 複製 `source_code_mappings.json` 和 `handlers/` 目錄

## 測試結論

✅ **成功完成整合測試**

1. ✅ 可以從 Tempo 搜尋 traces
2. ✅ 可以獲取 trace 詳細資訊
3. ✅ 可以使用原始碼 API 獲取對應的程式碼
4. ✅ 返回的資料包含：
   - Span 名稱
   - 檔案路徑
   - 函數名稱
   - Duration
   - Child spans 資訊

## 完整整合測試 (使用 longest-span API)

### 測試流程

1. **產生測試 trace**
```bash
curl -X POST http://localhost:8080/api/order/create \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test","product_id":"prod_999","quantity":3,"price":299.99}'
```

2. **從 Tempo 搜尋 trace ID**
```bash
curl "http://localhost:3200/api/search?tags=service.name=trace-demo-service&limit=10"
```
結果: `traceID: 5162d81d38f1190cc3d2818038dbe89`

3. **從 Anomaly Service 獲取 longest span**
```bash
curl "http://localhost:8081/v1/traces/5162d81d38f1190cc3d2818038dbe89/longest-span"
```
結果:
```json
{
  "traceID": "5162d81d38f1190cc3d2818038dbe89",
  "spanId": "HYmVDsl1Z0I=",
  "spanName": "POST /api/order/create",
  "durationMs": 1186
}
```

4. **使用 Source Code API 獲取原始碼和分析資料**
```bash
curl "http://localhost:8080/api/source-code?span_id=HYmVDsl1Z0I%3D&trace_id=5162d81d38f1190cc3d2818038dbe89"
```
結果:
```json
{
  "span_name": "POST /api/order/create",
  "file_path": "handlers/order.go",
  "function_name": "CreateOrder",
  "duration": "1.19s",
  "child_spans": [
    {"span_name": "validateOrder", "duration": "76.56ms"},
    {"span_name": "checkInventory", "duration": "193.83ms"},
    {"span_name": "calculatePrice", "duration": "77.14ms"},
    {"span_name": "processPayment", "duration": "364.32ms"},  ← 最慢
    {"span_name": "createShipment", "duration": "149.94ms"},
    {"span_name": "sendNotification", "duration": "69.70ms"},
    {"span_name": "saveToDatabase", "duration": "254.52ms"}
  ]
}
```

### ✅ 整合測試結論

1. ✅ **從 tempo-latency-anomaly-service 獲取 longest span**
   - API: `/v1/traces/{traceId}/longest-span`
   - 返回: trace ID, span ID, span name, duration

2. ✅ **使用 span ID 查詢原始碼**
   - API: `/api/source-code?span_id={spanId}&trace_id={traceId}`
   - 返回: 檔案路徑、函數名稱、原始碼、child spans

3. ✅ **效能分析**
   - 可以識別最慢的子操作 (processPayment: 364.32ms)
   - 可以查看完整的原始碼
   - 可以提供給 LLM 進行分析

### 測試腳本

執行完整測試:
```bash
./test-integration.sh
```

## 修改的檔案

1. `tempo-otlp-trace-demo/tracing/tempo.go` - 添加 OTLP 格式支援
2. `tempo-otlp-trace-demo/docker-compose.yml` - 添加 TEMPO_URL 環境變數
3. `tempo-otlp-trace-demo/Dockerfile` - 複製映射檔案和原始碼
4. `tempo-otlp-trace-demo/tempo.yaml` - 啟用 Jaeger API (雖然最後沒用到)
