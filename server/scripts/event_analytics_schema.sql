-- 埋点原始事件表
CREATE TABLE IF NOT EXISTS event_logs (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  event_type VARCHAR(32) NOT NULL,
  content_type VARCHAR(32) NOT NULL,
  content_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NULL,
  session_id VARCHAR(64) NOT NULL DEFAULT '',
  scene VARCHAR(64) NOT NULL DEFAULT '',
  position INT NOT NULL DEFAULT 0,
  ip VARCHAR(64) NOT NULL DEFAULT '',
  ua VARCHAR(255) NOT NULL DEFAULT '',
  occurred_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_evt_time (event_type, occurred_at),
  INDEX idx_content_time (content_type, content_id, occurred_at),
  INDEX idx_user_time (user_id, occurred_at)
);

-- 小时聚合表（看板查询）
CREATE TABLE IF NOT EXISTS event_stats_hourly (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  bucket_hour DATETIME NOT NULL,
  event_type VARCHAR(32) NOT NULL,
  content_type VARCHAR(32) NOT NULL,
  content_id BIGINT UNSIGNED NOT NULL,
  scene VARCHAR(64) NOT NULL DEFAULT '',
  pv BIGINT UNSIGNED NOT NULL DEFAULT 0,
  uv BIGINT UNSIGNED NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_hourly_event (bucket_hour, event_type, content_type, content_id, scene),
  INDEX idx_hourly_lookup (event_type, content_type, bucket_hour)
);
