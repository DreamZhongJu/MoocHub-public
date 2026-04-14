# Flutter 客户端（MoocHub）

## 目标
实现移动端学习体验：推荐流、课程详情、多 P 视频播放、评论互动、收藏与学习进度。

## 运行
```bash
cd flutter_app
cp assets/.env.example assets/.env
flutter pub get
flutter run
```

## 环境配置
- `assets/.env`：配置后端地址（`BACKEND_HOST`）
- Android 推送：需要将 Firebase 控制台下载的 `google-services.json` 放到 `android/app/`

## 目录结构（关键）
- `lib/pages/`：页面（首页/分类/详情/播放/我的等）
- `lib/widget/`：通用组件
- `lib/services/`：网络、存储封装
- `lib/model/`：数据模型
- `lib/routers/`：路由配置
- `assets/`：配置与资源

## 关键能力
- 推荐流展示
- 课程详情 + 视频列表
- 视频播放 + 进度保存 + 续播
- 评论列表
- 收藏列表（课程 / 视频 / 文章）
- 我的页（登录入口/信息卡片）
- 通知设置页（跳转系统通知/应用设置）
- QQ 分享（好友/空间）

## 离线缓存 / 弱网策略 / 骨架屏 / 空态统一
- 离线缓存：Hive `offline_cache`，支持 TTL 读取
- 弱网策略：`ApiService.getWithRetry` 指数退避
- 统一骨架屏与空态组件：`lib/widget/AppStateWidgets.dart`

## 客户端性能测试（论文）
- 请使用 Flutter DevTools 进行帧率/内存监控
- 测试模板见：`server/test/jmeter/results/README.md`（记录模板汇总）
