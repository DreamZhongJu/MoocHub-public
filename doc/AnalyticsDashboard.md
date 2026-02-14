# 埋点与数据看板技术文档（M1 + M3）

## 1. 目标与范围

本次实现覆盖两部分：

1. 埋点链路（曝光 / 点击 / 开播 / 完播）  
2. 数据看板（管理端查询接口 + Grafana 面板 JSON）

当前已落地内容：

- 客户端埋点上报（首页推荐流 + 视频页）
- 服务端去重、MQ 异步消费、原始事件入库、小时聚合入库
- 管理端看板查询接口
- Grafana 可直接导入的看板模板

---

## 2. 总体架构

```text
Flutter
  └─ POST /api/v1/events/*
        └─ Gin Controller（参数校验 + Redis去重）
              └─ RabbitMQ topic: analytics.event
                    └─ Analytics Worker
                          ├─ 写 event_logs（原始明细）
                          └─ 更新 event_stats_hourly（小时聚合 PV/UV）

Admin / Grafana
  ├─ GET /api/v1/admin/analytics/*
  └─ 直接查 MySQL（event_stats_hourly）
```

补充：

- `/events/play` 仍同时投递旧队列 `play.view`，兼容原有播放量统计逻辑。

---

## 3. 埋点事件定义

### 3.1 事件类型

- `exposure`：曝光
- `click`：点击
- `play_start`：开播（由 `/events/play` 产生）
- `play_complete`：完播

### 3.2 通用字段

- `content_type`：`course/article/video`
- `content_id`：内容 ID
- `scene`：场景（如 `home_feed`、`video_detail`）
- `session_id`：会话 ID（客户端生成）
- `position`：列表位次或播放位置

### 3.3 指标口径

- `CTR = click_pv / exposure_pv`
- `完播率 = play_complete_uv / play_start_uv`

---

## 4. 去重策略

服务端基于 Redis `SETNX` 去重：

- `click`：3 秒
- `exposure` / `play_start`：30 分钟
- `play_complete`：24 小时（按天防重复）

维度优先级：

1. 登录用户：`user_id`
2. 匿名会话：`session_id`
3. 兜底：`ip + ua` 指纹

---

## 5. 数据库设计

建表脚本：`server/scripts/event_analytics_schema.sql`

### 5.1 原始事件表 `event_logs`

作用：事件留痕、排查、离线分析。

关键字段：

- `event_type`, `content_type`, `content_id`
- `user_id`, `session_id`, `scene`, `position`
- `ip`, `ua`, `occurred_at`

### 5.2 小时聚合表 `event_stats_hourly`

作用：看板查询主表。

关键字段：

- `bucket_hour`
- `event_type`, `content_type`, `content_id`, `scene`
- `pv`, `uv`

唯一键：

- `(bucket_hour, event_type, content_type, content_id, scene)`

---

## 6. 后端接口

### 6.1 客户端埋点接口

- `POST /api/v1/events/exposure`
- `POST /api/v1/events/click`
- `POST /api/v1/events/play`
- `POST /api/v1/events/complete`

返回统一包含 `skipped`（是否被去重）。

### 6.2 管理端看板接口

- `GET /api/v1/admin/analytics/overview`
  - 汇总：曝光/点击/开播/完播 + CTR + 完播率
- `GET /api/v1/admin/analytics/trend`
  - 小时趋势：PV/UV/CTR/完播率
- `GET /api/v1/admin/analytics/top`
  - Top 内容（按 PV）

通用筛选参数：

- `from`、`to`（支持时间字符串或 Unix 秒）
- `content_type`（可选）
- `scene`（可选）

---

## 7. Grafana 看板

文件：`server/grafana/moochub-analytics-dashboard.json`

包含面板：

1. 曝光 PV
2. 点击 PV
3. CTR
4. 完播率
5. 事件趋势（PV）
6. CTR/完播率趋势
7. 点击 Top 内容

导入步骤：

1. Grafana -> Dashboards -> Import
2. 上传 `moochub-analytics-dashboard.json`
3. 选择 MySQL 数据源（指向 Moochub 数据库）

---

## 8. 客户端接入点

### 8.1 首页 `Home`

- 推荐流卡片曝光：`trackExposure`
- 卡片点击：`trackClick`

### 8.2 视频页 `VideoDetail`

- 开播：播放达到阈值后触发 `trackPlayStart`
- 完播：播放进度 >= 90% 触发 `trackPlayComplete`

---

## 9. 联调验收

### 9.1 基础检查

1. 执行建表脚本 `server/scripts/event_analytics_schema.sql`
2. 启动后端（确保 analytics worker 已启动）
3. 打开首页滑动、点击；播放视频到 90% 以上

### 9.2 SQL 验证

```sql
SELECT event_type, content_type, COUNT(*) AS cnt
FROM event_logs
GROUP BY event_type, content_type
ORDER BY cnt DESC;

SELECT bucket_hour, event_type, SUM(pv) AS pv, SUM(uv) AS uv
FROM event_stats_hourly
GROUP BY bucket_hour, event_type
ORDER BY bucket_hour DESC;
```

### 9.3 接口验证（管理员）

```bash
curl -H "Authorization: Bearer <ADMIN_TOKEN>" \
  "http://<host>:3000/api/v1/admin/analytics/overview?from=2026-02-14T00:00:00%2B08:00&to=2026-02-15T00:00:00%2B08:00"
```

---

## 10. 已知边界与下一步

当前版本定位为可用 MVP：

- 已有事件链路与看板能力
- 还未接入 Prometheus 指标采集与告警规则（Grafana Alert / Prometheus Alertmanager）

下一步建议：

1. 增加 `/metrics` 暴露与业务计数器
2. 配置 Prometheus 抓取任务
3. 编写告警规则（5xx、延迟、MQ 堆积、事件断流）
