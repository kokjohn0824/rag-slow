#!/bin/bash

# ============================================================================
# 完整整合測試：Anomaly Service + Source Code API (遠端版本)
# ============================================================================
# 
# 此腳本用於在遠端環境測試 Anomaly Service 的 child-span-anomalies API
#
# 必要服務:
#   - Anomaly Service (預設: http://192.168.4.208:3201)
#   - Trace Demo Service (預設: http://192.168.4.208:3202)
#   - Tempo (預設: http://192.168.4.208:3200)
#
# ============================================================================

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 遠端配置
ANOMALY_SERVICE="${ANOMALY_SERVICE:-http://192.168.4.208:3202}"
TRACE_DEMO_SERVICE="${TRACE_DEMO_SERVICE:-http://192.168.4.208:3201}"
TEMPO_SERVICE="${TEMPO_SERVICE:-http://192.168.4.208:3200}"

# 模擬異常參數 (可透過環境變數或命令列參數設定)
# SIMULATE_ANOMALY=true 會在 order/create 請求中加入 sleep=true 參數
SIMULATE_ANOMALY="${SIMULATE_ANOMALY:-false}"

# 解析命令列參數
while [[ $# -gt 0 ]]; do
  case $1 in
    --simulate-anomaly|-s)
      SIMULATE_ANOMALY=true
      shift
      ;;
    --help|-h)
      echo "用法: $0 [選項]"
      echo ""
      echo "選項:"
      echo "  -s, --simulate-anomaly  模擬異常延遲 (在 order/create 中加入 5 秒延遲)"
      echo "  -h, --help              顯示此說明"
      echo ""
      echo "環境變數:"
      echo "  ANOMALY_SERVICE         Anomaly Service URL (預設: http://192.168.4.208:3201)"
      echo "  TRACE_DEMO_SERVICE      Trace Demo Service URL (預設: http://192.168.4.208:3202)"
      echo "  TEMPO_SERVICE           Tempo URL (預設: http://192.168.4.208:3200)"
      echo "  SIMULATE_ANOMALY        設為 true 以模擬異常 (預設: false)"
      echo "  NON_INTERACTIVE         設為 1 以跳過互動式選擇"
      exit 0
      ;;
    *)
      echo "未知選項: $1"
      echo "使用 --help 查看說明"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}整合測試：Anomaly Service + Source Code API${NC}"
echo -e "${BLUE}(遠端版本)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================================================
# 步驟 0: 檢查服務健康狀態
# ============================================================================
echo -e "${GREEN}步驟 0: 檢查服務健康狀態${NC}"

check_service() {
  local name=$1
  local url=$2
  local response
  response=$(curl -s --connect-timeout 5 "$url" 2>&1)
  if [ $? -eq 0 ] && [ -n "$response" ]; then
    echo -e "  ${GREEN}✓${NC} $name: OK"
    return 0
  else
    echo -e "  ${RED}✗${NC} $name: Failed ($url)"
    return 1
  fi
}

SERVICES_OK=true

check_service "Anomaly Service" "${ANOMALY_SERVICE}/healthz" || SERVICES_OK=false
check_service "Trace Demo App" "${TRACE_DEMO_SERVICE}/health" || SERVICES_OK=false
check_service "Tempo" "${TEMPO_SERVICE}/ready" || SERVICES_OK=false

echo ""

if [ "$SERVICES_OK" = false ]; then
  echo -e "${RED}錯誤: 部分服務未正常運行${NC}"
  echo ""
  echo "請確保以下遠端服務已啟動並可連線:"
  echo "  - Anomaly Service: ${ANOMALY_SERVICE}"
  echo "  - Trace Demo Service: ${TRACE_DEMO_SERVICE}"
  echo "  - Tempo: ${TEMPO_SERVICE}"
  echo ""
  exit 1
fi

# ============================================================================
# 步驟 1: 檢查可用的 endpoints
# ============================================================================
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
  echo "等待 60 秒讓系統收集和處理資料..."
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

