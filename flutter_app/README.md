# Flutter 客户端（MoocHub）

## 目标
实现移动端学习体验：推荐流、课程详情、多 P 视频播放、评论互动、收藏与学习进度。

## 运行
```bash
flutter pub get
flutter run
```

## 目录结构（关键）
- `lib/pages/`：页面（首页/分类/详情/播放/我的等）
- `lib/widget/`：通用组件（课程卡片、评论面板等）
- `lib/services/`：网络、存储封装
- `lib/model/`：数据模型
- `lib/routers/`：路由配置
- `assets/`：配置与资源（含 `.env`）

## 环境配置
- `assets/.env`：配置后端地址（`BACKEND_HOST`）
- Android 推送：需要将 Firebase 控制台下载的 `google-services.json` 放到 `android/app/`

## 关键能力
- 推荐流展示
- 课程详情 + 视频列表
- 视频播放 + 进度保存 + 续播
- 评论列表
- 收藏列表（课程 / 视频）
- 我的页（登录入口/信息卡片）
- 通知设置页（跳转系统通知/应用设置）

## 待办（客户端）
- 交互完善：倍速、全屏、进度上报节流
- UI 优化：统一色系、动效、空态
- 登录/注册完善：错误提示、状态保持
