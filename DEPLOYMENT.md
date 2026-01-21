# 遠端部署指南

本文檔說明如何將系統部署到遠端伺服器。

## 📋 前置需求

### 本地環境
- Docker & Docker Compose
- SSH 客戶端
- SFTP 客戶端
- Make

### 遠端伺服器
- Docker & Docker Compose 已安裝
- SSH 存取權限
- 足夠的磁碟空間（建議至少 5GB）

### SSH 金鑰設定（建議）

```bash
# 產生 SSH 金鑰（如果還沒有）
ssh-keygen -t rsa -b 4096

# 複製公鑰到遠端伺服器
ssh-copy-id root@192.168.4.208

# 測試連線
ssh root@192.168.4.208 "echo 'SSH connection successful'"
```

## 🚀 快速部署

### 部署 Anomaly Service

```bash
cd tempo-latency-anomaly-service

# 完整部署（推薦）
make deploy-full \
  REMOTE_HOST=192.168.4.208 \
  REMOTE_USER=root \
  REMOTE_PATH=/root/tempo-anomaly

# 或使用預設值（已在 Makefile 中設定）
make deploy-full
```

### 部署 Trace Demo Service

```bash
cd tempo-otlp-trace-demo

# 完整部署（推薦）
make deploy-full \
  REMOTE_HOST=192.168.4.208 \
  REMOTE_USER=root \
  REMOTE_PATH=/root/trace-demo

# 或使用預設值
make deploy-full
```

## 📦 部署指令說明

### Anomaly Service 部署指令

| 指令 | 說明 | 用途 |
|------|------|------|
| `make image-save` | 建立並儲存 Docker image | 離線部署準備 |
| `make deploy-image` | 部署 Docker image | 只更新程式碼 |
| `make deploy-compose` | 部署配置檔案 | 只更新配置 |
| `make deploy-full` | 完整部署 | 首次部署或重大更新 |

### Trace Demo 部署指令

| 指令 | 說明 | 用途 |
|------|------|------|
| `make image-save` | 建立並儲存 Docker image | 離線部署準備 |
| `make deploy-image` | 部署 Docker image | 只更新程式碼 |
| `make deploy-compose` | 部署配置檔案 | 只更新配置 |
| `make deploy-mappings` | 部署 span 映射 | 只更新映射配置 |
| `make deploy-full` | 完整部署 | 首次部署或重大更新 |

## 🔧 自訂部署參數

### 可覆寫的變數

**Anomaly Service**:
```bash
make deploy-full \
  REMOTE_HOST=your-server-ip \
  REMOTE_USER=your-username \
  REMOTE_PATH=/custom/path \
  ARCH=amd64
```

**Trace Demo**:
```bash
make deploy-full \
  REMOTE_HOST=your-server-ip \
  REMOTE_USER=your-username \
  REMOTE_PATH=/custom/path \
  ARCH=amd64
```

### 變數說明

| 變數 | 預設值 | 說明 |
|------|--------|------|
| `REMOTE_HOST` | `192.168.4.208` | 遠端伺服器 IP |
| `REMOTE_USER` | `root` | SSH 使用者名稱 |
| `REMOTE_PATH` | `/root/tempo-anomaly` 或 `/root/trace-demo` | 部署目錄 |
| `ARCH` | `amd64` | CPU 架構（amd64 或 arm64） |
| `PLATFORM` | `linux/$(ARCH)` | Docker 平台 |

## 📝 部署流程詳解

### 完整部署流程（deploy-full）

#### Anomaly Service

```
1. 執行測試
   └─> go test ./internal/...

2. 建立 Docker Image
   └─> docker buildx build --platform=linux/amd64 ...

3. 儲存為 tar 檔案
   └─> docker save tempo-anomaly-service-amd64.tar

4. 上傳到遠端伺服器
   └─> sftp upload to /root/tempo-anomaly/images/

5. 在遠端載入 Image
   └─> ssh: docker load -i ...

6. 部署配置檔案
   ├─> docker-compose.yml
   └─> configs/*.yaml

7. 重啟服務
   └─> docker compose down && docker compose up -d

8. 健康檢查
   └─> curl http://localhost:8081/healthz
```

#### Trace Demo

```
1. 建立 Docker Image
   └─> docker buildx build --platform=linux/amd64 ...

2. 儲存為 tar 檔案
   └─> docker save trace-demo-app-amd64.tar

3. 上傳到遠端伺服器
   └─> sftp upload to /root/trace-demo/images/

4. 在遠端載入 Image
   └─> ssh: docker load -i ...

5. 部署配置檔案
   ├─> docker-compose.yml
   ├─> otel-collector.yaml
   ├─> tempo.yaml
   └─> grafana-datasources.yaml

6. 部署 Span 映射
   ├─> source_code_mappings.json
   └─> handlers/ 目錄

7. 重啟服務
   └─> docker compose down && docker compose up -d

8. 健康檢查
   └─> curl http://localhost:8080/health
```

## 🔍 驗證部署

### 檢查服務狀態

```bash
# 連線到遠端伺服器
ssh root@192.168.4.208

# 檢查 Anomaly Service
cd /root/tempo-anomaly
docker compose ps
curl http://localhost:8081/healthz

# 檢查 Trace Demo
cd /root/trace-demo
docker compose ps
curl http://localhost:8080/health
```

### 查看日誌

