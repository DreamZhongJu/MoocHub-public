# MoocHub 系统推送实现说明

本文档说明 MoocHub 当前的系统推送实现方式（FCM + 本地通知），涵盖 Token 注册、服务端发送、客户端接收、消息路由与排查建议。

## 1. 总体方案（最小可用）

- 客户端使用 **Firebase Cloud Messaging（FCM）** 获取设备 Token。
- 客户端将 Token 上报到后端 `POST /api/v1/device_tokens`（需要登录）。
- 后端保存 Token，并通过 **FCM HTTP v1 API** 发送通知。
- 客户端接收后：
  - 前台：本地通知弹出
  - 点击通知：根据 payload 的 `route` / `message_id` 跳转并回写已读

## 2. 关键模块与数据流

### 2.1 Token 获取与上报（Flutter）
- 模块：`flutter_app/lib/services/PushService.dart`
- 关键流程：
  1. `FirebaseMessaging.instance.getToken()` 获取 FCM Token
  2. `POST /api/v1/device_tokens` 上报（`Authorization` 头携带 JWT）
  3. 监听 `onTokenRefresh`，Token 变更自动更新

### 2.2 设备 Token 存储（Server）
- 表：`device_tokens`
- 字段：`user_id / platform / token / created_at / updated_at`
- 接口：`POST /api/v1/device_tokens`（登录）

### 2.3 推送发送（Server）
- 模块：`server/notify/fcm.go`
- 依赖：Firebase Admin Service Account JSON
- 环境变量：
  - `FCM_SERVICE_ACCOUNT`：服务账号 JSON 的**绝对路径**
  - `FCM_PROJECT_ID`：Firebase Project ID
- 接口：`POST /api/v1/admin/push`（管理员）
  - 参数：`user_id` 或 `user_ids`，`title`，`content`，`type?`，`route?`，`biz_id?`

### 2.4 客户端接收与路由
- 模块：`flutter_app/lib/services/PushService.dart`
- 关键事件：
  - `FirebaseMessaging.onMessage`：前台消息 → 本地通知
  - `FirebaseMessaging.onMessageOpenedApp`：点击通知 → 解析 data → 路由跳转
  - 可携带 `message_id` 调用 `/messages/read` 标记已读

## 3. Payload 规范（建议）

**data payload 示例：**

```json
{
  "type": "system|like|comment|dm",
  "route": "/messages",
  "message_id": "123",
  "biz_id": "456"
}
```

- `type`：业务类型
- `route`：点击通知后跳转路由
- `message_id`：用于点击后标记已读
- `biz_id`：可选业务关联 ID

## 4. 本地通知（Flutter）

- Android 需创建通知渠道（`flutter_local_notifications`）
- 前台消息通过本地通知弹出
- 点击通知根据 payload 跳转到消息或业务页

## 5. 常见问题与排查

1. **Token 获取失败**
   - 检查 `google-services.json` 是否正确
   - 确认 Firebase 控制台 SHA1/SHA256 已配置
   - 确认设备可访问 FCM（网络/地区限制）

2. **Token 上报 401**
   - 检查客户端是否已登录
   - 确认 Authorization 头携带 JWT

3. **推送发送成功但设备无通知**
   - 检查系统通知权限
   - `adb logcat` 查看是否收到 `onMessage`
   - 确认前台/后台消息处理逻辑

## 6. 安全与隐私

- 服务账号 JSON 放在 `server/secrets/`，并加入 `.gitignore`
- 管理端推送接口必须管理员鉴权
- 不在客户端保存服务端密钥

## 7. 后续可扩展项

- Topic 推送（按课程/分类订阅）
- 通知设置页（系统通知/私信开关）
- 发送策略（免打扰、频率控制）

