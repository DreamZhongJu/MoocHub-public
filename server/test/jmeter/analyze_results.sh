#!/bin/bash
# 分析 JMeter 结果 CSV，输出各阶梯的 TPS / 平均RT / P99 RT / 错误率
# 用法：bash analyze_results.sh [results目录]
# 依赖：awk（内置）
# P99 计算：对响应时间排序后取第99百分位

RESULTS_DIR="${1:-results}"

if [ ! -d "$RESULTS_DIR" ]; then
  echo "结果目录不存在：$RESULTS_DIR"
  exit 1
fi

analyze_csv() {
  local file="$1"
  local label="$2"

  if [ ! -f "$file" ]; then
    printf "  %-35s  文件不存在\n" "$label"
    return
  fi

  # CSV列：timeStamp,elapsed,label,responseCode,responseMessage,threadName,dataType,success,failureMessage,bytes,sentBytes,grpThreads,allThreads,URL,Latency,IdleTime,Connect
  # timeStamp(ms), elapsed(ms), success(true/false), responseCode
  awk -F',' -v label="$label" '
  NR==1 {
    for(i=1;i<=NF;i++) {
      if($i=="timeStamp")  ts_col=i
      if($i=="elapsed")    el_col=i
      if($i=="success")    ok_col=i
      if($i=="responseCode") code_col=i
    }
    next
  }
  {
    ts  = $ts_col + 0
    el  = $el_col + 0
    ok  = $ok_col
    code = $code_col

    if (NR==2) { min_ts=ts; max_ts=ts }
    if (ts < min_ts) min_ts=ts
    if (ts > max_ts) max_ts=ts

    total++
    sum_el += el
    elapsed[total] = el

    if (ok != "true") errors++
  }
  END {
    if (total == 0) { print "  " label "  无数据"; exit }

    # 排序计算P99
    n = asort(elapsed)
    p99_idx = int(n * 0.99)
    if (p99_idx < 1) p99_idx = 1
    p99 = elapsed[p99_idx]

    # TPS = 总请求 / 实际持续秒数
    duration_sec = (max_ts - min_ts) / 1000.0
    if (duration_sec <= 0) duration_sec = 1
    tps = total / duration_sec

    avg_rt = sum_el / total
    err_rate = errors / total * 100

    printf "  %-35s  TPS=%6.1f  avgRT=%5.0fms  P99=%5.0fms  错误率=%.2f%%  (样本=%d)\n",
      label, tps, avg_rt, p99, err_rate, total
  }
  ' "$file"
}

echo "========================================================"
echo "  MoocHub 压测结果汇总"
echo "========================================================"

echo ""
echo "【场景一：课程列表查询（Redis缓存命中）】"
analyze_csv "$RESULTS_DIR/s1_10users.csv"  "  10并发"
analyze_csv "$RESULTS_DIR/s1_50users.csv"  "  50并发"
analyze_csv "$RESULTS_DIR/s1_100users.csv" " 100并发"
analyze_csv "$RESULTS_DIR/s1_200users.csv" " 200并发"
analyze_csv "$RESULTS_DIR/s1_500users.csv" " 500并发"

echo ""
echo "【场景二：课程列表查询（缓存穿透，直查MySQL）】"
analyze_csv "$RESULTS_DIR/s2_10users.csv"  "  10并发（冷缓存）"
analyze_csv "$RESULTS_DIR/s2_50users.csv"  "  50并发（冷缓存）"
analyze_csv "$RESULTS_DIR/s2_100users.csv" " 100并发（冷缓存）"
analyze_csv "$RESULTS_DIR/s2_200users.csv" " 200并发（冷缓存）"

echo ""
echo "【场景三：进度上报（Redis缓冲写，70%写+30%读）】"
analyze_csv "$RESULTS_DIR/s3_50users.csv"  "  50并发（混合）"
analyze_csv "$RESULTS_DIR/s3_100users.csv" " 100并发（混合）"
analyze_csv "$RESULTS_DIR/s3_200users.csv" " 200并发（混合）"
analyze_csv "$RESULTS_DIR/s3_500users.csv" " 500并发（混合）"

echo ""
echo "【场景四：高频写（完播事件含积分与推送）】"
analyze_csv "$RESULTS_DIR/s4_50users.csv"  "  50并发（完播写）"
analyze_csv "$RESULTS_DIR/s4_100users.csv" " 100并发（完播写）"
analyze_csv "$RESULTS_DIR/s4_200users.csv" " 200并发（完播写）"
analyze_csv "$RESULTS_DIR/s4_500users.csv" " 500并发（完播写）"

echo ""
echo "【场景五：限流验证】"
if [ -f "$RESULTS_DIR/s5_ratelimit_summary.txt" ]; then
  cat "$RESULTS_DIR/s5_ratelimit_summary.txt"
else
  analyze_csv "$RESULTS_DIR/s5_ratelimit_raw.csv" "500并发限流冲击"
  # 额外统计429比例
  if [ -f "$RESULTS_DIR/s5_ratelimit_raw.csv" ]; then
    awk -F',' '
    NR==1 { for(i=1;i<=NF;i++) if($i=="responseCode") col=i; next }
    { codes[$col]++ }
    END {
      printf "  HTTP 200 (正常): %d\n", codes["200"]
      printf "  HTTP 429 (限流): %d\n", codes["429"]
      total = codes["200"] + codes["429"]
      if (total > 0)
        printf "  限流拦截率: %.1f%%\n", codes["429"]/total*100
    }' "$RESULTS_DIR/s5_ratelimit_raw.csv"
  fi
fi

echo ""
echo "========================================================"
echo "  注：TPS/RT数据基于整个阶梯60秒全量数据"
echo "  论文取值建议使用后30秒稳定阶段数据（过滤 timeStamp 前30s）"
echo "========================================================"
