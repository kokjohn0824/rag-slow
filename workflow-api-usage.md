# Slow-RCA Workflow API 使用說明

## 📋 概述

本文件說明 `slow-rca-workflow.yml` 實際使用的 API 端點和資料格式。

**最後更新**: 2026-01-22

---

## 🔗 使用中的 API 端點

### 1. Tempo Traces API (tempo-latency-anomaly-service)

**基礎 URL**: `http://localhost:8081`

#### 1.1 搜尋 Traces

```
GET /v1/traces
```

**Query Parameters**:
- `service` (string, required): 服務名稱
- `endpoint` (string, required): 端點名稱（如 "/api/orders"）
- `start` (int, required): 開始時間 (Unix timestamp)
- `end` (int, required): 結束時間 (Unix timestamp)
- `limit` (int, optional): 回傳數量限制，預設 5

**Response**:
```json
{
  "service": "order-service",
  "endpoint": "/api/orders",
  "start": 1705392000,
  "end": 1705393800,
  "count": 3,
  "traces": [
    {
      "traceId": "abc123def456",
      "durationMs": 32000,
      "startTime": 1705392100,
      "endTime": 1705392132
    }
  ]
}
```

**Workflow 節點**: `node-tempo-search`

---

#### 1.2 取得最慢 Span

```
GET /v1/traces/{traceId}/longest-span
```

**Path Parameters**:
- `traceId` (string, required): Trace ID

**Response**:
```json
{
  "traceId": "abc123def456",
  "longestSpan": {
    "spanId": "span001",
    "name": "OrderRepository.createOrder",
    "service": "order-service",
    "serviceName": "order-service",
    "durationMs": 28000,
    "startTime": 1705392100,
    "endTime": 1705392128
  }
}
```

**Workflow 節點**: `node-trace-detail`

---

### 2. Source Code API (tempo-otlp-trace-demo)

**基礎 URL**: `http://localhost:8080`

#### 2.1 搜尋原始碼

```
POST /api/source-code
```

**Request Body**:
```json
{
  "spanName": "OrderRepository.createOrder"
}
```

**Response**:
```json
{
  "spanName": "OrderRepository.createOrder",
  "filePath": "/src/main/java/com/example/OrderRepository.java",
  "functionName": "createOrder",
  "startLine": 45,
  "endLine": 78,
  "sourceCode": "public Order createOrder(OrderRequest req) {\n  // ... code ...\n}"
}
```

**Workflow 節點**: `node-rag-search`

---

## 🚫 已停用的 API 節點

以下節點在當前版本中已停用：

### 1. Service Mapping API
- **節點**: `node-mapping-api`, `node-parse-mapping`
- **狀態**: 已停用
- **替代方案**: 直接使用告警信中的 `service_name` 欄位

### 2. Topology API
- **節點**: `node-topology-api`
- **狀態**: 未實作
- **未來計劃**: 可整合 K8s/Service Mesh 資料

### 3. SNMP/Metrics API
- **節點**: `node-snmp-api`
- **狀態**: 未實作
- **未來計劃**: 可整合 Prometheus/Grafana 指標

### 4. Infrastructure Evidence Merge
- **節點**: `node-merge-infra-evidence`
- **狀態**: 已停用
- **原因**: 依賴的 topology 和 SNMP API 未實作

---

## 🔄 完整流程圖

```
告警信輸入 (node-start)
    ↓
解析告警信 (node-parse-alert) [LLM]
    ↓
解析時間軸 (node-parse-time) [Code]
    ↓
搜尋慢 Traces (node-tempo-search) [GET /v1/traces]
    ↓
判斷異常狀態 (node-judge-anomaly) [Code]
    ↓
取得 Trace 詳情 (node-trace-detail) [GET /v1/traces/{id}/longest-span]
    ↓
分析 Critical Path (node-critical-path) [Code]
    ↓
RAG 搜尋原始碼 (node-rag-search) [POST /api/source-code]
    ↓
Root Cause Analysis (node-rca) [LLM]
    ↓
輸出 RCA 報告 (node-end)
```

