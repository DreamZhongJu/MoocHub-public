#!/bin/bash
# 批量注册压测用户（运行 JMeter 场景3/4/5 前必须先执行）
# 用法：bash create_test_users.sh [HOST] [PORT]

HOST="${1:-127.0.0.1}"
PORT="${2:-3000}"
BASE_URL="http://${HOST}:${PORT}"

echo "=== 创建压测用户 ==="
echo "目标地址：${BASE_URL}"
echo ""

SUCCESS=0
FAIL=0

for i in $(seq -w 1 50); do
  USERNAME="testuser${i}"
  PASSWORD="Test@123456"

  RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}" 2>/dev/null)

  HTTP_CODE=$(echo "$RESP" | tail -n1)
  BODY=$(echo "$RESP" | head -n-1)

  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "[OK] 创建用户 ${USERNAME}"
    SUCCESS=$((SUCCESS + 1))
  elif echo "$BODY" | grep -qi "already\|exist\|duplicate"; then
    echo "[SKIP] 用户 ${USERNAME} 已存在"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "[FAIL] 创建用户 ${USERNAME} 失败 (HTTP ${HTTP_CODE}): ${BODY}"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "=== 完成：成功/跳过 ${SUCCESS}，失败 ${FAIL} ==="
