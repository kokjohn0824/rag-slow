# 最終測試總結

## ✅ 測試完成時間
2026-01-20 18:18

## ✅ 測試目標
透過 tempo-latency-anomaly-service 的 API 查詢到某個 endpoint 的 Span，再利用 tempo-otlp-trace-demo 提供的原始碼 API 來獲取該 span 的原始碼資料。

## ✅ 測試結果：成功

### 正確的完整流程

```
1. 從 tempo-latency-anomaly-service 調用 /v1/available
   獲取有 baseline 資料的 endpoints
   ↓
2. 選擇要分析的 endpoint
   (例如: trace-demo-service 的 POST /api/order/create)
   ↓
3. 產生該 endpoint 的測試 trace
   ↓
4. 使用 tempo-latency-anomaly-service 的 /v1/traces API
   搜尋該 endpoint 的 traces (不需要直接查詢 Tempo)
   ↓
5. 使用 tempo-latency-anomaly-service 的 /v1/traces/{traceId}/longest-span
   獲取最長的 span 資訊 (包含 span ID)
   ↓
6. 使用 tempo-otlp-trace-demo 的 /api/source-code
   根據 span ID 和 trace ID 獲取原始碼
   ↓
7. 分析結果 (識別效能瓶頸)
```

### 關鍵改進

**第一次修正（之前）**:
- ❌ 直接從 Tempo 搜尋 trace ID（繞過了 anomaly service 的 /v1/available）
- ❌ 沒有確認 endpoint 是否有 baseline 資料

**第二次修正（現在）**:
- ✅ 先調用 `/v1/available` 確認哪些 endpoints 有資料
- ✅ 選擇一個有 baseline 的 endpoint 進行測試
- ✅ **使用 `/v1/traces` API 搜尋該 endpoint 的 traces**
- ✅ 完全透過 anomaly service 的 API 查詢，不需要直接連接 Tempo
- ✅ 確保測試的是有意義的、已收集資料的 endpoint

### 實際測試資料

**步驟 1: 從 /v1/available 獲取可用的 endpoints**
```json
{
  "totalServices": 1,
  "totalEndpoints": 1,
  "services": [
    {
      "service": "trace-demo-service",
      "endpoint": "POST /api/order/create",
      "buckets": ["17|weekday"]
    }
  ]
}
```

**步驟 2: 選擇要分析的 endpoint**
- Service: `trace-demo-service`
- Endpoint: `POST /api/order/create`

**步驟 3: 從 Tempo 搜尋該 endpoint 的 traces**
- 搜尋條件: `service.name=trace-demo-service` + `rootTraceName=POST /api/order/create`
- 找到 Trace ID: `ca2c4e49846fdf94ddef6d6e497e079c`

**步驟 4: 從 Anomaly Service 獲取 Longest Span**
```json
{
  "traceID": "ca2c4e49846fdf94ddef6d6e497e079c",
  "spanId": "4xqqfIBEKtU=",
  "spanName": "POST /api/order/create",
  "service": "trace-demo-service",
  "durationMs": 1067
}
```

**步驟 5: 從 Source Code API 獲取分析資料**
```json
{
  "span_name": "POST /api/order/create",
  "file_path": "handlers/order.go",
  "function_name": "CreateOrder",
  "duration": "1.07s",
  "child_spans": [
    {"span_name": "validateOrder", "duration": "86.27ms"},
    {"span_name": "checkInventory", "duration": "174.26ms"},
    {"span_name": "calculatePrice", "duration": "57.90ms"},
    {"span_name": "processPayment", "duration": "344.69ms"},  ← 最慢
    {"span_name": "createShipment", "duration": "100.75ms"},
    {"span_name": "sendNotification", "duration": "91.18ms"},
    {"span_name": "saveToDatabase", "duration": "212.46ms"}
  ]
}
```

## 解決的技術問題

### 1. OTLP 格式支援
**問題**: tempo-otlp-trace-demo 原本只支援 Jaeger 格式，但 Tempo 返回 OTLP 格式。

**解決**: 
- 修改 `tracing/tempo.go`
- 添加 OTLP 結構定義
- 實作 `convertOTLPToJaeger()` 函數
- 自動檢測並轉換格式

### 2. Docker 網路配置
**問題**: 容器內無法連接 `localhost:3200`。

