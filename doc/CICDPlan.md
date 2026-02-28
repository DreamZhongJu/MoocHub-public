# CI/CD 与质量门禁实施计划

## 1. 目标
- 每次 PR 自动执行：格式检查、静态检查、单元测试。
- 主分支自动执行：质量检查 + 构建产物（Android）。
- 质量门禁未通过时禁止合并。

## 2. 规范（第一步落地）

### 2.1 Server（Go）
- 格式检查：`gofmt -l`
- 静态检查：`go vet ./...`
- 单元测试：`go test ./...`

### 2.2 Flutter
- 依赖安装：`flutter pub get`
- 格式检查：`dart format --set-exit-if-changed .`
- 静态检查：`flutter analyze`
- 单元测试：`flutter test`
- 构建校验：`flutter build apk --debug`

### 2.3 合并门禁规则
- 必须通过：Server 检查、Flutter 检查
- 建议通过：Android 构建（主分支必跑）
- 可后续收紧：warning 逐步升级为阻断

## 3. 本地验证结果（第二步落地）
- 见本次执行记录（终端输出）

