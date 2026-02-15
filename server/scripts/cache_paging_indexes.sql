-- 缓存预热/热点保护配套的分页索引优化
-- 执行方式：在 moochub 库执行本脚本（建议先在测试库验证）

SET @db = DATABASE();

-- -------- courses --------
SET @idx = 'idx_courses_status_created_id';
SELECT COUNT(*) INTO @exists FROM information_schema.statistics
WHERE table_schema = @db AND table_name = 'courses' AND index_name = @idx;
SET @sql = IF(@exists = 0,
  'ALTER TABLE courses ADD INDEX idx_courses_status_created_id (status, created_at, id)',
  'SELECT "skip idx_courses_status_created_id"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx = 'idx_courses_category_status_created_id';
SELECT COUNT(*) INTO @exists FROM information_schema.statistics
WHERE table_schema = @db AND table_name = 'courses' AND index_name = @idx;
SET @sql = IF(@exists = 0,
  'ALTER TABLE courses ADD INDEX idx_courses_category_status_created_id (category_id, status, created_at, id)',
  'SELECT "skip idx_courses_category_status_created_id"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx = 'idx_courses_status_view_id';
SELECT COUNT(*) INTO @exists FROM information_schema.statistics
WHERE table_schema = @db AND table_name = 'courses' AND index_name = @idx;
SET @sql = IF(@exists = 0,
  'ALTER TABLE courses ADD INDEX idx_courses_status_view_id (status, view_count, id)',
  'SELECT "skip idx_courses_status_view_id"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx = 'idx_courses_category_status_view_id';
SELECT COUNT(*) INTO @exists FROM information_schema.statistics
WHERE table_schema = @db AND table_name = 'courses' AND index_name = @idx;
SET @sql = IF(@exists = 0,
  'ALTER TABLE courses ADD INDEX idx_courses_category_status_view_id (category_id, status, view_count, id)',
  'SELECT "skip idx_courses_category_status_view_id"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx = 'idx_courses_status_favorite_id';
SELECT COUNT(*) INTO @exists FROM information_schema.statistics
WHERE table_schema = @db AND table_name = 'courses' AND index_name = @idx;
SET @sql = IF(@exists = 0,
  'ALTER TABLE courses ADD INDEX idx_courses_status_favorite_id (status, favorite_count, id)',
  'SELECT "skip idx_courses_status_favorite_id"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx = 'idx_courses_category_status_favorite_id';
SELECT COUNT(*) INTO @exists FROM information_schema.statistics
WHERE table_schema = @db AND table_name = 'courses' AND index_name = @idx;
SET @sql = IF(@exists = 0,
  'ALTER TABLE courses ADD INDEX idx_courses_category_status_favorite_id (category_id, status, favorite_count, id)',
  'SELECT "skip idx_courses_category_status_favorite_id"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- -------- articles --------
SET @idx = 'idx_articles_status_created_id';
SELECT COUNT(*) INTO @exists FROM information_schema.statistics
WHERE table_schema = @db AND table_name = 'articles' AND index_name = @idx;
SET @sql = IF(@exists = 0,
  'ALTER TABLE articles ADD INDEX idx_articles_status_created_id (status, created_at, id)',
  'SELECT "skip idx_articles_status_created_id"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx = 'idx_articles_status_view_id';
SELECT COUNT(*) INTO @exists FROM information_schema.statistics
WHERE table_schema = @db AND table_name = 'articles' AND index_name = @idx;
SET @sql = IF(@exists = 0,
  'ALTER TABLE articles ADD INDEX idx_articles_status_view_id (status, view_count, id)',
  'SELECT "skip idx_articles_status_view_id"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx = 'idx_articles_status_like_id';
SELECT COUNT(*) INTO @exists FROM information_schema.statistics
WHERE table_schema = @db AND table_name = 'articles' AND index_name = @idx;
SET @sql = IF(@exists = 0,
  'ALTER TABLE articles ADD INDEX idx_articles_status_like_id (status, like_count, id)',
  'SELECT "skip idx_articles_status_like_id"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