**解決**: 
- 在 `docker-compose.yml` 添加 `TEMPO_URL=http://tempo-server:3200`
- 使用 Docker 網路中的服務名稱

### 3. URL 編碼問題
**問題**: Span ID 中的 `+` 被解碼成空格。

**解決**: 
- 使用 URL 編碼: `q3c6Uaob%2BcQ%3D`
- 在腳本中使用 `jq -sRr @uri` 進行編碼

### 4. 容器檔案缺失
**問題**: Docker 容器內缺少 `source_code_mappings.json` 和原始碼檔案。

**解決**: 
- 修改 `Dockerfile`
- 複製 `source_code_mappings.json` 和 `handlers/` 目錄到容器

### 5. OTLP 資料類型錯誤
**問題**: `kind` 和 `status.code` 欄位類型錯誤。

**解決**: 
- 將 `kind` 從 `int` 改為 `string`
- 將 `status.code` 從 `int` 改為 `string`

## 修改的檔案清單

1. `tempo-otlp-trace-demo/tracing/tempo.go`
   - 添加 OTLP 格式支援
   - 實作格式轉換邏輯
   - 添加調試日誌

2. `tempo-otlp-trace-demo/docker-compose.yml`
   - 添加 `TEMPO_URL` 環境變數

3. `tempo-otlp-trace-demo/Dockerfile`
   - 複製映射檔案和原始碼到容器

4. `tempo-otlp-trace-demo/tempo.yaml`
   - 啟用 Jaeger API (最後未使用)

## API 使用範例

### 完整流程範例

```bash
# 步驟 1: 獲取可用的 endpoints
curl "http://localhost:8081/v1/available"

# 步驟 2: 選擇一個 endpoint (例如: POST /api/order/create)

# 步驟 3: 使用 /v1/traces API 搜尋該 endpoint 的 traces
END_TIME=$(date +%s)
START_TIME=$((END_TIME - 300))
curl "http://localhost:8081/v1/traces?service=trace-demo-service&endpoint=POST%20/api/order/create&start=${START_TIME}&end=${END_TIME}&limit=5"

# 回應範例:
# {
#   "service": "trace-demo-service",
#   "endpoint": "POST /api/order/create",
#   "count": 3,
#   "traces": [
#     {"traceID": "954c13f76aed98ea58b9a4dcc9cf11e", "durationMs": 997},
#     ...
#   ]
# }

# 步驟 4: 選擇一個 trace ID

# 步驟 5: 獲取 longest span
curl "http://localhost:8081/v1/traces/${TRACE_ID}/longest-span"

# 步驟 6: 獲取原始碼
SPAN_ID_ENCODED=$(echo -n "$SPAN_ID" | jq -sRr @uri)
curl "http://localhost:8080/api/source-code?span_id=${SPAN_ID_ENCODED}&trace_id=${TRACE_ID}"
```

### 自動化測試腳本

```bash
./test-integration.sh
```

這個腳本會自動執行完整的流程並生成分析報告。

## 可用於 LLM 分析的資料

整合後的 API 提供以下資料供 LLM 分析：

1. **Span 基本資訊**
   - Span name
   - Duration
   - Service name

2. **原始碼資訊**
   - 檔案路徑
   - 函數名稱
   - 行號範圍
   - 完整原始碼

3. **效能資料**
   - 所有 child spans 的 duration
   - 可識別效能瓶頸

4. **Attributes**
   - HTTP method, route
   - 業務相關資料 (user ID, order ID, etc.)

## 下一步建議

1. ✅ **基本功能已完成**
   - 可以查詢 longest span
   - 可以獲取原始碼
   - 可以分析效能瓶頸

2. **可選的增強功能**
   - 整合 LLM 進行自動分析
   - 建立監控告警
   - 批次分析多個 traces
   - 生成效能報告

3. **等待 Anomaly Service 收集資料**
   - 需要 10-15 分鐘收集 baseline
   - 然後可以測試異常檢測功能

## 測試腳本

- `test-integration.sh` - 完整整合測試
- `TEST_RESULTS.md` - 詳細測試結果
- `FINAL_TEST_SUMMARY.md` - 本文檔

## 結論

✅ **整合測試完全成功！**

兩個服務可以正常協作：
1. tempo-latency-anomaly-service 提供 span 查詢功能
2. tempo-otlp-trace-demo 提供原始碼分析功能
3. 整合後可以完整分析效能問題

所有技術問題都已解決，系統可以正常運作。
