#!/bin/bash

# ============================================================================
# 完整整合測試：Anomaly Service + Source Code API
# ============================================================================

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}整合測試：Anomaly Service + Source Code API${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 配置
ANOMALY_SERVICE="http://192.168.4.208:3201"
TRACE_DEMO_SERVICE="http://192.168.4.208:3202"

# 步驟 1: 檢查可用的 endpoints
echo -e "${GREEN}步驟 1: 從 Anomaly Service 檢查可用的 endpoints${NC}"
AVAILABLE=$(curl -s "${ANOMALY_SERVICE}/v1/available")

echo "可用的 endpoints:"
echo "$AVAILABLE" | jq '{totalServices, totalEndpoints, services}'
echo ""

TOTAL_ENDPOINTS=$(echo "$AVAILABLE" | jq -r '.totalEndpoints')

if [ "$TOTAL_ENDPOINTS" -eq 0 ]; then
  echo -e "${YELLOW}警告: 沒有可用的 endpoints，需要先產生測試資料${NC}"
  echo ""
  echo -e "${GREEN}產生測試 traces...${NC}"
  for i in {1..10}; do
    curl -s -X POST "${TRACE_DEMO_SERVICE}/api/order/create" \
      -H "Content-Type: application/json" \
      -d '{"user_id":"user_'$i'","product_id":"prod_123","quantity":1,"price":99.99}' >/dev/null
    echo "  產生 trace $i/10"
    sleep 2
  done
  echo ""
  echo "等待 10 分鐘讓系統收集和處理資料..."
  echo "（這是正常的，系統需要時間建立 baseline）"
  sleep 60

  # 重新檢查
  AVAILABLE=$(curl -s "${ANOMALY_SERVICE}/v1/available")
  TOTAL_ENDPOINTS=$(echo "$AVAILABLE" | jq -r '.totalEndpoints')

  if [ "$TOTAL_ENDPOINTS" -eq 0 ]; then
    echo -e "${YELLOW}仍然沒有可用的 endpoints，請稍後再試${NC}"
    exit 1
  fi
fi

# 選擇第一個可用的 endpoint
SERVICE_NAME=$(echo "$AVAILABLE" | jq -r '.services[0].service')
ENDPOINT_NAME=$(echo "$AVAILABLE" | jq -r '.services[0].endpoint')

echo "選擇要分析的 endpoint:"
echo "  Service: $SERVICE_NAME"
echo "  Endpoint: $ENDPOINT_NAME"
echo ""

# 步驟 2: 產生該 endpoint 的新 trace
echo -e "${GREEN}步驟 2: 產生該 endpoint 的測試 trace${NC}"
echo "呼叫 $ENDPOINT_NAME..."

if [[ "$ENDPOINT_NAME" == *"order/create"* ]]; then
  RESPONSE=$(curl -s -X POST "${TRACE_DEMO_SERVICE}/api/order/create" \
    -H "Content-Type: application/json" \
    -d '{"user_id":"test_user","product_id":"prod_123","quantity":2,"price":199.99}')
elif [[ "$ENDPOINT_NAME" == *"user/profile"* ]]; then
  RESPONSE=$(curl -s "${TRACE_DEMO_SERVICE}/api/user/profile?user_id=test_user")
elif [[ "$ENDPOINT_NAME" == *"report/generate"* ]]; then
  RESPONSE=$(curl -s -X POST "${TRACE_DEMO_SERVICE}/api/report/generate" \
    -H "Content-Type: application/json" \
    -d '{"report_type":"sales"}')
else
  RESPONSE=$(curl -s -X POST "${TRACE_DEMO_SERVICE}/api/order/create" \
    -H "Content-Type: application/json" \
    -d '{"user_id":"test_user","product_id":"prod_123","quantity":2,"price":199.99}')
fi

echo "Response: $RESPONSE"
echo ""

# 等待 trace 傳送到 Tempo
echo "等待 15 秒讓 trace 傳送到 Tempo..."
sleep 15

# 步驟 3: 使用 Anomaly Service 的 /v1/traces API 搜尋該 endpoint 的 traces
echo -e "${GREEN}步驟 3: 使用 Anomaly Service 搜尋該 endpoint 的 traces${NC}"
END_TIME=$(date +%s)
START_TIME=$((END_TIME - 300))

# URL encode endpoint name
ENDPOINT_ENCODED=$(echo -n "$ENDPOINT_NAME" | jq -sRr @uri)

echo "搜尋條件:"
echo "  Service: ${SERVICE_NAME}"
echo "  Endpoint: ${ENDPOINT_NAME}"
echo "  Time range: ${START_TIME} - ${END_TIME}"
echo ""

# 使用 anomaly service 的 /v1/traces API
TRACE_LOOKUP_RESULT=$(curl -s "${ANOMALY_SERVICE}/v1/traces?service=${SERVICE_NAME}&endpoint=${ENDPOINT_ENCODED}&start=${START_TIME}&end=${END_TIME}&limit=5")

echo "找到的 traces:"
echo "$TRACE_LOOKUP_RESULT" | jq '{count, traces: [.traces[] | {traceID, durationMs}]}'
echo ""

# 選擇第一個 trace ID
TRACE_ID=$(echo "$TRACE_LOOKUP_RESULT" | jq -r '.traces[0].traceID')

if [ -z "$TRACE_ID" ] || [ "$TRACE_ID" == "null" ]; then
  echo -e "${YELLOW}錯誤: 找不到該 endpoint 的 traces${NC}"
  exit 1
fi

echo "找到 Trace ID: $TRACE_ID"
echo "  來自 endpoint: $ENDPOINT_NAME"
echo ""

# 步驟 4: 從 Anomaly Service 獲取 longest span
echo -e "${GREEN}步驟 4: 從 Anomaly Service 獲取 longest span${NC}"
LONGEST_SPAN_RESULT=$(curl -s "${ANOMALY_SERVICE}/v1/traces/${TRACE_ID}/longest-span")

echo "Longest Span 資訊:"
echo "$LONGEST_SPAN_RESULT" | jq '{
  traceID,
  spanId: .longestSpan.spanId,
  spanName: .longestSpan.name,
  service: .longestSpan.service,
  durationMs: .longestSpan.durationMs,
  startTime: .longestSpan.startTime
}'
echo ""

