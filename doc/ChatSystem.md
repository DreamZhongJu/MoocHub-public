# 实时聊天（私信/群聊）技术方案与实现流程

本方案适配 MoocHub 现有 Flutter + Go 后端架构，目标是完成私信与群聊的实时通信。
当前仅落地前端页面与交互结构，后端/数据库留作下一步实现。

## 1. 总体架构
- **WebSocket**：用于实时消息收发、已读回执、状态通知。
- **HTTP REST**：用于历史消息、会话列表、群成员管理。
- **MySQL**：消息持久化、会话与成员关系。
- **Redis（可选）**：在线状态、未读计数缓存、消息投递队列。

## 2. 数据模型（建议）
### 2.1 会话表
```
conversations
- id
- type (private / group)
- last_message_id
- last_message_at
```

### 2.2 会话成员
```
conversation_members
- conversation_id
- user_id
- role (owner / admin / member)
- joined_at
```

### 2.3 消息表
```
messages
- id
- conversation_id
- sender_id
- type (text / image / file / system)
- content
- created_at
```

### 2.4 已读记录
```
message_reads
- message_id
- user_id
- read_at
```

## 3. 通信协议设计
### 3.1 WebSocket 事件
- `chat:send`：发送消息
- `chat:message`：接收消息
- `chat:ack`：服务端确认发送成功
- `chat:read`：已读回执
- `chat:typing`：正在输入（可选）

### 3.2 HTTP API（建议）
- `GET /chat/conversations` 获取会话列表
- `GET /chat/messages?conversation_id=...` 拉取历史
- `POST /chat/group` 创建群聊
- `POST /chat/group/invite` 邀请成员

## 4. 客户端流程
1. 打开消息页 → 展示会话列表
2. 进入会话 → 拉历史消息 + 订阅 WS
3. 发送消息 → 本地插入“发送中”，WS 发出
4. 收到 `chat:ack` → 更新消息状态
5. 进入会话即回执已读 → 更新未读数

## 5. 离线补偿与可靠性
- **断线重连**：指数退避重连
- **离线补拉**：重连后基于时间戳补拉消息
- **ACK 机制**：保证发送状态准确
- **幂等处理**：同一消息 ID 只入库一次

## 6. 安全与权限
- WS 连接携带 JWT
- 服务端校验用户是否属于会话
- 群聊操作权限：群主/管理员/成员

## 7. 现阶段前端实现说明（已完成）
本阶段仅实现 UI 与页面结构：
- 会话列表页（私信/群聊 Tab）
- 聊天详情页（消息列表 + 输入框）
- 使用 TDesign 组件完成基础样式（TDTabBar、TDSearchBar、TDButton、TDNoticeBar、TDImage）

后续接入后端后，只需在以下位置补齐数据：
- 会话列表：替换 mock 数据为 `/chat/conversations`
- 消息列表：替换 mock 数据为 `/chat/messages`
- 发送按钮：接入 WebSocket 发送 + ACK

## 8. 后续实现建议顺序
1) 先完成 **会话列表 + 历史消息** REST  
2) 再补 **WebSocket 实时收发**  
3) 最后做 **已读/未读、离线补拉、推送提醒**  

