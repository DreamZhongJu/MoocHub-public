-- 最小个性化推荐：用户交互表
-- 建议在 moochub 库执行

CREATE TABLE IF NOT EXISTS recommend_interactions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  item_id BIGINT UNSIGNED NOT NULL,
  category_id BIGINT UNSIGNED NOT NULL,
  action VARCHAR(16) NOT NULL,
  ts DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_ts (user_id, ts),
  INDEX idx_action_ts (action, ts),
  INDEX idx_category_ts (category_id, ts),
  INDEX idx_item_ts (item_id, ts)
);

