# MoocHub

面向“中国大学 MOOC”风格的在线学习社区（移动端为主）。支持课程浏览、视频播放、评论互动、收藏与学习进度。目标交付：可运行系统 + 规范论文。

## 项目定位
- 产品形态：学习社区 + 课程平台
- 首页风格：类 B 站推荐流（卡片瀑布流 + 热门/继续观看）
- MVP 功能：课程/视频/评论/收藏/进度/用户中心
- 中后期：个性化推荐（DIN）、AI 问答、管理后台

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
- `docs/`：接口与设计文档（预留）

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

| 阶段 | 事项                                 | 细节 TODO                                                           | 状态 |
| ---- | ------------------------------------ | ------------------------------------------------------------------- | ---- |
| 0    | 明确 MVP 功能边界与扩展范围          | MVP 与后期扩展清单已划分                                            | ✅    |
| 0    | MySQL/MongoDB 分工设计               | 结构化/文档化边界已确定                                             | ✅    |
| 0    | 架构草图与目录结构                   | 前后端分层与目录约定                                                | ✅    |
| 1    | 主要页面流程图与交互                 | 首页/分类/我的/详情/评论流程                                        | ✅    |
| 1    | 首页推荐模块定义                     | 推荐卡片/继续观看/混排规范                                          | ✅    |
| 2    | 数据模型与索引设计                   | MySQL/Mongo 表与索引                                                | ✅    |
| 2    | 建库与初始化脚本                     | SQL/Mongo 初始化脚本                                                | ✅    |
| 3    | Gin 路由/中间件                      | 认证/日志/CORS                                                      | ✅    |
| 3    | 数据库连接层                         | MySQL/Mongo/MinIO/Redis/RabbitMQ 初始化                             | ✅    |
| 3    | 按接口清单实现模块                   | 课程/视频/评论/收藏/进度/后台                                       | ✅    |
| 4    | API 文档完善                         | 补齐错误码/鉴权/分页规则/示例请求与响应                             | 🟡    |
| 4.5  | 本地视频接入流程                     | 本地上传+写库流程                                                   | ✅    |
| 5    | Flutter 骨架与路由                   | Tabs/路由骨架                                                       | ✅    |
| 5    | API 接入（课程/详情/播放/评论/收藏） | 客户端接口联调                                                      | ✅    |
| 6    | 播放器与进度上报                     | 播放控制/节流/上报                                                  | ✅    |
| 6    | 继续观看模块                         | 首页卡片 + latest 接口                                              | ✅    |
| 7    | 评论 UI / 回复 / 举报                | 评论列表/发布/点赞；回复与举报预留                                  | ✅    |
| 8    | 积分体系（规则/展示/流水）           | 规则定义；流水表设计；前端展示与排行                                | ✅    |
| 9    | 测试体系（单元/接口/集成/回归）      | 核心业务单测；接口测试脚本；回归清单                                | 🟡    |
| 9    | 演示数据与脚本                       | 课程/视频/评论/用户一键生成；导入说明                               | 🟡    |
| 10   | Redis 深度结合（缓存击穿/预热/统计） | 预热策略；热点 key 保护；缓存一致性与失效策略                       | 🟡    |
| 10   | RabbitMQ 深度结合（重试/死信/监控）  | 重试/死信队列；消费幂等；监控与告警                                 | 🟡    |
| 11   | UI 深度优化（品牌色/动效/空态）      | 统一色板与排版；动效规范；空态与骨架屏                              | 🟡    |
| 11   | 第三方登录接入（QQ）                 | OAuth 登录流程；绑定/解绑；回调与错误处理                           | ✅    |
| 11   | 管理端界面                           | 登录与权限；课程/视频/评论管理后台                                  | ✅    |
| 11   | 教师角色与课程发布                   | 新增 teacher 角色；teacher/admin 可新建课程并上传视频（含权限校验） | ⬜    |
| 11   | 实时聊天（私信/群聊）                | 入口：首页右上角消息；头像私信；私聊+群聊                           | ✅    |
| 11   | 文章发布与查看                       | 文章发布/详情；首页混排（视频+文章）；文章列表                      | ✅    |
| 12   | 搜索与筛选（联想/高亮/排序）         | 搜索接口；过滤/排序；高亮与空结果处理                               | ✅    |
| 12   | 埋点与数据看板（曝光/点击/完播）     | 埋点事件定义；看板指标口径；可视化面板                              | ✅    |
| 12   | 指标告警（Prometheus/Grafana）       | 指标采集；告警规则；可视化面板                                      | ✅    |
| 12   | 统一日志规范（结构化/链路追踪）      | 结构化字段；trace_id；采样与落盘策略                                | ✅    |
| 12   | 缓存预热/热点保护/分页索引优化       | 首页/分类预热；热点 key 锁；分页索引优化                            | ✅    |
| 12   | 限流/熔断/重试/幂等设计              | 限流策略；熔断与重试；幂等 key 与去重                               | ✅    |
| 12   | 离线缓存/弱网策略/骨架屏/空态统一    | 本地缓存策略；弱网重试；统一骨架屏与空态组件                        | ✅    |
| 12   | CI/CD/自动化测试/代码规范/静态检查   | lint/format 规范；自动化测试流水线；构建与发布                      | ⬜    |
| 12   | 安全与风控（限流/鉴权/审计）         | 鉴权强化；审计日志；风控规则                                        | ⬜    |
| 12   | 个性化推荐                           | 埋点采样；训练与评估；在线召回与排序                                | ✅    |
| 12   | 学习计划与打卡（可选）               | 日/周目标；连续打卡；提醒与激励                                     | ⬜    |
| 12   | 章节测验与错题本（可选）             | 章节题库；自动判分；错题回练与统计                                  | ⬜    |
| 12   | 视频时间轴笔记（可选）               | 时间点笔记；回看定位；导出与检索                                    | ⬜    |
| 12   | 学习路径与专题合集（可选）           | 路线编排；阶段任务；完成进度可视化                                  | ⬜    |
| 12   | 证书与成就系统（可选）               | 完课证书；成就徽章；分享海报                                        | ⬜    |
| 12   | 稍后再学（统一待办）（可选）         | 课程/视频/文章统一收藏；跨端同步                                    | ⬜    |
| 12   | 搜索增强（容错与权重）（可选）       | 拼音/错别字召回；多因子排序；搜索日志学习                           | ⬜    |
| 12   | A/B 实验平台（可选）                 | 实验分流；指标对比；灰度开关                                        | ⬜    |
| 12   | 内容治理与审核（可选）               | 敏感词；举报流程；后台审核与处罚                                    | ⬜    |
| 13   | 论文与答辩材料                       | 论文初稿/修订；PPT；演示脚本                                        | ⬜    |

---

## DIN 落地实施路线（细化）

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
