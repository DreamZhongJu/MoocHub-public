import csv
import sys


def load_rows(path):
    rows = []
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                success_raw = str(row.get("success", "")).strip().lower()
                # Some JMeter CSV exports may contain duplicated malformed rows
                # where columns shift and the "success" column becomes "OK".
                # Only keep canonical boolean success rows for analysis.
                if success_raw not in {"true", "false"}:
                    continue
                rows.append({
                    "ts": int(row["timeStamp"]),
                    "elapsed": float(row["elapsed"]),
                    "success": success_raw == "true",
                })
            except Exception:
                continue
    return rows


def window_stats(rows, start_ts, end_ts):
    bucket = [r for r in rows if start_ts <= r["ts"] < end_ts]
    if not bucket:
        return None
    total = len(bucket)
    ok = sum(1 for r in bucket if r["success"])
    avg_rt = sum(r["elapsed"] for r in bucket) / total
    err_rate = (total - ok) / total * 100.0
    return {
        "samples": total,
        "avg_rt_ms": round(avg_rt, 2),
        "error_rate_pct": round(err_rate, 2),
    }


def main():
    if len(sys.argv) < 2:
        print("usage: python analyze_soak_results.py <jmeter_csv>")
        sys.exit(1)

    rows = load_rows(sys.argv[1])
    if not rows:
        print("no rows")
        sys.exit(1)

    start_ts = min(r["ts"] for r in rows)
    end_ts = max(r["ts"] for r in rows)
    checkpoints = {
        "前5分钟": (start_ts, start_ts + 5 * 60 * 1000),
        "1小时": (start_ts + 55 * 60 * 1000, start_ts + 60 * 60 * 1000),
        "2小时": (start_ts + 115 * 60 * 1000, start_ts + 120 * 60 * 1000),
        "最终5分钟": (max(start_ts, end_ts - 5 * 60 * 1000), end_ts + 1),
    }

    for name, (s, e) in checkpoints.items():
        print(name, window_stats(rows, s, e))


if __name__ == "__main__":
    main()