---

## 📊 資料流轉換

### 階段 1: 告警解析
**輸入**: 原始告警信文字
**輸出**: 結構化 JSON
```json
{
  "event": "系統回應緩慢",
  "service_name": "order-service",
  "time_stamp": "2026-01-16 14:30:00",
  "url": "http://api.example.com/api/orders",
  "env": "PROD",
  "user_symptom": "slow"
}
```

### 階段 2: 時間軸解析
**輸入**: `time_stamp` (string)
**輸出**: UTC 時間範圍 + Unix timestamps
```json
{
  "start": "2026-01-16T06:15:00Z",
  "end": "2026-01-16T06:30:00Z",
  "start_unix": 1705392900,
  "end_unix": 1705393800
}
```

### 階段 3: Trace 搜尋
**輸入**: `service`, `endpoint`, `start_unix`, `end_unix`
**輸出**: Traces 列表
```json
{
  "service": "order-service",
  "endpoint": "/api/orders",
  "traces": [
    { "traceId": "...", "durationMs": 32000 }
  ]
}
```

### 階段 4: 異常判斷
**輸入**: Traces 列表
**輸出**: 異常狀態 + Top Trace
```json
{
  "is_anomalous": true,
  "top_trace_id": "abc123",
  "top_trace_duration_ms": 32000,
  "slow_trace_count": 5,
  "baseline_p95_ms": 1200
}
```

### 階段 5: Critical Path 分析
**輸入**: Longest Span 資訊
**輸出**: 嫌疑點列表
```json
{
  "top_suspect_service": "order-service",
  "top_suspect_operation": "OrderRepository.createOrder",
  "top_suspect_duration_ms": 28000,
  "top_suspect_type": "longest_span",
  "suspects_json": "[...]"
}
```

### 階段 6: 原始碼檢索
**輸入**: Span 名稱
**輸出**: 程式碼片段
```json
{
  "spanName": "OrderRepository.createOrder",
  "filePath": "/src/.../OrderRepository.java",
  "sourceCode": "..."
}
```

---

## 🔧 環境變數設定

在 Dify 中設定以下環境變數：

```yaml
TEMPO_API_URL: http://localhost:8081
RAG_API_URL: http://localhost:8080
```

---

## ✅ 成功標準

1. ✅ 告警信能成功解析為結構化資料
2. ✅ Tempo API 能回傳慢 traces
3. ✅ Longest span API 能識別最慢的 span
4. ✅ RAG API 能找到對應的原始碼
5. ✅ LLM 能生成完整的 RCA 報告

---

## 📝 範例告警信

```
序號：20166775_20292200
告警狀態：告警中
事件等級：Critical
事件名稱：系統回應緩慢
服務名稱：order-service
監控URL：http://api.example.com/api/orders
環境資訊：PROD
事件發生時間：2026-01-16 14:30:00
```

---

## 🚀 測試步驟

1. 確保 tempo-latency-anomaly-service 在 port 8081 運行
2. 確保 tempo-otlp-trace-demo 在 port 8080 運行
3. 在 Dify 中匯入 `slow-rca-workflow.yml`
4. 設定環境變數 TEMPO_API_URL 和 RAG_API_URL
5. 使用範例告警信測試完整流程
6. 檢查每個節點的輸出是否正確

---

## 📞 相關文件

- **實作計劃**: `cursor-plan://plan.md`
- **Workflow 定義**: `slow-rca-workflow.yml`
- **Dify README**: `dify-readme.md`

---

## 🔄 版本歷史

### v1.1 (2026-01-22)
- ✅ 更新 Tempo API 端點為實際的 tempo-latency-anomaly-service
- ✅ 更新 RAG API 端點為實際的 tempo-otlp-trace-demo
- ✅ 移除未實作的 mapping/topology/snmp 節點
- ✅ 簡化流程，直接使用告警信中的 service_name
- ✅ 更新所有解析邏輯以處理新的 API 格式

### v1.0 (初始版本)
- 設計原型 workflow
- 定義預期的 API 契約
