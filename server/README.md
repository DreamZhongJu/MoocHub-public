# Server（MoocHub）

## 目标
提供课程/视频/评论/收藏/学习进度等 API，并支持管理端操作与 AI 问答能力。

## 运行
```bash
cd server

go run main.go
```

启动脚本包含密钥与环境变量，已从仓库忽略。可在本地按下述模板创建：

PowerShell 示例：
```powershell
$env:LIGHTRAG_SYNC_URL = "http://127.0.0.1:9621/documents/text"
$env:LIGHTRAG_QUERY_URL = "http://127.0.0.1:9621/query"
$env:DEEPSEEK_API_BASE_URL = "https://api.deepseek.com/v1"
$env:DEEPSEEK_API_KEY = "<your_api_key>"
$env:DEEPSEEK_MODEL = "deepseek-chat"
$env:DEEPSEEK_TIMEOUT_MS = "120000"

$env:JWT_SECRET = "<your_jwt_secret>"

go run main.go
```

Bash 示例：
```bash
export LIGHTRAG_SYNC_URL="http://127.0.0.1:9621/documents/text"
export LIGHTRAG_QUERY_URL="http://127.0.0.1:9621/query"
export DEEPSEEK_API_BASE_URL="https://api.deepseek.com/v1"
export DEEPSEEK_API_KEY="<your_api_key>"
export DEEPSEEK_MODEL="deepseek-chat"
export DEEPSEEK_TIMEOUT_MS="120000"

export JWT_SECRET="<your_jwt_secret>"

go run main.go
```

## 目录结构（关键）
- `controllers/`：控制器
- `model/`：数据模型
- `router/`：路由
- `db/`：数据库初始化
- `middleware/`：鉴权、日志、CORS
- `config/`：环境变量
- `logs/`：日志输出

## 环境变量
> 默认配置写在 `server/config/db.go`，如需覆盖可使用系统环境变量。
- `DB_DRIVER`：SQL 数据库驱动，`mysql` 或 `postgres`，默认 `mysql`
- `MYSQL_DSN`：MySQL 连接
- `POSTGRES_DSN`：PostgreSQL 连接（当 `DB_DRIVER=postgres` 时使用）
- `MONGO_URI`：MongoDB 连接
- `MONGO_DB`：MongoDB 数据库名
- `MINIO_ENDPOINT`：MinIO 服务地址（如 `127.0.0.1:9000`）
- `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY`：MinIO 账号密码
- `MINIO_BUCKET`：存储桶（如 `moochub-video`）
- `MINIO_SECURE`：是否 https（`true/false`）
- `MINIO_USE_PRESIGN`：是否启用签名 URL（`true/false`）
- `MINIO_PRESIGN_EXPIRE`：签名 URL 有效期（秒）
- `REDIS_ADDR`：Redis 地址（示例：`127.0.0.1:16379`）
- `REDIS_PASSWORD`：Redis 密码（如无可空）
- `REDIS_DB`：Redis DB（默认 0）
- `RABBITMQ_URL`：RabbitMQ 连接（示例：`amqp://guest:guest@127.0.0.1:5672/`）
- `INTERNAL_TOKEN`：内部接口 Token（用于内部接口鉴权）
- `JWT_SECRET`：JWT 签名密钥
- `LIGHTRAG_SYNC_URL`：LightRAG 同步接口地址（未配置时知识同步 worker 不启动）
- `LIGHTRAG_SYNC_TOKEN`：LightRAG 同步接口 Bearer Token（可选）
- `LIGHTRAG_SYNC_TIMEOUT_MS`：LightRAG 同步请求超时（毫秒，默认 `5000`）
- `LIGHTRAG_SYNC_MAX_RETRY`：LightRAG 同步最大重试次数（默认 `3`，超限后进入死信队列）
- `LIGHTRAG_QUERY_URL`：LightRAG 查询接口地址（未配置时 `/api/v1/ai/query` 返回 `503`）
- `LIGHTRAG_QUERY_TOKEN`：LightRAG 查询接口 Bearer Token（可选）
- `LIGHTRAG_QUERY_TIMEOUT_MS`：LightRAG 查询超时（毫秒，默认 `120000`）
- `DEEPSEEK_API_BASE_URL`：DeepSeek API Base URL
- `DEEPSEEK_API_KEY`：DeepSeek API Key
- `DEEPSEEK_MODEL`：DeepSeek 模型名（默认 `deepseek-chat`）
- `DEEPSEEK_TIMEOUT_MS`：DeepSeek 请求超时（毫秒）
- `FCM_SERVICE_ACCOUNT`：Firebase 服务账号 JSON 文件路径
- `FCM_PROJECT_ID`：Firebase 项目 ID（可选，默认从服务账号读取）
- `LOG_ACCESS_SAMPLE_RATE`：访问日志采样率（`0~1`，默认 `1`）
- `LOG_SLOW_THRESHOLD_MS`：慢请求阈值（毫秒，默认 `1000`）
- `RATE_LIMIT_GLOBAL_PER_MIN`：全局请求限流（默认 `300/min`）
- `RATE_LIMIT_AUTH_PER_MIN`：登录/注册限流（默认 `40/min`）
- `RATE_LIMIT_WRITE_PER_MIN`：写接口限流（默认 `120/min`）
- `IDEMPOTENCY_TTL_SEC`：幂等结果缓存 TTL（默认 `600s`）
- `BREAKER_FAILURE_THRESHOLD`：熔断触发连续失败阈值（默认 `5`）
- `BREAKER_OPEN_SEC`：熔断打开时长（默认 `30s`）

