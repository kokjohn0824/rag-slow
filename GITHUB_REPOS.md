# GitHub Repositories

本專案已成功上傳到 GitHub，包含三個 repositories。

## 📦 Repositories 列表

### 1. 主專案 (rag-slow)

**Repository**: https://github.com/kokjohn0824/rag-slow

**說明**: 分散式追蹤效能分析系統的整合專案

**內容**:
- 📖 完整的系統文檔
- 🚀 快速開始指南
- 🤖 Coding Agent 參考
- 🚢 部署指南
- 🧪 整合測試腳本

**主要文檔**:
- [README.md](README.md) - 系統概述
- [QUICKSTART.md](QUICKSTART.md) - 快速開始
- [AGENT_GUIDE.md](AGENT_GUIDE.md) - API 參考
- [DEPLOYMENT.md](DEPLOYMENT.md) - 部署指南
- [DOCS.md](DOCS.md) - 文檔索引

**Clone**:
```bash
git clone https://github.com/kokjohn0824/rag-slow.git
```

---

### 2. Tempo Latency Anomaly Service

**Repository**: https://github.com/kokjohn0824/tempo-latency-anomaly-service

**說明**: 效能異常檢測服務

**功能**:
- ⚡ 時間感知的延遲異常檢測
- 📊 基於 Grafana Tempo 的 trace 分析
- 🔍 O(1) 快速檢查路徑
- 🔄 自動更新 baseline
- 📈 可解釋的決策（非黑盒 ML）

**技術棧**:
- Go 1.24+
- Redis (快取)
- Grafana Tempo
- Docker & Docker Compose

**API 端點**:
- `GET /v1/available` - 查詢可用 endpoints
- `GET /v1/traces` - 搜尋 traces
- `GET /v1/traces/{traceId}/longest-span` - 獲取最慢 span
- `POST /v1/traces/child-spans` - 獲取 child spans
- `GET /swagger/` - Swagger UI

**Clone**:
```bash
git clone https://github.com/kokjohn0824/tempo-latency-anomaly-service.git
```

**快速啟動**:
```bash
cd tempo-latency-anomaly-service
docker-compose -f docker/compose.yml up -d
```

---

### 3. Tempo OTLP Trace Demo

**Repository**: https://github.com/kokjohn0824/tempo-otlp-trace-demo

**說明**: OpenTelemetry 追蹤產生與原始碼映射服務

**功能**:
- 🎯 產生真實世界的 trace 資料
- 🗺️ Span name → 原始碼映射
- 📝 完整的 Swagger UI 文檔
- 🔄 動態映射管理
- 📊 多種 trace 模式（訂單、報表、搜尋等）

**技術棧**:
- Go 1.24+
- OpenTelemetry
- Grafana Tempo
- OTEL Collector
- Docker & Docker Compose

**API 端點**:
- `GET /api/span-names` - 列出所有 span names
- `POST /api/source-code` - 獲取原始碼
- `GET /api/mappings` - 管理映射
- `POST /api/order/create` - 產生測試 trace
- `GET /swagger/` - Swagger UI

**Clone**:
```bash
git clone https://github.com/kokjohn0824/tempo-otlp-trace-demo.git
```

**快速啟動**:
```bash
cd tempo-otlp-trace-demo
docker-compose up -d
```

---

## 🚀 完整系統部署

### 方式 1: 使用主專案

```bash
# Clone 主專案
git clone https://github.com/kokjohn0824/rag-slow.git
cd rag-slow

# Clone 子專案
git clone https://github.com/kokjohn0824/tempo-latency-anomaly-service.git
git clone https://github.com/kokjohn0824/tempo-otlp-trace-demo.git

# 啟動 Anomaly Service
cd tempo-latency-anomaly-service
docker-compose -f docker/compose.yml up -d

# 啟動 Trace Demo
cd ../tempo-otlp-trace-demo
docker-compose up -d

# 執行整合測試
cd ..
./test-integration.sh
```

### 方式 2: 分別 Clone

