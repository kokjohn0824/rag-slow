# 任務交接文件：Workflow 移植到 n8n/Dify

> **目標**：將 `test-integration.sh` 的效能分析流程移植到 n8n 或 Dify workflow  
> **最後更新**：2026-01-27

---

## 一、專案背景（30 秒了解）

這是一個**分散式追蹤效能分析系統**，可以：
1. 從告警或 API 請求開始
2. 自動查詢 Tempo 找出慢 trace
3. 分析 child spans 定位效能瓶頸
4. 查詢對應的原始碼位置
5. 生成 RCA 報告

**核心價值**：自動化從「系統變慢」到「問題程式碼定位」的完整流程。

---

## 二、需要移植的流程

`test-integration.sh` 執行的 8 個步驟：

| 步驟 | 動作 | API |
|------|------|-----|
| 0 | 健康檢查 | `GET /healthz`, `GET /health`, `GET /ready` |
| 1 | 查詢可用 endpoints | `GET /v1/available` |
| 2 | 產生測試 trace | `POST /api/order/create` |
| 3 | 搜尋 traces | `GET /v1/traces?service=&endpoint=&start=&end=` |
| 4 | 獲取最慢 span | `GET /v1/traces/{traceId}/longest-span` |
| 5 | 分析 child spans | `POST /v1/traces/child-span-anomalies` |
| 6 | 分析結果 | (邏輯判斷) |
| 7 | 查詢原始碼 | `POST /api/source-code` |
| 8 | 查詢 root span 原始碼 | `POST /api/source-code` |

---

## 三、服務端點

| 服務 | 用途 | 預設 URL |
|------|------|----------|
| **Anomaly Service** | Trace 查詢、效能分析 | `http://localhost:8081` |
| **Trace Demo** | 原始碼映射、測試資料 | `http://localhost:8080` |
| **Tempo** | Trace 儲存 | `http://localhost:3200` |

> 遠端環境使用 `192.168.4.208` 的 3201/3202/3200 port

---

## 四、必讀文件（依優先順序）

1. **[workflow-api-usage.md](workflow-api-usage.md)** - API 規格和資料流轉換（**最重要**）
2. **[AGENT_GUIDE.md](AGENT_GUIDE.md)** - API 端點總覽和資料結構
3. **[dify-readme.md](dify-readme.md)** - 現有 Dify workflow 設計參考
4. **[../slow-rca-workflow.yml](../slow-rca-workflow.yml)** - 現有 Dify workflow 定義檔

---

## 五、API 快速參考

### Anomaly Service (`http://localhost:8081`)

```bash
# 1. 查詢可用 endpoints
GET /v1/available
# Response: {totalEndpoints, services: [{service, endpoint}]}

# 2. 搜尋 traces
GET /v1/traces?service=trace-demo-service&endpoint=POST%20/api/order/create&start=1706300000&end=1706310000&limit=5
# Response: {count, traces: [{traceID, durationMs}]}

# 3. 獲取最慢 span
GET /v1/traces/{traceId}/longest-span
# Response: {traceID, longestSpan: {spanId, name, service, durationMs}}

# 4. 獲取 child spans 異常分析
POST /v1/traces/child-span-anomalies
Body: {"traceId": "xxx", "parentSpanId": "xxx"}
# Response: {anomalyCount, children: [{span: {name, durationMs}, isAnomaly, explanation}]}
```

### Trace Demo (`http://localhost:8080`)

```bash
# 查詢原始碼
POST /api/source-code
Body: {"spanName": "POST /api/order/create"}
# Response: {file_path, function_name, start_line, end_line, source_code}
```

---

## 六、Workflow 設計建議

### 節點規劃

```
[Start] → [健康檢查] → [查詢 endpoints] → [搜尋 traces]
                                              ↓
[輸出報告] ← [LLM 分析] ← [查詢原始碼] ← [分析 child spans] ← [獲取 longest span]
```

### 節點類型建議

| 節點 | n8n | Dify |
|------|-----|------|
| API 呼叫 | HTTP Request | http-request |
| 資料處理 | Code / Function | code |
| 條件判斷 | IF | if-else |
| LLM 分析 | OpenAI / Claude | llm |

### 關鍵處理邏輯

1. **時間戳處理**：Unix timestamp (秒)
   ```javascript
   const endTime = Math.floor(Date.now() / 1000);
   const startTime = endTime - 300; // 5 分鐘前
   ```

2. **URL Encode**：endpoint 需要 URL encode
   ```javascript
   const encodedEndpoint = encodeURIComponent("POST /api/order/create");
   ```

3. **異常判斷**：
   ```javascript
   const isAnomalous = anomalyCount > 0;
   const targetSpans = isAnomalous 
     ? children.filter(c => c.isAnomaly).map(c => c.span.name)
     : [slowestChild.name];
   ```

---

## 七、現有資源

| 資源 | 路徑 | 說明 |
|------|------|------|
| Shell 測試腳本 | `test-integration.sh` | 完整流程參考 |
| Localhost 版本 | `test-integration-localhost.sh` | 本地測試用 |
| Dify Workflow | `slow-rca-workflow.yml` | 可直接匯入 Dify |
| API 測試腳本 | `test-workflow-apis.sh` | 驗證 API 連通性 |

---

## 八、驗收標準

1. ✅ 可輸入 service name 和時間範圍
2. ✅ 自動搜尋並識別慢 trace
3. ✅ 分析 child spans 找出異常/最慢的操作
4. ✅ 查詢並顯示對應原始碼
5. ✅ 生成結構化分析報告

---

## 九、注意事項

1. **API 相容性**：`child-span-anomalies` API 可能返回 405，需 fallback 到 `child-spans`
2. **Timeout**：Tempo 查詢可能較慢，建議設 60 秒 timeout
3. **空結果處理**：trace 可能為空，需處理 `totalEndpoints = 0` 的情況
4. **模擬異常**：可用 `{"sleep": true}` 參數產生慢請求測試

---

## 十、聯絡資訊

如有問題，請參考：
- 詳細 API 規格：[workflow-api-usage.md](workflow-api-usage.md)
- 系統架構：[../README.md](../README.md)
- 部署指南：[DEPLOYMENT.md](DEPLOYMENT.md)
