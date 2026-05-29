-- PostgreSQL schema for MoocHub.
-- Run on an empty database before importing data.

BEGIN;

CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  username VARCHAR(64) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(16) NOT NULL DEFAULT 'student',
  nickname VARCHAR(64),
  avatar_url VARCHAR(512),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  points_balance INT NOT NULL DEFAULT 0,
  CONSTRAINT chk_users_role CHECK (role IN ('student', 'teacher', 'admin')),
  CONSTRAINT uk_users_username UNIQUE (username)
);

CREATE TABLE IF NOT EXISTS course_categories (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(64) NOT NULL,
  parent_id BIGINT REFERENCES course_categories(id) ON DELETE SET NULL ON UPDATE CASCADE,
  sort_order INT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_course_categories_parent_id ON course_categories(parent_id);

CREATE TABLE IF NOT EXISTS courses (
  id BIGSERIAL PRIMARY KEY,
  category_id BIGINT NOT NULL REFERENCES course_categories(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  title VARCHAR(128) NOT NULL,
  summary VARCHAR(1024),
  cover_url VARCHAR(512),
  instructor_name VARCHAR(64),
  level VARCHAR(32),
  status VARCHAR(16) NOT NULL DEFAULT 'draft',
  view_count BIGINT NOT NULL DEFAULT 0,
  favorite_count BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_courses_status CHECK (status IN ('draft', 'published'))
);
CREATE INDEX IF NOT EXISTS idx_courses_category_id ON courses(category_id);
CREATE INDEX IF NOT EXISTS idx_courses_status_created_at ON courses(status, created_at);
CREATE INDEX IF NOT EXISTS idx_courses_status_created_id ON courses(status, created_at, id);
CREATE INDEX IF NOT EXISTS idx_courses_category_status_created_id ON courses(category_id, status, created_at, id);
CREATE INDEX IF NOT EXISTS idx_courses_status_view_id ON courses(status, view_count, id);
CREATE INDEX IF NOT EXISTS idx_courses_category_status_view_id ON courses(category_id, status, view_count, id);
CREATE INDEX IF NOT EXISTS idx_courses_status_favorite_id ON courses(status, favorite_count, id);
CREATE INDEX IF NOT EXISTS idx_courses_category_status_favorite_id ON courses(category_id, status, favorite_count, id);

CREATE TABLE IF NOT EXISTS videos (
  id BIGSERIAL PRIMARY KEY,
  course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE ON UPDATE CASCADE,
  title VARCHAR(128) NOT NULL,
  description VARCHAR(1024),
  duration_sec INT NOT NULL DEFAULT 0,
  video_url VARCHAR(512) NOT NULL,
  thumb_url VARCHAR(512),
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_videos_course_id_sort ON videos(course_id, sort_order, id);

CREATE TABLE IF NOT EXISTS articles (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  title VARCHAR(128) NOT NULL,
  summary VARCHAR(255) NOT NULL,
  cover_url VARCHAR(512) NOT NULL,
  content TEXT NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'published',
  view_count BIGINT NOT NULL DEFAULT 0,
  like_count BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_articles_user_created ON articles(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_articles_status_created ON articles(status, created_at);
CREATE INDEX IF NOT EXISTS idx_articles_status_created_id ON articles(status, created_at, id);
CREATE INDEX IF NOT EXISTS idx_articles_status_view_id ON articles(status, view_count, id);
CREATE INDEX IF NOT EXISTS idx_articles_status_like_id ON articles(status, like_count, id);

CREATE TABLE IF NOT EXISTS device_tokens (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  platform VARCHAR(16) NOT NULL DEFAULT 'android',
  token VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uk_device_token UNIQUE (token)
);
CREATE INDEX IF NOT EXISTS idx_user_platform ON device_tokens(user_id, platform);

CREATE TABLE IF NOT EXISTS event_logs (
  id BIGSERIAL PRIMARY KEY,
  event_type VARCHAR(32) NOT NULL,
  content_type VARCHAR(32) NOT NULL,
  content_id BIGINT NOT NULL,
  user_id BIGINT,
  session_id VARCHAR(64) NOT NULL DEFAULT '',
  scene VARCHAR(64) NOT NULL DEFAULT '',
  position INT NOT NULL DEFAULT 0,
  ip VARCHAR(64) NOT NULL DEFAULT '',
  ua VARCHAR(255) NOT NULL DEFAULT '',
  occurred_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_evt_time ON event_logs(event_type, occurred_at);
CREATE INDEX IF NOT EXISTS idx_content_time ON event_logs(content_type, content_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_user_time ON event_logs(user_id, occurred_at);

CREATE TABLE IF NOT EXISTS event_stats_hourly (
  id BIGSERIAL PRIMARY KEY,
  bucket_hour TIMESTAMPTZ NOT NULL,
  event_type VARCHAR(32) NOT NULL,
  content_type VARCHAR(32) NOT NULL,
  content_id BIGINT NOT NULL,
  scene VARCHAR(64) NOT NULL DEFAULT '',
  pv BIGINT NOT NULL DEFAULT 0,
  uv BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uk_hourly_event UNIQUE (bucket_hour, event_type, content_type, content_id, scene)
);
CREATE INDEX IF NOT EXISTS idx_hourly_lookup ON event_stats_hourly(event_type, content_type, bucket_hour);

CREATE TABLE IF NOT EXISTS favorite_articles (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  article_id BIGINT NOT NULL REFERENCES articles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  CONSTRAINT uk_fav_articles_user_article UNIQUE (user_id, article_id)
);
CREATE INDEX IF NOT EXISTS idx_fav_articles_article ON favorite_articles(article_id);

CREATE TABLE IF NOT EXISTS favorite_courses (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  CONSTRAINT uk_fav_courses_user_course UNIQUE (user_id, course_id)
);
CREATE INDEX IF NOT EXISTS idx_fav_courses_course_id ON favorite_courses(course_id);

CREATE TABLE IF NOT EXISTS favorite_videos (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  video_id BIGINT NOT NULL REFERENCES videos(id) ON DELETE CASCADE ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_deleted SMALLINT NOT NULL DEFAULT 0,
  CONSTRAINT uk_fav_videos_user_video UNIQUE (user_id, video_id)
);
CREATE INDEX IF NOT EXISTS idx_fav_videos_video_id ON favorite_videos(video_id);

CREATE TABLE IF NOT EXISTS learning_progress (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  video_id BIGINT NOT NULL REFERENCES videos(id) ON DELETE CASCADE ON UPDATE CASCADE,
  last_position_sec INT NOT NULL DEFAULT 0,
  progress_percent NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uk_progress_user_video UNIQUE (user_id, video_id)
);
CREATE INDEX IF NOT EXISTS idx_progress_video_id ON learning_progress(video_id);

CREATE TABLE IF NOT EXISTS messages (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  type VARCHAR(32) NOT NULL,
  title VARCHAR(64) NOT NULL,
  content VARCHAR(512) NOT NULL,
  biz_id BIGINT,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_messages_user_created ON messages(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_user_read ON messages(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_messages_user_type ON messages(user_id, type);

CREATE TABLE IF NOT EXISTS points_transactions (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  event_type VARCHAR(32) NOT NULL,
  points INT NOT NULL,
  biz_id BIGINT,
  remark VARCHAR(255),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_points_user_created ON points_transactions(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_points_event_created ON points_transactions(event_type, created_at);

CREATE TABLE IF NOT EXISTS recommend_interactions (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  item_id BIGINT NOT NULL,
  category_id BIGINT NOT NULL,
  action VARCHAR(16) NOT NULL,
  ts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_user_ts ON recommend_interactions(user_id, ts);
CREATE INDEX IF NOT EXISTS idx_action_ts ON recommend_interactions(action, ts);
CREATE INDEX IF NOT EXISTS idx_category_ts ON recommend_interactions(category_id, ts);
CREATE INDEX IF NOT EXISTS idx_item_ts ON recommend_interactions(item_id, ts);

CREATE TABLE IF NOT EXISTS chat_conversations (
  id BIGSERIAL PRIMARY KEY,
  type VARCHAR(16) NOT NULL,
  name VARCHAR(128) NOT NULL DEFAULT '',
  avatar_url VARCHAR(512) NOT NULL DEFAULT '',
  private_key VARCHAR(64),
  creator_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uk_chat_private_key UNIQUE (private_key)
);
CREATE INDEX IF NOT EXISTS idx_chat_type_updated ON chat_conversations(type, updated_at);
CREATE INDEX IF NOT EXISTS idx_chat_creator ON chat_conversations(creator_id);

CREATE TABLE IF NOT EXISTS chat_conversation_members (
  id BIGSERIAL PRIMARY KEY,
  conversation_id BIGINT NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  role VARCHAR(32) NOT NULL DEFAULT 'member',
  last_read_message_id BIGINT NOT NULL DEFAULT 0,
  last_read_at TIMESTAMPTZ,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uk_chat_member UNIQUE (conversation_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_chat_member_user ON chat_conversation_members(user_id, is_deleted);
CREATE INDEX IF NOT EXISTS idx_chat_member_conversation ON chat_conversation_members(conversation_id, is_deleted);

CREATE TABLE IF NOT EXISTS chat_messages (
  id BIGSERIAL PRIMARY KEY,
  conversation_id BIGINT NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE ON UPDATE CASCADE,
  sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  msg_type VARCHAR(16) NOT NULL DEFAULT 'text',
  content TEXT NOT NULL,
  extra_json JSONB,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_chat_message_conversation_id ON chat_messages(conversation_id, id);
CREATE INDEX IF NOT EXISTS idx_chat_message_sender_id ON chat_messages(sender_id);

CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS trg_courses_updated_at ON courses;
CREATE TRIGGER trg_courses_updated_at BEFORE UPDATE ON courses
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS trg_articles_updated_at ON articles;
CREATE TRIGGER trg_articles_updated_at BEFORE UPDATE ON articles
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS trg_device_tokens_updated_at ON device_tokens;
CREATE TRIGGER trg_device_tokens_updated_at BEFORE UPDATE ON device_tokens
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS trg_event_stats_hourly_updated_at ON event_stats_hourly;
CREATE TRIGGER trg_event_stats_hourly_updated_at BEFORE UPDATE ON event_stats_hourly
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS trg_chat_conversations_updated_at ON chat_conversations;
CREATE TRIGGER trg_chat_conversations_updated_at BEFORE UPDATE ON chat_conversations
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS trg_chat_conversation_members_updated_at ON chat_conversation_members;
CREATE TRIGGER trg_chat_conversation_members_updated_at BEFORE UPDATE ON chat_conversation_members
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

COMMIT;
