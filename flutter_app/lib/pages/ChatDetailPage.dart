import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:flutter/material.dart';

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
  final FocusNode _focusNode = FocusNode();

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
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (_conversationId == null || _conversationId! <= 0) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = true;
        });
      return;
    }
    _myUserId = await _storage.getUserId() ?? 0;
    await _loadMessages(showLoading: true);
  }

  Future<void> _loadMessages({required bool showLoading}) async {
    final cid = _conversationId;
    if (cid == null) return;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/chat/messages',
        queryParameters: {'conversation_id': cid, 'page': 1, 'page_size': 100},
        fromJson: (raw) => Map<String, dynamic>.from(raw as Map),
      );
      final rawItems = response.data['items'] as List<dynamic>? ?? [];
      final messages =
          rawItems
              .whereType<Map>()
              .map((e) => _ChatMessage.fromJson(Map<String, dynamic>.from(e)))
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));

      if (mounted)
        setState(() {
          _messages = messages;
          _loading = false;
          _error = false;
        });
      if (messages.isNotEmpty) await _markRead(messages.last.id);
      _scrollToBottom();
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = true;
        });
    }
  }

  Future<void> _markRead(int lastMessageId) async {
    final cid = _conversationId;
    if (cid == null || lastMessageId <= 0) return;
    try {
      await _api.post<Map<String, dynamic>>(
        '/chat/read',
        data: {'conversation_id': cid, 'last_message_id': lastMessageId},
        fromJson: (raw) => (raw as Map<String, dynamic>?) ?? {},
      );
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final cid = _conversationId;
    if (cid == null || _sending) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/chat/messages',
        data: {'conversation_id': cid, 'msg_type': 'text', 'content': text},
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送失败：$e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startPrivateChat(_ChatMessage msg) async {
    if (_myUserId > 0 && msg.senderId == _myUserId) return;
    if (msg.senderId <= 0) return;

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
      final data = resp.data;
      final raw = data['id'] ?? data['ID'];
      final cid = raw is num
          ? raw.toInt()
          : int.tryParse(raw?.toString() ?? '') ?? 0;
      if (cid <= 0) throw Exception('会话编号无效');
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        '/chatDetail',
        arguments: {
          'conversationId': cid.toString(),
          'title': msg.senderName,
          'isGroup': false,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('发起私信失败：$e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  bool _isMine(_ChatMessage msg) {
    if (_myUserId > 0) return msg.senderId == _myUserId;
    return msg.senderName == '我';
  }

  // ── Time helpers ────────────────────────────────────────────────────────────

  String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDateLabel(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '今天';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day)
      return '昨天';
    return '${dt.month}月${dt.day}日';
  }

  bool _needDateSeparator(int index) {
    if (index == 0) return true;
    final prev = DateTime.tryParse(_messages[index - 1].createdAt)?.toLocal();
    final curr = DateTime.tryParse(_messages[index].createdAt)?.toLocal();
    if (prev == null || curr == null) return false;
    return prev.year != curr.year ||
        prev.month != curr.month ||
        prev.day != curr.day;
  }

  // ── Widgets ─────────────────────────────────────────────────────────────────

  Widget _buildDateSeparator(String raw) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _formatDateLabel(raw),
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ),
    );
  }

  Widget _buildAvatar(_ChatMessage msg, bool mine) {
    final resolved = Config.resolveImage(msg.senderAvatar);
    final url = resolved.isEmpty
        ? 'https://picsum.photos/seed/chat_${msg.senderId}/80'
        : resolved;
    final avatar = GestureDetector(
      onTap: (!mine && widget.isGroup) ? () => _startPrivateChat(msg) : null,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: NetworkImage(url),
      ),
    );
    return avatar;
  }

  Widget _buildBubble(_ChatMessage msg) {
    final mine = _isMine(msg);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final bubbleBg = mine
        ? primary
        : (isDark ? const Color(0xFF2A2D38) : Colors.white);
    final textColor = mine
        ? Colors.white
        : (isDark ? const Color(0xDEFFFFFF) : Colors.black87);
    final timeColor = mine
        ? Colors.white.withValues(alpha: 0.65)
        : Colors.grey.shade400;

    // Bubble radius: sharper corner at tail side
    final radius = mine
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.65,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleBg,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            msg.content,
            style: TextStyle(color: textColor, fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(msg.createdAt),
            style: TextStyle(color: timeColor, fontSize: 10),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[_buildAvatar(msg, false), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!mine && widget.isGroup)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      msg.senderName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                bubble,
              ],
            ),
          ),
          if (mine) ...[const SizedBox(width: 8), _buildAvatar(msg, true)],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF171A21) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F1115)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: _inputController,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 4,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: '输入消息…',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: InputBorder.none,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _sending ? Colors.grey.shade300 : primary,
                  shape: BoxShape.circle,
                  boxShadow: _sending
                      ? []
                      : [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.38),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadMessages(showLoading: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 180),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '还没有消息，先打个招呼吧',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMessages(showLoading: false),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          return Column(
            children: [
              if (_needDateSeparator(index)) _buildDateSeparator(msg.createdAt),
              _buildBubble(msg),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Container(
        color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF0F2F5),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text('会话加载失败'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _loadMessages(showLoading: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF0F2F5),
            child: _buildMessageList(),
          ),
        ),
        _buildInputBar(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F1115)
          : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF171A21) : Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (widget.isGroup)
              Text(
                '群聊',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
            onPressed: () => _loadMessages(showLoading: true),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _buildBody(),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

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
