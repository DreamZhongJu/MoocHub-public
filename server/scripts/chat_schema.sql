-- Chat schema for private/group conversations.
-- Run this once on the `moochub` database.

CREATE TABLE IF NOT EXISTS chat_conversations (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  type VARCHAR(16) NOT NULL COMMENT 'private/group',
  name VARCHAR(128) NOT NULL DEFAULT '',
  avatar_url VARCHAR(512) NOT NULL DEFAULT '',
  private_key VARCHAR(64) NULL,
  creator_id BIGINT UNSIGNED NOT NULL,
  last_message TEXT NULL,
  last_message_at DATETIME NULL,
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_chat_private_key (private_key),
  INDEX idx_chat_type_updated (type, updated_at),
  INDEX idx_chat_creator (creator_id),
  CONSTRAINT fk_chat_conversation_creator
    FOREIGN KEY (creator_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS chat_conversation_members (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  conversation_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  role VARCHAR(32) NOT NULL DEFAULT 'member',
  last_read_message_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
  last_read_at DATETIME NULL,
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_chat_member (conversation_id, user_id),
  INDEX idx_chat_member_user (user_id, is_deleted),
  INDEX idx_chat_member_conversation (conversation_id, is_deleted),
  CONSTRAINT fk_chat_member_conversation
    FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_chat_member_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS chat_messages (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  conversation_id BIGINT UNSIGNED NOT NULL,
  sender_id BIGINT UNSIGNED NOT NULL,
  msg_type VARCHAR(16) NOT NULL DEFAULT 'text',
  content TEXT NOT NULL,
  extra_json JSON NULL,
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_chat_message_conversation_id (conversation_id, id),
  INDEX idx_chat_message_sender_id (sender_id),
  CONSTRAINT fk_chat_message_conversation
    FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_chat_message_sender
    FOREIGN KEY (sender_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
);