# 提取 span ID 和 trace ID
SPAN_ID=$(echo "$LONGEST_SPAN_RESULT" | jq -r '.longestSpan.spanId')
SPAN_NAME=$(echo "$LONGEST_SPAN_RESULT" | jq -r '.longestSpan.name')
DURATION_MS=$(echo "$LONGEST_SPAN_RESULT" | jq -r '.longestSpan.durationMs')

echo "提取的資訊:"
echo "  Trace ID: $TRACE_ID"
echo "  Span ID: $SPAN_ID"
echo "  Span Name: $SPAN_NAME"
echo "  Duration: ${DURATION_MS}ms"
echo ""

# 步驟 5: 從 Anomaly Service 獲取 child spans 異常分析
echo -e "${GREEN}步驟 5: 從 Anomaly Service 獲取 child spans 異常分析${NC}"
CHILD_SPANS_RESULT=$(curl -s -X POST "${ANOMALY_SERVICE}/v1/traces/child-span-anomalies" \
  -H "Content-Type: application/json" \
  -d "{\"traceId\":\"${TRACE_ID}\",\"parentSpanId\":\"${SPAN_ID}\"}")

echo "Child Spans 異常分析結果:"
echo "$CHILD_SPANS_RESULT" | jq '{
  traceId,
  parentSpan: .parentSpan.name,
  childCount,
  anomalyCount,
  children: [.children[] | {
    name: .span.name,
    durationMs: .span.durationMs,
    isAnomaly,
    cannotDetermine,
    baselineSource,
    explanation
  }]
}'
echo ""

