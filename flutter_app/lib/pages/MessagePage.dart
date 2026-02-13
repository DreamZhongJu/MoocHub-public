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
  bool _loadingDM = true;
  bool _errorSystem = false;
  bool _errorDM = false;
  int _unreadCount = 0;
  List<_MessageItem> _systemItems = [];
  List<_MessageItem> _dmItems = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadUnread(),
      _loadMessages(type: 'system'),
      _loadMessages(type: 'dm'),
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
        } else {
          _loadingDM = true;
          _errorDM = false;
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
          } else {
            _dmItems = items;
            _loadingDM = false;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (type == 'system') {
            _errorSystem = true;
            _loadingSystem = false;
          } else {
            _errorDM = true;
            _loadingDM = false;
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
          for (final item in _dmItems) {
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

  Widget _buildChatItem(_ConversationItem item, {bool showBottom = true}) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/chatDetail',
          arguments: {
            'title': item.title,
            'conversationId': item.id,
            'isGroup': item.isGroup,
          },
        );
      },
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
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
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

  List<_ConversationItem> _buildConversationItems() {
    final List<_ConversationItem> items = [
      const _ConversationItem(
        id: 'group-frontend',
        title: 'MoocHub 前端组',
        preview: 'UI 我今晚改完。',
        time: '20:12',
        unread: 5,
        avatarUrl: 'https://picsum.photos/seed/moochub_group1/80',
        isGroup: true,
      ),
      const _ConversationItem(
        id: 'group-design',
        title: '毕业设计讨论群',
        preview: '下周五答辩流程已整理。',
        time: '18:40',
        unread: 0,
        avatarUrl: 'https://picsum.photos/seed/moochub_group2/80',
        isGroup: true,
      ),
    ];

    for (final item in _dmItems) {
      items.add(
        _ConversationItem(
          id: item.id,
          title: item.title,
          preview: item.content,
          time: item.displayTime,
          unread: item.isRead ? 0 : 1,
          avatarUrl: 'https://picsum.photos/seed/${item.id}/80',
          isGroup: false,
        ),
      );
    }
    return items;
  }

  Widget _buildConversationList() {
    if (_loadingDM) {
      return _buildCard(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
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
    if (_errorDM) {
      return _buildCard(
        children: const [
          TDCell(
            title: '\u4f1a\u8bdd\u5217\u8868',
            description: '\u52a0\u8f7d\u5931\u8d25\uff0c\u70b9\u51fb\u91cd\u8bd5',
            leftIcon: TDIcons.error_circle,
            arrow: false,
            showBottomBorder: false,
          ),
        ],
      );
    }

    final items = _buildConversationItems();
    if (items.isEmpty) {
      return _buildCard(
        children: const [
          TDCell(
            title: '\u4f1a\u8bdd\u5217\u8868',
            description: '\u6682\u65e0\u6d88\u606f',
            leftIcon: TDIcons.user_circle,
            arrow: false,
            showBottomBorder: false,
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _buildChatItem(items[i]),
            if (i != items.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
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
              const SizedBox(height: 12),
              _buildSectionTitle('\u4f1a\u8bdd\u5217\u8868'),
              _buildConversationList(),
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
}