```bash
# Clone 各個專案
git clone https://github.com/kokjohn0824/tempo-latency-anomaly-service.git
git clone https://github.com/kokjohn0824/tempo-otlp-trace-demo.git

# 分別啟動
cd tempo-latency-anomaly-service && docker-compose -f docker/compose.yml up -d
cd ../tempo-otlp-trace-demo && docker-compose up -d
```

---

## 📊 Repository 統計

| Repository | 語言 | 服務 | Port |
|-----------|------|------|------|
| rag-slow | Markdown | 整合文檔 | - |
| tempo-latency-anomaly-service | Go | 效能分析 | 8081 |
| tempo-otlp-trace-demo | Go | Trace 產生 | 8080 |

---

## 🔗 相關連結

### Anomaly Service
- 🌐 GitHub: https://github.com/kokjohn0824/tempo-latency-anomaly-service
- 📖 README: [tempo-latency-anomaly-service/README.md](tempo-latency-anomaly-service/README.md)
- 📚 API 文檔: http://localhost:8081/swagger/

### Trace Demo
- 🌐 GitHub: https://github.com/kokjohn0824/tempo-otlp-trace-demo
- 📖 README: [tempo-otlp-trace-demo/README.md](tempo-otlp-trace-demo/README.md)
- 📚 API 文檔: http://localhost:8080/swagger/

### 主專案
- 🌐 GitHub: https://github.com/kokjohn0824/rag-slow
- 📖 README: [README.md](README.md)
- 🚀 快速開始: [QUICKSTART.md](QUICKSTART.md)
- 🤖 Agent 指南: [AGENT_GUIDE.md](AGENT_GUIDE.md)
- 🚢 部署指南: [DEPLOYMENT.md](DEPLOYMENT.md)

---

## 🔄 更新 Repositories

### 更新 Anomaly Service

```bash
cd tempo-latency-anomaly-service
git pull origin main
docker-compose -f docker/compose.yml down
docker-compose -f docker/compose.yml build --no-cache
docker-compose -f docker/compose.yml up -d
```

### 更新 Trace Demo

```bash
cd tempo-otlp-trace-demo
git pull origin master
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### 更新主專案

```bash
cd rag-slow
git pull origin master
```

---

## 🤝 貢獻

歡迎貢獻！請參考各專案的 CONTRIBUTING.md：

- [Anomaly Service Contributing](tempo-latency-anomaly-service/CONTRIBUTING.md)
- [Trace Demo Contributing](tempo-otlp-trace-demo/CONTRIBUTING.md)

---

## 📝 Git 工作流程

### 開發新功能

```bash
# 建立新分支
git checkout -b feature/new-feature

# 開發並提交
git add .
git commit -m "feat: 新增功能描述"

# 推送到 GitHub
git push origin feature/new-feature

# 建立 Pull Request
gh pr create --title "新增功能" --body "功能說明"
```

### 修復 Bug

```bash
# 建立修復分支
git checkout -b fix/bug-description

# 修復並提交
git add .
git commit -m "fix: 修復問題描述"

# 推送並建立 PR
git push origin fix/bug-description
gh pr create --title "修復 Bug" --body "問題說明和解決方案"
```

---

## 🏷️ Badges

### Anomaly Service

```markdown
[![GitHub](https://img.shields.io/badge/GitHub-tempo--latency--anomaly--service-blue?logo=github)](https://github.com/kokjohn0824/tempo-latency-anomaly-service)
[![Go Version](https://img.shields.io/badge/Go-1.24+-00ADD8?logo=go)](https://go.dev/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)](https://www.docker.com/)
```

### Trace Demo

```markdown
[![GitHub](https://img.shields.io/badge/GitHub-tempo--otlp--trace--demo-blue?logo=github)](https://github.com/kokjohn0824/tempo-otlp-trace-demo)
[![Go Version](https://img.shields.io/badge/Go-1.24+-00ADD8?logo=go)](https://go.dev/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)](https://www.docker.com/)
[![Swagger](https://img.shields.io/badge/API-Swagger-85EA2D?logo=swagger)](http://localhost:8080/swagger/)
```

---

## 📧 聯絡資訊

- GitHub: [@kokjohn0824](https://github.com/kokjohn0824)
- Issues: 請在各專案的 GitHub Issues 頁面提出

---

**最後更新**: 2026-01-21
