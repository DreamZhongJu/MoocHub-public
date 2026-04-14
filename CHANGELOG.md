# Changelog

All notable changes to this project are documented in this file.

The format follows Keep a Changelog and semantic versioning tags (`vX.Y.Z`).

## [Unreleased]

### Added
- 待补充

### Changed
- 待补充

### Fixed
- 待补充

## [v1.0.7] - 2026-04-14

### Changed
- `.gitignore` 移除 `.github/*` 排除规则，workflow 文件可直接 `git add` 无需 `-f`。

### Fixed
- CI artifact 存储配额耗尽：`build-android.yml` 的 debug APK artifact 保留期改为 1 天，自动清理历史堆积。

## [v1.0.1] - 2026-04-14

### Added
- `server/config`: 新增 `MinioDataDir()` 配置项，支持本地磁盘直接挂载回退。
- `server/controllers/upload.go`: `ServeUpload` 新增 MinIO DataDir 磁盘回退路径，以及 presign 失败时的 WARN 日志，方便排查。
- `server/router`: 补充缺失的事件路由 `POST /events/page_view`、`/events/favorite`、`/events/comment`。

### Changed
- `server/config`: MinIO 默认配置恢复为本地开发实际值（endpoint `192.168.10.2:9000`，用户 `appuser`）。
- `server/main.go`: 移除 `godotenv` 依赖，回归无外部配置文件的简洁启动方式。

### Fixed
- 修复 MinIO presign 持续触发 circuit breaker 的问题：根因为 `godotenv.Load` 多路径陷阱导致 `.env` 未被加载，服务器使用了错误的默认凭证（`minioadmin`）而非实际凭证（`appuser`）。

## [v1.0.2] - 2026-02-28

### Added
- 新增 `CHANGELOG.md` 版本日志规范，统一记录每次发布内容。
- 新增 README 文档导航中的版本日志入口，方便查阅发布历史。

### Changed
- 发布流水线改为优先读取 `CHANGELOG` 对应版本段落作为 Release 说明。
- 当 `CHANGELOG` 未命中当前标签时，自动回退为 GitHub 自动生成更新说明。

### Fixed
- 修复 Release 工作流中 `google-services.json` 写入与路径校验流程。
- 修复仅生成源码包但未附带 APK 的发布问题，现自动附带 `app-release.apk`。

## [v1.0.1] - 2026-02-28

### Added
- Added CI workflows (`flutter-check`, `server-check`, Android build).
- Added Android build secret injection for `google-services.json`.
- Added CI/CD collaboration guide and repository documentation navigation.

### Changed
- Improved CI compatibility for Flutter analyze/test and Go vet checks.

### Fixed
- Fixed CI format and lint issues in Flutter and server modules.
