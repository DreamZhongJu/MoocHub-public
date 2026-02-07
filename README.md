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

## 环境变量（示例）
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
- `BACKEND_HOST`：Flutter 端后端地址（assets/.env）

## 对象存储（MinIO，方案 B：私有桶 + 签名 URL）
### 1) 部署 MinIO（示例）
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

## 数据库结构（恢复）

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

5) `favorite_courses`
- `id` (PK)
- `user_id` (FK -> users.id)
- `course_id` (FK -> courses.id)
- `created_at`
- `is_deleted` (软删除)
- UNIQUE(`user_id`, `course_id`)

6) `favorite_videos`
- `id` (PK)
- `user_id` (FK -> users.id)
- `video_id` (FK -> videos.id)
- `created_at`
- `is_deleted` (软删除)
- UNIQUE(`user_id`, `video_id`)

7) `learning_progress`
- `id` (PK)
- `user_id` (FK -> users.id)
- `video_id` (FK -> videos.id)
- `last_position_sec`, `progress_percent`
- `updated_at`
- UNIQUE(`user_id`, `video_id`)

8) `points_transactions`
- `id` (PK)
- `user_id` (FK -> users.id)
- `event_type` (login/video_complete/comment/favorite/other)
- `points` (正负积分)
- `biz_id` (关联业务 ID，如 video_id/comment_id，可空)
- `remark` (可空)
- `created_at`
- 索引：`(user_id, created_at)`、`(event_type, created_at)`

9) `users`（积分字段扩展）
- `points_balance` (当前积分余额，默认 0)

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

## TODO List（细化 + 状态）
状态说明：✅ 已实现 / ⬜ 未实现 / 🟡 部分完成

| 阶段 | 事项                                 | 细节 TODO                                      | 状态 |
| ---- | ------------------------------------ | ---------------------------------------------- | ---- |
| 0    | 明确 MVP 功能边界与扩展范围          | MVP 与后期扩展清单已划分                       | ✅    |
| 0    | MySQL/MongoDB 分工设计               | 结构化/文档化边界已确定                        | ✅    |
| 0    | 架构草图与目录结构                   | 前后端分层与目录约定                           | ✅    |
| 1    | 主要页面流程图与交互                 | 首页/分类/我的/详情/评论流程                   | ✅    |
| 1    | 首页推荐模块定义                     | 推荐卡片/继续观看/混排规范                     | ✅    |
| 2    | 数据模型与索引设计                   | MySQL/Mongo 表与索引                           | ✅    |
| 2    | 建库与初始化脚本                     | SQL/Mongo 初始化脚本                           | ✅    |
| 3    | Gin 路由/中间件                      | 认证/日志/CORS                                 | ✅    |
| 3    | 数据库连接层                         | MySQL/Mongo/MinIO/Redis/RabbitMQ 初始化        | ✅    |
| 3    | 按接口清单实现模块                   | 课程/视频/评论/收藏/进度/后台                  | ✅    |
| 4    | API 文档完善                         | 补齐错误码/鉴权/分页规则/示例请求与响应        | 🟡    |
| 4.5  | 本地视频接入流程                     | 本地上传+写库流程                              | ✅    |
| 5    | Flutter 骨架与路由                   | Tabs/路由骨架                                  | ✅    |
| 5    | API 接入（课程/详情/播放/评论/收藏） | 客户端接口联调                                 | ✅    |
| 6    | 播放器与进度上报                     | 播放控制/节流/上报                             | ✅    |
| 6    | 继续观看模块                         | 首页卡片 + latest 接口                         | ✅    |
| 7    | 评论 UI / 回复 / 举报                | 评论列表/发布/点赞；回复与举报预留             | ✅    |
| 8    | 积分体系（规则/展示/流水）           | 规则定义；流水表设计；前端展示与排行           | ✅    |
| 9    | 测试体系（单元/接口/集成/回归）      | 核心业务单测；接口测试脚本；回归清单           | 🟡    |
| 9    | 演示数据与脚本                       | 课程/视频/评论/用户一键生成；导入说明          | 🟡    |
| 10   | Redis 深度结合（缓存击穿/预热/统计） | 预热策略；热点 key 保护；缓存一致性与失效策略  | 🟡    |
| 10   | RabbitMQ 深度结合（重试/死信/监控）  | 重试/死信队列；消费幂等；监控与告警            | 🟡    |
| 11   | UI 深度优化（品牌色/动效/空态）      | 统一色板与排版；动效规范；空态与骨架屏         | ⬜    |
| 11   | 管理端界面                           | 登录与权限；课程/视频/评论管理后台             | ⬜    |
| 11   | 实时聊天（私信/群聊）                | 入口：首页右上角消息；头像私信；私聊+群聊      | ⬜    |
| 11   | 文章发布与查看                       | 文章发布/详情；首页混排（视频+文章）；文章列表 | ⬜    |
| 12   | 搜索与筛选（联想/高亮/排序）         | 搜索接口；过滤/排序；高亮与空结果处理          | ⬜    |
| 12   | 埋点与数据看板（曝光/点击/完播）     | 埋点事件定义；看板指标口径；可视化面板         | ⬜    |
| 12   | 指标告警（Prometheus/Grafana）       | 指标采集；告警规则；可视化面板                 | ⬜    |
| 12   | 统一日志规范（结构化/链路追踪）      | 结构化字段；trace_id；采样与落盘策略           | ⬜    |
| 12   | 缓存预热/热点保护/分页索引优化       | 首页/分类预热；热点 key 锁；分页索引优化       | ⬜    |
| 12   | 限流/熔断/重试/幂等设计              | 限流策略；熔断与重试；幂等 key 与去重          | ⬜    |
| 12   | 离线缓存/弱网策略/骨架屏/空态统一    | 本地缓存策略；弱网重试；统一骨架屏与空态组件   | ⬜    |
| 12   | CI/CD/自动化测试/代码规范/静态检查   | lint/format 规范；自动化测试流水线；构建与发布 | ⬜    |
| 12   | 安全与风控（限流/鉴权/审计）         | 鉴权强化；审计日志；风控规则                   | ⬜    |
| 12   | 个性化推荐（DIN）                    | 埋点采样；训练与评估；在线召回与排序           | ⬜    |
| 13   | 论文与答辩材料                       | 论文初稿/修订；PPT；演示脚本                   | ⬜    |

