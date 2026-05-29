-- JSONB + GIN benchmark for chat_messages.extra_json.
-- This script uses a temporary table, so it does not pollute application data.

\timing on

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM chat_messages
WHERE extra_json @> '{"seed":"177099809715681"}'::jsonb;

CREATE TEMP TABLE tmp_chat_messages_jsonb_bench AS
SELECT
  gs AS id,
  jsonb_build_object(
    'seed', CASE WHEN gs % 10 = 0 THEN 'hot' ELSE 'cold' END,
    'n', gs % 1000,
    'kind', CASE WHEN gs % 3 = 0 THEN 'image' ELSE 'text' END,
    'attrs', jsonb_build_object(
      'course_id', gs % 500,
      'vip', gs % 7 = 0
    )
  ) AS extra_json
FROM generate_series(1, 100000) AS gs;

ANALYZE tmp_chat_messages_jsonb_bench;

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM tmp_chat_messages_jsonb_bench
WHERE extra_json @> '{"seed":"hot"}'::jsonb;

CREATE INDEX tmp_chat_messages_jsonb_bench_gin
ON tmp_chat_messages_jsonb_bench USING GIN (extra_json jsonb_path_ops);

ANALYZE tmp_chat_messages_jsonb_bench;

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM tmp_chat_messages_jsonb_bench
WHERE extra_json @> '{"seed":"hot"}'::jsonb;

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM tmp_chat_messages_jsonb_bench
WHERE extra_json @> '{"attrs":{"vip":true}}'::jsonb;

SELECT
  pg_size_pretty(pg_relation_size('tmp_chat_messages_jsonb_bench_gin')) AS gin_index_size;
