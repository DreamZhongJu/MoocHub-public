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

## TODO List（表格 + 状态）
状态说明：✅ 已实现 / ⬜ 未实现 / 🟡 部分完成

| 阶段 | 事项                                 | 负责人 | 状态 |
| ---- | ------------------------------------ | ------ | ---- |
| 0    | 明确 MVP 功能边界与扩展范围          | @you   | ✅    |
| 0    | MySQL/MongoDB 分工设计               | @you   | ✅    |
| 0    | 架构草图与目录结构                   | @me    | ✅    |
| 1    | 主要页面流程图与交互                 | @you   | ✅    |
| 1    | 首页推荐模块定义                     | @you   | ✅    |
| 2    | 数据模型与索引设计                   | @me    | ✅    |
| 2    | 建库与初始化脚本                     | @you   | ✅    |
| 3    | Gin 路由/中间件                      | @me    | ✅    |
| 3    | 数据库连接层                         | @me    | ✅    |
| 3    | 按接口清单实现模块                   | @you   | ✅    |
| 4    | API 文档完善                         | @you   | 🟡    |
| 4.5  | 本地视频接入流程                     | @you   | ✅    |
| 5    | Flutter 骨架与路由                   | @you   | ✅    |
| 5    | API 接入（课程/详情/播放/评论/收藏） | @you   | ✅    |
| 6    | 播放器与进度上报                     | @you   | ✅    |
| 6    | 继续观看模块                         | @you   | ✅    |
| 7    | 评论 UI / 回复 / 举报                | @you   | ✅    |
| 8    | 积分体系（规则/展示/流水）           | @you   | ⬜    |
| 9    | 测试与演示数据                       | @you   | 🟡    |
| 10   | 论文与答辩材料                       | @you   | ⬜    |
| 11   | UI 深度优化（品牌色/动效/空态）      | @you   | ⬜    |
| 11   | 管理端界面                           | @you   | ⬜    |
| 11   | 个性化推荐（DIN）                    | @you   | ⬜    |

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