# 步驟 6: 使用 Source Code API 獲取原始碼（簡化版）
echo -e "${GREEN}步驟 6: 使用 Source Code API 獲取原始碼${NC}"
echo "API 請求:"
echo "  POST ${TRACE_DEMO_SERVICE}/api/source-code"
echo "  Body: {\"spanName\":\"${SPAN_NAME}\"}"
echo ""
echo "可以單獨測試此 API:"
echo "  curl -X POST ${TRACE_DEMO_SERVICE}/api/source-code -H \"Content-Type: application/json\" -d '{\"spanName\":\"${SPAN_NAME}\"}' | jq ."
echo ""
SOURCE_CODE_RESULT=$(curl -s -X POST "${TRACE_DEMO_SERVICE}/api/source-code" \
  -H "Content-Type: application/json" \
  -d "{\"spanName\":\"${SPAN_NAME}\"}")

echo "原始碼資訊:"
echo "$SOURCE_CODE_RESULT" | jq '{
  span_name,
  file_path,
  function_name,
  start_line,
  end_line
}'
echo ""

# 步驟 7: 分析結果
echo -e "${GREEN}步驟 7: 分析結果${NC}"
echo ""
echo "=== 效能與異常分析 ==="
echo ""

# 顯示異常數量統計
ANOMALY_COUNT=$(echo "$CHILD_SPANS_RESULT" | jq -r '.anomalyCount')
CHILD_COUNT=$(echo "$CHILD_SPANS_RESULT" | jq -r '.childCount')
echo "異常統計: ${ANOMALY_COUNT}/${CHILD_COUNT} 個子操作被判定為異常"
echo ""

# 找出最慢的 child span
SLOWEST_CHILD=$(echo "$CHILD_SPANS_RESULT" | jq -r '
  .children 
  | sort_by(.span.durationMs) 
  | reverse 
  | .[0] 
  | "\(.span.name) (\(.span.durationMs)ms) | anomaly=\(.isAnomaly)"
')

echo "最慢的子操作: $SLOWEST_CHILD"
echo ""

# 顯示所有 child spans 的 duration 和異常狀態
echo "所有子操作的執行時間和異常狀態:"
echo "$CHILD_SPANS_RESULT" | jq -r '.children[] | "  - \(.span.name): \(.span.durationMs)ms | anomaly=\(.isAnomaly) | \(.baselineSource)"'
echo ""

# 列出被判定為異常的 child spans
echo "被判定為異常的子操作:"
ANOMALY_CHILDREN=$(echo "$CHILD_SPANS_RESULT" | jq -r '.children[] | select(.isAnomaly == true) | "  - \(.span.name): \(.span.durationMs)ms | \(.explanation)"')
if [ -z "$ANOMALY_CHILDREN" ]; then
  echo "  (無異常)"
else
  echo "$ANOMALY_CHILDREN"
fi
echo ""

# 顯示原始碼位置
FILE_PATH=$(echo "$SOURCE_CODE_RESULT" | jq -r '.file_path')
FUNCTION_NAME=$(echo "$SOURCE_CODE_RESULT" | jq -r '.function_name')
START_LINE=$(echo "$SOURCE_CODE_RESULT" | jq -r '.start_line')
END_LINE=$(echo "$SOURCE_CODE_RESULT" | jq -r '.end_line')

echo "原始碼位置:"
echo "  檔案: $FILE_PATH"
echo "  函數: $FUNCTION_NAME"
echo "  行號: $START_LINE - $END_LINE"
echo ""

# 步驟 8: 顯示部分原始碼
echo -e "${GREEN}步驟 8: 顯示部分原始碼 (前 20 行)${NC}"
echo "$SOURCE_CODE_RESULT" | jq -r '.source_code' | head -20
echo "..."
echo ""

# 總結
# echo -e "${BLUE}========================================${NC}"
# echo -e "${BLUE}測試完成${NC}"
# echo -e "${BLUE}========================================${NC}"
# echo ""
# echo "✅ 成功從 Anomaly Service 獲取 longest span"
# echo "✅ 成功從 Anomaly Service 獲取 child spans"
# echo "✅ 成功從 Source Code API 獲取原始碼"
# echo "✅ 可以識別效能瓶頸 (最慢的子操作)"
# echo ""
# echo "架構改進完成："
# echo "  - Anomaly Service 負責所有 Tempo 查詢和 trace 分析"
# echo "  - Trace Demo 只負責 span name → 原始碼的映射"
# echo "  - 職責清晰，易於維護"
