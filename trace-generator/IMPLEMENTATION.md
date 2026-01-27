# Trace Generator Service 實作完成

## 📋 實作概要

已成功完成 Trace Generator Service 的實作，這是一個獨立的 Go 服務，用於定時週期性呼叫 trace-demo-app 的所有 API 端點以產生 traces。

## ✅ 完成的工作

### 1. 專案結構建立

```
trace-generator/
├── main.go              # 主程式入口（定時器和 API 呼叫邏輯）
├── config/
│   └── config.go       # 環境變數配置管理
├── client/
│   └── api_client.go   # 所有 API 端點的呼叫實作
├── logger/
│   └── logger.go       # 雙輸出日誌系統（檔案 + stdout）
├── Dockerfile          # Multi-stage Docker 建構
├── go.mod              # Go module 定義
├── go.sum              # 依賴版本鎖定
├── .gitignore          # Git 忽略規則
├── README.md           # 完整使用說明
├── test.sh             # 測試腳本
└── logs/               # 日誌輸出目錄
```

### 2. 核心功能

#### config/config.go
- ✅ 環境變數載入
- ✅ 預設值設定
- ✅ 型別轉換（string, int, duration, list）
- ✅ 靈活的配置選項

#### logger/logger.go
- ✅ 雙輸出機制（檔案 + stdout）
- ✅ 時間戳記和日誌等級
- ✅ 自動建立日誌目錄
- ✅ 資源清理

#### client/api_client.go
- ✅ HTTP 客戶端封裝
- ✅ 6 個 API 端點實作：
  - `CreateOrder()` - 動態產生訂單資料
  - `GetUserProfile()` - 查詢使用者資料
  - `GenerateReport()` - 產生報表（長時間操作）
  - `Search()` - 搜尋功能
  - `BatchProcess()` - 批次處理
  - `Simulate()` - 自訂 trace 模擬
- ✅ 錯誤處理和超時機制
- ✅ 動態測試資料產生

#### main.go
- ✅ 定時器機制（可配置間隔）
- ✅ 優雅關機（SIGINT/SIGTERM 處理）
- ✅ API 呼叫循環
- ✅ 效能統計（成功/失敗次數、耗時）
- ✅ API 之間的間隔控制（避免壓垮伺服器）

### 3. Docker 整合

#### Dockerfile
- ✅ Multi-stage build（builder + runtime）
- ✅ 最小化映像檔大小（Alpine Linux）
- ✅ 包含 ca-certificates 和 tzdata
- ✅ 非 root 使用者執行

#### docker-compose-deploy.yml
- ✅ 新增 trace-generator service
- ✅ 環境變數配置
- ✅ Volume 掛載（日誌持久化）
- ✅ 網路配置（tempo-network）
- ✅ 依賴關係設定
- ✅ 自動重啟策略

### 4. 文件和測試

- ✅ 完整的 README.md（中文）
- ✅ 使用範例和故障排除
- ✅ 測試腳本（test.sh）
- ✅ .gitignore 配置

## 🚀 使用方式

### 快速啟動

```bash
# 在 tempo-otlp-trace-demo 目錄下
cd /Users/alexchang/dev/rag-slow/tempo-otlp-trace-demo

# 啟動所有服務（包含 trace-generator）
docker-compose -f docker-compose-deploy.yml up -d

# 查看 trace-generator 日誌
docker logs -f trace-generator

# 或查看日誌檔案
tail -f trace-generator/logs/trace-generator.log
```

### 只啟動 trace-generator

```bash
docker-compose -f docker-compose-deploy.yml up -d trace-generator
```

### 停止服務

```bash
docker-compose -f docker-compose-deploy.yml stop trace-generator
```

## 📊 預期行為

啟動後，trace-generator 會：

1. 每 30 秒執行一次 API 呼叫循環
2. 依序呼叫 6 個 API 端點
3. 每個 API 呼叫間隔 1 秒
4. 記錄每個呼叫的結果和耗時
5. 統計每個循環的成功/失敗次數

### 日誌範例

```
2026/01/23 10:30:00 [INFO] Trace generator started
2026/01/23 10:30:00 [INFO] Target URL: http://trace-demo-app:8080
2026/01/23 10:30:00 [INFO] Interval: 30s
2026/01/23 10:30:00 [INFO] Enabled APIs: [order user report search batch simulate]
2026/01/23 10:30:00 [INFO] Starting API call cycle
2026/01/23 10:30:00 [INFO] API order succeeded (took 850ms)
2026/01/23 10:30:01 [INFO] API user succeeded (took 150ms)
2026/01/23 10:30:02 [INFO] API report succeeded (took 2.3s)
2026/01/23 10:30:05 [INFO] API search succeeded (took 320ms)
2026/01/23 10:30:06 [INFO] API batch succeeded (took 1.1s)
2026/01/23 10:30:07 [INFO] API simulate succeeded (took 450ms)
2026/01/23 10:30:07 [INFO] Cycle completed: 6 succeeded, 0 failed (total time: 7.2s)
```

## 🔧 配置選項

### 修改呼叫間隔

```bash
# 修改為每分鐘一次
docker-compose -f docker-compose-deploy.yml up -d \
  --build \
  --force-recreate \
  trace-generator
# 並在 docker-compose-deploy.yml 中設定 INTERVAL_SECONDS=60
```

### 只啟用特定 API

在 `docker-compose-deploy.yml` 中修改：
```yaml
environment:
  - ENABLED_APIS=order,user  # 只啟用 order 和 user API
```

### 調整超時時間

```yaml
environment:
  - TIMEOUT_SECONDS=60  # 增加到 60 秒
```

## 🎯 技術特點

1. **輕量化**：使用 Go 標準庫，無外部依賴
2. **可觀測性**：雙輸出日誌，方便監控和除錯
3. **可配置性**：完全透過環境變數配置
4. **可靠性**：自動重啟、錯誤處理、優雅關機
5. **高效能**：Multi-stage Docker build，最終映像檔小於 20MB

## 📝 測試驗證

執行測試腳本：

```bash
cd trace-generator
./test.sh
```

這會驗證：
- Go 環境
- 專案結構完整性
- Go 程式編譯
- Docker 映像建構

## 🔍 故障排除

### 無法連接到 trace-demo-app

```bash
# 確認 trace-demo-app 正在運行
docker ps | grep trace-demo-app

# 檢查網路連接
docker exec trace-generator ping -c 3 trace-demo-app
```

### 查看詳細錯誤

```bash
# 查看容器日誌
docker logs trace-generator

# 查看日誌檔案
cat trace-generator/logs/trace-generator.log
```

## 📚 相關文件

- `trace-generator/README.md` - 詳細使用說明
- `trace-generator/test.sh` - 測試腳本
- `docker-compose-deploy.yml` - Docker Compose 配置

## ✨ 總結

Trace Generator Service 已完全按照計劃實作完成，包含：

- ✅ 所有核心功能
- ✅ Docker 整合
- ✅ 完整文件
- ✅ 測試驗證

服務已準備好部署使用，可以開始產生持續的 traces 用於 Tempo 測試和監控。