# 如果啟用了模擬異常模式，自動選擇 order/create endpoint
if [ "$SIMULATE_ANOMALY" = true ]; then
  # 找到 order/create endpoint
  ORDER_CREATE_SERVICE=$(echo "$AVAILABLE" | jq -r '.services[] | select(.endpoint | contains("order/create")) | .service' | head -1)
  ORDER_CREATE_ENDPOINT=$(echo "$AVAILABLE" | jq -r '.services[] | select(.endpoint | contains("order/create")) | .endpoint' | head -1)
  
  if [ -n "$ORDER_CREATE_SERVICE" ] && [ -n "$ORDER_CREATE_ENDPOINT" ]; then
    SERVICE_NAME="$ORDER_CREATE_SERVICE"
    ENDPOINT_NAME="$ORDER_CREATE_ENDPOINT"
    echo -e "${YELLOW}模擬異常模式: 自動選擇 order/create endpoint${NC}"
  else
    echo -e "${RED}錯誤: 找不到 order/create endpoint，無法模擬異常${NC}"
    exit 1
  fi
# 檢查是否為互動模式 (直接啟動腳本，而非被其他腳本呼叫)
# 條件: stdin 是 terminal 且未設定 NON_INTERACTIVE 環境變數
elif [ -t 0 ] && [ -z "$NON_INTERACTIVE" ]; then
  # 互動模式：讓使用者選擇 endpoint
  echo -e "${BLUE}=== 選擇要分析的 Endpoint ===${NC}"
  echo ""
  
  # 建立 endpoint 列表
  ENDPOINT_LIST=()
  INDEX=1
  while IFS= read -r line; do
    SERVICE=$(echo "$line" | jq -r '.service')
    ENDPOINT=$(echo "$line" | jq -r '.endpoint')
    ENDPOINT_LIST+=("$SERVICE|$ENDPOINT")
    echo "  ${INDEX}) ${SERVICE} - ${ENDPOINT}"
    ((INDEX++))
  done < <(echo "$AVAILABLE" | jq -c '.services[]')
  
  echo ""
  echo -n "請選擇 endpoint (1-$((INDEX-1))) [預設: 1]: "
  read -r SELECTION
  
  # 預設選擇第一個
  if [ -z "$SELECTION" ]; then
    SELECTION=1
  fi
  
  # 驗證輸入
  if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt $((INDEX-1)) ]; then
    echo -e "${YELLOW}無效的選擇，使用預設值 1${NC}"
    SELECTION=1
  fi
  
  # 取得選擇的 service 和 endpoint
  SELECTED_ITEM="${ENDPOINT_LIST[$((SELECTION-1))]}"
  SERVICE_NAME=$(echo "$SELECTED_ITEM" | cut -d'|' -f1)
  ENDPOINT_NAME=$(echo "$SELECTED_ITEM" | cut -d'|' -f2)
  echo ""
  
  # 詢問是否要模擬異常 (只有在選擇 order/create 時才詢問)
  if [[ "$ENDPOINT_NAME" == *"order/create"* ]] && [ "$SIMULATE_ANOMALY" != true ]; then
    echo -n "是否要模擬異常延遲? (在 processPayment 中加入 5 秒延遲) [y/N]: "
    read -r SIMULATE_CHOICE
    if [[ "$SIMULATE_CHOICE" =~ ^[Yy]$ ]]; then
      SIMULATE_ANOMALY=true
      echo -e "${YELLOW}已啟用模擬異常模式${NC}"
    fi
    echo ""
  fi
else
  # 非互動模式：自動選擇第一個 endpoint
  SERVICE_NAME=$(echo "$AVAILABLE" | jq -r '.services[0].service')
  ENDPOINT_NAME=$(echo "$AVAILABLE" | jq -r '.services[0].endpoint')
fi

echo "選擇要分析的 endpoint:"
echo "  Service: $SERVICE_NAME"
echo "  Endpoint: $ENDPOINT_NAME"
echo ""

