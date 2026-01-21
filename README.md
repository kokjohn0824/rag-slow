# 整合測試：Tempo Latency Anomaly Service + Trace Demo

## 🎯 測試目標

透過 tempo-latency-anomaly-service 的 API 查詢到某個 endpoint 的 Span，再利用 tempo-otlp-trace-demo 提供的原始碼 API 來獲取該 span 的原始碼資料。

## ✅ 測試狀態：完全成功

## 📋 完整流程

```
1. GET /v1/available (anomaly-service)
   └─> 獲取有 baseline 的 endpoints

2. 選擇要分析的 endpoint

3. GET /v1/traces (anomaly-service)
   └─> 搜尋該 endpoint 的 traces

4. GET /v1/traces/{traceId}/longest-span (anomaly-service)
   └─> 獲取 longest span 和 span ID

5. POST /v1/traces/child-spans (anomaly-service)
   └─> 獲取 child spans 和效能資料

6. POST /api/source-code (trace-demo)
   └─> 獲取原始碼

7. 分析結果
   └─> 識別效能瓶頸
```

## 🚀 快速開始

### 執行測試

```bash
./test-integration.sh
```

### 手動測試

```bash
# 1. 檢查可用 endpoints
curl http://localhost:8081/v1/available | jq .

# 2. 搜尋 traces
END_TIME=$(date +%s)
START_TIME=$((END_TIME - 300))
curl "http://localhost:8081/v1/traces?service=trace-demo-service&endpoint=POST%20/api/order/create&start=${START_TIME}&end=${END_TIME}&limit=5" | jq .

# 3. 獲取 longest span
curl "http://localhost:8081/v1/traces/{traceId}/longest-span" | jq .

# 4. 獲取 child spans
curl -X POST http://localhost:8081/v1/traces/child-spans \
  -H "Content-Type: application/json" \
  -d '{"traceId":"{traceId}","spanId":"{spanId}"}' | jq .

# 5. 獲取原始碼
curl -X POST http://localhost:8080/api/source-code \
  -H "Content-Type: application/json" \
  -d '{"spanName":"POST /api/order/create"}' | jq .
```

## 📊 測試結果範例

### 步驟 3: 搜尋 traces
```json
{
  "count": 3,
  "traces": [
    {"traceID": "954c13f76aed98ea58b9a4dcc9cf11e", "durationMs": 997}
  ]
}
```

### 步驟 4: 獲取 longest span
```json
{
  "traceID": "954c13f76aed98ea58b9a4dcc9cf11e",
  "spanId": "h4yuRBv963E=",
  "spanName": "POST /api/order/create",
  "durationMs": 997
}
```

### 步驟 5: 獲取原始碼
```json
{
  "span_name": "POST /api/order/create",
  "file_path": "handlers/order.go",
  "function_name": "CreateOrder",
  "duration": "997ms",
  "child_spans": [
    {"span_name": "processPayment", "duration": "267ms"},
    {"span_name": "saveToDatabase", "duration": "199ms"},
    ...
  ]
}
```

## 🔧 解決的問題

1. ✅ OTLP 格式支援
2. ✅ Docker 網路配置
3. ✅ URL 編碼處理（改用 POST + JSON）
4. ✅ 容器檔案配置
5. ✅ 測試流程邏輯修正
6. ✅ 使用正確的 anomaly-service API
7. ✅ 架構改進：職責分離

## 📄 文檔

- `test-integration.sh` - 自動化測試腳本
- `TEST_SUMMARY_FINAL.md` - 完整測試總結
- `FINAL_TEST_SUMMARY.md` - 詳細測試說明
- `FINAL_IMPROVEMENT.md` - 改進歷程說明
- `TEST_RESULTS.md` - 測試結果記錄

## 🎓 關鍵學習

**正確的整合方式**:
- 完全透過 anomaly-service 查詢 Tempo 資料
- 不需要直接連接 Tempo
- 使用 POST + JSON 避免 URL 編碼問題
- 職責分離：Anomaly Service 負責分析，Trace Demo 負責映射

**架構清晰**:
```
anomaly-service (門面) → Tempo (後端)
                ↓
          提供統一的查詢介面
                ↓
         trace-demo (原始碼映射)
```

**API 設計改進**:
- 使用 POST + JSON 代替 GET + Query Parameters
- 避免 URL 編碼特殊字符（`+`, `=`, `/`）
- 更清晰的參數結構

## 🎉 結論

測試完全成功！所有 API 正常協作，可以完整分析特定 endpoint 的效能問題。
