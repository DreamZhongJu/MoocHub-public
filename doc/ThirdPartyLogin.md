# 第三方登录接入说明（QQ SDK + OAuth）

本文档说明 MoocHub 项目中第三方登录（QQ）如何接入与联调，包含客户端与服务端配置、流程、常见问题排查。

---

## 1. 接入目标

- 使用 QQ SDK 在移动端发起登录
- 服务端通过 QQ OpenAPI 校验 `access_token` 并拉取用户信息
- 若用户不存在则自动创建，返回系统 JWT

---

## 2. 客户端接入（Flutter）

### 2.1 依赖与配置

`pubspec.yaml` 已配置：
```yaml
dependencies:
  tencent_kit: ^6.x
```

插件配置（给 Android 构建时使用）：
```yaml
tencent_kit:
  app_id: xxx
```

### 2.2 环境变量

`flutter_app/assets/.env`：
```
QQ_APP_ID=xxx
BACKEND_IP=192.168.10.5
BACKEND_PORT=3000
```

确保 `pubspec.yaml` 有：
```yaml
assets:
  - assets/.env
```

> 修改 `.env` 后必须 **完全重启**（`flutter clean` + `flutter run`），热重载不会刷新。

### 2.3 登录流程（SDK）

1) 初始化 SDK（`LoginPage` 中）：
- 从 `.env` 读取 `QQ_APP_ID`
- `TencentKitPlatform.instance.registerApp(appId: _qqAppId)`
- 监听 `respStream()`，接收登录回调

2) 发起登录：
- `Tencent.login(scope: [TencentScope.kGetSimpleUserInfo])`

3) 回调结果：
- 成功拿到 `accessToken` / `openid`
- 调用后端 `POST /api/v1/auth/qq/sdk_login`

### 2.4 客户端关键逻辑（参考）

- 文件：`flutter_app/lib/pages/LoginPage.dart`
- 使用接口：`/api/v1/auth/qq/sdk_login`

请求参数：
```
access_token
openid
```

---

## 3. 服务端接入（Go/Gin）

### 3.1 环境变量（必须）

服务端通过环境变量读取 AppID/AppKey：
```
QQ_APP_ID=xxx
QQ_APP_KEY=<your_qq_app_key>
```

建议放在：
```
server/secrets/qq.env
```

并由 `server/run.ps1` 自动加载。

### 3.2 服务端登录接口

接口：
```
POST /api/v1/auth/qq/sdk_login
```

核心逻辑：
1) 校验 `access_token`（请求 `https://graph.qq.com/oauth2.0/me`）
2) 取得 `openid`
3) 拉取用户信息（`https://graph.qq.com/user/get_user_info`）
4) 查找/创建用户
5) 生成 JWT 返回

对应代码：
- `server/controllers/qq.go` -> `SDKLogin`
- `server/config/db.go` -> `QQAppID() / QQAppKey()`

---

## 4. 常见问题排查

### 4.1 “QQ AppID 未配置”

原因：
- `.env` 没加载（热重载不生效）
解决：
```
flutter clean
flutter pub get
flutter run
```

### 4.2 后端 `sdk_login` 返回 400

常见原因：
- 后端没有配置 `QQ_APP_ID` / `QQ_APP_KEY`
- `access_token` 无效或过期

检查：
```
server/config/db.go
```
确保环境变量生效。

### 4.3 QQ 登录弹窗后立即关闭

可能原因：
- App 签名与开放平台配置不一致
- AppID 未匹配应用包名

解决：
在 QQ 开放平台确认：
- 包名
- 签名（MD5）
- AppID 与当前构建一致

---

## 5. 关键路径汇总

客户端：
- `flutter_app/lib/pages/LoginPage.dart`
- `flutter_app/assets/.env`

服务端：
- `server/controllers/qq.go`
- `server/config/db.go`
- `server/secrets/qq.env`

---

## 6. 返回数据结构

登录成功返回：
```json
{
  "code": 200,
  "msg": "QQ登录成功",
  "data": {
    "user": { ... },
    "token": "jwt-token"
  }
}
```

---

如需新增其他平台登录（微信/微博），可复用该结构：客户端拿授权结果 → 服务端校验 → 统一返回 JWT。
