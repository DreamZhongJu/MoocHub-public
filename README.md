# MoocHub

一个对标“中国大学 MOOC”的在线学习社区（移动端为主，支持视频学习、课程体系、评论互动、学习进度、积分体系）。本项目决定**重新编写**，不继承现有电商代码逻辑与模型。

## 目标与定位
- 产品定位：学习型社区 + 课程平台
- 首页风格：类似 B 站的视频推荐流（卡片瀑布流 + 热门/继续观看/为你推荐）
- 核心功能：课程浏览、视频播放、评论互动、学习进度、积分激励

## 技术栈（规划）
- 客户端：Flutter
- 后端：Go（Gin/Gorm）
- 数据库：MySQL + MongoDB
  - MySQL：用户、课程、章节、权限、积分规则等结构化数据
  - MongoDB：评论、学习日志、推荐曝光/点击等高写入文档数据

## 仓库结构（建议）
- `flutter/`：Flutter 客户端
- `server/`：Go 服务端
- `docs/`：接口文档与设计文档

## TODO（按执行顺序，Todo Tree 语法）

### 0. 立项与规范
- TODO(@you): 明确功能清单与范围边界（MVP 先做哪些，后期再扩展哪些）
- TODO(@you): 确认数据库分工设计（哪些表在 MySQL，哪些集合在 MongoDB）
- TODO(@me): 输出最小可行架构草图与目录结构建议

#### MVP 需求范围（已确认）
- TODO(@you): 首页视频卡片流（无个性化推荐，仅按热度/最新）
- TODO(@you): 视频详情页 + 播放页
- TODO(@you): 收藏功能（课程/视频）
- TODO(@you): 评论功能（列表 + 发布）
- TODO(@you): 用户中心（个人信息、收藏列表、学习记录入口）
- TODO(@you): 管理员后台（内容管理：课程/视频/评论）
- TODO(@you): 登录/注册与基础鉴权

#### 后期扩展（已确认）
- TODO(@you): AI 问答
- TODO(@you): 首页个性化推荐

#### 数据库存储分工（建议）
- TODO(@me): MySQL（强一致、结构化）
  - users, course_categories, courses, videos, favorites, learning_progress
- TODO(@me): MongoDB（高写入、文档/日志）
  - comments, comment_likes, report_logs
  - recommend_events（曝光/点击日志，后期推荐用）
  - video_thumbnails（只存 URL + 元数据）
- TODO(@you): 已确认缩略图放对象存储，MongoDB 只存 URL 与元数据

#### 视频存储方案（现有主流方案参考）
- TODO(@me): 推荐方案（易上线）
  - 视频文件存对象存储（如 MinIO / COS / OSS / S3），服务端保存 URL
  - 本地开发可先放 `server/uploads/videos/`，生产再切对象存储
- TODO(@you): 选择一种方案并确定路径与鉴权策略

### 1. 产品与交互设计
- TODO(@you): 画出主要页面流程图（首页/课程详情/播放页/评论/我的）
- TODO(@you): 定义首页推荐模块（轮播、继续观看、热门、为你推荐）
- TODO(@me): 给出页面信息架构与组件拆分建议

#### done 主要页面流程（已确认）
- TODO(@you): 底部导航：`首页 / 分类 / 我的`（后续可扩展更多 Tab）
- TODO(@you): 首页 -> 视频卡片 -> 进入“课程详情 / 视频播放”
- TODO(@you): 播放页结构参照 B 站：上方视频播放器，下方课程详情 + 评论列表
- TODO(@you): 分类页：按课程分类浏览（一级/二级分类）
- TODO(@you): 我的页：登录入口、收藏、学习记录、个人信息

### 2. done 数据模型与数据库
- TODO(@me): 输出精简模型（见下方表结构与外键）
- TODO(@you): 根据实际业务调整字段与索引，确认最终版本
- TODO(@you): 建库与初始化脚本（或迁移方案）

#### done MySQL（MVP，结构化）
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
   - `video_url`, `thumb_url`（对象存储 URL）
   - `sort_order`, `created_at`
