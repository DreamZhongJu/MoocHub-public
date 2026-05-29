# PostgreSQL JSONB + GIN Practice

This note records the JSONB/GIN practice path used by MoocHub.

## Target Field

Use `chat_messages.extra_json`.

Reasons:

- The column already exists as PostgreSQL `JSONB`.
- It stores extension data for chat messages, so the blast radius is small.
- Existing data is shaped like `{"n": 10, "seed": "177099809715681"}`.
- The Go API still returns it as a string, so we can add query capability without changing the Flutter response shape.

## Migration

Run this in pgAdmin Query Tool or `psql`:

```sql
\i server/scripts/chat_messages_extra_json_gin.sql
```

The script:

- sets `extra_json` default to `{}`.
- fills NULL values.
- marks the column `NOT NULL`.
- creates a GIN index with `jsonb_path_ops`.
- runs `ANALYZE`.

Index:

```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_chat_messages_extra_json_gin
ON chat_messages USING GIN (extra_json jsonb_path_ops);
```

`jsonb_path_ops` is preferred here because the intended query is containment:

```sql
WHERE extra_json @> '{"seed":"177099809715681"}'::jsonb
```

If you need key-exists queries such as `extra_json ? 'seed'`, use the default `jsonb_ops` operator class instead:

```sql
CREATE INDEX CONCURRENTLY idx_chat_messages_extra_json_ops_gin
ON chat_messages USING GIN (extra_json);
```

## API

Authenticated endpoint:

```http
POST /api/v1/chat/messages/search
Authorization: Bearer <token>
Content-Type: application/json
```

Request:

```json
{
  "conversation_id": 0,
  "contains": {
    "seed": "177099809715681"
  },
  "page": 1,
  "page_size": 20
}
```

`conversation_id` is optional. When it is `0`, the API searches all conversations joined by the current user.

Nested JSONB containment also works:

```json
{
  "contains": {
    "attrs": {
      "vip": true
    }
  }
}
```

## Benchmark

Run:

```sql
\i server/scripts/bench_chat_messages_extra_json.sql
```

The real `chat_messages` table is currently small, so PostgreSQL may still choose a sequential scan. The benchmark script creates a temporary 100,000-row table to make the planner use GIN.

Local result on PostgreSQL 18:

- before GIN: about 55 ms with sequential scan.
- after GIN: about 21 ms with bitmap index scan.
- nested containment query: about 23 ms with bitmap index scan.

Look for this in the execution plan:

```text
Bitmap Index Scan on tmp_chat_messages_jsonb_bench_gin
Index Cond: (extra_json @> ...)
```
