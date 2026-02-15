import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/widget/AppStateWidgets.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  bool _loggedIn = true;
  bool _loadingSystem = true;
  bool _errorSystem = false;
  bool _weakNetwork = false;
  bool _usingOfflineCache = false;
  String _networkHint = '';
  int _userId = 0;
  int _unreadCount = 0;
  List<_MessageItem> _systemItems = [];

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    final token = await _storageService.getUserToken();
    final loggedIn =
        token != null && token.toString().isNotEmpty && token != 'null';
    final userId = await _storageService.getUserId();
    if (!mounted) return;
    setState(() {
      _loggedIn = loggedIn;
      _userId = userId ?? 0;
    });
    if (loggedIn) {
      await _loadAll(reset: true);
    }
  }

  String _systemCacheKey() => 'message_system_v1_$_userId';
  String _unreadCacheKey() => 'message_unread_v1_$_userId';

  Future<bool> _applySystemCache({Duration? maxAge}) async {
    final payload = await _storageService.getOfflinePayload(
      _systemCacheKey(),
      maxAge: maxAge,
    );
    if (payload == null) return false;
    final raw = payload['items'];
    if (raw is! List) return false;
    final items = <_MessageItem>[];
    for (final item in raw) {
      if (item is Map) {
        items.add(_MessageItem.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    if (items.isEmpty) return false;
    if (!mounted) return true;
    setState(() {
      _systemItems = items;
      _loadingSystem = false;
    });
    return true;
  }

  Future<void> _saveSystemCache(List<_MessageItem> items) async {
    await _storageService.saveOfflinePayload(_systemCacheKey(), {
      'items': items.map((e) => e.toJson()).toList(),
    });
  }

  Future<bool> _applyUnreadCache({Duration? maxAge}) async {
    final payload = await _storageService.getOfflinePayload(
      _unreadCacheKey(),
      maxAge: maxAge,
    );
    if (payload == null) return false;
    final raw = payload['unread_count'];
    int count = 0;
    if (raw is num) {
      count = raw.toInt();
    } else {
      count = int.tryParse(raw?.toString() ?? '') ?? 0;
    }
    if (!mounted) return true;
    setState(() {
      _unreadCount = count;
    });
    return true;
  }

  Future<void> _saveUnreadCache(int count) async {
    await _storageService.saveOfflinePayload(_unreadCacheKey(), {
      'unread_count': count,
    });
  }

  Future<void> _loadAll({bool reset = false}) async {
    if (reset && mounted) {
      setState(() {
        _weakNetwork = false;
        _usingOfflineCache = false;
        _networkHint = '';
      });
    }
    await Future.wait([_loadUnread(), _loadMessages(type: 'system')]);
  }

  Future<void> _loadUnread() async {
    try {
      final response = await _apiService.getWithRetry<Map<String, dynamic>>(
        '/messages/unread_count',
        fromJson: (raw) => raw as Map<String, dynamic>,
        retries: 2,
        baseDelay: const Duration(milliseconds: 300),
      );
      final data = response.data;
      final count = data['unread_count'];
      final unread = count is num ? count.toInt() : 0;
      if (mounted) {
        setState(() {
          _unreadCount = unread;
        });
      }
      await _saveUnreadCache(unread);
    } catch (_) {
      final loaded = await _applyUnreadCache(maxAge: const Duration(days: 1));
      if (mounted && loaded) {
        setState(() {
          _weakNetwork = true;
          _usingOfflineCache = true;
          _networkHint = '网络较弱，未读数来自离线缓存';
        });
      }
    }
  }

  Future<void> _loadMessages({required String type}) async {
    bool usedCache = false;
    if (mounted) {
      setState(() {
        if (type == 'system') {
          _loadingSystem = true;
          _errorSystem = false;
        }
      });
    }
    if (type == 'system') {
      usedCache = await _applySystemCache(maxAge: const Duration(hours: 6));
      if (usedCache && mounted) {
        setState(() {
          _usingOfflineCache = true;
        });
      }
    }

    try {
      final response = await _apiService.getWithRetry<Map<String, dynamic>>(
        '/messages',
        queryParameters: {'type': type, 'page': 1, 'page_size': 20},
        fromJson: (raw) => raw as Map<String, dynamic>,
        retries: 2,
        baseDelay: const Duration(milliseconds: 320),
      );
      final raw = response.data['items'];
      final items = <_MessageItem>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            items.add(_MessageItem.fromJson(item));
          }
        }
      }
      if (mounted) {
        setState(() {
          if (type == 'system') {
            _systemItems = items;
            _loadingSystem = false;
            _weakNetwork = false;
            _usingOfflineCache = false;
            _networkHint = '';
          }
        });
      }
      if (type == 'system') {
        await _saveSystemCache(items);
      }
    } catch (_) {
      if (type == 'system') {
        final fallback = usedCache
            ? true
            : await _applySystemCache(maxAge: const Duration(days: 3));
        if (mounted) {
          setState(() {
            _loadingSystem = false;
            _errorSystem = !fallback;
            _weakNetwork = true;
            _usingOfflineCache = fallback;
            _networkHint = fallback ? '网络较弱，已展示离线缓存消息' : '消息加载失败，请下拉重试';
          });
        }
      }
    }
  }

  Future<void> _markReadAll() async {
    try {
      await _apiService.post<Map<String, dynamic>>(
        '/messages/read',
        data: {'all': true},
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      if (mounted) {
        setState(() {
          _unreadCount = 0;
          for (final item in _systemItems) {
            item.isRead = true;
          }
        });
      }
      await _saveUnreadCache(0);
    } catch (_) {}
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildSystemNotice() {
    if (_loadingSystem && _systemItems.isEmpty) {
      return const AppListSkeleton(
        itemCount: 4,
        itemHeight: 72,
        padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
      );
    }
    if (_errorSystem) {
      return AppEmptyState(
        icon: Icons.notifications_off_outlined,
        title: '系统消息加载失败',
        subtitle: '请检查网络后下拉重试',
        actionText: '立即重试',
        onAction: () => _loadMessages(type: 'system'),
      );
    }
    if (_systemItems.isEmpty) {
      return const AppEmptyState(
        icon: Icons.notifications_none_outlined,
        title: '暂无系统通知',
        subtitle: '后续公告会显示在这里',
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x11000000)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _systemItems.length; i++)
            TDCell(
              title: _systemItems[i].title,
              description: _systemItems[i].content,
              note: _systemItems[i].displayTime,
              leftIcon: TDIcons.sound,
              arrow: false,
              showBottomBorder: i != _systemItems.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildLoginState() {
    return AppEmptyState(
      icon: Icons.lock_outline,
      title: '请先登录',
      subtitle: '登录后可查看系统通知',
      actionText: '去登录',
      onAction: () async {
        await Navigator.pushNamed(context, '/login');
        await _initPage();
      },
      margin: const EdgeInsets.fromLTRB(16, 40, 16, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loggedIn ? _markReadAll : null,
            icon: badges.Badge(
              showBadge: _unreadCount > 0,
              badgeContent: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              child: const Icon(TDIcons.notification),
            ),
          ),
        ],
      ),
      body: !_loggedIn
          ? _buildLoginState()
          : RefreshIndicator(
              onRefresh: () => _loadAll(reset: true),
              child: ListView(
                children: [
                  const SizedBox(height: 8),
                  if (_weakNetwork || _usingOfflineCache)
                    AppWeakNetworkBanner(
                      text: _networkHint.isNotEmpty
                          ? _networkHint
                          : (_usingOfflineCache ? '已展示离线缓存内容' : '当前网络较弱'),
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    ),
                  _buildSectionTitle('系统通知'),
                  _buildSystemNotice(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

class _MessageItem {
  final String id;
  final String type;
  final String title;
  final String content;
  final String createdAt;
  bool isRead;

  _MessageItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.isRead,
  });

  factory _MessageItem.fromJson(Map<String, dynamic> json) {
    return _MessageItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      isRead: json['is_read'] == true || json['is_read'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'content': content,
      'created_at': createdAt,
      'is_read': isRead ? 1 : 0,
    };
  }

  String get displayTime {
    if (createdAt.isEmpty) return '';
    return createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt;
  }
}
