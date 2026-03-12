<div align="center">

# MoocHub

湖北大学计算机专业毕业设计项目（Flutter + Go）

[![License](https://img.shields.io/github/license/DreamZhongJu/MoocHub)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/DreamZhongJu/MoocHub)](https://github.com/DreamZhongJu/MoocHub/commits/main)
[![Repo Stars](https://img.shields.io/github/stars/DreamZhongJu/MoocHub?style=social)](https://github.com/DreamZhongJu/MoocHub/stargazers)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-blue)](https://github.com/DreamZhongJu/MoocHub/pulls)
[![CI Check](https://img.shields.io/github/actions/workflow/status/DreamZhongJu/MoocHub/ci-check.yml?branch=main&label=CI)](https://github.com/DreamZhongJu/MoocHub/actions/workflows/ci-check.yml)
[![Android Build](https://img.shields.io/github/actions/workflow/status/DreamZhongJu/MoocHub/build-android.yml?branch=main&label=Android%20Build)](https://github.com/DreamZhongJu/MoocHub/actions/workflows/build-android.yml)

[快速开始](#快速运行) | [文档导航](#文档导航) | [技术栈](#技术栈) | [开发流程](doc/DevWorkflow.md) | [更新日志](CHANGELOG.md)

</div>

面向“中国大学 MOOC”风格的在线学习社区（移动端为主）。支持课程浏览、视频播放、评论互动、收藏与学习进度。目标交付：可运行系统 + 规范论文。

## 核心能力
- 多端学习体验：课程浏览、视频播放、评论互动、收藏和学习进度
- 推荐与运营能力：埋点看板、推荐系统、缓存预热、热点保护
- 稳定性工程：限流、熔断、重试、幂等、结构化日志与 trace
- 客户端体验：离线缓存、弱网重试、统一骨架屏/空态
- 工程协作：CI/CD、PR 流程、版本管理、Release 产物

## 导航目录
- [功能截图](#功能截图)
- [系统架构图](#系统架构图)
- [版本节奏](#版本节奏)
- [文档导航](#文档导航)
- [快速运行](#快速运行)
- [API 文档](#api-文档)
- [TODO List](#todo-list)
- [贡献与协作](#贡献与协作)

## 功能截图
> 当前先放统一展示区位，后续可替换成真实页面截图（首页/课程详情/消息/学习页）。

<div align="center">
  <img src="./flutter_app/assets/icon.png" alt="MoocHub App Icon" width="96" />
</div>

| 首页推荐流                 | 学习页进度                  | 消息页                         |
| -------------------------- | --------------------------- | ------------------------------ |
| `doc/screenshots/home.png` | `doc/screenshots/study.png` | `doc/screenshots/messages.png` |

| 管理后台                    | 数据看板                      | 搜索与文章                           |
| --------------------------- | ----------------------------- | ------------------------------------ |
| `doc/screenshots/admin.png` | `doc/screenshots/grafana.png` | `doc/screenshots/search_article.png` |

## 系统架构图
```mermaid
flowchart LR
  A[Flutter App] --> B[Go API Server]
  B --> C[(MySQL)]
  B --> D[(MongoDB)]
  B --> E[(Redis)]
  B --> F[(RabbitMQ)]
  B --> G[(MinIO)]
  H[Grafana] --> C
  I[Prometheus] --> B
```

## 版本节奏
| 轨道       | 说明                                      | 入口                                                                        |
| ---------- | ----------------------------------------- | --------------------------------------------------------------------------- |
| 需求规划   | TODO 拆分、Issue 管理、迭代范围冻结       | [Issues](https://github.com/DreamZhongJu/MoocHub/issues)                    |
| 开发联调   | 功能分支开发 + PR 评审 + CI 门禁          | [Pull Requests](https://github.com/DreamZhongJu/MoocHub/pulls)              |
| 持续集成   | Flutter/Go 检查、Android 构建、格式与测试 | [Actions](https://github.com/DreamZhongJu/MoocHub/actions)                  |
| 版本发布   | Tag + Release + 变更说明 + APK 产物       | [Releases](https://github.com/DreamZhongJu/MoocHub/releases)                |
| 里程碑追踪 | 版本目标、已完成事项、下一阶段计划        | [CHANGELOG.md](CHANGELOG.md) / [doc/CompletedTodo.md](doc/CompletedTodo.md) |

## 文档导航
- 开发流程与 PR 规范：[`doc/DevWorkflow.md`](doc/DevWorkflow.md)
- CI/CD 落地计划：[`doc/CICDPlan.md`](doc/CICDPlan.md)
- 版本更新日志：[`CHANGELOG.md`](CHANGELOG.md)
- 已完成 TODO 清单：[`doc/CompletedTodo.md`](doc/CompletedTodo.md)
- 推送系统说明：[`doc/PushSystem.md`](doc/PushSystem.md)
- 第三方登录（QQ）：[`doc/ThirdPartyLogin.md`](doc/ThirdPartyLogin.md)
- 实时聊天方案：[`doc/ChatSystem.md`](doc/ChatSystem.md)
- 埋点看板方案：[`doc/AnalyticsDashboard.md`](doc/AnalyticsDashboard.md)
- LightRAG 接入路线：[`doc/LightRAGPlan.md`](doc/LightRAGPlan.md)
- LightRAG 任务拆解：[`doc/LightRAGTaskBreakdown.md`](doc/LightRAGTaskBreakdown.md)
- LightRAG 导出接口：[`doc/LightRAGKnowledgeExportAPI.md`](doc/LightRAGKnowledgeExportAPI.md)

## 项目定位
- 产品形态：学习社区 + 课程平台
- 首页风格：类 B 站推荐流（卡片瀑布流 + 热门/继续观看）
- MVP 功能：课程/视频/评论/收藏/进度/用户中心
- 当前深化方向：已完成功能稳定化 + LightRAG 路线接入 + 论文实验材料整理

## 技术栈
- 客户端：Flutter
- 后端：Go (Gin/Gorm)
- 数据库：MySQL + MongoDB
- 文件/对象存储：MinIO（本地部署，S3 兼容）
- 缓存：Redis（课程列表/课程详情/继续观看）
- 消息队列：RabbitMQ（进度事件异步处理）

## 目录结构
- `flutter_app/`：Flutter 客户端
- `server/`：Go 服务端
- `doc/`：技术文档

## 快速运行
### Server
```bash
cd server
# 配置环境变量（见 server/config/db.go）
# 启动
 go run main.go
```

### Flutter
```bash
cd flutter_app
flutter pub get
flutter run
```

## 环境变量
> 当前后端默认配置写在 `server/config/db.go`，如需覆盖可使用系统环境变量（可选）。
- `MYSQL_DSN`：MySQL 连接
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
- `LIGHTRAG_SYNC_URL`：LightRAG 同步接口地址（未配置时知识同步 worker 不启动）
- `LIGHTRAG_SYNC_TOKEN`：LightRAG 同步接口 Bearer Token（可选）
- `LIGHTRAG_SYNC_TIMEOUT_MS`：LightRAG 同步请求超时（毫秒，默认 `5000`）
- `LIGHTRAG_SYNC_MAX_RETRY`：LightRAG 同步最大重试次数（默认 `3`，超限后进入死信队列）
- `LIGHTRAG_QUERY_URL`：LightRAG 查询接口地址（未配置时 `/api/v1/ai/query` 返回 `503`）
- `LIGHTRAG_QUERY_TOKEN`：LightRAG 查询接口 Bearer Token（可选）
- `LIGHTRAG_QUERY_TIMEOUT_MS`：LightRAG 查询超时（毫秒，默认 `8000`）
- `FCM_SERVICE_ACCOUNT`：Firebase 服务账号 JSON 文件路径
- `FCM_PROJECT_ID`：Firebase 项目 ID（可选，默认从服务账号读取）
- `LOG_ACCESS_SAMPLE_RATE`：访问日志采样率（`0~1`，默认 `1`，错误与慢请求不采样）
- `LOG_SLOW_THRESHOLD_MS`：慢请求阈值（毫秒，默认 `1000`）
- `RATE_LIMIT_GLOBAL_PER_MIN`：全局请求限流（默认 `300/min`）
- `RATE_LIMIT_AUTH_PER_MIN`：登录/注册限流（默认 `40/min`）
- `RATE_LIMIT_WRITE_PER_MIN`：写接口限流（默认 `120/min`）
- `IDEMPOTENCY_TTL_SEC`：幂等结果缓存 TTL（默认 `600s`）
- `BREAKER_FAILURE_THRESHOLD`：熔断触发连续失败阈值（默认 `5`）
- `BREAKER_OPEN_SEC`：熔断打开时长（默认 `30s`）
- `BACKEND_HOST`：Flutter 端后端地址（assets/.env）

> 为了避免敏感文件入库，建议把 `serviceAccount.json` 放到 `server/secrets/`，并通过启动参数或环境变量加载。

## 统一日志与链路追踪（已接入）
- 请求可带 `X-Trace-Id`；未传时后端自动生成。
- 每个响应头都会回传 `X-Trace-Id`，响应 JSON 追加 `trace_id` 字段。
- HTTP 访问日志统一结构化字段：`trace_id / method / path / status / latency / ip / user_agent / user_id`。
- MQ 事件（`progress.updated`、`play.view`、`analytics.event`）会透传 `trace_id`，消费者日志可按同一 `trace_id` 串联。
- 采样策略：成功请求按 `LOG_ACCESS_SAMPLE_RATE` 采样；`4xx/5xx` 与慢请求全量记录。

## 缓存预热 / 热点保护 / 分页索引优化（已接入）
- 课程列表、课程详情、文章列表、文章详情、分类列表、搜索联想接入缓存。
- 热点保护：缓存 miss 时加 Redis 锁 + 短等待 + stale 旧值兜底，避免击穿。
- 预热策略：服务启动后立即预热，之后每 5 分钟自动预热；可通过 `/api/v1/admin/cache/prewarm` 手动触发。
- 分页排序优化：列表查询补充稳定排序（`... DESC, id DESC`），减少翻页抖动。
- 索引脚本：`server/scripts/cache_paging_indexes.sql`。

## 限流 / 熔断 / 重试 / 幂等（已接入）
- 限流：
  - 全局按 IP 限流（固定窗口，Redis 计数）
  - 登录注册单独限流
  - 写接口按用户（未登录回退 IP）限流
- 熔断：
  - FCM 发送链路接入熔断
  - MinIO URL 解析与上传接入熔断
- 重试：
  - MQ 发布失败自动重试（指数退避）
  - FCM 发送在 5xx/429 与网络错误时重试
  - MinIO 预签名失败自动重试
- 幂等：
  - 写接口支持请求头 `Idempotency-Key`
  - 重复请求返回首次结果，响应头带 `X-Idempotent-Replay: 1`

## 离线缓存 / 弱网策略 / 骨架屏 / 空态统一（Flutter 端，已接入）
- 离线缓存：
  - 新增通用离线缓存仓（Hive `offline_cache`），支持 TTL 读取。
  - 首页推荐流、搜索结果、分类课程列表已接入离线回退。
- 弱网策略：
  - `ApiService` 新增 `getWithRetry`（指数退避重试，针对超时/连接异常/429/5xx）。
  - 页面层在请求失败后优先回退离线缓存，并给出弱网提示。
- 骨架屏与空态统一：
  - 新增 `flutter_app/lib/widget/AppStateWidgets.dart`：
    - `AppGridSkeleton`
    - `AppListSkeleton`
    - `AppEmptyState`
    - `AppWeakNetworkBanner`
  - 首页、搜索页、分类课程列表、文章列表、消息页、学习页已切换为统一组件。

## CI/CD 协作规范（私有仓库免费版）
> 当前仓库为私有且未升级 Team/Enterprise，GitHub 分支保护规则会显示 `Not enforced`。  
> 因此本项目采用“流程强约束”方式执行门禁。

详细流程见：[`doc/DevWorkflow.md`](doc/DevWorkflow.md)

### 1) 合并门禁（必须执行）
- 所有代码变更必须走 PR，禁止直接向 `main` 提交。
- PR 合并前必须满足：
  - `CI Check / flutter-check` 通过
  - `CI Check / server-check` 通过
  - `Build Android` 至少手动验证通过一次（关键改动建议每次验证）
- 至少完成一次代码自检：
  - Flutter：`flutter format --set-exit-if-changed .`、`flutter analyze`、`flutter test`
  - Server：`gofmt -w <文件列表>`、`go vet ./...`、`go test ./...`

### 2) PR 的作用
- 代码评审入口：让改动在合并前可审查、可讨论、可追踪。
- 质量闸门入口：CI 在 PR 上自动执行，提前发现格式/编译/测试问题。
- 变更审计入口：保留每次变更的背景、决策与回滚依据。

### 3) CI/CD 建议落地阶段
- 第 1 阶段（项目启动后尽早）：接入最小 CI（format/lint/build/test）。
- 第 2 阶段（功能迭代期）：补齐自动化测试、产物构建、缓存与依赖优化。
- 第 3 阶段（提测/上线前）：接入发布流水线（tag/release）、环境配置与回滚策略。
- 第 4 阶段（运营期）：补充监控告警、质量阈值、发布节奏与变更审计。

### 4) 当前执行策略（本仓库）
- 规则“已创建但不强制”，以人工流程保证质量：
  1. 功能分支开发
  2. 提交 PR
  3. 等 CI 全绿
  4. 审核通过后合并
  5. 合并后观察 `main` 上工作流与制品

## 对象存储
### 1) 部署 MinIO
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
- 创建用户：例如 `appuser / <your_minio_secret_key>`，赋予读写权限

### 3) 服务端配置
- 方案 B 使用 **签名 URL**：服务端返回 `video_url` / `thumb_url` 为临时可访问地址
- 当前默认配置写在 `server/config/db.go`（或用环境变量覆盖）
- 建议填入：
  - `MINIO_ENDPOINT=127.0.0.1:9000`
  - `MINIO_ACCESS_KEY=appuser`
  - `MINIO_SECRET_KEY=<your_minio_secret_key>
  - `MINIO_BUCKET=moochub-video`
  - `MINIO_SECURE=false`
  - `MINIO_USE_PRESIGN=true`
  - `MINIO_PRESIGN_EXPIRE=3600`

### 4) 数据库存储约定
- `videos.video_url` / `videos.thumb_url` **只存对象 Key**
  - 示例：`videos/1000/10001.mp4`、`thumbs/1000/10001.png`
- MinIO 内对象路径必须与数据库 Key 一致

---

## 数据库结构

### MySQL（结构化）
1) `users`
- `id` (PK)
- `username`, `password_hash`, `role` (student/admin)
- `nickname`, `avatar_url`
- `created_at`, `updated_at`

2) `course_categories`
- `id` (PK)
- `name`, `parent_id` (FK -> course_categories.id, 可空)
- `sort_order`

3) `courses`
- `id` (PK)
- `category_id` (FK -> course_categories.id)
- `title`, `summary`, `cover_url`
- `instructor_name`, `level`, `status` (draft/published)
- `view_count`, `favorite_count`
- `created_at`, `updated_at`

4) `videos`
- `id` (PK)
- `course_id` (FK -> courses.id)
- `title`, `description`, `duration_sec`
- `video_url`, `thumb_url`
- `sort_order`, `created_at`

5) `messages`
- `id` (PK)
- `user_id` (FK -> users.id)
- `type`（system/like/comment/dm 等）
- `title`, `content`
- `biz_id`（业务关联 ID，可空）
- `is_read`
- `created_at`

6) `device_tokens`
- `id` (PK)
- `user_id` (FK -> users.id)
- `platform`（android/ios 等）
- `token`（FCM Token）
- `created_at`, `updated_at`

7) `articles`
- `id` (PK)
- `user_id` (FK -> users.id)
- `title`, `summary`, `content`
- `cover_url`
- `status`
- `view_count`, `like_count`
- `created_at`, `updated_at`

7.1) `favorite_articles`
- `id` (PK)
- `user_id` (FK -> users.id)
- `article_id` (FK -> articles.id)
- `created_at`
- `is_deleted` (软删除)
- UNIQUE(`user_id`, `article_id`)

#### SQL（messages）
```sql
CREATE TABLE messages (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  type VARCHAR(32) NOT NULL,
  title VARCHAR(64) NOT NULL,
  content VARCHAR(512) NOT NULL,
  biz_id BIGINT UNSIGNED NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_created (user_id, created_at),
  INDEX idx_user_read (user_id, is_read),
  INDEX idx_user_type (user_id, type),
  CONSTRAINT fk_messages_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
);
```

#### SQL（device_tokens）
```sql
CREATE TABLE device_tokens (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  platform VARCHAR(16) NOT NULL DEFAULT 'android',
  token VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_device_token (token),
  INDEX idx_user_platform (user_id, platform),
  CONSTRAINT fk_device_tokens_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
);
```

#### SQL（articles）
```sql
CREATE TABLE articles (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(128) NOT NULL,
  summary VARCHAR(255) NOT NULL,
  cover_url VARCHAR(512) NOT NULL,
  content LONGTEXT NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'published',
  view_count BIGINT NOT NULL DEFAULT 0,
  like_count BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_created (user_id, created_at),
  INDEX idx_status_created (status, created_at),
  CONSTRAINT fk_articles_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
);
```

#### SQL（favorite_articles）
```sql
CREATE TABLE favorite_articles (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  article_id BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  UNIQUE KEY uk_fav_articles_user_article (user_id, article_id),
  INDEX idx_fav_articles_article (article_id),
  CONSTRAINT fk_fav_articles_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_fav_articles_article
    FOREIGN KEY (article_id) REFERENCES articles(id)
    ON DELETE CASCADE ON UPDATE CASCADE
);
```

8) `favorite_courses`
- `id` (PK)
- `user_id` (FK -> users.id)
- `course_id` (FK -> courses.id)
- `created_at`
- `is_deleted` (软删除)
- UNIQUE(`user_id`, `course_id`)

9) `favorite_videos`
- `id` (PK)
- `user_id` (FK -> users.id)
- `video_id` (FK -> videos.id)
- `created_at`
- `is_deleted` (软删除)
- UNIQUE(`user_id`, `video_id`)

10) `learning_progress`
- `id` (PK)
- `user_id` (FK -> users.id)
- `video_id` (FK -> videos.id)
- `last_position_sec`, `progress_percent`
- `updated_at`
- UNIQUE(`user_id`, `video_id`)

11) `points_transactions`
- `id` (PK)
- `user_id` (FK -> users.id)
- `event_type` (login/video_complete/comment/favorite/other)
- `points` (正负积分)
- `biz_id` (关联业务 ID，如 video_id/comment_id，可空)
- `remark` (可空)
- `created_at`
- 索引：`(user_id, created_at)`、`(event_type, created_at)`

12) `users`（积分字段扩展）
- `points_balance` (当前积分余额，默认 0)

13) `event_logs`（埋点原始事件）
- `id` (PK)
- `event_type`（`exposure/click/play_start/play_complete`）
- `content_type`, `content_id`
- `user_id`（可空）, `session_id`, `scene`, `position`
- `ip`, `ua`, `occurred_at`, `created_at`
- 索引：`(event_type, occurred_at)`、`(content_type, content_id, occurred_at)`

14) `event_stats_hourly`（埋点小时聚合）
- `id` (PK)
- `bucket_hour`（小时粒度）
- `event_type`, `content_type`, `content_id`, `scene`
- `pv`, `uv`
- `created_at`, `updated_at`
- UNIQUE(`bucket_hour`, `event_type`, `content_type`, `content_id`, `scene`)

> 建表脚本：`server/scripts/event_analytics_schema.sql`

### MongoDB（文档型）
1) `comments`
- `target_type` (course/video), `target_id` (MySQL ID)
- `user_id` (MySQL users.id)
- `content`, `like_count`, `status`, `created_at`
- `parent_id`（可空，用于回复，MVP 可不启用）
- 索引：`(target_type, target_id, created_at)`，`user_id`

2) `video_thumbnails`
- `video_id` (MySQL videos.id)
- `url`, `width`, `height`, `format`, `size_bytes`, `created_at`
- 索引：`video_id` 唯一

3) `recommend_events`（后期扩展）
- `user_id`, `video_id`, `event_type`(exposure/click/play), `created_at`
- 索引：`(user_id, created_at)`，`(video_id, created_at)`

---

## TODO List
状态说明：✅ 已实现 / ⬜ 未实现 / 🟡 部分完成

说明：
- 当前阶段不再新增业务功能，重点是已完成功能深化 + LightRAG 论文亮点落地
- 已完成事项已单独整理到：[`doc/CompletedTodo.md`](doc/CompletedTodo.md)
- 当前开发排期与迭代追踪以 GitHub `Issues + Projects` 为准

| 阶段 | 事项                                 | 细节 TODO                                                           | 状态 |
| ---- | ------------------------------------ | ------------------------------------------------------------------- | ---- |
| 12   | LightRAG 知识库接入                  | 课程/文章标准导出、图索引构建、增量更新（[#29](https://github.com/DreamZhongJu/MoocHub/issues/29) / [#30](https://github.com/DreamZhongJu/MoocHub/issues/30)） | ⬜    |
| 12   | LightRAG 智能问答                    | 多模式检索、课程/文章问答、引用来源展示（[#31](https://github.com/DreamZhongJu/MoocHub/issues/31) / [#32](https://github.com/DreamZhongJu/MoocHub/issues/32)） | ⬜    |
| 12   | LightRAG 内容总结                    | 课程要点提炼、章节摘要、学习卡片生成（[#33](https://github.com/DreamZhongJu/MoocHub/issues/33)） | ⬜    |
| 12   | LightRAG 自动出题                    | 按章节生成题目、答案与解析、错题讲解（[#33](https://github.com/DreamZhongJu/MoocHub/issues/33)） | ⬜    |
| 12   | LightRAG 语义搜索增强                | 语义召回 + 关键词混排 + 结果重排（[#33](https://github.com/DreamZhongJu/MoocHub/issues/33)） | ⬜    |
| 12   | LightRAG 评估与成本看板              | 命中率/延迟/成本统计、论文实验材料整理（[#34](https://github.com/DreamZhongJu/MoocHub/issues/34)） | ⬜    |
| 13   | 论文与答辩材料                       | 论文初稿/修订；PPT；演示脚本                                        | ⬜    |

---

## DIN 落地实施路线（已完成基础版，保留过程记录）

> 目标：在“热门推荐”基线之上，提升首页点击率（CTR）和完播率（Completion Rate）。

### 第 1 步：目标与口径冻结
- 业务目标：CTR、完播率、次日留存（D1）至少提升一个主指标。
- 统计口径：曝光、点击、播放、完播统一按 `trace_id + user_id + content_id + ts` 去重。
- 产出：`doc/DINPlan.md`（目标、口径、对照组定义）。

### 第 2 步：埋点与样本定义
- 事件：`exposure / click / play_start / play_finish / favorite / like / comment`。
- 样本标签：点击任务用 `click=1/0`；完播任务用 `finish=1/0`。
- 负样本策略：同批曝光未点击即负样本，控制正负样本比例（例如 1:4）。
- 产出：样本抽取 SQL + 每日样本量监控。

### 第 3 步：特征工程（先离线）
- 用户特征：近 1/7/30 天活跃度、偏好分类、学习时段。
- 内容特征：分类、时长、热度、发布时间、作者权重。
- 交叉与序列特征：用户最近 N 次行为序列（DIN 核心）。
- 产出：离线特征表（按天分区）+ 缺失率检查脚本。

### 第 4 步：召回层先行
- 多路召回：热门召回 + 协同过滤召回 + 内容相似召回。
- 每路召回固定配额（如 100~300）并去重合并。
- 产出：`/api/v1/recommend/candidates`（仅候选，不排序）。

### 第 5 步：DIN 训练与评估
- 训练集/验证集按时间切分，避免信息泄漏。
- 指标：AUC、LogLoss、GAUC（按用户分组）。
- 同时保留 baseline（LR/GBDT）做对照，避免“只看深度模型”。
- 产出：最佳模型权重、离线评估报告、特征重要性分析。

### 第 6 步：在线排序服务
- 服务形态：`召回 -> 特征拼装 -> DIN 打分 -> 重排`。
- 重排策略：加入多样性与探索（避免同类内容堆叠）。
- 超时兜底：排序超时直接回退热门榜，保证可用性。
- 产出：`/api/v1/recommend/feed` 在线可用。

### 第 7 步：灰度与 A/B 实验
- 分组：`control=热门排序`，`treatment=DIN 排序`。
- 观察周期：至少 3~7 天，覆盖工作日/周末。
- 判定：主指标显著提升才全量；否则回滚并分析。
- 产出：实验看板（CTR、完播率、留存、投诉率）。

### 第 8 步：持续迭代
- 周期训练：每日增量、每周全量重训。
- 漂移监控：输入特征分布漂移、模型效果衰减告警。
- 版本管理：模型版本、特征版本、回滚机制。
- 产出：稳定的训练/发布流水线。

### 建议执行节奏（4 周）
- 第 1 周：步骤 1~3（口径、埋点、特征表）
- 第 2 周：步骤 4~5（召回 + 训练）
- 第 3 周：步骤 6（在线排序 + 兜底）
- 第 4 周：步骤 7~8（A/B、迭代与文档固化）

---

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

### LightRAG 查询
| 方法 | 路径        | 权限 | 请求参数                                                                 | 响应                                                  |
| ---- | ----------- | ---- | ------------------------------------------------------------------------ | ----------------------------------------------------- |
| POST | `/ai/query` | 无   | `query`, `mode?`, `scope?`, `course_id?`, `article_id?`, `top_k?`       | `answer`, `sources`, `entities`, `mode_used`, `confidence` |

> 当前 Go 服务已适配 LightRAG 原生 `/query` 与 `/query/data` 返回结构；若未配置 `LIGHTRAG_QUERY_URL`，接口返回 `503`。

### 收藏
| 方法   | 路径                               | 权限 | 请求参数     | 响应                           |
| ------ | ---------------------------------- | ---- | ------------ | ------------------------------ |
| POST   | `/favorites/courses`               | 登录 | `course_id`  | -                              |
| DELETE | `/favorites/courses/{course_id}`   | 登录 | -            | -                              |
| POST   | `/favorites/videos`                | 登录 | `video_id`   | -                              |
| DELETE | `/favorites/videos/{video_id}`     | 登录 | -            | -                              |
| POST   | `/favorites/articles`              | 登录 | `article_id` | -                              |
| DELETE | `/favorites/articles/{article_id}` | 登录 | -            | -                              |
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

### 埋点事件（M1）
| 方法 | 路径               | 权限 | 请求参数                                                           | 响应              |
| ---- | ------------------ | ---- | ------------------------------------------------------------------ | ----------------- |
| POST | `/events/exposure` | 无   | `content_type`, `content_id`, `scene?`, `session_id?`, `position?` | `skipped`（去重） |
| POST | `/events/click`    | 无   | `content_type`, `content_id`, `scene?`, `session_id?`, `position?` | `skipped`（去重） |
| POST | `/events/complete` | 无   | `content_type`, `content_id`, `scene?`, `session_id?`, `position?` | `skipped`（去重） |
| POST | `/events/play`     | 无   | `video_id`, `scene?`, `session_id?`, `position?`                   | `skipped`（去重） |

> 事件会异步写入 `event_logs`，并聚合到 `event_stats_hourly`（PV/UV）。

### 积分体系
| 方法 | 路径                    | 权限 | 请求参数                                     | 响应                          |
| ---- | ----------------------- | ---- | -------------------------------------------- | ----------------------------- |
| GET  | `/points/balance`       | 登录 | -                                            | `points_balance`              |
| GET  | `/points/transactions`  | 登录 | `page`, `page_size`, `event_type?`           | 积分流水列表                  |
| GET  | `/points/rank`          | 登录 | `page`, `page_size`                          | 排行榜（按 `points_balance`） |
| POST | `/points/award`（内部） | 内部 | `event_type`, `points`, `biz_id?`, `remark?` | -                             |

### 消息通知（最小可用）
| 方法 | 路径                      | 权限 | 请求参数                                         | 响应                     |
| ---- | ------------------------- | ---- | ------------------------------------------------ | ------------------------ |
| GET  | `/messages`               | 登录 | `type?`, `page`, `page_size`                     | `items`, `page`, `total` |
| GET  | `/messages/unread_count`  | 登录 | `type?`                                          | `unread_count`           |
| POST | `/messages/read`          | 登录 | `ids?`, `type?`, `all?`                          | `updated`                |
| POST | `/messages/award`（内部） | 内部 | `user_id`, `type`, `title`, `content`, `biz_id?` | -                        |

### 实时聊天（私信/群聊，MVP）
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

### Grafana 看板（M3）
- 看板 JSON：`server/grafana/moochub-analytics-dashboard.json`
- 数据源：MySQL（指向 `event_stats_hourly` 所在库）
- 导入方式：Grafana -> Dashboards -> Import -> 上传 JSON -> 选择数据源

---

## 本地视频接入（开发阶段）
目标：本地跑通“视频播放 + 缩略图展示 + 数据入库”。

**A. 本地存储路径**
- 视频：`server/uploads/videos/`
- 缩略图：`server/uploads/thumbs/`
- 访问：`/uploads/videos/xxx.mp4`

**B. 写入数据库**
1) 拷贝视频与缩略图到本地目录
2) MySQL `videos` 表插入记录（video_url / thumb_url）
3) MongoDB `video_thumbnails` 可选保存元数据

---

## 说明
- 本仓库当前采用“PR + CI 绿灯后手动合并”的协作模式。
- 分支与 PR 规范详见：[`doc/DevWorkflow.md`](doc/DevWorkflow.md)

## 贡献与协作
- 分支规范：`feat/*`、`fix/*`、`docs/*`、`chore/*`
- 每个需求新建分支，合并后删除，不复用历史分支
- 合并前至少通过：
  - `CI Check / flutter-check`
  - `CI Check / server-check`
- 关键改动建议额外验证 `Build Android` 工作流

## 贡献者
<a href="https://github.com/DreamZhongJu/MoocHub/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=DreamZhongJu/MoocHub" alt="contributors" />
</a>

## 协作看板
- 项目规划：[`README.md`](README.md) / [`doc/CompletedTodo.md`](doc/CompletedTodo.md)
- 任务协同：GitHub Issues + Projects（Sprint 迭代）
- 代码协同：功能分支 -> PR -> CI 通过 -> 合并主干
- 版本协同：`CHANGELOG.md` 维护发布说明，`release.yml` 负责发布流程
