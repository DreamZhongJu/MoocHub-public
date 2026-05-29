-- Add JSONB defaults and a GIN index for chat_messages.extra_json.
-- Run with psql or pgAdmin Query Tool on the PostgreSQL database.
--
-- Note: CREATE INDEX CONCURRENTLY cannot run inside a transaction block.

ALTER TABLE chat_messages
  ALTER COLUMN extra_json SET DEFAULT '{}'::jsonb;

UPDATE chat_messages
SET extra_json = '{}'::jsonb
WHERE extra_json IS NULL;

ALTER TABLE chat_messages
  ALTER COLUMN extra_json SET NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_chat_messages_extra_json_gin
ON chat_messages USING GIN (extra_json jsonb_path_ops);

ANALYZE chat_messages;
