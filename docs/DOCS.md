# 文檔索引

## 🔗 GitHub Repositories

- **主專案**: https://github.com/kokjohn0824/rag-slow
- **Anomaly Service**: https://github.com/kokjohn0824/tempo-latency-anomaly-service
- **Trace Demo**: https://github.com/kokjohn0824/tempo-otlp-trace-demo

詳細資訊請參考 [GITHUB_REPOS.md](GITHUB_REPOS.md)

---

## 主要文檔

### 📖 [README.md](README.md)
系統概述、架構說明、使用流程

**適合**: 初次使用者、了解系統功能

**內容**:
- 系統功能介紹
- 服務組成說明
- 系統架構圖
- 基本使用流程
- 常用指令
- 故障排除

---

### 🚀 [QUICKSTART.md](QUICKSTART.md)
5 分鐘快速上手指南

**適合**: 想快速試用系統的使用者

**內容**:
- 快速啟動步驟
- 驗證服務
- 產生測試資料
- 執行分析
- 常見使用場景

---

### 🤖 [AGENT_GUIDE.md](AGENT_GUIDE.md)
Coding Agent 參考指南

**適合**: AI coding agents、開發者

**內容**:
- API 端點總覽
- 資料結構定義
- 典型工作流程
- 開發指南
- 常見任務範例
- 錯誤處理

---

### 🚢 [DEPLOYMENT.md](DEPLOYMENT.md)
遠端部署指南

**適合**: DevOps、系統管理員

**內容**:
- 前置需求和 SSH 設定
- 快速部署指令
- 部署流程詳解
- 驗證和測試
- 更新和回滾
- 故障排除
- 安全建議

---

### 📋 [HANDOVER.md](HANDOVER.md)
Workflow 移植任務交接文件

**適合**: 需要將流程移植到 n8n/Dify 的開發者

**內容**:
- 專案背景快速了解
- 需移植的 8 個步驟
- API 快速參考
- Workflow 設計建議
- 驗收標準

---

### 🔄 [workflow-api-usage.md](workflow-api-usage.md)
Workflow API 使用說明

**適合**: Workflow 開發者、整合工程師

**內容**:
- 使用中的 API 端點
- 資料流轉換
- 完整流程圖
- 測試步驟

---

### 📊 [dify-readme.md](dify-readme.md)
Dify Workflow 完整專案文檔

**適合**: Dify 平台使用者

**內容**:
- 工作流程詳解
- 節點設計說明
- 快速開始
- 設計原則
- 注意事項與風險

---

## 服務文檔

### Tempo Latency Anomaly Service

**主文檔**: [tempo-latency-anomaly-service/README.md](tempo-latency-anomaly-service/README.md)

**API 文檔**: http://localhost:8081/swagger/

**功能**:
- Trace 查詢和分析
- 效能異常檢測
- Span 詳細資訊

---

### Tempo OTLP Trace Demo

**主文檔**: [tempo-otlp-trace-demo/README.md](tempo-otlp-trace-demo/README.md)

**API 文檔**: http://localhost:8080/swagger/

**功能**:
- 產生測試 traces
- Span 到原始碼映射
- 原始碼查詢 API

---

## 測試腳本

### [test-integration.sh](test-integration.sh)
完整的整合測試腳本

**執行**:
```bash
./test-integration.sh
```

**測試內容**:
1. 查詢可用 endpoints
2. 產生測試 traces
3. 搜尋 traces
4. 分析 longest span
5. 獲取 child spans
6. 查詢原始碼
7. 驗證結果

---

## 快速參考

### 服務端點

| 服務 | 端點 | 說明 |
|------|------|------|
| Anomaly Service | http://localhost:8081 | 效能分析 API |
| Trace Demo | http://localhost:8080 | 原始碼映射 API |
| Grafana | http://localhost:3000 | 視覺化介面 |
| Tempo | http://localhost:3200 | Trace 儲存後端 |

### Swagger UI

- **Anomaly Service**: http://localhost:8081/swagger/
- **Trace Demo**: http://localhost:8080/swagger/

### 健康檢查

```bash
curl http://localhost:8081/health  # Anomaly Service
curl http://localhost:8080/health  # Trace Demo
curl http://localhost:3200/ready   # Tempo
```

---

## 使用流程圖

```
開始
  │
  ├─→ 閱讀 README.md（了解系統）
  │
  ├─→ 執行 QUICKSTART.md（快速試用）
  │
  ├─→ 查看 Swagger UI（探索 API）
  │
  ├─→ 執行 test-integration.sh（驗證功能）
  │
  ├─→ 參考 AGENT_GUIDE.md（深入開發）
  │
  ├─→ 閱讀 DEPLOYMENT.md（部署到生產）
  │
  └─→ 參考 HANDOVER.md（移植到 n8n/Dify）
```

---

## 問題排查

遇到問題時的查找順序：

1. **服務無法啟動** → 查看 [README.md - 故障排除](README.md#🐛-故障排除)
2. **API 使用問題** → 查看 [Swagger UI](http://localhost:8081/swagger/)
3. **開發問題** → 查看 [AGENT_GUIDE.md](AGENT_GUIDE.md)
4. **服務文檔** → 查看各服務的 README.md

---

## 文檔維護

### 更新文檔

當修改 API 時：
1. 更新程式碼中的 Swagger 註解
2. 執行 `make swagger` 生成新文檔
3. 更新相關的 README.md
4. 測試所有範例指令

### 文檔結構原則

- **主資料夾**: 只保留概述和快速參考
- **服務資料夾**: 詳細的技術文檔
- **避免重複**: 使用連結而非複製內容
- **保持更新**: API 變更時同步更新文檔

---

## 外部資源

- [Grafana Tempo 文檔](https://grafana.com/docs/tempo/latest/)
- [OpenTelemetry 文檔](https://opentelemetry.io/docs/)
- [Swagger/OpenAPI 規範](https://swagger.io/specification/)
- [Docker Compose 文檔](https://docs.docker.com/compose/)