5) `favorite_courses`
   - `id` (PK)
   - `user_id` (FK -> users.id)
   - `course_id` (FK -> courses.id)
   - `created_at`
   - UNIQUE(`user_id`, `course_id`)
6) `favorite_videos`
   - `id` (PK)
   - `user_id` (FK -> users.id)
   - `video_id` (FK -> videos.id)
   - `created_at`
   - UNIQUE(`user_id`, `video_id`)
7) `learning_progress`（MVP 可保留但不强依赖）
   - `id` (PK)
   - `user_id` (FK -> users.id)
   - `video_id` (FK -> videos.id)
   - `last_position_sec`, `progress_percent`
   - `updated_at`
   - UNIQUE(`user_id`, `video_id`)

#### done 外键依赖（MySQL）
- `course_categories.parent_id` -> `course_categories.id`
- `courses.category_id` -> `course_categories.id`
- `videos.course_id` -> `courses.id`
- `favorite_courses.user_id` -> `users.id`
- `favorite_courses.course_id` -> `courses.id`
- `favorite_videos.user_id` -> `users.id`
- `favorite_videos.video_id` -> `videos.id`
- `learning_progress.user_id` -> `users.id`
- `learning_progress.video_id` -> `videos.id`

#### done MongoDB（文档型）
1) `comments`
   - `target_type` (course/video), `target_id` (MySQL ID)
   - `user_id` (MySQL users.id), `content`
   - `like_count`, `status`, `created_at`
   - `parent_id`（可空，用于回复，MVP 可不启用）
   - 索引：`(target_type, target_id, created_at)`，`user_id`
2) `video_thumbnails`
   - `video_id` (MySQL videos.id)
   - `url`, `width`, `height`, `format`, `size_bytes`, `created_at`
   - 索引：`video_id` 唯一
3) `recommend_events`（后期扩展）
   - `user_id`, `video_id`, `event_type`(exposure/click/play), `created_at`
   - 索引：`(user_id, created_at)`，`(video_id, created_at)`

#### done 对象存储字段约定（视频/缩略图）
- `video_url`: 对象存储可访问地址（或保存 `storage_key`，由后端生成签名 URL）
- `thumb_url`: 对象存储缩略图地址（MongoDB 仅存 URL + 元数据）
- 跨库关联为“软关联”：MongoDB 通过 `video_id/user_id` 与 MySQL 对应

### TODO 3. 后端基础框架
- TODO(@me): 搭建 Gin 路由骨架与中间件（日志、错误处理、CORS）
- TODO(@me): 搭建 MySQL 与 MongoDB 连接层
- TODO(@you): 按接口清单实现模块（课程/播放/评论/进度）
- TODO(@you): 配置环境变量与本地运行说明

### 4. 接口清单（MVP）
接口统一前缀：`/api/v1`

#### 1) 认证与用户
| 方法 | 路径             | 权限 | 请求参数                           | 响应                                               |
| ---- | ---------------- | ---- | ---------------------------------- | -------------------------------------------------- |
| POST | `/auth/register` | 无   | `username`, `password`, `nickname` | `user`, `token`                                    |
| POST | `/auth/login`    | 无   | `username`, `password`             | `user`, `token`                                    |
| GET  | `/me`            | 登录 | -                                  | `id`, `username`, `nickname`, `avatar_url`, `role` |

#### 2) 分类与课程
| 方法 | 路径                       | 权限 | 请求参数                                     | 响应                                                                                      |
| ---- | -------------------------- | ---- | -------------------------------------------- | ----------------------------------------------------------------------------------------- |
| GET  | `/categories`              | 无   | -                                            | 分类树（`id`, `name`, `parent_id`）                                                       |
| GET  | `/categories/{id}/courses` | 无   | `sort?`, `page`, `page_size`                 | 课程列表（按分类筛选）                                                                    |
| GET  | `/courses`                 | 无   | `category_id?`, `sort?`, `page`, `page_size` | 课程列表（`id`, `title`, `cover_url`, `instructor_name`, `view_count`, `favorite_count`） |
| GET  | `/courses/{id}`            | 无   | -                                            | 课程详情 + `videos`                                                                       |

