#!/bin/bash
# 測試 Workflow API 端點

set -e

echo "=========================================="
echo "測試 Slow-RCA Workflow API 端點"
echo "=========================================="
echo ""

# 顏色定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 測試結果
PASSED=0
FAILED=0

# 測試函數
test_api() {
    local name="$1"
    local cmd="$2"
    local expected="$3"
    
    echo -n "測試 $name ... "
    
    result=$(eval "$cmd" 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if [ -n "$expected" ]; then
            if echo "$result" | grep -q "$expected"; then
                echo -e "${GREEN}✓ PASS${NC}"
                PASSED=$((PASSED + 1))
            else
                echo -e "${RED}✗ FAIL${NC} (未包含預期內容: $expected)"
                echo "回應: $result"
                FAILED=$((FAILED + 1))
            fi
        else
            echo -e "${GREEN}✓ PASS${NC}"
            PASSED=$((PASSED + 1))
        fi
    else
        echo -e "${RED}✗ FAIL${NC} (exit code: $exit_code)"
        echo "錯誤: $result"
        FAILED=$((FAILED + 1))
    fi
}

echo "1. 測試 Tempo Latency Anomaly Service (port 8081)"
echo "=================================================="

# 測試參數
SERVICE="order-service"
ENDPOINT="/api/orders"
START=$(date -u -v-1H +%s 2>/dev/null || date -u -d '1 hour ago' +%s)
END=$(date -u +%s)

test_api "GET /v1/traces (需要所有參數)" \
    "curl -s 'http://localhost:8081/v1/traces?service=$SERVICE&endpoint=$ENDPOINT&start=$START&end=$END&limit=5'" \
    "traces"

test_api "GET /v1/traces/{traceId}/longest-span (測試路由)" \
    "curl -s 'http://localhost:8081/v1/traces/test-trace-id/longest-span'" \
    "error"

test_api "POST /v1/traces/child-spans (測試路由)" \
    "curl -s -X POST http://localhost:8081/v1/traces/child-spans -H 'Content-Type: application/json' -d '{\"traceId\":\"test\",\"spanId\":\"test\"}'" \
    "error"

echo ""
echo "2. 測試 Tempo OTLP Trace Demo (port 8080)"
echo "=========================================="

test_api "GET /health" \
    "curl -s http://localhost:8080/health" \
    "OK"

test_api "POST /api/source-code" \
    "curl -s -X POST http://localhost:8080/api/source-code -H 'Content-Type: application/json' -d '{\"spanName\":\"test\"}'" \
    ""

echo ""
echo "=========================================="
echo "測試摘要"
echo "=========================================="
echo -e "${GREEN}通過: $PASSED${NC}"
echo -e "${RED}失敗: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ 所有 API 端點運作正常！${NC}"
    exit 0
else
    echo -e "${RED}✗ 部分測試失敗，請檢查服務狀態${NC}"
    exit 1
fi