# ============================================================================
# 步驟 2: 產生該 endpoint 的新 trace
# ============================================================================
echo -e "${GREEN}步驟 2: 產生該 endpoint 的測試 trace${NC}"

# 顯示模擬異常狀態
if [ "$SIMULATE_ANOMALY" = true ]; then
  echo -e "${YELLOW}*** 模擬異常模式已啟用 ***${NC}"
  echo "將在 order/create 的 processPayment 子操作中加入 5 秒延遲"
  echo ""
fi

echo "呼叫 $ENDPOINT_NAME..."

if [[ "$ENDPOINT_NAME" == *"order/create"* ]]; then
  if [ "$SIMULATE_ANOMALY" = true ]; then
    # 模擬異常：加入 sleep=true 參數
    echo "(使用 sleep=true 參數模擬異常延遲)"
    RESPONSE=$(curl -s -X POST "${TRACE_DEMO_SERVICE}/api/order/create" \
      -H "Content-Type: application/json" \
      -d '{"user_id":"test_user","product_id":"prod_123","quantity":2,"price":199.99,"sleep":true}')
  else
    RESPONSE=$(curl -s -X POST "${TRACE_DEMO_SERVICE}/api/order/create" \
      -H "Content-Type: application/json" \
      -d '{"user_id":"test_user","product_id":"prod_123","quantity":2,"price":199.99}')
  fi
elif [[ "$ENDPOINT_NAME" == *"user/profile"* ]]; then
  RESPONSE=$(curl -s "${TRACE_DEMO_SERVICE}/api/user/profile?user_id=test_user")
elif [[ "$ENDPOINT_NAME" == *"report/generate"* ]]; then
  RESPONSE=$(curl -s -X POST "${TRACE_DEMO_SERVICE}/api/report/generate" \
    -H "Content-Type: application/json" \
    -d '{"report_type":"sales"}')
else
  if [ "$SIMULATE_ANOMALY" = true ]; then
    # 預設使用 order/create 並模擬異常
    echo "(使用 sleep=true 參數模擬異常延遲)"
    RESPONSE=$(curl -s -X POST "${TRACE_DEMO_SERVICE}/api/order/create" \
      -H "Content-Type: application/json" \
      -d '{"user_id":"test_user","product_id":"prod_123","quantity":2,"price":199.99,"sleep":true}')
  else
    RESPONSE=$(curl -s -X POST "${TRACE_DEMO_SERVICE}/api/order/create" \
      -H "Content-Type: application/json" \
      -d '{"user_id":"test_user","product_id":"prod_123","quantity":2,"price":199.99}')
  fi
fi

echo "Response: $RESPONSE"
echo ""

# 等待 trace 傳送到 Tempo
echo "等待 5 秒讓 trace 傳送到 Tempo..."
sleep 5

# ============================================================================
# 步驟 3: 使用 Anomaly Service 的 /v1/traces API 搜尋該 endpoint 的 traces
# ============================================================================
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
echo "$TRACE_LOOKUP_RESULT" | jq '{count, traces: [.traces[]? | {traceID, durationMs}]}'
echo ""

# 選擇第一個 trace ID
TRACE_ID=$(echo "$TRACE_LOOKUP_RESULT" | jq -r '.traces[0].traceID // .traces[0].traceId // empty')

if [ -z "$TRACE_ID" ] || [ "$TRACE_ID" == "null" ]; then
  echo -e "${YELLOW}錯誤: 找不到該 endpoint 的 traces${NC}"
  echo "Response: $TRACE_LOOKUP_RESULT"
  exit 1
fi

echo "找到 Trace ID: $TRACE_ID"
echo "  來自 endpoint: $ENDPOINT_NAME"
echo ""

# ============================================================================
# 步驟 4: 從 Anomaly Service 獲取 longest span
# ============================================================================
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

