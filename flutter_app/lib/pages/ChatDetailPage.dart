import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class ChatDetailPage extends StatefulWidget {
  final String conversationId;
  final String title;
  final bool isGroup;

  const ChatDetailPage({
    super.key,
    required this.conversationId,
    required this.title,
    required this.isGroup,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _inputController = TextEditingController();
  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.addAll(_mockMessages(widget.isGroup));
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: '我',
          content: text,
          isMine: true,
          time: DateTime.now(),
        ),
      );
      _inputController.clear();
    });
  }

  Widget _buildBubble(_ChatMessage msg) {
    final bubbleColor = msg.isMine ? const Color(0xFF2E6BE6) : Colors.white;
    final textColor = msg.isMine ? Colors.white : Colors.black87;
    final align =
        msg.isMine ? MainAxisAlignment.end : MainAxisAlignment.start;

    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: TDImage(
        imgUrl: msg.avatar ?? 'https://picsum.photos/seed/chat/80',
        width: 32,
        height: 32,
        fit: BoxFit.cover,
      ),
    );

    return Row(
      mainAxisAlignment: align,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!msg.isMine) avatar,
        if (!msg.isMine) const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment:
                msg.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!msg.isMine && widget.isGroup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    msg.sender,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(12),
                  border: msg.isMine
                      ? null
                      : Border.all(color: const Color(0x11000000)),
                ),
                child: Text(
                  msg.content,
                  style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        if (msg.isMine) const SizedBox(width: 8),
        if (msg.isMine) avatar,
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x11000000))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                hintText: '输入消息...',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ),
          const SizedBox(width: 10),
          TDButton(
            text: '发送',
            size: TDButtonSize.small,
            type: TDButtonType.fill,
            onTap: _sendMessage,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          TDNoticeBar(
            content: '演示模式：实时消息服务未接入',
            prefixIcon: TDIcons.info_circle_filled,
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildBubble(_messages[index]),
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String id;
  final String sender;
  final String content;
  final bool isMine;
  final DateTime time;
  final String? avatar;

  const _ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.isMine,
    required this.time,
    this.avatar,
  });
}

List<_ChatMessage> _mockMessages(bool isGroup) {
  final now = DateTime.now();
  return [
    _ChatMessage(
      id: 'm1',
      sender: isGroup ? '澄空海' : '澄空海',
      content: '今晚把需求整理一下发群里。',
      isMine: false,
      time: now.subtract(const Duration(minutes: 15)),
      avatar: 'https://picsum.photos/seed/chat1/80',
    ),
    _ChatMessage(
      id: 'm2',
      sender: '我',
      content: '收到，我把接口文档也补充一下。',
      isMine: true,
      time: now.subtract(const Duration(minutes: 10)),
      avatar: 'https://picsum.photos/seed/chat2/80',
    ),
    _ChatMessage(
      id: 'm3',
      sender: isGroup ? 'ProfessorLeo65' : 'ProfessorLeo65',
      content: '注意区分私信和群聊的已读逻辑。',
      isMine: false,
      time: now.subtract(const Duration(minutes: 5)),
      avatar: 'https://picsum.photos/seed/chat3/80',
    ),
  ];
}
