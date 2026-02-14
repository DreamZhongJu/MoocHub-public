import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  bool _loading = true;
  bool _error = false;
  bool _loggedIn = true;

  String _keyword = '';
  List<_ChatItem> _items = [];
  Set<String> _hiddenConversationIds = <String>{};

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    await _loadHiddenConversationIds();
    await _loadConversations();
  }

  Future<void> _loadHiddenConversationIds() async {
    final ids = await _storage.getHiddenConversationIds();
    if (!mounted) return;
    setState(() {
      _hiddenConversationIds = ids;
    });
  }

  Future<void> _loadConversations() async {
    final token = await _storage.getUserToken();
    final loggedIn =
        token != null && token.toString().isNotEmpty && token != 'null';

    if (!loggedIn) {
      if (mounted) {
        setState(() {
          _loggedIn = false;
          _loading = false;
          _error = false;
          _items = [];
        });
      }
      return;
    }

    _hiddenConversationIds = await _storage.getHiddenConversationIds();

    if (mounted) {
      setState(() {
        _loggedIn = true;
        _loading = true;
        _error = false;
      });
    }

    try {
      final resp = await _api.get<Map<String, dynamic>>(
        '/chat/conversations',
        queryParameters: const {'page': 1, 'page_size': 100},
        fromJson: (raw) => Map<String, dynamic>.from(raw as Map),
      );

      final rawItems = resp.data['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .whereType<Map>()
          .map((e) => _ChatItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => !_hiddenConversationIds.contains(e.id.toString()))
          .toList();

      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  List<_ChatItem> _filterItems(bool group) {
    final source = _items.where((e) => e.isGroup == group).toList();
    final keyword = _keyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return source;
    }
    return source.where((e) {
      final title = e.title.toLowerCase();
      final last = e.lastMessage.toLowerCase();
      return title.contains(keyword) || last.contains(keyword);
    }).toList();
  }

  Future<void> _openChat(_ChatItem item) async {
    await Navigator.pushNamed(
      context,
      '/chatDetail',
      arguments: {
        'conversationId': item.id,
        'title': item.title,
        'isGroup': item.isGroup,
      },
    );
    await _loadConversations();
  }

  Future<void> _hideConversation(_ChatItem item) async {
    final id = item.id.toString();
    if (id.isEmpty || _hiddenConversationIds.contains(id)) {
      return;
    }

    final previous = Set<String>.from(_hiddenConversationIds);
    setState(() {
      _hiddenConversationIds = {..._hiddenConversationIds, id};
      _items = _items.where((e) => e.id != item.id).toList();
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
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
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
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      controller.close();
    });
  }

  Future<void> _restoreConversation(int conversationId) async {
    final id = conversationId.toString();
    if (!_hiddenConversationIds.contains(id)) {
      return;
    }
    setState(() {
      _hiddenConversationIds = Set<String>.from(_hiddenConversationIds)
        ..remove(id);
    });
    await _storage.saveHiddenConversationIds(_hiddenConversationIds);
    await _loadConversations();
  }

  Future<void> _showCreateGroupDialog() async {
    final result = await showDialog<_CreateGroupResult>(
      context: context,
      builder: (_) => _CreateGroupDialog(api: _api),
    );

    if (!mounted || result == null) {
      return;
    }

    await _loadConversations();
    if (!mounted) return;

    await Navigator.pushNamed(
      context,
      '/chatDetail',
      arguments: {
        'conversationId': result.id.toString(),
        'title': result.name,
        'isGroup': true,
      },
    );

    await _loadConversations();
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TDSearchBar(
        placeHolder: '搜索会话',
        onTextChanged: (value) {
          setState(() {
            _keyword = value;
          });
        },
        onSubmitted: (value) {
          setState(() {
            _keyword = value;
          });
        },
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Row(
          children: [
            TDSkeleton(
              animation: TDSkeletonAnimation.gradient,
              theme: TDSkeletonTheme.paragraph,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('会话列表加载失败'),
          const SizedBox(height: 8),
          TDButton(
            text: '重试',
            size: TDButtonSize.small,
            onTap: _loadConversations,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 46, color: Colors.grey),
          const SizedBox(height: 10),
          const Text('请先登录后使用聊天'),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              await Navigator.pushNamed(context, '/login');
              await _initPage();
            },
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatCell(_ChatItem item) {
    return InkWell(
      onTap: () => _openChat(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x11000000)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: TDImage(
                imgUrl: item.avatar,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.time,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                if (item.unread > 0)
                  Container(
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
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(_ChatItem item) {
    final screenWidth = MediaQuery.of(context).size.width;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: TDSwipeCell(
        slidableKey: ValueKey('chat_${item.id}'),
        groupTag: 'chat_list',
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

  Widget _buildChatList(List<_ChatItem> items) {
    if (_loading) {
      return _buildLoading();
    }
    if (_error) {
      return _buildError();
    }
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadConversations,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('暂无会话')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildChatItem(items[index]),
      ),
    );
  }

  Widget _buildGroupAction() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TDButton(
        text: '创建群聊',
        type: TDButtonType.outline,
        size: TDButtonSize.large,
        onTap: _showCreateGroupDialog,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('聊天'), centerTitle: true),
        body: _buildLoginPrompt(),
      );
    }

    final privateChats = _filterItems(false);
    final groupChats = _filterItems(true);

    return Scaffold(
      appBar: AppBar(title: const Text('聊天'), centerTitle: true),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            _buildSearch(),
            const SizedBox(height: 6),
            const TDTabBar(
              tabs: [
                TDTab(text: '私信'),
                TDTab(text: '群聊'),
              ],
              showIndicator: true,
            ),
            Expanded(
              child: TDTabBarView(
                children: [
                  _buildChatList(privateChats),
                  Column(
                    children: [
                      Expanded(child: _buildChatList(groupChats)),
                      _buildGroupAction(),
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
}

class _CreateGroupResult {
  final int id;
  final String name;

  const _CreateGroupResult({required this.id, required this.name});
}

class _CreateGroupDialog extends StatefulWidget {
  final ApiService api;

  const _CreateGroupDialog({required this.api});

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  String _groupName = '';
  String _memberIdsText = '';
  String _avatarUrl = '';

  bool _creating = false;

  List<int> _parseMemberIds(String raw) {
    final normalized = raw.replaceAll('，', ',');
    final parts = normalized
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    return parts
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .where((id) => id > 0)
        .toSet()
        .toList();
  }

  int _parseConversationId(Map<String, dynamic> data) {
    final raw = data['id'] ?? data['ID'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  Future<void> _submit() async {
    final name = _groupName.trim();
    final avatar = _avatarUrl.trim();
    final memberIds = _parseMemberIds(_memberIdsText);

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入群名称')));
      return;
    }

    setState(() {
      _creating = true;
    });

    try {
      final payload = <String, dynamic>{'name': name, 'member_ids': memberIds};
      if (avatar.isNotEmpty) {
        payload['avatar_url'] = avatar;
      }

      final resp = await widget.api.post<Map<String, dynamic>>(
        '/chat/groups',
        data: payload,
        fromJson: (raw) => Map<String, dynamic>.from(raw as Map),
      );

      final conversationId = _parseConversationId(resp.data);
      if (conversationId <= 0) {
        throw Exception('会话编号无效');
      }

      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(_CreateGroupResult(id: conversationId, name: name));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建群聊失败: $e')));
      setState(() {
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建群聊'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) => _groupName = value,
              decoration: const InputDecoration(
                labelText: '群名称',
                hintText: '例如：学习交流群',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              onChanged: (value) => _memberIdsText = value,
              decoration: const InputDecoration(
                labelText: '成员用户编号（可选）',
                hintText: '使用逗号分隔，例如：8,9,12',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              onChanged: (value) => _avatarUrl = value,
              decoration: const InputDecoration(labelText: '群头像地址（可选）'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _creating ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _creating ? null : _submit,
          child: _creating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('创建'),
        ),
      ],
    );
  }
}

class _ChatItem {
  final int id;
  final String title;
  final String lastMessage;
  final String time;
  final int unread;
  final String avatar;
  final bool isGroup;

  const _ChatItem({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.avatar,
    required this.isGroup,
  });

  factory _ChatItem.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final type = json['type']?.toString() ?? 'private';
    final rawTitle = json['name']?.toString().trim() ?? '';
    final rawMessage = json['last_message']?.toString().trim() ?? '';
    final rawAvatar = json['avatar_url']?.toString().trim() ?? '';
    final avatar = Config.resolveImage(rawAvatar);

    return _ChatItem(
      id: id,
      title: rawTitle.isEmpty ? (type == 'group' ? '群聊' : '私聊') : rawTitle,
      lastMessage: rawMessage.isEmpty ? '暂无消息' : rawMessage,
      time: _formatTime(json['last_message_at']?.toString() ?? ''),
      unread: (json['unread_count'] as num?)?.toInt() ?? 0,
      avatar: avatar.isEmpty
          ? 'https://picsum.photos/seed/chat_$id/80'
          : avatar,
      isGroup: type == 'group',
    );
  }

  static String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;

    final local = dt.toLocal();
    final now = DateTime.now();
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