# ============================================================================
# 步驟 5: 從 Anomaly Service 獲取 child spans 異常分析
# ============================================================================
echo -e "${GREEN}步驟 5: 從 Anomaly Service 獲取 child spans 異常分析${NC}"
CHILD_SPANS_RESULT=$(curl -s -X POST "${ANOMALY_SERVICE}/v1/traces/child-span-anomalies" \
  -H "Content-Type: application/json" \
  -d "{\"traceId\":\"${TRACE_ID}\",\"parentSpanId\":\"${SPAN_ID}\"}")

# 檢查 API 是否返回錯誤 (405 = Method Not Allowed 表示 API 尚未部署)
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${ANOMALY_SERVICE}/v1/traces/child-span-anomalies" \
  -H "Content-Type: application/json" \
  -d "{\"traceId\":\"${TRACE_ID}\",\"parentSpanId\":\"${SPAN_ID}\"}")

if [ "$HTTP_STATUS" == "405" ]; then
  echo -e "${YELLOW}警告: child-span-anomalies API 返回 405 (Method Not Allowed)${NC}"
  echo "這可能表示目前運行的 Anomaly Service 版本尚未包含此 API。"
  echo ""
  echo "嘗試使用舊的 child-spans API 作為備用..."
  CHILD_SPANS_RESULT=$(curl -s -X POST "${ANOMALY_SERVICE}/v1/traces/child-spans" \
    -H "Content-Type: application/json" \
    -d "{\"traceId\":\"${TRACE_ID}\",\"spanId\":\"${SPAN_ID}\"}")
  
  echo "Child Spans 資訊 (舊 API):"
  echo "$CHILD_SPANS_RESULT" | jq '{
    parentSpan: .parentSpan.name,
    childCount,
    children: [.children[]? | {name, durationMs}]
  }'
else
  echo "Child Spans 異常分析結果:"
  echo "$CHILD_SPANS_RESULT" | jq '{
    traceId,
    parentSpan: .parentSpan.name,
    childCount,
    anomalyCount,
    children: [.children[]? | {
      name: .span.name,
      durationMs: .span.durationMs,
      isAnomaly,
      cannotDetermine,
      baselineSource,
      explanation
    }]
  }'
fi
echo ""

# ============================================================================
# 步驟 6: 分析 Child Spans 結果
# ============================================================================
echo -e "${GREEN}步驟 6: 分析 Child Spans 結果${NC}"
echo ""

