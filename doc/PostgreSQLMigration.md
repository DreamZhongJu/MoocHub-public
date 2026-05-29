# MoocHub MySQL to PostgreSQL Migration

这份文档用于两件事：

1. 保留你需要学习和理解的 PostgreSQL 迁移知识点。
2. 把重复性执行步骤整理成命令，后续可以直接交给 Codex 跑。

## 当前项目事实

- 后端是 Go + GORM。
- 原来固定使用 `gorm.io/driver/mysql` 和 `MYSQL_DSN`。
- 现在已支持通过 `DB_DRIVER` 在 MySQL/PostgreSQL 之间切换。
- MongoDB、Redis、RabbitMQ、MinIO 不属于这次 SQL 数据库迁移范围。
- 主要 SQL 风险点已经处理：
  - `ON DUPLICATE KEY UPDATE` 改成 GORM `clause.OnConflict`。
  - `is_read = 0`、聊天表 `is_deleted = 0` 改成可兼容 PostgreSQL boolean 的写法。

## 本地启动 PostgreSQL

```powershell
docker run -d --name moochub-postgres `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=root `
  -e POSTGRES_DB=moochub `
  -p 5432:5432 `
  postgres:16
```

建表：

```powershell
psql "postgresql://postgres:root@127.0.0.1:5432/moochub?sslmode=disable" `
  -f server/scripts/postgres_schema.sql
```

后端切到 PostgreSQL：

```powershell
$env:DB_DRIVER = "postgres"
$env:POSTGRES_DSN = "host=127.0.0.1 user=postgres password=root dbname=moochub port=5432 sslmode=disable TimeZone=Asia/Shanghai"

cd server
go run main.go
```

仍然使用 MySQL：

```powershell
$env:DB_DRIVER = "mysql"
$env:MYSQL_DSN = "root:root@tcp(127.0.0.1:3306)/moochub?parseTime=true"
```

## 数据迁移方案

推荐先用 `pgloader` 从正在运行的 MySQL 直连迁移，而不是手工改 `moochub_with_data.sql`。原因是 dump 里有大量 MySQL 方言，例如反引号、`AUTO_INCREMENT`、`datetime ON UPDATE`、`enum`、`tinyint(1)`、`json`，手改容易漏。

```bash
pgloader mysql://root:root@127.0.0.1:3306/moochub \
  postgresql://postgres:root@127.0.0.1:5432/moochub
```

迁移后重点检查 boolean 字段：

```sql
ALTER TABLE messages
  ALTER COLUMN is_read TYPE boolean USING is_read <> 0,
  ALTER COLUMN is_read SET DEFAULT false;

ALTER TABLE chat_conversations
  ALTER COLUMN is_deleted TYPE boolean USING is_deleted <> 0,
  ALTER COLUMN is_deleted SET DEFAULT false;

ALTER TABLE chat_conversation_members
  ALTER COLUMN is_deleted TYPE boolean USING is_deleted <> 0,
  ALTER COLUMN is_deleted SET DEFAULT false;

ALTER TABLE chat_messages
  ALTER COLUMN is_deleted TYPE boolean USING is_deleted <> 0,
  ALTER COLUMN is_deleted SET DEFAULT false;
```

`favorite_courses`、`favorite_videos`、`favorite_articles` 的 `is_deleted` 在 Go 代码里是 `int`，可以继续保留 `smallint` 或 `integer`。

迁移后修正自增序列：

```sql
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT table_name
    FROM information_schema.columns
    WHERE table_schema = 'public' AND column_name = 'id'
  LOOP
    EXECUTE format(
      'SELECT setval(pg_get_serial_sequence(%L, %L), COALESCE((SELECT MAX(id) FROM %I), 1), true)',
      r.table_name,
      'id',
      r.table_name
    );
  END LOOP;
END $$;
```

## 验证清单

- `go test ./...` 通过。
- 后端可用 `DB_DRIVER=postgres` 启动。
- 注册、登录、课程列表、课程详情、收藏、学习进度、消息未读数、聊天、埋点接口至少各测一次。
- 对比 MySQL/PostgreSQL 核心表行数：

```sql
SELECT 'users' AS table_name, COUNT(*) FROM users
UNION ALL SELECT 'course_categories', COUNT(*) FROM course_categories
UNION ALL SELECT 'courses', COUNT(*) FROM courses
UNION ALL SELECT 'videos', COUNT(*) FROM videos
UNION ALL SELECT 'articles', COUNT(*) FROM articles
UNION ALL SELECT 'learning_progress', COUNT(*) FROM learning_progress;
```

## 你应该重点学的 PostgreSQL 知识

- 类型映射：`AUTO_INCREMENT` 到 `BIGSERIAL`/identity，`datetime` 到 `timestamp/timestamptz`，`longtext` 到 `text`，`json` 到 `jsonb`，`tinyint(1)` 到 `boolean`。
- Upsert：MySQL `ON DUPLICATE KEY UPDATE` 对应 PostgreSQL `ON CONFLICT (...) DO UPDATE`。
- 自增序列：导入已有 id 后，需要 `setval` 修正序列。
- 时间字段：PostgreSQL 没有 MySQL 的 `ON UPDATE CURRENT_TIMESTAMP`，通常用应用层更新或 trigger。
- 索引：普通 B-tree 多列索引语法相近，但 PostgreSQL 还可以学习 partial index、GIN、expression index。
- SQL 方言习惯：布尔值用 `true/false`，字符串拼接可用 `concat()` 或 `||`。

## Codex 可代劳的重复工作

- 启动本地 PostgreSQL 容器并建库。
- 跑 `pgloader` 或按导出文件迁移数据。
- 批量对比 MySQL/PostgreSQL 行数。
- 跑后端测试并修 SQL 兼容问题。
- 写临时数据校验脚本，例如检查外键孤儿数据、序列值、关键接口 smoke test。
