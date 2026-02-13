-- Add soft-delete column to favorites tables
ALTER TABLE favorite_courses
  ADD COLUMN is_deleted TINYINT(1) NOT NULL DEFAULT 0;

ALTER TABLE favorite_videos
  ADD COLUMN is_deleted TINYINT(1) NOT NULL DEFAULT 0;

ALTER TABLE favorite_articles
  ADD COLUMN is_deleted TINYINT(1) NOT NULL DEFAULT 0;

-- Initialize existing rows
UPDATE favorite_courses SET is_deleted = 0;
UPDATE favorite_videos SET is_deleted = 0;
UPDATE favorite_articles SET is_deleted = 0;
