# Server（MoocHub）

## 目标
提供课程/视频/评论/收藏/学习进度等 API，并支持管理端操作与后续推荐体系。

## 运行
```bash
# 进入 server 目录
cd server

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

## 数据库
- MySQL：用户、课程、视频、收藏、学习进度
- MongoDB：评论等文档型数据

## 已支持接口（MVP）
- 认证：/auth/login /auth/register
- 课程：/courses /courses/{id}
- 视频：/videos/{id}
- 评论：/comments
- 收藏：/favorites
- 进度：/progress /progress/{video_id}

## 待办（后端）
- 继续观看：/progress/latest（支持首页展示）
- 管理端：课程/视频/评论管理
- 推荐相关：曝光/点击日志