# 根據使用的 API 版本顯示不同的分析結果
if [ "$HTTP_STATUS" != "405" ]; then
  # 使用新的 child-span-anomalies API
  ANOMALY_COUNT=$(echo "$CHILD_SPANS_RESULT" | jq -r '.anomalyCount // 0')
  CHILD_COUNT=$(echo "$CHILD_SPANS_RESULT" | jq -r '.childCount // 0')
  echo "異常統計: ${ANOMALY_COUNT}/${CHILD_COUNT} 個子操作被判定為異常"
  echo ""

  # 顯示所有 child spans 的 duration 和異常狀態
  echo "所有子操作的執行時間和異常狀態:"
  echo "$CHILD_SPANS_RESULT" | jq -r '.children[]? | "  - \(.span.name): \(.span.durationMs)ms | anomaly=\(.isAnomaly) | \(.baselineSource)"' 2>/dev/null || echo "  (無資料)"
  echo ""

  # 列出被判定為異常的 child spans
  echo "被判定為異常的子操作:"
  ANOMALY_CHILDREN=$(echo "$CHILD_SPANS_RESULT" | jq -r '.children[]? | select(.isAnomaly == true) | "  - \(.span.name): \(.span.durationMs)ms | \(.explanation)"' 2>/dev/null)
  if [ -z "$ANOMALY_CHILDREN" ]; then
    echo "  (無異常)"
  else
    echo "$ANOMALY_CHILDREN"
  fi
  echo ""

  # 找出最慢的 child span
  SLOWEST_CHILD_NAME=$(echo "$CHILD_SPANS_RESULT" | jq -r '
    .children 
    | sort_by(.span.durationMs) 
    | reverse 
    | .[0].span.name // empty
  ' 2>/dev/null)
  SLOWEST_CHILD_DURATION=$(echo "$CHILD_SPANS_RESULT" | jq -r '
    .children 
    | sort_by(.span.durationMs) 
    | reverse 
    | .[0].span.durationMs // 0
  ' 2>/dev/null)

  echo "最慢的子操作: ${SLOWEST_CHILD_NAME} (${SLOWEST_CHILD_DURATION}ms)"
  echo ""
else
  # 使用舊的 child-spans API
  CHILD_COUNT=$(echo "$CHILD_SPANS_RESULT" | jq -r '.childCount // 0')
  ANOMALY_COUNT=0
  echo "Child span 數量: $CHILD_COUNT"
  echo ""

  # 顯示所有 child spans 的 duration
  echo "所有子操作的執行時間:"
  echo "$CHILD_SPANS_RESULT" | jq -r '.children[]? | "  - \(.name): \(.durationMs)ms"' 2>/dev/null || echo "  (無資料)"
  echo ""

  # 找出最慢的 child span
  SLOWEST_CHILD_NAME=$(echo "$CHILD_SPANS_RESULT" | jq -r '
    .children 
    | sort_by(.durationMs) 
    | reverse 
    | .[0].name // empty
  ' 2>/dev/null)
  SLOWEST_CHILD_DURATION=$(echo "$CHILD_SPANS_RESULT" | jq -r '
    .children 
    | sort_by(.durationMs) 
    | reverse 
    | .[0].durationMs // 0
  ' 2>/dev/null)

  echo "最慢的子操作: ${SLOWEST_CHILD_NAME} (${SLOWEST_CHILD_DURATION}ms)"
  echo ""
fi

# ============================================================================
# 步驟 7: 根據異常狀態查詢對應原始碼
# ============================================================================
echo -e "${GREEN}步驟 7: 查詢關鍵子操作的原始碼${NC}"
echo ""

# 決定要查詢的 span names
TARGET_SPANS=()

if [ "$HTTP_STATUS" != "405" ] && [ "$ANOMALY_COUNT" -gt 0 ]; then
  # 有異常的子操作，查詢所有異常的 span
  echo "發現 ${ANOMALY_COUNT} 個異常子操作，將查詢其原始碼..."
  echo ""
  
  # 取得所有異常的 span names
  while IFS= read -r span_name; do
    if [ -n "$span_name" ]; then
      TARGET_SPANS+=("$span_name")
    fi
  done < <(echo "$CHILD_SPANS_RESULT" | jq -r '.children[]? | select(.isAnomaly == true) | .span.name' 2>/dev/null)
else
  # 沒有異常的子操作，查詢最慢的 span
  echo "無異常子操作，將查詢最慢的子操作原始碼..."
  echo ""
  
  if [ -n "$SLOWEST_CHILD_NAME" ]; then
    TARGET_SPANS+=("$SLOWEST_CHILD_NAME")
  fi
fi

# 查詢每個目標 span 的原始碼
if [ ${#TARGET_SPANS[@]} -eq 0 ]; then
  echo -e "${YELLOW}警告: 沒有可查詢的子操作${NC}"
else
  for TARGET_SPAN in "${TARGET_SPANS[@]}"; do
    echo -e "${BLUE}--- 查詢: ${TARGET_SPAN} ---${NC}"
    
    # 取得該 span 的詳細資訊
    if [ "$HTTP_STATUS" != "405" ]; then
      SPAN_INFO=$(echo "$CHILD_SPANS_RESULT" | jq -r --arg name "$TARGET_SPAN" '
        .children[]? | select(.span.name == $name) | 
        "Duration: \(.span.durationMs)ms | Anomaly: \(.isAnomaly) | Source: \(.baselineSource)\nExplanation: \(.explanation)"
      ' 2>/dev/null)
    else
      SPAN_INFO=$(echo "$CHILD_SPANS_RESULT" | jq -r --arg name "$TARGET_SPAN" '
        .children[]? | select(.name == $name) | 
        "Duration: \(.durationMs)ms"
      ' 2>/dev/null)
    fi
    
    if [ -n "$SPAN_INFO" ]; then
      echo "$SPAN_INFO"
    fi
    echo ""
    
    # 查詢原始碼
    SOURCE_CODE_RESULT=$(curl -s -X POST "${TRACE_DEMO_SERVICE}/api/source-code" \
      -H "Content-Type: application/json" \
      -d "{\"spanName\":\"${TARGET_SPAN}\"}")
    
    # 檢查是否有錯誤
    ERROR_MSG=$(echo "$SOURCE_CODE_RESULT" | jq -r '.error // empty' 2>/dev/null)
    
    if [ -n "$ERROR_MSG" ]; then
      echo -e "${YELLOW}無法取得原始碼: ${ERROR_MSG}${NC}"
    else
      FILE_PATH=$(echo "$SOURCE_CODE_RESULT" | jq -r '.file_path // "N/A"')
      FUNCTION_NAME=$(echo "$SOURCE_CODE_RESULT" | jq -r '.function_name // "N/A"')
      START_LINE=$(echo "$SOURCE_CODE_RESULT" | jq -r '.start_line // "N/A"')
      END_LINE=$(echo "$SOURCE_CODE_RESULT" | jq -r '.end_line // "N/A"')
      
      echo "原始碼位置:"
      echo "  檔案: $FILE_PATH"
      echo "  函數: $FUNCTION_NAME"
      echo "  行號: $START_LINE - $END_LINE"
      echo ""
      
      # 顯示部分原始碼
      SOURCE_CODE=$(echo "$SOURCE_CODE_RESULT" | jq -r '.source_code // empty')
      if [ -n "$SOURCE_CODE" ]; then
        echo "原始碼 (前 25 行):"
        echo "$SOURCE_CODE" | head -25
        echo "..."
      fi
    fi
    echo ""
  done
fi

# ============================================================================
# 步驟 8: 查詢 Root Span 原始碼
# ============================================================================
echo -e "${GREEN}步驟 8: 查詢 Root Span 原始碼${NC}"
echo ""
echo "Root Span: ${SPAN_NAME} (${DURATION_MS}ms)"
echo ""

SOURCE_CODE_RESULT=$(curl -s -X POST "${TRACE_DEMO_SERVICE}/api/source-code" \
  -H "Content-Type: application/json" \
  -d "{\"spanName\":\"${SPAN_NAME}\"}")

ERROR_MSG=$(echo "$SOURCE_CODE_RESULT" | jq -r '.error // empty' 2>/dev/null)

if [ -n "$ERROR_MSG" ]; then
  echo -e "${YELLOW}無法取得原始碼: ${ERROR_MSG}${NC}"
else
  FILE_PATH=$(echo "$SOURCE_CODE_RESULT" | jq -r '.file_path // "N/A"')
  FUNCTION_NAME=$(echo "$SOURCE_CODE_RESULT" | jq -r '.function_name // "N/A"')
  START_LINE=$(echo "$SOURCE_CODE_RESULT" | jq -r '.start_line // "N/A"')
  END_LINE=$(echo "$SOURCE_CODE_RESULT" | jq -r '.end_line // "N/A"')
  
  echo "原始碼位置:"
  echo "  檔案: $FILE_PATH"
  echo "  函數: $FUNCTION_NAME"
  echo "  行號: $START_LINE - $END_LINE"
  echo ""
  
  # 顯示部分原始碼
  SOURCE_CODE=$(echo "$SOURCE_CODE_RESULT" | jq -r '.source_code // empty')
  if [ -n "$SOURCE_CODE" ]; then
    echo "原始碼 (前 20 行):"
    echo "$SOURCE_CODE" | head -20
    echo "..."
  fi
fi
echo ""

# ============================================================================
# 總結
# ============================================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}測試完成${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "測試服務配置:"
echo "  - Anomaly Service: ${ANOMALY_SERVICE}"
echo "  - Trace Demo Service: ${TRACE_DEMO_SERVICE}"
echo "  - Tempo: ${TEMPO_SERVICE}"
echo ""
