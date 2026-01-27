# Trace Generator

自動化的 trace 生成器，定時週期性呼叫所有 trace-demo-app API 端點以產生 traces。

## 功能特性

- 🔄 定時週期性呼叫所有 API 端點
- 📝 同時輸出日誌到檔案和 stdout
- ⚙️ 透過環境變數靈活配置
- 🐳 Docker 容器化部署
- 🪶 輕量化設計，無外部依賴

## 支援的 API 端點

- `POST /api/order/create` - 訂單建立
- `GET /api/user/profile` - 使用者查詢
- `POST /api/report/generate` - 報表生成
- `GET /api/search` - 搜尋功能
- `POST /api/batch/process` - 批次處理
- `GET /api/simulate` - 自訂 trace 模擬

## 環境變數配置

| 變數名稱 | 說明 | 預設值 |
|---------|------|--------|
| `TARGET_URL` | API 基礎 URL | `http://trace-demo-app:8080` |
| `INTERVAL_SECONDS` | 呼叫間隔（秒） | `30` |
| `LOG_PATH` | 日誌檔案路徑 | `/logs/trace-generator.log` |
| `ENABLED_APIS` | 啟用的 API（逗號分隔） | `order,user,report,search,batch,simulate` |
| `TIMEOUT_SECONDS` | HTTP 超時時間（秒） | `30` |

## 使用方式

### Docker Compose 部署（推薦）

在 `docker-compose-deploy.yml` 中已包含 trace-generator 服務配置：

```bash
# 啟動所有服務（包含 trace-generator）
docker-compose -f docker-compose-deploy.yml up -d

# 只啟動 trace-generator
docker-compose -f docker-compose-deploy.yml up -d trace-generator

# 停止 trace-generator
docker-compose -f docker-compose-deploy.yml stop trace-generator

# 查看日誌
docker-compose -f docker-compose-deploy.yml logs -f trace-generator
```

### 獨立 Docker 部署

```bash
# 建構映像檔
docker build -t trace-generator .

# 執行容器
docker run -d \
  --name trace-generator \
  --network tempo-network \
  -e TARGET_URL=http://trace-demo-app:8080 \
  -e INTERVAL_SECONDS=30 \
  -v $(pwd)/logs:/logs \
  trace-generator
```

### 本地開發執行

```bash
# 安裝依賴
go mod download

# 設定環境變數
export TARGET_URL=http://localhost:8080
export INTERVAL_SECONDS=30
export LOG_PATH=./logs/trace-generator.log

# 執行
go run main.go
```

## 配置範例

### 每分鐘呼叫一次

```yaml
environment:
  - INTERVAL_SECONDS=60
```

### 只啟用特定 API

```yaml
environment:
  - ENABLED_APIS=order,user
```

### 調整超時時間

```yaml
environment:
  - TIMEOUT_SECONDS=60
```

## 日誌格式

日誌會同時輸出到檔案和 stdout：

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

## 專案結構

```
trace-generator/
├── main.go              # 主程式入口
├── config/
│   └── config.go       # 配置管理
├── client/
│   └── api_client.go   # API 呼叫邏輯
├── logger/
│   └── logger.go       # 日誌處理
├── Dockerfile          # Docker 映像檔定義
├── go.mod              # Go module 定義
├── go.sum              # 依賴版本鎖定
├── .gitignore          # Git 忽略規則
└── README.md           # 說明文件
```

## 故障排除

### 無法連接到 trace-demo-app

確認：
1. trace-demo-app 服務已啟動
2. 網路配置正確（使用相同的 Docker network）
3. `TARGET_URL` 環境變數設定正確

### 日誌檔案沒有建立

確認：
1. `/logs` 目錄已掛載（使用 volume）
2. 容器有寫入權限

### API 呼叫失敗

查看日誌中的錯誤訊息：
```bash
docker logs trace-generator
```

或查看日誌檔案：
```bash
tail -f trace-generator/logs/trace-generator.log
```

## 開發

### 新增 API 端點

1. 在 `client/api_client.go` 中新增 API 方法
2. 在 `main.go` 的 `callAllAPIs` 函數中註冊新 API
3. 更新 README.md 說明

### 測試

```bash
# 執行測試（如果有）
go test ./...

# 格式化程式碼
go fmt ./...

# 靜態分析
go vet ./...
```

## 授權

MIT License
