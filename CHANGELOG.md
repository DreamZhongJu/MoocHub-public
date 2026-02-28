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
