# LightRAG 知识源导出接口说明

## 1. 目标

这组接口用于把 MoocHub 现有教学内容导出为标准知识源，供后续 LightRAG 服务执行：

- 首次离线建库
- 定时全量抽取
- 单条增量拉取

当前导出粒度基于现有业务模型，支持：

- `course`
- `video`
- `article`

## 2. 鉴权

接口属于内部接口，请求头必须携带：

```http
X-Internal-Token: moochub-internal
```

如果服务端配置了环境变量 `INTERNAL_TOKEN`，则以环境变量为准。

## 3. 单类型分页导出

### 接口

```http
GET /api/v1/internal/knowledge/sources/:type
```

### 支持的 `type`

- `course`
- `video`
- `article`

### 查询参数

- `page`：页码，默认 `1`
- `page_size`：每页数量，默认 `50`，最大 `100`
- `status`：默认 `published`

### 示例

```bash
curl --location --request GET 'http://127.0.0.1:3000/api/v1/internal/knowledge/sources/course?page=1&page_size=10&status=published' \
--header 'X-Internal-Token: moochub-internal'
```

```bash
curl --location --request GET 'http://127.0.0.1:3000/api/v1/internal/knowledge/sources/article?page=1&page_size=10&status=published' \
--header 'X-Internal-Token: moochub-internal'
```

## 4. 单条详情导出

### 接口

```http
GET /api/v1/internal/knowledge/sources/:type/:id
```

### 查询参数

- `status`：默认 `published`

### 示例

```bash
curl --location --request GET 'http://127.0.0.1:3000/api/v1/internal/knowledge/sources/article/1?status=published' \
--header 'X-Internal-Token: moochub-internal'
```

## 5. 聚合导出接口

### 接口

```http
GET /api/v1/internal/knowledge/sources
```

### 查询参数

- `types`：逗号分隔，默认 `course,video,article`
- `per_type_limit`：每种类型最大导出条数，默认 `100`，最大 `100`
- `status`：默认 `published`

### 示例

```bash
curl --location --request GET 'http://127.0.0.1:3000/api/v1/internal/knowledge/sources?types=course,video,article&per_type_limit=20&status=published' \
--header 'X-Internal-Token: moochub-internal'
```

```bash
curl --location --request GET 'http://127.0.0.1:3000/api/v1/internal/knowledge/sources?types=course,article&per_type_limit=20&status=published' \
--header 'X-Internal-Token: moochub-internal'
```

## 6. 返回结构

### 6.1 标准知识源结构

每条导出结果统一为：

```json
{
  "source_id": "course:1",
  "source_type": "course",
  "biz_id": 1,
  "title": "Go 并发编程",
  "summary": "讲解 goroutine 与 channel",
  "content": "Go 并发编程\n\n讲解 goroutine 与 channel",
  "tags": ["category:后端开发", "level:advanced", "instructor:teacher-a"],
  "source_url": "/api/v1/courses/1",
  "status": "published",
  "updated_at": "2026-03-12T10:00:00Z",
  "metadata": {
    "category_id": 2,
    "category_name": "后端开发"
  }
}
```

### 6.2 聚合接口返回

```json
{
  "types": ["course", "video", "article"],
  "status": "published",
  "per_type_limit": 20,
  "counts": {
    "course": 20,
    "video": 20,
    "article": 20
  },
  "items_by_type": {
    "course": [],
    "video": [],
    "article": []
  }
}
```

## 7. 当前边界

- 当前不需要改 SQL 表
- 当前不新增 migration
- 当前不导出评论、聊天、用户隐私数据
- 当前没有独立 `chapter` 表，因此第一版以 `video` 作为课程内最细粒度教学单元

## 8. 推荐使用方式

### 首次建库

先用聚合接口拉一批：

```http
GET /api/v1/internal/knowledge/sources?types=course,video,article&per_type_limit=100
```

### 增量更新

拿到 `knowledge.sync` 事件后，再调用单条详情接口：

```http
GET /api/v1/internal/knowledge/sources/course/123
GET /api/v1/internal/knowledge/sources/video/456
GET /api/v1/internal/knowledge/sources/article/789
```

这样后续 LightRAG 服务可以采用“事件驱动 + 单条拉取”的方式同步知识源。

## 9. 与知识同步事件的关系

当前后端已经补上 `knowledge.sync` 事件骨架：

- 课程创建 / 更新 / 删除
- 视频创建 / 更新 / 删除
- 文章创建（发布）

如果配置了以下环境变量：

- `LIGHTRAG_SYNC_URL`
- `LIGHTRAG_SYNC_TOKEN`（可选）
- `LIGHTRAG_SYNC_TIMEOUT_MS`（可选）
- `LIGHTRAG_SYNC_MAX_RETRY`（可选，默认 `3`）

则后端 worker 会消费 `knowledge.sync` 事件，并把单条知识源内容转发给外部 LightRAG 服务。

如果没有配置 `LIGHTRAG_SYNC_URL`：

- worker 不启动
- 主业务不报错
- 仍可通过本文档中的导出接口手动拉取知识源，后续再做 LightRAG 建库

## 10. 同步失败处理

- `knowledge.sync` 同步失败后，不会无限重回主队列
- worker 会按 `LIGHTRAG_SYNC_MAX_RETRY` 做有界重试
- 超过重试上限后，消息会进入死信队列 `moochub.knowledge.sync.dead`

这样做的目的有两个：

- 避免外部 LightRAG 服务异常时长期阻塞主同步队列
- 保留失败消息，方便后续排查和补偿