```bash
# Anomaly Service 日誌
ssh root@192.168.4.208 "cd /root/tempo-anomaly && docker compose logs -f"

# Trace Demo 日誌
ssh root@192.168.4.208 "cd /root/trace-demo && docker compose logs -f"
```

### 測試 API

```bash
# 從本地測試遠端 API
REMOTE_HOST=192.168.4.208

# 測試 Anomaly Service
curl http://${REMOTE_HOST}:8081/healthz
curl http://${REMOTE_HOST}:8081/v1/available

# 測試 Trace Demo
curl http://${REMOTE_HOST}:8080/health
curl http://${REMOTE_HOST}:8080/api/span-names
```

## 🔄 更新部署

### 只更新程式碼

當只修改程式碼時：

```bash
# Anomaly Service
cd tempo-latency-anomaly-service
make deploy-image

# Trace Demo
cd tempo-otlp-trace-demo
make deploy-image
```

### 只更新配置

當只修改配置檔案時：

```bash
# Anomaly Service
cd tempo-latency-anomaly-service
make deploy-compose

# Trace Demo
cd tempo-otlp-trace-demo
make deploy-compose
```

### 只更新 Span 映射

當只修改 `source_code_mappings.json` 時：

```bash
cd tempo-otlp-trace-demo
make deploy-mappings

# 重啟服務以載入新映射
ssh root@192.168.4.208 "cd /root/trace-demo && docker compose restart trace-demo-app"
```

## 🐛 故障排除

### 部署失敗

#### SSH 連線失敗

```bash
# 檢查 SSH 連線
ssh -v root@192.168.4.208

# 檢查防火牆
ssh root@192.168.4.208 "ufw status"
```

#### SFTP 上傳失敗

```bash
# 測試 SFTP 連線
echo "ls" | sftp root@192.168.4.208

# 檢查磁碟空間
ssh root@192.168.4.208 "df -h"
```

#### Docker 載入失敗

```bash
# 檢查 Docker 狀態
ssh root@192.168.4.208 "docker info"

# 檢查 image 檔案
ssh root@192.168.4.208 "ls -lh /root/tempo-anomaly/images/"
```

### 服務啟動失敗

#### 查看詳細錯誤

```bash
# 查看服務日誌
ssh root@192.168.4.208 "cd /root/tempo-anomaly && docker compose logs"

# 查看容器狀態
ssh root@192.168.4.208 "docker ps -a"
```

#### 埠號衝突

```bash
# 檢查埠號使用情況
ssh root@192.168.4.208 "netstat -tulpn | grep -E '8080|8081|3200|3000'"

# 停止衝突的服務
ssh root@192.168.4.208 "docker compose down"
```

### 健康檢查失敗

```bash
# 等待更長時間
sleep 30
curl http://192.168.4.208:8081/healthz

# 檢查服務日誌
ssh root@192.168.4.208 "cd /root/tempo-anomaly && docker compose logs anomaly-service"
```

## 🔐 安全建議

### 生產環境部署

1. **使用非 root 使用者**
   ```bash
   make deploy-full REMOTE_USER=deploy-user
   ```

2. **設定防火牆規則**
   ```bash
   ssh root@192.168.4.208 "ufw allow 8080/tcp"
   ssh root@192.168.4.208 "ufw allow 8081/tcp"
   ```

3. **使用 HTTPS**
   - 在前面加上 Nginx 或 Traefik
   - 配置 SSL 憑證

4. **限制 Swagger UI 存取**
   - 使用環境變數控制
   - 新增認證機制

5. **定期備份**
   ```bash
   # 備份配置
   scp -r root@192.168.4.208:/root/tempo-anomaly/configs ./backup/
   
   # 備份映射
   scp root@192.168.4.208:/root/trace-demo/source_code_mappings.json ./backup/
   ```

## 📊 效能調校

### 資源限制

編輯遠端的 `docker-compose.yml`：

```yaml
services:
  anomaly-service:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

### 監控

```bash
# 查看資源使用
ssh root@192.168.4.208 "docker stats"

# 查看磁碟使用
ssh root@192.168.4.208 "du -sh /root/tempo-anomaly /root/trace-demo"
```

## 🔄 回滾

### 回滾到先前版本

```bash
# 1. 保存目前的 image tag
ssh root@192.168.4.208 "docker images | grep tempo-anomaly-service"

# 2. 載入舊版本的 tar 檔案
ssh root@192.168.4.208 "docker load -i /root/tempo-anomaly/images/tempo-anomaly-service-amd64.tar.old"

# 3. 重啟服務
ssh root@192.168.4.208 "cd /root/tempo-anomaly && docker compose down && docker compose up -d"
```

## 📚 相關資源

- [README.md](README.md) - 系統概述
- [QUICKSTART.md](QUICKSTART.md) - 快速開始
- [AGENT_GUIDE.md](AGENT_GUIDE.md) - API 參考
- [Anomaly Service Makefile](tempo-latency-anomaly-service/Makefile)
- [Trace Demo Makefile](tempo-otlp-trace-demo/Makefile)

## 💡 最佳實踐

1. **首次部署使用 `deploy-full`**
2. **程式碼更新使用 `deploy-image`**
3. **配置更新使用 `deploy-compose`**
4. **部署前先在本地測試**
5. **保留舊版本的 tar 檔案以便回滾**
6. **定期備份配置和映射檔案**
7. **監控服務健康狀態和資源使用**
8. **使用 SSH 金鑰而非密碼**
