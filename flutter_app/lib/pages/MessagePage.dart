import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:badges/badges.dart' as badges;

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  bool _loadingSystem = true;
  bool _errorSystem = false;
  int _unreadCount = 0;
  List<_MessageItem> _systemItems = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadUnread(),
      _loadMessages(type: 'system'),
    ]);
  }

  Future<void> _loadUnread() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/messages/unread_count',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final data = response.data;
      final count = data['unread_count'];
      if (mounted) {
        setState(() {
          _unreadCount = count is num ? count.toInt() : 0;
        });
      }
    } catch (_) {
      // ignore unread error
    }
  }

  Future<void> _loadMessages({required String type}) async {
    if (mounted) {
        setState(() {
          if (type == 'system') {
            _loadingSystem = true;
            _errorSystem = false;
          }
        });
      }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/messages',
        queryParameters: {'type': type, 'page': 1, 'page_size': 20},
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final raw = response.data['items'];
      final List<_MessageItem> items = [];
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
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (type == 'system') {
            _errorSystem = true;
            _loadingSystem = false;
          }
        });
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
    } catch (_) {
      // ignore
    }
  }

  Future<void> _ensureLogin() async {
    final token = await _storageService.getUserToken();
    if (token == null || token.toString().isEmpty || token == 'null') {
      if (mounted) {
        await Navigator.pushNamed(context, '/login');
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x11000000)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSystemNotice() {
    if (_loadingSystem) {
      return _buildCard(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                TDSkeleton(
                  animation: TDSkeletonAnimation.gradient,
                  theme: TDSkeletonTheme.paragraph,
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_errorSystem) {
      return _buildCard(
        children: const [
          TDCell(
            title: '\u7cfb\u7edf\u901a\u77e5',
            description: '\u52a0\u8f7d\u5931\u8d25\uff0c\u70b9\u51fb\u91cd\u8bd5',
            leftIcon: TDIcons.error_circle,
            arrow: false,
            showBottomBorder: false,
          ),
        ],
      );
    }
    if (_systemItems.isEmpty) {
      return _buildCard(
        children: const [
          TDCell(
            title: '\u7cfb\u7edf\u901a\u77e5',
            description: '\u6682\u65e0\u7cfb\u7edf\u901a\u77e5',
            leftIcon: TDIcons.sound,
            arrow: false,
            showBottomBorder: false,
          ),
        ],
      );
    }
    return _buildCard(
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
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('\u6d88\u606f'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _markReadAll,
            icon: badges.Badge(
              showBadge: _unreadCount > 0,
              badgeContent: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              child: const Icon(TDIcons.notification),
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: FutureBuilder(
        future: _ensureLogin(),
        builder: (context, snapshot) {
          return ListView(
            children: [
              const SizedBox(height: 8),
              _buildSectionTitle('\u7cfb\u7edf\u901a\u77e5'),
              _buildSystemNotice(),
              const SizedBox(height: 16),
            ],
          );
        },
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

  String get displayTime {
    if (createdAt.isEmpty) return '';
    return createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt;
  }
}
