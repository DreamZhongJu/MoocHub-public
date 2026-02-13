import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => LearnPageState();
}

class LearnPageState extends State<LearnPage>
    with AutomaticKeepAliveClientMixin<LearnPage>, WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  bool _loading = true;
  bool _loggedIn = false;
  int _balance = 0;

  bool _loadingChats = false;
  bool _errorChats = false;
  int _chatUnreadTotal = 0;
  List<_ConversationItem> _chatItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshFromParent();
    }
  }

  Future<void> refreshFromParent() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
    await _loadData();
  }

  Future<void> _loadData() async {
    final token = await _storage.getUserToken();
    final loggedIn =
        token != null && token.toString().isNotEmpty && token != 'null';
    if (!loggedIn) {
      if (mounted) {
        setState(() {
          _loggedIn = false;
          _loading = false;
          _balance = 0;
          _chatItems = [];
          _chatUnreadTotal = 0;
          _loadingChats = false;
          _errorChats = false;
        });
      }
      return;
    }

    try {
      final balanceResp = await _api.get<Map<String, dynamic>>(
        '/points/balance',
        fromJson: (data) => Map<String, dynamic>.from(data as Map),
      );
      final balance =
          (balanceResp.data['points_balance'] as num?)?.toInt() ?? 0;

      if (mounted) {
        setState(() {
          _loggedIn = true;
          _balance = balance;
          _loading = false;
        });
      }

      await _loadChats();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loggedIn = true;
          _loading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('积分加载失败: $e')));
      }
    }
  }

  Future<void> _loadChats() async {
    if (mounted) {
      setState(() {
        _loadingChats = true;
        _errorChats = false;
      });
    }

    try {
      final responses = await Future.wait([
        _api.get<Map<String, dynamic>>(
          '/chat/conversations',
          queryParameters: const {'page': 1, 'page_size': 8},
          fromJson: (data) => Map<String, dynamic>.from(data as Map),
        ),
        _api.get<Map<String, dynamic>>(
          '/chat/unread_count',
          fromJson: (data) => Map<String, dynamic>.from(data as Map),
        ),
      ]);

      final convData = responses[0].data;
      final unreadData = responses[1].data;

      final rawItems = convData['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .whereType<Map>()
          .map((e) => _ConversationItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final unread =
          (unreadData['unread_count'] as num?)?.toInt() ??
          items.fold<int>(0, (prev, e) => prev + e.unread);

      if (mounted) {
        setState(() {
          _chatItems = items;
          _chatUnreadTotal = unread;
          _loadingChats = false;
          _errorChats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingChats = false;
          _errorChats = true;
        });
      }
    }
  }

  Widget _buildBalanceCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/pointsDetail'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.stars, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '积分',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_balance',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openConversation(_ConversationItem item) async {
    await Navigator.pushNamed(
      context,
      '/chatDetail',
      arguments: {
        'conversationId': item.id,
        'title': item.title,
        'isGroup': item.isGroup,
      },
    );
    await _loadChats();
  }

  Widget _buildChatItem(_ConversationItem item) {
    return InkWell(
      onTap: () => _openConversation(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x11000000)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: TDImage(
                imgUrl: item.avatarUrl,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        item.time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      if (item.unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.unread > 99 ? '99+' : '${item.unread}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatSection() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '即时聊天',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                TDButton(
                  text: _chatUnreadTotal > 99
                      ? '会话列表 (99+)'
                      : _chatUnreadTotal > 0
                      ? '会话列表 ($_chatUnreadTotal)'
                      : '会话列表',
                  size: TDButtonSize.small,
                  type: TDButtonType.outline,
                  onTap: () async {
                    await Navigator.pushNamed(context, '/chat');
                    await _loadChats();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loadingChats)
              Row(
                children: [
                  TDSkeleton(
                    animation: TDSkeletonAnimation.gradient,
                    theme: TDSkeletonTheme.paragraph,
                  ),
                ],
              )
            else if (_errorChats)
              const Text('聊天列表加载失败', style: TextStyle(color: Colors.grey))
            else if (_chatItems.isEmpty)
              const Text('暂无会话', style: TextStyle(color: Colors.grey))
            else
              Column(
                children: [
                  for (var i = 0; i < _chatItems.length; i++) ...[
                    _buildChatItem(_chatItems[i]),
                    if (i != _chatItems.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('登录后查看积分与聊天'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/login');
                await _loadData();
              },
              child: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_loggedIn) {
      return _buildLoginPrompt();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        children: [
          _buildBalanceCard(),
          _buildChatSection(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(
              '后续功能：学习计划 / 成就 / 课程目标',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _ConversationItem {
  final String id;
  final String title;
  final String preview;
  final String time;
  final int unread;
  final String avatarUrl;
  final bool isGroup;

  const _ConversationItem({
    required this.id,
    required this.title,
    required this.preview,
    required this.time,
    required this.unread,
    required this.avatarUrl,
    required this.isGroup,
  });

  factory _ConversationItem.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final type = json['type']?.toString() ?? 'private';
    final title = (json['name']?.toString().trim() ?? '').isEmpty
        ? (type == 'group' ? '群聊' : '私聊')
        : json['name'].toString();

    final previewRaw = json['last_message']?.toString().trim() ?? '';
    final avatarRaw = json['avatar_url']?.toString().trim() ?? '';
    final avatarUrl = Config.resolveImage(avatarRaw);

    return _ConversationItem(
      id: id,
      title: title,
      preview: previewRaw.isEmpty ? '暂无消息' : previewRaw,
      time: _formatTime(json['last_message_at']?.toString() ?? ''),
      unread: (json['unread_count'] as num?)?.toInt() ?? 0,
      avatarUrl: avatarUrl.isEmpty
          ? 'https://picsum.photos/seed/chat_$id/80'
          : avatarUrl,
      isGroup: type == 'group',
    );
  }

  static String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;

    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$mm-$dd';
  }
}
