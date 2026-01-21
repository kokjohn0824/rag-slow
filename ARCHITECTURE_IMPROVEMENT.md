# 架構改進總結

## 🎯 改進目標

將 Tempo 查詢邏輯完全集中在 `tempo-latency-anomaly-service`，讓 `tempo-otlp-trace-demo` 專注於原始碼映射功能。

## ✅ 完成的改進

### Phase 1: Anomaly Service - 新增 Child Spans API

**新增 API**: `POST /v1/traces/child-spans`

**請求格式**:
```json
{
  "traceId": "abc123def456",
  "spanId": "xyz789"
}
```

**回應格式**:
```json
{
  "traceId": "abc123def456",
  "parentSpan": {
    "spanId": "xyz789",
    "name": "POST /api/order/create",
    "service": "trace-demo-service",
    "durationMs": 1034,
    "startTime": "2026-01-21T08:48:12Z",
    "endTime": "2026-01-21T08:48:13Z"
  },
  "children": [
    {
      "spanId": "child1",
      "name": "validateOrder",
      "service": "trace-demo-service",
      "durationMs": 81,
      "startTime": "2026-01-21T08:48:12Z",
      "endTime": "2026-01-21T08:48:12Z",
      "parentSpanId": "xyz789"
    }
  ],
  "childCount": 7,
  "computedAt": "2026-01-21T08:48:27Z"
}
```

**優勢**:
- ✅ 使用 POST + JSON，避免 URL 編碼問題
- ✅ 提供完整的 child spans 資訊（duration、service、時間等）
- ✅ 集中 Tempo 查詢邏輯

### Phase 2: Trace Demo - 簡化 Source Code API

**改進前**:
```bash
GET /api/source-code?span_id=xxx&trace_id=yyy
```
- ❌ 需要 trace_id
- ❌ 需要查詢 Tempo
- ❌ 需要解析 OTLP 格式
- ❌ 需要找 child spans
- ❌ URL 編碼問題

**改進後**:
```bash
POST /api/source-code
Body: {"spanName": "POST /api/order/create"}
```
- ✅ 只需要 span name
- ✅ 不需要查詢 Tempo
- ✅ 不需要 trace_id
- ✅ 使用 JSON，避免 URL 編碼
- ✅ 專注於原始碼映射

**回應格式**:
```json
{
  "span_name": "POST /api/order/create",
  "file_path": "handlers/order.go",
  "function_name": "CreateOrder",
  "start_line": 21,
  "end_line": 85,
  "source_code": "func CreateOrder(w http.ResponseWriter, r *http.Request) {...}"
}
```

## 📊 新的整合流程

```
步驟 1: GET /v1/available
        ↓
步驟 2: 產生測試 trace
        ↓
步驟 3: GET /v1/traces?service=xxx&endpoint=yyy
        ↓
步驟 4: GET /v1/traces/{traceId}/longest-span
        ↓
步驟 5: POST /v1/traces/child-spans
        Body: {traceId, spanId}
        ↓
步驟 6: POST /api/source-code
        Body: {spanName}
        ↓
步驟 7: 分析效能瓶頸
```

## 🎯 職責劃分

### Tempo Latency Anomaly Service
**負責**: 所有 Tempo 查詢和 trace 分析
- ✅ `/v1/available` - 查詢可用 endpoints
- ✅ `/v1/traces` - 搜尋 traces
- ✅ `/v1/traces/{traceId}/longest-span` - 獲取 longest span
- ✅ `/v1/traces/child-spans` - 獲取 child spans（新增）

### Tempo OTLP Trace Demo
**負責**: Span name → 原始碼的映射
- ✅ `/api/source-code` - 根據 span name 返回原始碼
- ✅ `/api/mappings` - 管理映射關係

## 🔧 技術改進

### 1. 使用 POST + JSON 代替 GET + Query Parameters

**優勢**:
- 避免 URL 編碼問題（`+`, `=`, `/` 等特殊字符）
- 更清晰的參數結構
- 支援複雜的請求參數
- 更符合 RESTful 設計（查詢操作使用 POST body）

### 2. 簡化 API 職責

**Trace Demo API 改進**:
- 移除 124 行 Tempo 查詢代碼
- 移除 OTLP 格式轉換邏輯
- 移除 child spans 查找邏輯
- 程式碼從 ~300 行減少到 ~150 行

### 3. 統一資料來源

**改進前**:
```
調用方 → Trace Demo → Tempo (直接查詢)
       ↓
     原始碼
```

**改進後**:
```
調用方 → Anomaly Service → Tempo (統一查詢)
       ↓
     Trace 分析資料
       ↓
調用方 → Trace Demo
       ↓
     原始碼
```

## 📝 API 使用範例

### 完整流程

```bash
# 1. 查詢可用 endpoints
curl http://localhost:8081/v1/available | jq .

# 2. 搜尋 traces
END_TIME=$(date +%s)
START_TIME=$((END_TIME - 300))
curl "http://localhost:8081/v1/traces?service=trace-demo-service&endpoint=POST%20/api/order/create&start=${START_TIME}&end=${END_TIME}&limit=5" | jq .

# 3. 獲取 longest span
TRACE_ID="xxx"
curl "http://localhost:8081/v1/traces/${TRACE_ID}/longest-span" | jq .

# 4. 獲取 child spans (新)
curl -X POST http://localhost:8081/v1/traces/child-spans \
  -H "Content-Type: application/json" \
  -d '{"traceId":"xxx","spanId":"yyy"}' | jq .

# 5. 獲取原始碼 (簡化)
curl -X POST http://localhost:8080/api/source-code \
  -H "Content-Type: application/json" \
  -d '{"spanName":"POST /api/order/create"}' | jq .
```

## 🎓 學習重點

1. **職責分離**: 每個服務只做自己該做的事
2. **避免重複**: 不要在多個服務中實作相同的邏輯
3. **API 設計**: 使用 POST + JSON 避免 URL 編碼問題
4. **架構清晰**: 統一的資料查詢入口

## 📈 效益

1. **可維護性**: Tempo 格式變更只需修改 Anomaly Service
2. **可測試性**: 每個服務可以獨立測試
3. **效能**: Trace Demo 不需要查詢 Tempo
4. **擴展性**: 容易添加新的分析功能

## 🎉 測試結果

✅ 所有 API 測試通過
✅ 整合測試成功
✅ 架構改進完成

執行測試: `./test-integration.sh`