---

## API 文档（表格）
统一前缀：`/api/v1`

### 认证与用户
| 方法 | 路径             | 权限 | 请求参数                           | 响应                                               |
| ---- | ---------------- | ---- | ---------------------------------- | -------------------------------------------------- |
| POST | `/auth/register` | 无   | `username`, `password`, `nickname` | `user`, `token`                                    |
| POST | `/auth/login`    | 无   | `username`, `password`             | `user`, `token`                                    |
| GET  | `/auth/me`       | 登录 | -                                  | `id`, `username`, `nickname`, `avatar_url`, `role` |

### 分类与课程
| 方法 | 路径                       | 权限 | 请求参数                                     | 响应                                |
| ---- | -------------------------- | ---- | -------------------------------------------- | ----------------------------------- |
| GET  | `/categories`              | 无   | -                                            | 分类树（`id`, `name`, `parent_id`） |
| GET  | `/categories/{id}/courses` | 无   | `sort?`, `page`, `page_size`                 | 课程列表                            |
| GET  | `/courses`                 | 无   | `category_id?`, `sort?`, `page`, `page_size` | 课程列表                            |
| GET  | `/courses/{id}`            | 无   | -                                            | 课程详情 + `videos`                 |

### 视频
| 方法 | 路径           | 权限 | 请求参数 | 响应                                                                                |
| ---- | -------------- | ---- | -------- | ----------------------------------------------------------------------------------- |
| GET  | `/videos/{id}` | 无   | -        | `id`, `course_id`, `title`, `description`, `duration_sec`, `video_url`, `thumb_url` |

### 收藏
| 方法   | 路径                             | 权限 | 请求参数    | 响应                |
| ------ | -------------------------------- | ---- | ----------- | ------------------- |
| POST   | `/favorites/courses`             | 登录 | `course_id` | -                   |
| DELETE | `/favorites/courses/{course_id}` | 登录 | -           | -                   |
| POST   | `/favorites/videos`              | 登录 | `video_id`  | -                   |
| DELETE | `/favorites/videos/{video_id}`   | 登录 | -           | -                   |
| GET    | `/favorites`                     | 登录 | -           | 收藏课程 + 收藏视频 |

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

### 积分体系
| 方法 | 路径                    | 权限 | 请求参数                                     | 响应                          |
| ---- | ----------------------- | ---- | -------------------------------------------- | ----------------------------- |
| GET  | `/points/balance`       | 登录 | -                                            | `points_balance`              |
| GET  | `/points/transactions`  | 登录 | `page`, `page_size`, `event_type?`           | 积分流水列表                  |
| GET  | `/points/rank`          | 登录 | `page`, `page_size`                          | 排行榜（按 `points_balance`） |
| POST | `/points/award`（内部） | 内部 | `event_type`, `points`, `biz_id?`, `remark?` | -                             |

### 管理端（MVP）
| 方法   | 路径                   | 权限   | 请求参数                                                                                    | 响应     |
| ------ | ---------------------- | ------ | ------------------------------------------------------------------------------------------- | -------- |
| POST   | `/admin/courses`       | 管理员 | `category_id`, `title`, `summary`, `cover_url`, `instructor_name`, `level`, `status`        | `course` |
| PUT    | `/admin/courses/{id}`  | 管理员 | 可选字段                                                                                    | -        |
| DELETE | `/admin/courses/{id}`  | 管理员 | -                                                                                           | -        |
| POST   | `/admin/videos`        | 管理员 | `course_id`, `title`, `description`, `duration_sec`, `video_url`, `thumb_url`, `sort_order` | `video`  |
| PUT    | `/admin/videos/{id}`   | 管理员 | 可选字段                                                                                    | -        |
| DELETE | `/admin/videos/{id}`   | 管理员 | -                                                                                           | -        |
| DELETE | `/admin/comments/{id}` | 管理员 | -                                                                                           | -        |

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
“原来的接口文档去哪了？”——已统一整理到本 README 的 **API 文档表格** 中。