#### 3) 视频与播放
| 方法 | 路径           | 权限 | 请求参数 | 响应                                                                                |
| ---- | -------------- | ---- | -------- | ----------------------------------------------------------------------------------- |
| GET  | `/videos/{id}` | 无   | -        | `id`, `course_id`, `title`, `description`, `duration_sec`, `video_url`, `thumb_url` |

#### 4) 收藏
| 方法   | 路径                             | 权限 | 请求参数    | 响应                   |
| ------ | -------------------------------- | ---- | ----------- | ---------------------- |
| POST   | `/favorites/courses`             | 登录 | `course_id` | -                      |
| DELETE | `/favorites/courses/{course_id}` | 登录 | -           | -                      |
| POST   | `/favorites/videos`              | 登录 | `video_id`  | -                      |
| DELETE | `/favorites/videos/{video_id}`   | 登录 | -           | -                      |
| GET    | `/favorites`                     | 登录 | -           | 收藏课程与收藏视频列表 |

#### 5) 评论（MongoDB）
| 方法 | 路径                  | 权限 | 请求参数                                        | 响应         |
| ---- | --------------------- | ---- | ----------------------------------------------- | ------------ |
| GET  | `/comments`           | 无   | `target_type`, `target_id`, `page`, `page_size` | 评论列表     |
| POST | `/comments`           | 登录 | `target_type`, `target_id`, `content`           | `comment`    |
| POST | `/comments/{id}/like` | 登录 | -                                               | `like_count` |

#### 6) 学习进度
| 方法 | 路径                   | 权限 | 请求参数                                            | 响应                                    |
| ---- | ---------------------- | ---- | --------------------------------------------------- | --------------------------------------- |
| POST | `/progress`            | 登录 | `video_id`, `last_position_sec`, `progress_percent` | -                                       |
| GET  | `/progress/{video_id}` | 登录 | -                                                   | `last_position_sec`, `progress_percent` |

#### 7) 管理员后台（MVP）
| 方法   | 路径                   | 权限   | 请求参数                                                                                    | 响应     |
| ------ | ---------------------- | ------ | ------------------------------------------------------------------------------------------- | -------- |
| POST   | `/admin/courses`       | 管理员 | `category_id`, `title`, `summary`, `cover_url`, `instructor_name`, `level`, `status`        | `course` |
| PUT    | `/admin/courses/{id}`  | 管理员 | 可选字段                                                                                    | -        |
| DELETE | `/admin/courses/{id}`  | 管理员 | -                                                                                           | -        |
| POST   | `/admin/videos`        | 管理员 | `course_id`, `title`, `description`, `duration_sec`, `video_url`, `thumb_url`, `sort_order` | `video`  |
| PUT    | `/admin/videos/{id}`   | 管理员 | 可选字段                                                                                    | -        |
| DELETE | `/admin/videos/{id}`   | 管理员 | -                                                                                           | -        |
| DELETE | `/admin/comments/{id}` | 管理员 | -                                                                                           | -        |
### done 4.5) 本地视频接入（开发阶段）
目标：在本地快速跑通“视频播放 + 缩略图展示 + 数据入库”。

**A. 本地存储路径（开发）**
- 视频：`server/uploads/videos/`
- 缩略图：`server/uploads/thumbs/`
- 访问：通过 Nginx 或 Gin 静态路由暴露（示例：`/uploads/videos/xxx.mp4`）

**B. 将视频与缩略图写入数据库（MySQL + MongoDB）**
1) 上传视频文件与缩略图到本地目录（手动拷贝即可）
2) 在 MySQL `videos` 表插入一条记录：
   - `course_id`：关联课程 ID
   - `title`、`description`、`duration_sec`
   - `video_url`：例如 `http://127.0.0.1:3000/uploads/videos/xxx.mp4`
   - `thumb_url`：例如 `http://127.0.0.1:3000/uploads/thumbs/xxx.jpg`
   - `sort_order`：播放顺序
