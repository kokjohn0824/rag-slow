# Dify 慢速告警 RCA 工作流 - 完整專案文檔

> **自動化根因分析系統** - 從告警信到根因定位的完整證據鏈  
> **版本**: v2.0 | **最後更新**: 2026-01-19

---

## 📖 目錄

1. [專案簡介](#-專案簡介)
2. [系統架構](#-系統架構)
3. [工作流程詳解](#-工作流程詳解)
4. [資料來源與 API 契約](#-資料來源與-api-契約)
5. [節點設計說明](#-節點設計說明)
6. [快速開始](#-快速開始)
7. [專案結構](#-專案結構)
8. [設計原則](#-設計原則)
9. [注意事項與風險](#-注意事項與風險)

---

## 📖 專案簡介

### 專案目標

本專案實現一個 **Dify Workflow**，用於自動化處理「**使用者反應系統變慢**」的告警事件。透過整合多維度資料源，提供從告警到根因定位的完整分析流程。

### 核心能力

```
告警信輸入 → 自動解析 → 服務定位 → Trace 驗證 → 慢點分析 → 原始碼檢索 → RCA 報告
```

**具體實現**:
1. ✅ 自動解析非結構化告警信內容
2. ✅ 透過 domain/port/API 路徑定位服務與版本
3. ✅ 從 Tempo 搜尋並驗證慢速 Traces
4. ✅ 分析 Critical Path 並定位最可疑的 Span/Method
5. ✅ 從 RAG 知識庫檢索對應原始碼片段
6. ✅ 生成結構化 RCA 報告（含證據鏈、根因假說、改善建議）

### 關鍵特點

| 特點 | 說明 |
|------|------|
| **高效設計** | 僅使用 **2 個 LLM 節點**，其餘皆為 API/Code 節點 |
| **證據導向** | 每個結論都追溯到 TraceID、SpanID、Code Location |
| **可擴展** | 模組化設計，易於新增資料源或分析邏輯 |
| **可驗證** | 輸出包含「缺少的資訊」清單，不做無根據斷言 |

---

## 🏗️ 系統架構

### 高階架構圖

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Dify Workflow 工作流                              │
│                                                                           │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌────────┐ │
│  │ Stage A  │──▶│ Stage B  │──▶│ Stage C  │──▶│ Stage D  │──▶│Stage E │ │
│  │  告警    │   │  服務    │   │  Tempo   │   │  慢點    │   │ 原始碼 │ │
│  │  解析    │   │  映射    │   │  查詢    │   │  定位    │   │ 檢索   │ │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘   └────────┘ │
│       │              │              │              │              │       │
│       ▼              ▼              ▼              ▼              ▼       │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                    Stage F: RCA 報告生成                            │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
         │              │              │              │              │
         ▼              ▼              ▼              ▼              ▼
    ┌─────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
    │   LLM   │   │ Mapping  │   │  Tempo   │   │  Trace   │   │ RAG/Git  │
    │ Parser  │   │   API    │   │   API    │   │ Analyzer │   │   API    │
    └─────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
```

### 依賴的外部系統

| 系統 | 用途 | 資料類型 |
|------|------|----------|
| **Mapping API** | 將 URL/Domain 映射到服務名稱與版本 | 路由表、服務拓撲 |
| **Tempo API** | 查詢分散式追蹤資料 | Traces、Spans、Duration |
| **Topology API** | 查詢服務拓撲與依賴關係 | 1-hop 依賴、呼叫路徑 |
| **SNMP/Metrics API** | 查詢基礎設施指標與異常 | CPU、Memory、Network、Disk |
| **RAG/Git API** | 檢索服務原始碼 | Code Snippets、Method 定義 |
| **LLM** | 解析告警信與生成 RCA 報告 | 自然語言處理 |

---

## 🔄 工作流程詳解

### 節點類型圖例

| 符號 | 類型 | Dify 節點類型 | 說明 |
|------|------|---------------|------|
| 🤖 | **LLM** | `llm` | 需要自然語言理解/生成（僅 2 個） |
| 🌐 | **HTTP** | `http-request` | 直接呼叫外部 API |
| 💻 | **Code** | `code` | Python 程式碼處理（解析/計算） |
| ▶️ | **Start/End** | `start`/`end` | 工作流起始與結束節點 |

---

### Stage A: 告警解析與標準化

**目標**: 將非結構化告警信轉換為結構化 JSON 資料

```
┌─────────────┐      ┌──────────────┐      ┌──────────────┐
│ ▶️ 開始     │─────▶│ 🤖 解析告警信 │─────▶│ 💻 解析時間軸│
│  輸入告警信 │      │   (LLM)      │      │  (Code)     │
└─────────────┘      └──────────────┘      └──────────────┘
```

**處理流程**:

1. **節點 1: 開始** (`start`)
   - **輸入**: `targetLog`（告警信全文，最多 5000 字元）
   - **範例輸入**:
     ```
     序號：20166775_20292200
     告警狀態：告警中
     事件等級：Critical
     事件名稱：系統回應緩慢
     服務名稱：order-service
     監控 URL：http://api.example.com/api/orders
     環境資訊：PROD
     事件發生時間：2026-01-16 14:30:00
     ```

2. **節點 2: 解析告警信** (`llm`)
   - **使用 Agent**: Alert Parser Agent
   - **技術**: LLM + Structured Output（JSON Schema）
   - **輸出欄位**:
     ```json
     {
       "event": "系統回應緩慢",
       "device": "監控伺服器",
       "host": "api.example.com",
       "env": "prod",
       "service_name": "order-service",
       "time_stamp": "2026-01-16 14:30:00",
       "url": "http://api.example.com/api/orders",
       "domain": "api.example.com",
       "port": null,
       "api_path": "/api/orders",
       "http_method": "POST",
       "user_symptom": "slow"
     }
     ```
   - **user_symptom 枚舉值**: `slow`, `timeout`, `lag`, `error`, `intermittent`, `unknown`

3. **節點 3: 解析時間軸** (`code`)
   - **功能**: 將本地時間轉換為 UTC 時間範圍
   - **時間窗口**: `[事件時間 - 15 分鐘, 事件時間]`
   - **預設時區**: Asia/Taipei
   - **輸出**:
     ```json
     {
       "start": "2026-01-16T06:15:00Z",
       "end": "2026-01-16T06:30:00Z"
     }
     ```

---

### Stage B: 服務映射

**目標**: 透過 URL/Domain/API 路徑定位實際執行的服務與版本

```
┌──────────────┐      ┌──────────────┐
│ 🌐 查詢服務  │─────▶│ 💻 解析映射  │
│   映射 API   │      │   結果       │
└──────────────┘      └──────────────┘
```

**處理流程**:

4. **節點 4: 查詢服務映射** (`http-request`)
   - **API Endpoint**: `POST {{DEV_DOMAIN}}:8000/api/service-mapping`
   - **Request Body**:
     ```json
     {
       "timestamp": "2026-01-16T06:30:00Z",
       "env": "prod",
       "domain": "api.example.com",
       "port": 443,
       "api_path": "/api/orders",
       "url": "http://api.example.com/api/orders"
     }
     ```
   - **重試策略**: 最多 3 次，間隔 100ms

5. **節點 5: 解析映射結果** (`code`)
   - **功能**: 提取 `rootServiceName`、`version`、`owner_team` 等資訊
   - **決策邏輯**:
     - 若 `confidence >= 0.7` 且僅 1 個候選 → 直接使用
     - 否則 → 選擇第一個候選，並在報告中標註不確定性
   - **輸出**:
     ```json
     {
       "rootServiceName": "order-service",
       "service_name": "order-service",
       "version": "v2.3.1-abc1234",
       "owner_team": "order-team",
       "confidence": 0.95,
       "error": ""
     }
     ```

---

### Stage C: Tempo 查詢與驗證

**目標**: 從 Tempo 搜尋慢速 Traces 並驗證異常狀態

```
┌──────────────┐      ┌──────────────┐
│ 🌐 搜尋慢   │─────▶│ 💻 判斷異常  │
│  Traces     │      │   狀態       │
└──────────────┘      └──────────────┘
```

**處理流程**:

6. **節點 6: 搜尋慢 Traces** (`http-request`)
   - **API Endpoint**: `POST {{TEMPO_API_URL}}/api/v1/search_slow_traces`
   - **Request Body**:
     ```json
     {
       "rootServiceName": "order-service",
       "start_time": "2026-01-16T06:15:00Z",
       "end_time": "2026-01-16T06:30:00Z",
       "min_duration_ms": 1000,
       "limit": 5
     }
     ```
   - **Timeout**: Read 60s / Connect 10s

7. **節點 7: 判斷異常狀態** (`code`)
   - **功能**: 分析是否存在異常慢的 Traces
   - **異常判定**: `top_trace_duration > baseline_p95 * 1.5`
   - **輸出**:
     ```json
     {
       "is_anomalous": true,
       "top_trace_id": "abc123def456",
       "top_trace_duration_ms": 32450,
       "slow_trace_count": 5,
       "baseline_p95_ms": 1200,
       "evidence_summary": "找到 5 條慢 traces，最慢 32450ms，baseline p95 1200ms"
     }
     ```

---

### Stage D: 慢點定位

**目標**: 分析 Trace 詳情，找出 Critical Path 和最耗時的 Span

```
┌──────────────┐      ┌──────────────┐
│ 🌐 取得 Trace│─────▶│ 💻 分析      │
│   詳情       │      │ Critical Path│
└──────────────┘      └──────────────┘
```

**處理流程**:

8. **節點 8: 取得 Trace 詳情** (`http-request`)
   - **API Endpoint**: `POST {{TEMPO_API_URL}}/api/v1/analyze_trace`
   - **Request Body**:
     ```json
     {
       "traceId": "abc123def456"
     }
     ```

9. **節點 9: 分析 Critical Path** (`code`)
   - **功能**: 
     - 提取 suspects 清單（嫌疑 Spans）
     - 按 `duration_ms` 排序
     - 識別 Critical Path
   - **嫌疑點類型**: `db`, `downstream_http`, `cache`, `queue`, `unknown`
   - **輸出**:
     ```json
     {
       "suspects_json": "[{\"service\":\"order-service\",\"operation\":\"OrderRepository.createOrder\",\"duration_ms\":28000}]",
       "top_suspect_service": "order-service",
       "top_suspect_operation": "OrderRepository.createOrder",
       "top_suspect_duration_ms": 28000,
       "top_suspect_type": "db",
       "critical_path_summary": "OrderRepository.createOrder (86.3%) → InventoryClient.checkStock (9.8%)"
     }
     ```

---

### Stage E: 基礎設施與拓撲證據收集

**目標**: 查詢服務拓撲與基礎設施指標,識別基礎設施層面的異常

```
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│ 🌐 查詢服務  │      │ 🌐 查詢      │─────▶│ 💻 整合證據  │
│   拓撲       │      │ SNMP/Metrics │      │             │
└──────────────┘      └──────────────┘      └──────────────┘
```

**處理流程**:

10. **節點 10: 查詢服務拓撲** (`http-request`)
    - **API Endpoint**: `POST {{TOPOLOGY_API_URL}}/api/topology/dependencies`
    - **Request Body**:
      ```json
      {
        "service": "order-service",
        "env": "prod",
        "timestamp": "2026-01-16T06:30:00Z",
        "depth": 1
      }
      ```
    - **預期回應**: 依賴服務列表、呼叫路徑

11. **節點 11: 查詢 SNMP/Metrics** (`http-request`)
    - **API Endpoint**: `POST {{SNMP_API_URL}}/api/metrics/query`
    - **Request Body**:
      ```json
      {
        "service": "order-service",
        "env": "prod",
        "start_time": "2026-01-16T06:15:00Z",
        "end_time": "2026-01-16T06:30:00Z",
        "metrics": ["cpu_usage", "memory_usage", "network_io", "disk_io"],
        "include_baseline": true
      }
      ```
    - **預期回應**: 指標統計值、baseline 對照、異常清單

12. **節點 12: 整合基礎設施證據** (`code`)
    - **功能**: 整合拓撲與 SNMP 資料
    - **輸出**:
      ```json
      {
        "topology_context": "{...}",
        "snmp_evidence": "{...}",
        "combined_json": "{...}"
      }
      ```

---

### Stage F: 原始碼檢索

**目標**: 從 RAG 知識庫檢索嫌疑 Method 的原始碼片段

```
┌──────────────┐
│ 🌐 RAG 搜尋 │
│  原始碼      │
└──────────────┘
```

**處理流程**:

13. **節點 13: RAG 搜尋原始碼** (`http-request`)
    - **API Endpoint**: `POST {{RAG_API_URL}}/api/code/search`
    - **Request Body**:
      ```json
      {
        "service": "order-service",
        "operation": "OrderRepository.createOrder",
        "version": "v2.3.1-abc1234",
        "context_lines": 100
      }
      ```
    - **預期回應**: Code snippet、檔案路徑、版本資訊

---

### Stage F: 根因分析與報告生成

**目標**: 整合所有證據，生成結構化 RCA 報告

```
┌──────────────┐      ┌──────────────┐
│ 🤖 Root     │─────▶│ ▶️ 輸出      │
│  Cause      │      │   (End)     │
│ Analysis    │      │             │
└──────────────┘      └──────────────┘
```

**處理流程**:

14. **節點 14: Root Cause Analysis** (`llm`)
    - **使用 Agent**: RCA Report Agent
    - **輸入資料**:
      - Stage A: 告警解析結果
      - Stage B: 服務映射資訊
      - Stage C: Tempo 證據（慢 traces、baseline）
      - Stage D: Critical Path 分析
      - Stage E: 拓撲與基礎設施證據
      - Stage F: 原始碼片段
    - **輸出格式**: Markdown 報告，包含：
      - **執行摘要**: 事件時間、影響範圍、症狀描述
      - **證據鏈**: 每個結論的證據來源（TraceID、SpanID、Code）
      - **根因假說**: 包含信心度（高/中/低）
      - **改善建議**: 短期止血/中期修復/長期治理
      - **缺少的資訊**: 明確列出需補充的資料

15. **節點 15: 輸出** (`end`)
    - **輸出變數**: `result`（完整 RCA 報告文字）

---

### 完整流程圖

```
┌─────────────┐
│ ▶️ 開始     │ (start)
│  targetLog  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 🤖 解析告警信 │ (llm) ← Stage A
│  structured │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 💻 解析時間軸 │ (code)
│  UTC 轉換   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 🌐 查詢服務  │ (http-request) ← Stage B
│   映射      │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 💻 解析映射  │ (code)
│   結果      │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 🌐 搜尋慢   │ (http-request) ← Stage C
│  Traces    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 💻 判斷異常  │ (code)
│   狀態      │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 🌐 Trace   │ (http-request) ← Stage D
│  詳情      │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 💻 分析    │ (code)
│ Critical  │
│   Path    │
└──────┬──────┘
       │
       ├─────────────────┐
       │                 │
       ▼                 ▼
┌─────────────┐   ┌─────────────┐
│ 🌐 查詢服務 │   │ 🌐 查詢     │ ← Stage E
│   拓撲      │   │ SNMP/Metrics│
└──────┬──────┘   └──────┬──────┘
       │                 │
       └────────┬────────┘
                ▼
        ┌─────────────┐
        │ 💻 整合     │ (code)
        │ 基礎設施    │
        │   證據      │
        └──────┬──────┘
               │
               ▼
        ┌─────────────┐
        │ 🌐 RAG 搜尋 │ (http-request) ← Stage F
        │  原始碼    │
        └──────┬──────┘
               │
               ▼
        ┌─────────────┐
        │ 🤖 Root    │ (llm) ← Stage G
        │  Cause    │
        │ Analysis  │
        └──────┬──────┘
               │
               ▼
        ┌─────────────┐
        │ ▶️ 輸出     │ (end)
        │  result   │
        └─────────────┘
```

---

## 📊 資料來源與 API 契約

### 1. Service Mapping API

**用途**: 將 URL/Domain 映射到實際服務名稱與部署版本

**Endpoint**: `POST /api/service-mapping`

**Request**:
```json
{
  "timestamp": "2026-01-16T06:30:00Z",
  "env": "prod",
  "domain": "api.example.com",
  "port": 443,
  "api_path": "/api/v1/orders/create",
  "url": "https://api.example.com/api/v1/orders/create"
}
```

**Response**:
```json
{
  "confidence": 0.95,
  "candidates": [
    {
      "rootServiceName": "order-service",
      "service_name": "order-service",
      "cluster": "prod-cluster-01",
      "namespace": "production",
      "workload_type": "deployment",
      "workload_name": "order-service-deployment",
      "version": "v2.3.1-abc1234",
      "owner_team": "order-team",
      "instance_targets": ["order-service-pod-xyz123"],
      "routing_evidence": "ingress rule: api.example.com/api/v1/orders/* -> order-service:8080"
    }
  ]
}
```

**資料來源需求**:
- Kubernetes Ingress/Gateway 路由規則
- Service Mesh（如 Istio）路由配置
- Load Balancer 配置
- 服務註冊中心（如 Consul、Eureka）
- 版本部署記錄

---

### 2. Tempo Search API

**用途**: 搜尋指定服務在特定時間窗內的慢速 Traces

**Endpoint**: `POST /api/v1/search_slow_traces`

**Request**:
```json
{
  "rootServiceName": "order-service",
  "start_time": "2026-01-16T06:15:00Z",
  "end_time": "2026-01-16T06:30:00Z",
  "http_route": "/api/v1/orders/create",
  "http_method": "POST",
  "min_duration_ms": 1000,
  "limit": 5
}
```

**Response**:
```json
{
  "traces": [
    {
      "traceId": "abc123def456",
      "duration_ms": 32450,
      "rootTraceName": "POST /api/v1/orders/create",
      "startTime": "2026-01-16T06:30:15Z",
      "status_code": 200
    }
  ],
  "total_count": 47,
  "baseline": {
    "p50_ms": 250,
    "p95_ms": 1200,
    "p99_ms": 3500
  }
}
```

**資料來源需求**:
- Tempo 分散式追蹤系統
- 服務需埋點 OpenTelemetry/Jaeger Spans
- 建議保留至少 15 天的追蹤資料
- Baseline 需有對照窗口資料（如 t-1h ~ t-50m）

---

### 3. Trace Analyze API

**用途**: 分析單一 Trace 的 Critical Path 與嫌疑 Spans

**Endpoint**: `POST /api/v1/analyze_trace`

**Request**:
```json
{
  "traceId": "abc123def456"
}
```

**Response**:
```json
{
  "traceId": "abc123def456",
  "total_duration_ms": 32450,
  "span_count": 24,
  "suspects": [
    {
      "spanId": "span_001",
      "service": "order-service",
      "operation": "OrderRepository.createOrder",
      "duration_ms": 28000,
      "self_time_ms": 500,
      "pct_of_trace": 86.3,
      "suspect_type": "db",
      "is_critical_path": true,
      "evidence_tags": {
        "db.statement": "INSERT INTO orders ...",
        "db.type": "postgresql"
      }
    },
    {
      "spanId": "span_002",
      "service": "inventory-service",
      "operation": "InventoryClient.checkStock",
      "duration_ms": 3200,
      "self_time_ms": 3100,
      "pct_of_trace": 9.8,
      "suspect_type": "downstream_http",
      "is_critical_path": true,
      "evidence_tags": {
        "http.url": "http://inventory-service/api/stock/check",
        "http.status_code": 200
      }
    }
  ],
  "critical_path": ["span_001", "span_002", "span_003"]
}
```

**資料來源需求**:
- Tempo Trace Detail API
- Span 需包含完整的 Tags/Attributes
- 建議 Tag 規範: `db.*`, `http.*`, `rpc.*`, `cache.*`

---

### 4. RAG Code Search API

**用途**: 從知識庫檢索對應服務版本的原始碼片段

**Endpoint**: `POST /api/code/search`

**Request**:
```json
{
  "service": "order-service",
  "operation": "OrderRepository.createOrder",
  "version": "v2.3.1-abc1234",
  "context_lines": 100
}
```

**Response**:
```json
{
  "repo": "git@github.com:company/order-service.git",
  "ref": "abc1234",
  "file_path": "src/main/java/com/company/order/repository/OrderRepository.java",
  "start_line": 45,
  "end_line": 120,
  "snippet": "public class OrderRepository {\n    public Order createOrder(...) {\n        ...\n    }\n}",
  "symbol": {
    "class": "OrderRepository",
    "method": "createOrder",
    "package": "com.company.order.repository"
  },
  "code_provenance": {
    "retrieved_version": "abc1234",
    "deployed_version": "abc1234",
    "version_match": true
  }
}
```

**資料來源需求**:
- RAG 向量知識庫（如 Weaviate、Qdrant）
- Git Repository（需與部署版本對齊）
- Code Indexing 工具（如 Sourcegraph、ctags）
- **版本對齊策略**:
  - **Level 0 (MVP)**: 不切版本，報告中標註風險
  - **Level 1 (推薦)**: RAG 定位 + Git API 取指定 ref
  - **Level 2 (長期)**: Per-release embeddings

---

### 資料來源總覽

| 資料來源 | 必要性 | 用途 | 備註 |
|----------|--------|------|------|
| **Mapping API** | 🔴 必須 | 服務定位 | 需整合路由配置/服務註冊 |
| **Tempo** | 🔴 必須 | Trace 查詢 | 需埋點 OpenTelemetry |
| **RAG/Git** | 🟡 建議 | 原始碼檢索 | 無此資料源時，報告僅含 Trace 分析 |
| **Metrics** | ⚪ 可選 | Baseline 對比 | 用於降級策略（Tempo 查無資料時） |
| **Logs** | ⚪ 可選 | 補充證據 | 用於深入分析 |

---

## 🛠️ 節點設計說明

### 設計原則: 最小化 LLM 使用

| Stage | 節點類型 | 原因 |
|-------|----------|------|
| **A - 告警解析** | 🤖 LLM | 需要理解非結構化自然語言文字 |
| **B - 服務映射** | 🌐 HTTP + 💻 Code | 直接查詢 API，用 Code 做決策邏輯 |
| **C - Tempo 查詢** | 🌐 HTTP + 💻 Code | 直接查詢 API，用 Code 判斷異常 |
| **D - 慢點定位** | 🌐 HTTP + 💻 Code | API 取 Trace 資料，Code 分析 Critical Path |
| **E - 原始碼檢索** | 🌐 HTTP | 直接查詢 RAG API |
| **F - RCA 報告** | 🤖 LLM | 需要推論、綜合分析與生成結構化報告 |

### LLM 節點數量對比

- **原始設計**: 6 個 LLM Agent（每個 Stage 都用 LLM）
- **優化後**: **僅 2 個 LLM 節點**
  - 解析告警信（Stage A）
  - Root Cause Analysis（Stage F）
- **效益**: 降低成本、提升回應速度、減少幻覺風險

### 節點統計

| 節點類型 | 數量 | 節點名稱 |
|----------|------|----------|
| 🤖 LLM | 2 | 解析告警信、Root Cause Analysis |
| 🌐 HTTP | 6 | 查詢服務映射、搜尋慢 Traces、取得 Trace 詳情、查詢服務拓撲、查詢 SNMP/Metrics、RAG 搜尋原始碼 |
| 💻 Code | 5 | 解析時間軸、解析映射結果、判斷異常狀態、分析 Critical Path、整合基礎設施證據 |
| ▶️ Start/End | 2 | 開始、輸出 |
| **總計** | **15** | |

---

## 🚀 快速開始

### 前置需求

1. **Dify 平台**: 自建或使用 Dify Cloud
2. **LLM 模型**: 
   - YML 預設使用本地 Qwen2.5-14B-Instruct
   - 可替換為 OpenAI/Claude/其他模型
3. **外部 API**: 
   - Service Mapping API
   - Tempo API（需實作 2 個 endpoint）
   - RAG Code Search API

---

### Step 1: 匯入 Workflow

1. 登入 Dify 控制台
2. 進入「工作室」→「匯入 DSL」
3. 上傳 `slow-rca-workflow.yml`
4. 檢查節點連接關係

---

### Step 2: 設定環境變數

在 Dify Workflow 設定中配置以下環境變數:

| 變數名稱 | 說明 | 範例值 | 必要性 |
|----------|------|--------|--------|
| `DEV_DOMAIN` | Mapping API 基礎 URL | `http://192.168.4.208` | 🔴 必須 |
| `TEMPO_API_URL` | Tempo 查詢 API 基礎 URL | `http://tempo.example.com` | 🔴 必須 |
| `TOPOLOGY_API_URL` | 拓撲 API 基礎 URL | `http://topology.example.com` | 🟡 建議 |
| `SNMP_API_URL` | SNMP/Metrics API 基礎 URL | `http://metrics.example.com` | 🟡 建議 |
| `RAG_API_URL` | RAG 知識庫 API 基礎 URL | `http://rag.example.com` | 🔵 可選 |

**配置路徑**: Workflow 設定 → 環境變數 → 編輯

---

### Step 3: 調整 LLM 模型

**預設模型**: `/Users/chtadmin/mlx/models/Qwen2.5-14B-Instruct-bf16`

**替換步驟**:
1. 開啟 `slow-rca-workflow.yml`
2. 搜尋 `model.name` 欄位
3. 修改為你的模型路徑或 Provider ID

**範例**:
```yaml
model:
  name: gpt-4o                    # OpenAI
  provider: openai
  
model:
  name: claude-3-sonnet-20240320  # Anthropic
  provider: anthropic
```

---

### Step 4: 測試執行

1. **準備測試資料**: 使用範例告警信（YML 中已內建）
   ```
   序號：20166775_20292200
   告警狀態：告警中
   事件等級：Critical
   事件名稱：系統回應緩慢
   服務名稱：order-service
   監控 URL：http://api.example.com/api/orders
   環境資訊：PROD
   事件發生時間：2026-01-16 14:30:00
   ```

2. **執行 Workflow**: 點選「執行」按鈕

3. **查看輸出**: 檢查 RCA 報告品質
   - 是否包含完整證據鏈?
   - 根因假說是否合理?
   - 是否明確標註缺少的資訊?

---

### Step 5: API Endpoint 實作（重要）

YML 中的 API URL 為 **placeholder**，需要實作或調整:

| Endpoint | 實作狀態 | 替代方案 |
|----------|----------|----------|
| `/api/service-mapping` | ❌ 需實作 | 可用靜態映射表（JSON 檔） |
| `/api/v1/search_slow_traces` | ❌ 需實作 | 封裝 Tempo API |
| `/api/v1/analyze_trace` | ❌ 需實作 | 封裝 Tempo API + Span 分析邏輯 |
| `/api/topology/dependencies` | ❌ 需實作 | 查詢 Service Mesh / K8s / CMDB |
| `/api/metrics/query` | ❌ 需實作 | 封裝 Prometheus / CloudWatch |
| `/api/code/search` | ❌ 需實作 | 可先用 GitHub API 替代 |

**建議實作順序**:
1. Tempo Search/Analyze API（核心功能）
2. Service Mapping API（可先硬編碼）
3. Topology API（增強分析）
4. SNMP/Metrics API（增強分析）
5. RAG Code Search API（可後補）

**詳細 API 規格**: 請參閱 `API-SPECS.md` 文檔

---

## 📁 專案結構

```
danova-slow-incident-rca/
├── README.md                          # 📄 本文件 - 完整專案說明
├── Task.md                            # 📄 原始需求文件
├── PLAN.md                            # 📄 完整計劃書（v2.0）
├── API-SPECS.md                       # 📄 API 規格詳細說明（v2.1）
├── slow-rca-workflow.yml              # 📄 Dify Workflow 定義（可直接匯入）
├── RAG9-APP服務診斷.yml                # 📄 參考範例 Workflow
└── agents/                            # 📂 LLM Agent Prompt 定義
    ├── alert-parser-agent.md          # 📄 🤖 Stage A: 告警解析 Prompt
    └── rca-report-agent.md            # 📄 🤖 Stage G: RCA 報告生成 Prompt
```

### 檔案說明

| 檔案 | 說明 | 適用對象 |
|------|------|----------|
| **README.md** | 專案總覽、快速開始、API 契約 | 所有人 |
| **API-SPECS.md** | 詳細 API 規格與實作建議 | API 開發者 |
| **PLAN.md** | 詳細設計文檔、架構圖、里程碑 | 架構師、PM |
| **Task.md** | 原始需求與背景 | 產品經理 |
| **slow-rca-workflow.yml** | Dify Workflow 定義檔 | 開發者 |
| **agents/alert-parser-agent.md** | 告警解析 LLM Prompt | Prompt Engineer |
| **agents/rca-report-agent.md** | RCA 報告生成 LLM Prompt | Prompt Engineer |

---

## 📐 設計原則

### 1. 證據鏈完整性

**要求**: 每個結論都必須能回溯到具體證據

**實作**:
- Tempo 查詢 → 包含查詢條件、時間窗、traceId
- Span 分析 → 包含 spanId、service、operation、duration、tags
- 程式碼定位 → 包含 repo、file_path、line 範圍、class/method

**輸出範例**:
```markdown
### 證據鏈
1. **Tempo 查詢**: rootServiceName=order-service, timeRange=[2026-01-16T06:15:00Z, 2026-01-16T06:30:00Z]
2. **慢 Trace**: traceId=abc123def456, duration=32450ms（baseline p95=1200ms，異常倍數=27x）
3. **Critical Path**: span_001 (OrderRepository.createOrder) 佔 86.3%（28000ms）
4. **程式碼位置**: order-service/src/main/java/com/company/order/repository/OrderRepository.java:45-120
```

---

### 2. Baseline 對照

**要求**: 不僅說「這條 trace 很慢」，更要證明「異常慢」

**實作**:
- 對照窗口: t-1h ~ t-50m（避開事件窗）
- 對比指標: p50、p95、p99
- 異常閾值: `duration > baseline_p95 * 1.5`

**降級策略**:
- 若無 Baseline 資料 → 報告中標註「僅能確認絕對慢，無法判定是否異常」

---

### 3. 不做無根據斷言

**禁止**:
- ❌ 「推測可能是資料庫連線池滿」（無證據）
- ❌ 「懷疑是記憶體洩漏」（無證據）

**允許**:
- ✅ 「發現 db span 耗時 28s，佔 trace 86.3%，建議檢查該時段的 DB slow query log」
- ✅ 「該 method 呼叫了外部服務，但 http span 僅 3.2s，非主要瓶頸」

**實作**:
- RCA Report Agent 的 System Prompt 明確要求「每個結論必須引用證據」
- 若證據不足 → 輸出「缺少的資訊」清單

---

### 4. 欄位契約穩定性

**要求**: 所有中間節點輸出必須是固定 JSON Schema

**實作**:
- LLM 節點使用 `structured_output` 強制輸出 JSON
- Code 節點使用明確的 `outputs` 定義
- 時間處理統一: UTC ISO8601Z 格式（`2026-01-16T06:30:00Z`）

**時區規範**:
```
- xxx_local: 本地時間字串（如 "2026-01-16 14:30:00"）
- xxx_utc: ISO8601Z 格式（如 "2026-01-16T06:30:00Z"）
- xxx_epoch_ms: Unix timestamp（如 1768563000000）
```

---

### 5. 安全與權限

**考量事項**:
- Tempo、CMDB、Git/KB API 的 Token 權限分級
- 報告中的原始碼片段需脫敏（移除 secrets/URL/API keys）
- 建議使用 Service Account 而非個人 Token

---

## ⚠️ 注意事項與風險

### 常見風險與緩解措施

| 風險 | 影響 | 緩解措施 | 優先級 |
|------|------|----------|--------|
| **入口映射不準** | Gateway rewrite/A/B routing 導致誤判服務 | 多候選並行查詢 + Tempo 證據反向驗證 | 🔴 高 |
| **Trace Sampling** | 慢 trace 未被採樣，查無資料 | 降級到 metrics/logs，標註證據不足 | 🔴 高 |
| **時間對齊** | 告警時間 vs trace 時間偏移 | 擴大時間窗（t-15m ~ t） | 🟡 中 |
| **慢不是 App** | 實際瓶頸在 DB/外部 API/基礎設施 | span tags 分析 + suspect_type 分類 | 🟡 中 |
| **Code 版本不一致** | 分析錯誤版本的程式碼 | Code provenance 標註 + Git ref 對齊 | 🟡 中 |
| **LLM 幻覺** | 無根據的斷言或虛構資訊 | Prompt 強制輸出「證據與缺口」 | 🔴 高 |

---

### 降級策略

#### 1. Mapping API confidence 低

```
IF confidence < 0.7 OR candidates.length > 1:
  1. 對所有 candidates 並行查詢 Tempo
  2. 用 Tempo 查詢結果反向驗證（哪個有 slow trace）
  3. 報告中標註「多候選」與各自證據強弱
  
IF 仍找不到:
  輸出「需要補充的資訊」清單:
  - 完整 URL（含 query string）
  - 實際 request sample（curl 命令）
  - LB hostname / header host / SNI
  - Gateway access log
```

#### 2. Tempo 查不到 slow traces

```
可能原因:
- Sampling rate 過低，慢 trace 未被採樣
- 服務未埋點 OpenTelemetry
- 時間窗口偏移

降級處理:
1. 擴大時間窗（t-30m ~ t+5m）
2. 降低 min_duration_ms 閾值
3. 改用 metrics baseline（若可用）
4. 報告中標示「無 trace 證據，僅能做症狀推論」
5. 列出「建議補充的資料」
```

#### 3. RAG 查不到原始碼

```
可能原因:
- 服務未建立 RAG 知識庫
- 版本不一致
- Method 名稱變更

降級處理:
1. 僅輸出 Trace 分析結果（不含程式碼片段）
2. 報告中標註「缺少原始碼資訊」
3. 建議人工查看: [repo URL] + [suspected file path]
```

---

### 已知限制

| 限制 | 說明 | 解決方案 |
|------|------|----------|
| **不支援循環/迴圈** | 目前為線性流程，無法處理分支或迴圈 | 未來可用 Conditional/Loop 節點 |
| **不支援人工審核** | 完全自動化，無人工確認環節 | 可加入 Approval 節點（未來） |
| **不支援多服務關聯** | 僅分析單一 rootServiceName | 可擴展為多候選並行分析 |
| **Code Provenance Level 0** | 未做版本切換，報告標註風險 | 未來實作 Level 1/2 |

---

### 注意事項

1. **API Endpoint 為 Placeholder**:
   - YML 中的 API URL 需根據實際環境修改
   - 建議先實作 Mock API 以驗證流程

2. **LLM Model 路徑**:
   - 預設為本地 Qwen 模型路徑
   - 若使用雲端 LLM，需修改 provider 與 model name

3. **時區處理**:
   - 預設 Asia/Taipei
   - 若需變更，修改 Code 節點中的 `local_to_utc_iso_z_range` 函式

4. **Timeout 設定**:
   - Tempo API 讀取 timeout 為 60s
   - 若 Trace 資料量大，可能需調整

5. **重試策略**:
   - HTTP 節點預設重試 3 次，間隔 100ms
   - 可根據 API 穩定性調整

---

## 📞 聯絡與貢獻

### 專案負責人

- **姓名**: Alex Chang
- **版本**: v2.0
- **最後更新**: 2026-01-19

### 貢獻指南

歡迎提交 Issue 或 Pull Request!

**改進方向**:
- ✨ 新增更多資料來源（Metrics、Logs）
- ✨ 實作 Code Provenance Level 1/2
- ✨ 支援多服務關聯分析
- ✨ 加入人工審核節點
- ✨ 優化 Prompt 提升報告品質

---

## 📚 參考文件

- **PLAN.md**: 完整計劃書，包含架構設計、API 契約、里程碑
- **agents/alert-parser-agent.md**: 告警解析 LLM Prompt 設計
- **agents/rca-report-agent.md**: RCA 報告生成 LLM Prompt 設計
- **Task.md**: 原始需求文件

---

## 🎯 總結

本專案透過 **Dify Workflow** 實現了從告警到根因分析的完整自動化流程:

✅ **高效設計**: 僅 2 個 LLM 節點，其餘皆為 API/Code  
✅ **證據導向**: 每個結論都可回溯到具體證據  
✅ **可擴展**: 模組化設計，易於新增資料源  
✅ **可驗證**: 明確標註證據不足與缺少的資訊  

**適用場景**:
- 🎯 AIOps 自動化事件響應
- 🎯 SRE 團隊減少人工分析工作量
- 🎯 快速定位微服務架構中的效能瓶頸

---

*本專案基於 AIOps 與 Observability 最佳實踐設計，旨在提升事件響應效率與根因分析準確度。*
