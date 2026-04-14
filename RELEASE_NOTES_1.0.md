# MoocHub 1.0 Release Notes

发布日期：2026-04-14

## 概述
本版本完成系统主要功能交付，进入功能冻结与维护阶段。

## 核心功能
- 课程与视频：课程详情、视频播放、进度上报、继续观看
- 内容互动：评论发布与列表、收藏管理
- 用户中心：积分体系、通知设置、个人中心
- 第三方登录：QQ 登录
- 运营与稳定性：埋点、缓存、限流、熔断、重试、降级

## AI 能力（论文亮点）
- 后端接入 DeepSeek 实时问答，支持课程/文章上下文
- 统一问答接口 `/api/v1/ai/query` 返回 sources/entities

## 重要变更
- JWT 密钥改为环境变量 `JWT_SECRET`
- DeepSeek Key 改为环境变量 `DEEPSEEK_API_KEY`
- 本地脚本与密钥文件默认忽略入库（见 `.gitignore`）

## 已知限制
- AI 回答依赖外部推理服务，需保证网络与 API Key 可用
- LightRAG 作为后续扩展路线，当前以 DeepSeek 直连为主

## 运行提示
本地可使用 `server/scripts/start_server_with_lightrag.ps1` / `.sh` 一键启动。
脚本包含敏感配置，请勿提交到远程。
