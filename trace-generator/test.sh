#!/bin/bash

# Trace Generator 測試腳本

set -e

echo "================================"
echo "Trace Generator 測試"
echo "================================"
echo ""

# 顏色定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 檢查 Go 安裝
echo "1. 檢查 Go 環境..."
if command -v go &> /dev/null; then
    echo -e "${GREEN}✓${NC} Go 已安裝: $(go version)"
else
    echo -e "${RED}✗${NC} Go 未安裝"
    exit 1
fi

# 檢查專案結構
echo ""
echo "2. 檢查專案結構..."
cd "$(dirname "$0")"

required_files=(
    "main.go"
    "config/config.go"
    "client/api_client.go"
    "logger/logger.go"
    "Dockerfile"
    "go.mod"
    "README.md"
    ".gitignore"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file 存在"
    else
        echo -e "${RED}✗${NC} $file 不存在"
        exit 1
    fi
done

# 測試編譯
echo ""
echo "3. 測試 Go 程式編譯..."
if go build -o trace-generator-test . ; then
    echo -e "${GREEN}✓${NC} 編譯成功"
    rm -f trace-generator-test
else
    echo -e "${RED}✗${NC} 編譯失敗"
    exit 1
fi

# 測試 Docker 建構
echo ""
echo "4. 測試 Docker 映像建構..."
if docker build -t trace-generator:test . ; then
    echo -e "${GREEN}✓${NC} Docker 建構成功"
    docker rmi trace-generator:test
else
    echo -e "${RED}✗${NC} Docker 建構失敗"
    exit 1
fi

echo ""
echo "================================"
echo -e "${GREEN}所有測試通過！${NC}"
echo "================================"
echo ""
echo "使用方式："
echo "  啟動所有服務: docker-compose -f ../docker-compose-deploy.yml up -d"
echo "  查看日誌:     docker logs -f trace-generator"
echo "  停止服務:     docker-compose -f ../docker-compose-deploy.yml stop trace-generator"
echo ""
