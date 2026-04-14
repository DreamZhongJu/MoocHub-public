import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/model/VideoModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/widget/AppStateWidgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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

  // Continue watching
  bool _continueLoading = false;
  VideoModel? _continueVideo;
  int _continuePositionSec = 0;
  double _continuePercent = 0;

  // Chat
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
    if (state == AppLifecycleState.resumed) refreshFromParent();
  }

  Future<void> refreshFromParent() async {
    if (!mounted) return;
    setState(() => _loading = true);
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
    final value = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '') ?? 0;
    if (!mounted) return true;
    setState(() => _balance = value);
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
        if (!_hiddenConversationIds.contains(parsed.id)) items.add(parsed);
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
          _continueVideo = null;
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

    // Points balance
    try {
      final resp = await _api.getWithRetry<Map<String, dynamic>>(
        '/points/balance',
        fromJson: (data) => Map<String, dynamic>.from(data as Map),
        retries: 2,
        baseDelay: const Duration(milliseconds: 300),
      );
      final balance = (resp.data['points_balance'] as num?)?.toInt() ?? 0;
      if (mounted) setState(() => _balance = balance);
      await _saveBalanceCache(balance);
    } catch (_) {
      final ok = await _applyBalanceCache(maxAge: const Duration(days: 3));
      if (mounted && ok) {
        setState(() {
          _weakNetwork = true;
          _usingOfflineCache = true;
          _networkHint = '网络较弱，积分数据来自离线缓存';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    await _loadContinueWatching();
    await _loadHiddenConversationIds();
    await _loadChats();
  }

  Future<void> _loadContinueWatching() async {
    if (!_loggedIn) return;
    if (mounted) setState(() => _continueLoading = true);
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/progress/latest',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final data = response.data;
      final videoRaw = data['video'];
      final progressRaw = data['progress'];
      if (videoRaw is Map<String, dynamic> &&
          progressRaw is Map<String, dynamic>) {
        final video = VideoModel.fromJson(videoRaw);
        int pos = 0;
        final lastPos = progressRaw['last_position_sec'];
        if (lastPos is num) {
          pos = lastPos.toInt();
        } else if (lastPos is String) {
          pos = int.tryParse(lastPos) ?? 0;
        }
        double percent = 0;
        final rawPercent = progressRaw['progress_percent'];
        if (rawPercent is num) {
          percent = rawPercent.toDouble();
        } else if (rawPercent is String) {
          percent = double.tryParse(rawPercent) ?? 0;
        }
        if (mounted) {
          setState(() {
            _continueVideo = video;
            _continuePositionSec = pos;
            _continuePercent = percent;
          });
        }
      } else {
        if (mounted) setState(() => _continueVideo = null);
      }
    } catch (_) {
      if (mounted) setState(() => _continueVideo = null);
    } finally {
      if (mounted) setState(() => _continueLoading = false);
    }
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
    if (usedCache && mounted) setState(() => _usingOfflineCache = true);

    try {
      final resp = await _api.getWithRetry<Map<String, dynamic>>(
        '/chat/conversations',
        queryParameters: const {'page': 1, 'page_size': 8},
        fromJson: (data) => Map<String, dynamic>.from(data as Map),
        retries: 2,
        baseDelay: const Duration(milliseconds: 320),
      );
      final rawItems = resp.data['items'] as List<dynamic>? ?? [];
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
      final fallback =
          usedCache || await _applyChatCache(maxAge: const Duration(days: 3));
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
    setState(() => _hiddenConversationIds = ids);
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.35 : 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '学习中心',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '坚持学习，每天进步一点点',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/pointsDetail'),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    color: Colors.amber,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_balance',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '积分',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildContinueCard() {
    if (_continueLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: AppShimmerBlock(height: 88),
      );
    }
    final video = _continueVideo;
    if (video == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF171A21)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.play_circle_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '暂无学习记录',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '去首页挑选一门课程开始学习吧',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '去发现',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percentText = _continuePercent <= 0
        ? '未开始'
        : '${_continuePercent.toStringAsFixed(1)}%';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171A21) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: (_continuePercent / 100).clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: video.thumbUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: video.thumbUrl,
                            width: 90,
                            height: 54,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _thumbFallback(90, 54),
                          )
                        : _thumbFallback(90, 54),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.play_circle_filled,
                              size: 12,
                              color: primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '继续学习',
                              style: TextStyle(
                                fontSize: 11,
                                color: primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '已看 $percentText · ${_formatDuration(_continuePositionSec)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final id = int.tryParse(video.id);
                      if (id != null) {
                        Navigator.pushNamed(
                          context,
                          '/videoDetail',
                          arguments: id,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                      minimumSize: const Size(60, 34),
                    ),
                    child: const Text(
                      '继续',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.play_circle_outline_rounded,
        color: Colors.grey.shade400,
        size: 28,
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onMore}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (onMore != null)
            GestureDetector(
              onTap: onMore,
              child: Text(
                '查看全部',
                style: TextStyle(
                  fontSize: 12,
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
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
    if (item.id.isEmpty || _hiddenConversationIds.contains(item.id)) return;
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
      setState(() => _hiddenConversationIds = previous);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('会话已隐藏'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => _restoreConversation(item.id),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _restoreConversation(String conversationId) async {
    if (!_hiddenConversationIds.contains(conversationId)) return;
    setState(() {
      _hiddenConversationIds = Set<String>.from(_hiddenConversationIds)
        ..remove(conversationId);
    });
    await _storage.saveHiddenConversationIds(_hiddenConversationIds);
    await _loadChats();
  }

  Widget _buildChatCell(_ConversationItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => _openConversation(item),
      borderRadius: BorderRadius.circular(0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: item.avatarUrl.isNotEmpty
                      ? NetworkImage(item.avatarUrl)
                      : null,
                  child: item.avatarUrl.isEmpty
                      ? Icon(
                          item.isGroup
                              ? Icons.group_rounded
                              : Icons.person_rounded,
                          size: 22,
                          color: Colors.grey.shade500,
                        )
                      : null,
                ),
                if (item.isGroup)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF171A21)
                              : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.people_rounded,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
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
    return ClipRect(
      child: Dismissible(
        key: ValueKey('learn_chat_${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.redAccent,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hide_source_rounded, color: Colors.white, size: 20),
              SizedBox(height: 4),
              Text('隐藏', style: TextStyle(color: Colors.white, fontSize: 11)),
            ],
          ),
        ),
        onDismissed: (_) => _hideConversation(item),
        child: _buildChatCell(item),
      ),
    );
  }

  Widget _buildChatSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    Widget chatContent;
    if (_loadingChats && _chatItems.isEmpty) {
      chatContent = const Padding(
        padding: EdgeInsets.all(16),
        child: AppListSkeleton(
          itemCount: 3,
          itemHeight: 66,
          padding: EdgeInsets.zero,
        ),
      );
    } else if (_errorChats) {
      chatContent = Padding(
        padding: const EdgeInsets.all(16),
        child: AppEmptyState(
          icon: Icons.chat_bubble_outline,
          title: '聊天列表加载失败',
          subtitle: '请检查网络后重试',
          actionText: '重试',
          onAction: _loadChats,
          margin: EdgeInsets.zero,
        ),
      );
    } else if (_chatItems.isEmpty) {
      chatContent = const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: AppEmptyState(
          icon: Icons.forum_outlined,
          title: '暂无会话',
          subtitle: '发起私信或加入群聊后会显示在这里',
          margin: EdgeInsets.zero,
        ),
      );
    } else {
      chatContent = Column(
        children: List.generate(_chatItems.length, (i) {
          return Column(
            children: [
              _buildChatItem(_chatItems[i]),
              if (i < _chatItems.length - 1)
                Divider(
                  height: 1,
                  indent: 60,
                  endIndent: 16,
                  color: isDark ? Colors.white12 : Colors.grey.shade100,
                ),
            ],
          );
        }),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171A21) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 2),
            child: Row(
              children: [
                const Text(
                  '消息',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (_chatUnreadTotal > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _chatUnreadTotal > 99 ? '99+' : '$_chatUnreadTotal',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/chat');
                    await _loadChats();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '全部会话',
                    style: TextStyle(fontSize: 12, color: primary),
                  ),
                ),
              ],
            ),
          ),
          chatContent,
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: AppEmptyState(
        icon: Icons.lock_outline,
        title: '登录后查看学习数据',
        subtitle: '可查看积分、学习进度和消息会话',
        actionText: '去登录',
        onAction: () async {
          await Navigator.pushNamed(context, '/login');
          await _loadData();
        },
        margin: const EdgeInsets.fromLTRB(16, 60, 16, 0),
      ),
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
    if (!_loggedIn) return _buildLoginPrompt();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildHeader(),
          if (_weakNetwork || _usingOfflineCache)
            AppWeakNetworkBanner(
              text: _networkHint.isNotEmpty
                  ? _networkHint
                  : (_usingOfflineCache ? '已展示离线缓存内容' : '当前网络较弱'),
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            ),
          _buildSectionHeader('最近学习'),
          _buildContinueCard(),
          _buildSectionHeader(
            '消息聊天',
            onMore: () async {
              await Navigator.pushNamed(context, '/chat');
              await _loadChats();
            },
          ),
          _buildChatSection(),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ── Data model ────────────────────────────────────────────────────────────────

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'preview': preview,
    'time': time,
    'unread': unread,
    'avatar_url': avatarUrl,
    'is_group': isGroup ? 1 : 0,
  };

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
