# 开发流程与 PR 规范

本文档用于约束本仓库在“私有仓库免费版”条件下的协作流程，目标是保证质量稳定、变更可追踪。

## 1. 背景说明
- 当前仓库未升级 GitHub Team/Enterprise。
- Branch protection / Ruleset 在页面可配置，但会显示 `Not enforced`，不具备强制拦截能力。
- 因此采用“流程强约束 + CI 检查”替代平台强制规则。

## 2. 分支策略
- `main`：稳定分支，仅接收通过 PR 的改动。
- 功能分支：按需求新建，用完即删，不复用旧分支。

推荐命名：
- 新功能：`feat/<module>-<topic>`
- 缺陷修复：`fix/<module>-<bug>`
- 重构：`refactor/<module>-<topic>`
- 文档：`docs/<topic>`
- 构建运维：`chore/<topic>`

示例：
- `feat/search-highlight`
- `fix/chat-controller-dispose`
- `chore/ci-android-secret`

## 3. 标准开发流程（每个需求都执行）
1. 从最新 `main` 拉新分支：
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feat/xxx
   ```
2. 本地开发与自测（至少一次）。
3. 提交并推送分支：
   ```bash
   git add .
   git commit -m "feat: xxx"
   git push -u origin feat/xxx
   ```
4. 创建 PR：`feat/xxx -> main`。
5. 等待 CI 全绿（`flutter-check`、`server-check`）。
6. 通过审查后手动合并到 `main`。
7. 删除已合并分支（本地与远端）。

## 4. 合并门禁（人工强制）
PR 合并前必须满足：
- CI 通过：
  - `CI Check / flutter-check`
  - `CI Check / server-check`
- 关键改动建议额外跑一次 Android 构建：
  - `Build Android`
- 自检通过：
  - Flutter：`flutter format --set-exit-if-changed .`、`flutter analyze`、`flutter test`
  - Server：`gofmt -w <文件列表>`、`go vet ./...`、`go test ./...`

## 5. PR 的作用
- 代码评审入口：改动先审后合并。
- 质量闸门入口：CI 在 PR 上自动校验格式、静态检查、测试、构建。
- 变更审计入口：记录需求背景、实现方案、风险和回滚依据。

## 6. 分支合并后，后续怎么改
不要在旧分支继续开发。正确做法：
- 老功能出 bug：从最新 `main` 新建 `fix/xxx`。
- 旧功能要增强：从最新 `main` 新建 `feat/xxx-v2` 或 `feat/xxx-enhance`。
- 改完继续提 PR 到 `main`。

## 7. CI/CD 在项目生命周期中的落地建议
- 阶段 1（尽早）：最小 CI（format/lint/test/build）。
- 阶段 2（迭代期）：补齐更多自动化测试、制品发布、缓存优化。
- 阶段 3（上线前）：完善发布流水线、环境变量和回滚流程。
- 阶段 4（运营期）：监控、告警、质量阈值、发布审计闭环。

## 8. 常用命令
创建 PR：
```bash
gh pr create --base main --head feat/xxx --title "feat: xxx" --body "..."
```

合并 PR（squash）：
```bash
gh pr merge --squash --delete-branch
```

触发 Android 构建（main）：
```bash
gh workflow run "Build Android" --ref main
```

查看仓库 Secrets：
```bash
gh secret list
```