## 对象存储（MinIO）
### 1) 部署
```bash
docker run -d --name minio \
  -p 9000:9000 -p 9001:9001 \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=<your_minio_root_password>
  -v D:/data/minio:/data \
  minio/minio server /data --console-address ":9001"
```

### 2) 创建 bucket 与账号
- 控制台：`http://127.0.0.1:9001`
- 创建 bucket：`moochub-video`
- 创建用户并赋予读写权限

### 3) 服务端配置
- 方案 B 使用 **签名 URL**：服务端返回 `video_url` / `thumb_url` 为临时可访问地址
- 建议填入：
  - `MINIO_ENDPOINT=127.0.0.1:9000`
  - `MINIO_ACCESS_KEY=minioadmin`
  - `MINIO_SECRET_KEY=<your_minio_secret_key>
  - `MINIO_BUCKET=moochub-video`
  - `MINIO_SECURE=false`
  - `MINIO_USE_PRESIGN=true`
  - `MINIO_PRESIGN_EXPIRE=3600`

### 4) 数据库存储约定
- `videos.video_url` / `videos.thumb_url` **只存对象 Key**
  - 示例：`videos/1000/10001.mp4`、`thumbs/1000/10001.png`
- MinIO 内对象路径必须与数据库 Key 一致

## AI 与 LightRAG
- `/api/v1/ai/query` 为统一查询入口
- LightRAG 查询：配置 `LIGHTRAG_QUERY_URL`
- DeepSeek 回退：配置 `DEEPSEEK_API_*`

## 统一日志与链路追踪（已接入）
- 请求可带 `X-Trace-Id`；未传时后端自动生成。
- 每个响应头都会回传 `X-Trace-Id`，响应 JSON 追加 `trace_id` 字段。
- HTTP 访问日志统一结构化字段：`trace_id / method / path / status / latency / ip / user_agent / user_id`。
- MQ 事件会透传 `trace_id`。

## 缓存 / 限流 / 熔断 / 重试 / 幂等（已接入）
- 课程/文章列表与详情缓存
- 热点保护：Redis 锁 + stale 兜底
- 限流：全局/IP/写接口/登录单独限流
- 熔断：FCM、MinIO
- 重试：MQ/FCM/MinIO
- 幂等：`Idempotency-Key`

## API 文档
统一前缀：`/api/v1`

### 认证与用户
| 方法 | 路径             | 权限 | 请求参数                           | 响应                                               |
| ---- | ---------------- | ---- | ---------------------------------- | -------------------------------------------------- |
| POST | `/auth/register` | 无   | `username`, `password`, `nickname` | `user`, `token`                                    |
| POST | `/auth/login`    | 无   | `username`, `password`             | `user`, `token`                                    |
| GET  | `/auth/me`       | 登录 | -                                  | `id`, `username`, `nickname`, `avatar_url`, `role` |

### 分类与课程
| 方法 | 路径                       | 权限 | 请求参数                                     | 响应                                      |
| ---- | -------------------------- | ---- | -------------------------------------------- | ----------------------------------------- |
| GET  | `/categories`              | 无   | -                                            | 分类树（`id`, `name`, `parent_id`）       |
| GET  | `/categories/{id}/courses` | 无   | `sort?`, `page`, `page_size`                 | 课程列表                                  |
| GET  | `/courses`                 | 无   | `category_id?`, `sort?`, `page`, `page_size` | 课程列表                                  |
| GET  | `/recommend/courses`       | 无   | `page`, `page_size`                          | 最小个性化推荐课程流（70%个性化+30%热门） |
| GET  | `/courses/{id}`            | 无   | -                                            | 课程详情 + `videos`                       |

### 视频
| 方法 | 路径           | 权限 | 请求参数 | 响应                                                                                |
| ---- | -------------- | ---- | -------- | ----------------------------------------------------------------------------------- |
| GET  | `/videos/{id}` | 无   | -        | `id`, `course_id`, `title`, `description`, `duration_sec`, `video_url`, `thumb_url` |

### 文章
| 方法 | 路径                  | 权限 | 请求参数                                    | 响应      |
| ---- | --------------------- | ---- | ------------------------------------------- | --------- |
| GET  | `/articles`           | 无   | `sort?`, `page`, `page_size`                | 文章列表  |
| GET  | `/articles/{id}`      | 无   | -                                           | 文章详情  |
| POST | `/articles/{id}/view` | 无   | -                                           | 阅读 +1   |
| POST | `/articles/{id}/like` | 登录 | -                                           | 点赞 +1   |
| POST | `/articles`           | 登录 | `title`, `summary`, `cover_url?`, `content` | `article` |

### 搜索
| 方法 | 路径              | 权限 | 请求参数                                                             | 响应                                              |
| ---- | ----------------- | ---- | -------------------------------------------------------------------- | ------------------------------------------------- |
| GET  | `/search`         | 无   | `keyword`, `scope?=all/course/article`, `sort?`, `page`, `page_size` | `courses` + `articles` + `total_courses/articles` |
| GET  | `/search/suggest` | 无   | `keyword`, `limit?`                                                  | `suggestions`（联想词）                           |

### AI 问答
| 方法 | 路径        | 权限 | 请求参数                                                                 | 响应                                                      |
| ---- | ----------- | ---- | ------------------------------------------------------------------------ | --------------------------------------------------------- |
| POST | `/ai/query` | 无   | `query`, `mode?`, `scope?`, `course_id?`, `article_id?`, `top_k?`        | `answer`, `sources`, `entities`, `mode_used`, `confidence` |

### 收藏
| 方法   | 路径                               | 权限 | 请求参数     | 响应                           |
| ------ | ---------------------------------- | ---- | ------------ | ------------------------------ |
| POST   | `/favorites/courses`               | 登录 | `course_id`  | -                              |
| DELETE | `/favorites/courses/{course_id}`   | 登录 | -            | -                              |
| POST   | `/favorites/videos`                | 登录 | `video_id`   | -                              |
| DELETE | `/favorites/videos/{video_id}`     | 登录 | -                              |
| POST   | `/favorites/articles`              | 登录 | `article_id` | -                              |
| DELETE | `/favorites/articles/{article_id}` | 登录 | -                              |
| GET    | `/favorites`                       | 登录 | -            | 收藏课程 + 收藏视频 + 收藏文章 |

### 评论（MongoDB）
| 方法 | 路径                  | 权限 | 请求参数                                        | 响应         |
| ---- | --------------------- | ---- | ----------------------------------------------- | ------------ |
| GET  | `/comments`           | 无   | `target_type`, `target_id`, `page`, `page_size` | 评论列表     |
| POST | `/comments`           | 登录 | `target_type`, `target_id`, `content`           | `comment`    |
| POST | `/comments/{id}/like` | 登录 | -                                               | `like_count` |

### 学习进度
| 方法 | 路径                   | 权限 | 请求参数                                            | 响应                                    |
| ---- | ---------------------- | ---- | --------------------------------------------------- | --------------------------------------- |
| POST | `/progress`            | 登录 | `video_id`, `last_position_sec`, `progress_percent` | -                                       |
| GET  | `/progress/{video_id}` | 登录 | -                                                   | `last_position_sec`, `progress_percent` |
| GET  | `/progress/latest`     | 登录 | -                                                   | `video`, `progress`                     |

### 埋点事件
| 方法 | 路径               | 权限 | 请求参数                                                           | 响应              |
| ---- | ------------------ | ---- | ------------------------------------------------------------------ | ----------------- |
| POST | `/events/exposure` | 无   | `content_type`, `content_id`, `scene?`, `session_id?`, `position?` | `skipped`（去重） |
| POST | `/events/click`    | 无   | `content_type`, `content_id`, `scene?`, `session_id?`, `position?` | `skipped`（去重） |
| POST | `/events/complete` | 无   | `content_type`, `content_id`, `scene?`, `session_id?`, `position?` | `skipped`（去重） |
| POST | `/events/play`     | 无   | `video_id`, `scene?`, `session_id?`, `position?`                   | `skipped`（去重） |

### 积分体系
| 方法 | 路径                    | 权限 | 请求参数                                     | 响应                          |
| ---- | ----------------------- | ---- | -------------------------------------------- | ----------------------------- |
| GET  | `/points/balance`       | 登录 | -                                            | `points_balance`              |
| GET  | `/points/transactions`  | 登录 | `page`, `page_size`, `event_type?`           | 积分流水列表                  |
| GET  | `/points/rank`          | 登录 | `page`, `page_size`                          | 排行榜（按 `points_balance`） |
| POST | `/points/award`（内部） | 内部 | `event_type`, `points`, `biz_id?`, `remark?` | -                             |

### 消息通知
| 方法 | 路径                      | 权限 | 请求参数                                         | 响应                     |
| ---- | ------------------------- | ---- | ------------------------------------------------ | ------------------------ |
| GET  | `/messages`               | 登录 | `type?`, `page`, `page_size`                     | `items`, `page`, `total` |
| GET  | `/messages/unread_count`  | 登录 | `type?`                                          | `unread_count`           |
| POST | `/messages/read`          | 登录 | `ids?`, `type?`, `all?`                          | `updated`                |
| POST | `/messages/award`（内部） | 内部 | `user_id`, `type`, `title`, `content`, `biz_id?` | -                        |

### 实时聊天（MVP）
> 先执行建表脚本：`server/scripts/chat_schema.sql`

| 方法 | 路径                        | 权限 | 请求参数                                                              | 响应                          |
| ---- | --------------------------- | ---- | --------------------------------------------------------------------- | ----------------------------- |
| GET  | `/chat/conversations`       | 登录 | `page`, `page_size`                                                   | 会话列表（含 `unread_count`） |
| POST | `/chat/private/start`       | 登录 | `target_user_id`                                                      | 私聊会话                      |
| POST | `/chat/groups`              | 登录 | `name`, `avatar_url?`, `member_ids[]`                                 | 群聊会话                      |
| POST | `/chat/groups/{id}/members` | 登录 | `user_ids[]`                                                          | -                             |
| GET  | `/chat/messages`            | 登录 | `conversation_id`, `page`, `page_size`                                | 消息列表                      |
| POST | `/chat/messages`            | 登录 | `conversation_id`, `msg_type?`(默认 `text`), `content`, `extra_json?` | 新消息                        |
| POST | `/chat/read`                | 登录 | `conversation_id`, `last_message_id`                                  | -                             |
| GET  | `/chat/unread_count`        | 登录 | -                                                                     | 总未读                        |

### 设备推送 Token
| 方法 | 路径             | 权限 | 请求参数             | 响应 |
| ---- | ---------------- | ---- | -------------------- | ---- |
| POST | `/device_tokens` | 登录 | `token`, `platform?` | -    |

### 文件上传（MinIO）
| 方法 | 路径       | 权限 | 请求参数                  | 响应         |
| ---- | ---------- | ---- | ------------------------- | ------------ |
| POST | `/uploads` | 登录 | `file`(multipart), `dir?` | `key`, `url` |

### 管理端（MVP）
| 方法   | 路径                        | 权限   | 请求参数                                                                                    | 响应                           |
| ------ | --------------------------- | ------ | ------------------------------------------------------------------------------------------- | ------------------------------ |
| GET    | `/admin/analytics/overview` | 管理员 | `from?`, `to?`, `content_type?`, `scene?`                                                   | 汇总指标（曝光/点击/完播/CTR） |
| GET    | `/admin/analytics/trend`    | 管理员 | `from?`, `to?`, `content_type?`, `scene?`                                                   | 小时趋势（PV/UV/CTR/完播率）   |
| GET    | `/admin/analytics/top`      | 管理员 | `from?`, `to?`, `event_type?`, `content_type?`, `scene?`, `limit?`                          | Top 内容（按 PV）              |
| POST   | `/admin/cache/prewarm`      | 管理员 | `trigger?`                                                                                  | 手动触发缓存预热               |
| POST   | `/admin/courses`            | 管理员 | `category_id`, `title`, `summary`, `cover_url`, `instructor_name`, `level`, `status`        | `course`                       |
| PUT    | `/admin/courses/{id}`       | 管理员 | 可选字段                                                                                    | -                              |
| DELETE | `/admin/courses/{id}`       | 管理员 | -                                                                                           | -                              |
| POST   | `/admin/videos`             | 管理员 | `course_id`, `title`, `description`, `duration_sec`, `video_url`, `thumb_url`, `sort_order` | `video`                        |
| PUT    | `/admin/videos/{id}`        | 管理员 | 可选字段                                                                                    | -                              |
| DELETE | `/admin/videos/{id}`        | 管理员 | -                                                                                           | -                              |
| DELETE | `/admin/comments/{id}`      | 管理员 | -                                                                                           | -                              |
| POST   | `/admin/push`               | 管理员 | `user_id?`, `user_ids?`, `title`, `content`, `type?`, `route?`, `biz_id?`                   | `sent`, `failed`               |