3) 在 MongoDB `video_thumbnails` 中插入元数据（可选）：
   - `video_id`：MySQL 的视频 ID
   - `url`、`width`、`height`、`format`、`size_bytes`

**C. 示例 SQL（MySQL）**
```sql
INSERT INTO videos
(course_id, title, description, duration_sec, video_url, thumb_url, sort_order, created_at)
VALUES
(1, '示例视频', '本地上传测试', 120,
 'http://127.0.0.1:3000/uploads/videos/demo.mp4',
 'http://127.0.0.1:3000/uploads/thumbs/demo.jpg',
 1, NOW());
```

**D. 示例 MongoDB 文档**
```js
db.video_thumbnails.insertOne({
  video_id: 1,
  url: "http://127.0.0.1:3000/uploads/thumbs/demo.jpg",
  width: 1280,
  height: 720,
  format: "jpg",
  size_bytes: 34567,
  created_at: new Date()
});
```

### TODO 5. Flutter 客户端骨架
- TODO(@me): 设计路由结构与 Tab 规划（首页/分类/我的）
- TODO(@me): 提供推荐流 UI 结构示例（卡片/瀑布流/横滑模块）
- TODO(@you): 完成基础页面搭建与路由接入
- TODO(@you): 接入 API（课程列表、详情、播放、评论）

#### Flutter 骨架（小目标拆分）
1)  项目初始化 // done
   - TODO(@you): 新建 Flutter 项目并确认运行（Android/iOS 至少一端）
   - TODO(@you): 添加必要依赖（dio/riverpod或provider/route管理/视频播放器）
   - TODO(@you): 配置基础主题与字体

2) 路由与导航 // done
   - TODO(@you): 配置路由表（首页、分类、我的、课程详情、视频播放）
   - TODO(@you): 底部导航 Tab（首页/分类/我的）

3) 首页（视频推荐流）
   - TODO(@you): 主页布局：顶部搜索/轮播（可后置）+ 推荐卡片列表  // done
   - TODO(@you): 卡片样式包含：封面图、标题、讲师、观看数/收藏数 // done
   - TODO(@you): 点击卡片进入课程详情/播放页 // done

4) 分类页 // done
   - TODO(@you): 分类列表 + 课程列表（按分类过滤） 

5) 课程详情页 // done
   - TODO(@you): 展示课程信息 + 课程视频列表
   - TODO(@you): 点击视频跳转到播放页

6) 播放页 // done
   - TODO(@you): 视频播放器组件 + 基本控制
   - TODO(@you): 评论列表入口（先做展示，不做发布也行）

7) 我的页 // done
   - TODO(@you): 登录入口 + 用户信息卡片
   - TODO(@you): 收藏列表入口、学习记录入口（先做空页面）

8) API 接入顺序建议 // done
   - TODO(@you): /auth/login & /auth/register（先打通登录）
   - TODO(@you): /courses & /courses/{id}
   - TODO(@you): /videos/{id}
   - TODO(@you): /comments（列表）
   - TODO(@you): /favorites（课程/视频）

### 6. 播放与学习进度
- TODO(@me): 播放页交互规范（倍速/续播/进度保存）
- TODO(@you): 集成视频播放器与进度上报
- TODO(@you): 本地缓存与“继续观看”模块

### 7. 评论与社区
- TODO(@me): 评论数据结构与接口规范
- TODO(@you): 评论区 UI 与交互（回复、点赞、举报）

### 8. 积分体系
- TODO(@me): 积分规则与积分流水设计
- TODO(@you): 实现规则触发与积分展示

### 9. 测试与演示
- TODO(@you): 初始化演示数据（课程/视频/评论/用户）
- TODO(@you): 自测与录屏/截图准备
- TODO(@me): 提供测试清单模板与验收项

### 10. 文档与答辩材料
- TODO(@you): 完成论文结构与章节安排
- TODO(@you): 整理接口文档与部署说明
- TODO(@me): 提供论文/答辩 PPT 结构建议

## 备注
- TODO(@you): 确认“先做移动端还是先做后端”的工作节奏
- TODO(@you): 确认是否需要 Web 管理后台（课程/内容审核）
