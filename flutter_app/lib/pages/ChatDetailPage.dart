import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
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
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int? _conversationId;
  int _myUserId = 0;

  bool _loading = true;
  bool _error = false;
  bool _sending = false;

  List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _conversationId = int.tryParse(widget.conversationId);
    _init();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (_conversationId == null || _conversationId! <= 0) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
      return;
    }

    _myUserId = await _storage.getUserId() ?? 0;
    await _loadMessages(showLoading: true);
  }

  Future<void> _loadMessages({required bool showLoading}) async {
    final conversationId = _conversationId;
    if (conversationId == null) {
      return;
    }

    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/chat/messages',
        queryParameters: {
          'conversation_id': conversationId,
          'page': 1,
          'page_size': 100,
        },
        fromJson: (raw) => Map<String, dynamic>.from(raw as Map),
      );

      final rawItems = response.data['items'] as List<dynamic>? ?? [];
      final messages = rawItems
          .whereType<Map>()
          .map((e) => _ChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      messages.sort((a, b) => a.id.compareTo(b.id));

      if (mounted) {
        setState(() {
          _messages = messages;
          _loading = false;
          _error = false;
        });
      }

      if (messages.isNotEmpty) {
        await _markRead(messages.last.id);
      }
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  Future<void> _markRead(int lastMessageId) async {
    final conversationId = _conversationId;
    if (conversationId == null || lastMessageId <= 0) {
      return;
    }

    try {
      await _api.post<Map<String, dynamic>>(
        '/chat/read',
        data: {
          'conversation_id': conversationId,
          'last_message_id': lastMessageId,
        },
        fromJson: (raw) =>
            (raw as Map<String, dynamic>?) ?? <String, dynamic>{},
      );
    } catch (_) {
      // ignore read sync error
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final conversationId = _conversationId;
    if (conversationId == null || _sending) {
      return;
    }

    final text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/chat/messages',
        data: {
          'conversation_id': conversationId,
          'msg_type': 'text',
          'content': text,
        },
        fromJson: (raw) => Map<String, dynamic>.from(raw as Map),
      );

      final map = response.data;
      final msg = _ChatMessage(
        id:
            (map['id'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        senderId: (map['sender_id'] as num?)?.toInt() ?? _myUserId,
        senderName: '我',
        senderAvatar: '',
        content: map['content']?.toString() ?? text,
        createdAt:
            map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      );

      if (mounted) {
        setState(() {
          _messages = [..._messages, msg];
          _inputController.clear();
        });
      }

      await _markRead(msg.id);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发送失败：$e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  int _parseConversationId(Map<String, dynamic> data) {
    final raw = data['id'] ?? data['ID'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  Future<void> _startPrivateChatFromAvatar(_ChatMessage msg) async {
    if (_myUserId > 0 && msg.senderId == _myUserId) {
      return;
    }
    if (msg.senderId <= 0) {
      return;
    }

    final token = await _storage.getUserToken();
    final loggedIn =
        token != null && token.toString().isNotEmpty && token != 'null';
    if (!loggedIn) {
      if (!mounted) return;
      await Navigator.pushNamed(context, '/login');
      return;
    }

    try {
      final resp = await _api.post<Map<String, dynamic>>(
        '/chat/private/start',
        data: {'target_user_id': msg.senderId},
        fromJson: (raw) => Map<String, dynamic>.from(raw as Map),
      );
      final conversationId = _parseConversationId(resp.data);
      if (conversationId <= 0) {
        throw Exception('会话编号无效');
      }
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        '/chatDetail',
        arguments: {
          'conversationId': conversationId.toString(),
          'title': msg.senderName,
          'isGroup': false,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发起私信失败：$e')));
    }
  }

  bool _isMine(_ChatMessage msg) {
    if (_myUserId > 0) {
      return msg.senderId == _myUserId;
    }
    return msg.senderName == '我';
  }

  Widget _buildBubble(_ChatMessage msg) {
    final mine = _isMine(msg);
    final bubbleColor = mine ? const Color(0xFF2E6BE6) : Colors.white;
    final textColor = mine ? Colors.white : Colors.black87;
    final align = mine ? MainAxisAlignment.end : MainAxisAlignment.start;

    final resolvedAvatar = Config.resolveImage(msg.senderAvatar);
    final avatar = GestureDetector(
      onTap: (!mine && widget.isGroup)
          ? () => _startPrivateChatFromAvatar(msg)
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: TDImage(
          imgUrl: resolvedAvatar.isEmpty
              ? 'https://picsum.photos/seed/chat_${msg.senderId}/80'
              : resolvedAvatar,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
        ),
      ),
    );

    return Row(
      mainAxisAlignment: align,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!mine) avatar,
        if (!mine) const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!mine && widget.isGroup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    msg.senderName,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(12),
                  border: mine
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
        if (mine) const SizedBox(width: 8),
        if (mine) avatar,
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
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 10),
          TDButton(
            text: _sending ? '发送中' : '发送',
            size: TDButtonSize.small,
            type: TDButtonType.fill,
            onTap: _sending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('会话加载失败'),
            const SizedBox(height: 8),
            TDButton(
              text: '重试',
              size: TDButtonSize.small,
              onTap: () => _loadMessages(showLoading: true),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => _loadMessages(showLoading: false),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 140),
                      Center(
                        child: Text(
                          '暂无消息',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadMessages(showLoading: false),
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildBubble(_messages[index]),
                  ),
                ),
        ),
        _buildInputBar(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _buildBody(),
    );
  }
}

class _ChatMessage {
  final int id;
  final int senderId;
  final String senderName;
  final String senderAvatar;
  final String content;
  final String createdAt;

  const _ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.content,
    required this.createdAt,
  });

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    return _ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      senderName: json['sender_name']?.toString() ?? '用户',
      senderAvatar: json['sender_avatar']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
