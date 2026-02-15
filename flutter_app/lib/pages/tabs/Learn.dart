import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/widget/AppStateWidgets.dart';
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
  int _userId = 0;
  int _balance = 0;

  bool _loadingChats = false;
  bool _errorChats = false;
  int _chatUnreadTotal = 0;
  List<_ConversationItem> _chatItems = [];
  Set<String> _hiddenConversationIds = <String>{};

  bool _weakNetwork = false;
  bool _usingOfflineCache = false;
  String _networkHint = '';

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

  String _balanceCacheKey() => 'learn_points_balance_v1_$_userId';
  String _chatCacheKey() => 'learn_chat_list_v1_$_userId';

  Future<bool> _applyBalanceCache({Duration? maxAge}) async {
    final payload = await _storage.getOfflinePayload(
      _balanceCacheKey(),
      maxAge: maxAge,
    );
    if (payload == null) return false;
    final raw = payload['balance'];
    int value = 0;
    if (raw is num) {
      value = raw.toInt();
    } else {
      value = int.tryParse(raw?.toString() ?? '') ?? 0;
    }
    if (!mounted) return true;
    setState(() {
      _balance = value;
    });
    return true;
  }

  Future<void> _saveBalanceCache(int balance) async {
    await _storage.saveOfflinePayload(_balanceCacheKey(), {'balance': balance});
  }

  Future<bool> _applyChatCache({Duration? maxAge}) async {
    final payload = await _storage.getOfflinePayload(
      _chatCacheKey(),
      maxAge: maxAge,
    );
    if (payload == null) return false;
    final raw = payload['items'];
    if (raw is! List) return false;
    final items = <_ConversationItem>[];
    for (final item in raw) {
      if (item is Map) {
        final parsed = _ConversationItem.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (!_hiddenConversationIds.contains(parsed.id)) {
          items.add(parsed);
        }
      }
    }
    if (items.isEmpty) return false;
    if (!mounted) return true;

    final unread = items.fold<int>(0, (prev, e) => prev + e.unread);
    setState(() {
      _chatItems = items;
      _chatUnreadTotal = unread;
      _loadingChats = false;
    });
    return true;
  }

  Future<void> _saveChatCache(List<_ConversationItem> items) async {
    await _storage.saveOfflinePayload(_chatCacheKey(), {
      'items': items.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> _loadData() async {
    final token = await _storage.getUserToken();
    final loggedIn =
        token != null && token.toString().isNotEmpty && token != 'null';
    final userId = await _storage.getUserId();
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
          _weakNetwork = false;
          _usingOfflineCache = false;
          _networkHint = '';
        });
      }
      return;
    }

    _userId = userId ?? 0;
    if (mounted) {
      setState(() {
        _loggedIn = true;
        _weakNetwork = false;
        _usingOfflineCache = false;
        _networkHint = '';
      });
    }

    try {
      final balanceResp = await _api.getWithRetry<Map<String, dynamic>>(
        '/points/balance',
        fromJson: (data) => Map<String, dynamic>.from(data as Map),
        retries: 2,
        baseDelay: const Duration(milliseconds: 300),
      );
      final balance =
          (balanceResp.data['points_balance'] as num?)?.toInt() ?? 0;
      if (mounted) {
        setState(() {
          _balance = balance;
        });
      }
      await _saveBalanceCache(balance);
    } catch (_) {
      final loaded = await _applyBalanceCache(maxAge: const Duration(days: 3));
      if (mounted && loaded) {
        setState(() {
          _weakNetwork = true;
          _usingOfflineCache = true;
          _networkHint = '网络较弱，积分数据来自离线缓存';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }

    await _loadHiddenConversationIds();
    await _loadChats();
  }

  Future<void> _loadChats() async {
    bool usedCache = false;
    if (mounted) {
      setState(() {
        _loadingChats = true;
        _errorChats = false;
      });
    }

    usedCache = await _applyChatCache(maxAge: const Duration(hours: 6));
    if (usedCache && mounted) {
      setState(() {
        _usingOfflineCache = true;
      });
    }

    try {
      final convResp = await _api.getWithRetry<Map<String, dynamic>>(
        '/chat/conversations',
        queryParameters: const {'page': 1, 'page_size': 8},
        fromJson: (data) => Map<String, dynamic>.from(data as Map),
        retries: 2,
        baseDelay: const Duration(milliseconds: 320),
      );

      final convData = convResp.data;
      final rawItems = convData['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .whereType<Map>()
          .map((e) => _ConversationItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => !_hiddenConversationIds.contains(e.id))
          .toList();

      final unread = items.fold<int>(0, (prev, e) => prev + e.unread);

      if (mounted) {
        setState(() {
          _chatItems = items;
          _chatUnreadTotal = unread;
          _loadingChats = false;
          _errorChats = false;
          _weakNetwork = false;
          _usingOfflineCache = false;
          _networkHint = '';
        });
      }
      await _saveChatCache(items);
    } catch (_) {
      final fallback = usedCache
          ? true
          : await _applyChatCache(maxAge: const Duration(days: 3));
      if (mounted) {
        setState(() {
          _loadingChats = false;
          _errorChats = !fallback;
          _weakNetwork = true;
          _usingOfflineCache = fallback;
          _networkHint = fallback ? '网络较弱，聊天列表来自离线缓存' : '聊天列表加载失败，请下拉重试';
        });
      }
    }
  }

  Future<void> _loadHiddenConversationIds() async {
    final ids = await _storage.getHiddenConversationIds();
    if (!mounted) return;
    setState(() {
      _hiddenConversationIds = ids;
    });
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

  Future<void> _hideConversation(_ConversationItem item) async {
    if (item.id.isEmpty || _hiddenConversationIds.contains(item.id)) {
      return;
    }

    final previous = Set<String>.from(_hiddenConversationIds);
    setState(() {
      _hiddenConversationIds = {..._hiddenConversationIds, item.id};
      _chatItems = _chatItems.where((e) => e.id != item.id).toList();
      _chatUnreadTotal = _chatItems.fold<int>(0, (prev, e) => prev + e.unread);
    });

    try {
      await _storage.saveHiddenConversationIds(_hiddenConversationIds);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hiddenConversationIds = previous;
      });
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('会话已隐藏（历史消息不会删除）'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            _restoreConversation(item.id);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _restoreConversation(String conversationId) async {
    if (!_hiddenConversationIds.contains(conversationId)) {
      return;
    }
    setState(() {
      _hiddenConversationIds = Set<String>.from(_hiddenConversationIds)
        ..remove(conversationId);
    });
    await _storage.saveHiddenConversationIds(_hiddenConversationIds);
    await _loadChats();
  }

  Widget _buildChatCell(_ConversationItem item) {
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

  Widget _buildChatItem(_ConversationItem item) {
    final screenWidth = MediaQuery.of(context).size.width;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: TDSwipeCell(
        slidableKey: ValueKey('learn_chat_${item.id}'),
        groupTag: 'learn_chat_list',
        right: TDSwipeCellPanel(
          extentRatio: 72 / screenWidth,
          dragDismissible: false,
          onDismissed: (_) => _hideConversation(item),
          children: [
            TDSwipeCellAction(
              backgroundColor: TDTheme.of(context).errorNormalColor,
              label: '隐藏',
              onPressed: (_) => _hideConversation(item),
            ),
          ],
        ),
        cell: _buildChatCell(item),
      ),
    );
  }

  Widget _buildChatSection() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
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
            if (_loadingChats && _chatItems.isEmpty)
              const AppListSkeleton(
                itemCount: 3,
                itemHeight: 76,
                padding: EdgeInsets.zero,
              )
            else if (_errorChats)
              AppEmptyState(
                icon: Icons.chat_bubble_outline,
                title: '聊天列表加载失败',
                subtitle: '请检查网络后重试',
                actionText: '重试',
                onAction: _loadChats,
                margin: EdgeInsets.zero,
              )
            else if (_chatItems.isEmpty)
              const AppEmptyState(
                icon: Icons.forum_outlined,
                title: '暂无会话',
                subtitle: '发起私信或加入群聊后会显示在这里',
                margin: EdgeInsets.zero,
              )
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
    return AppEmptyState(
      icon: Icons.lock_outline,
      title: '登录后查看学习数据',
      subtitle: '可查看积分、会话和学习相关功能',
      actionText: '去登录',
      onAction: () async {
        await Navigator.pushNamed(context, '/login');
        await _loadData();
      },
      margin: const EdgeInsets.fromLTRB(16, 40, 16, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const AppListSkeleton(
        itemCount: 4,
        itemHeight: 84,
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
      );
    }

    if (!_loggedIn) {
      return _buildLoginPrompt();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        children: [
          _buildBalanceCard(),
          if (_weakNetwork || _usingOfflineCache)
            AppWeakNetworkBanner(
              text: _networkHint.isNotEmpty
                  ? _networkHint
                  : (_usingOfflineCache ? '已展示离线缓存内容' : '当前网络较弱'),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            ),
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
    if (json.containsKey('preview') && json.containsKey('avatar_url')) {
      return _ConversationItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '私聊',
        preview: json['preview']?.toString() ?? '暂无消息',
        time: json['time']?.toString() ?? '',
        unread: (json['unread'] as num?)?.toInt() ?? 0,
        avatarUrl: json['avatar_url']?.toString() ?? '',
        isGroup: json['is_group'] == true || json['is_group'] == 1,
      );
    }

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'preview': preview,
      'time': time,
      'unread': unread,
      'avatar_url': avatarUrl,
      'is_group': isGroup ? 1 : 0,
    };
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
