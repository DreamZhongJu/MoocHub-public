import 'package:MoocHub/services/StorageService.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage>
    with AutomaticKeepAliveClientMixin<UserPage> {
  final StorageService _storageService = StorageService();
  Map<String, dynamic> _userData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final userData = await _storageService.getUserData();
    if (mounted) {
      setState(() {
        _userData = userData;
        _loading = false;
      });
    }
  }

  bool get _isLoggedIn {
    final token = _userData['token'] ?? _userData['Token'];
    return token != null && token.toString().isNotEmpty && token != 'null';
  }

  String _pickString(
    Map<String, dynamic> map,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = map[key];
      final text = value?.toString() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  Widget _userCard() {
    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final dynamic rawUser = _userData['user'] ?? _userData['User'] ?? _userData;
    final user = rawUser is Map<String, dynamic>
        ? rawUser
        : <String, dynamic>{};

    final nickname = _pickString(user, [
      'nickname',
      'Nickname',
      'nickName',
      'NickName',
    ], _isLoggedIn ? '未命名用户' : '未登录');
    final username = _pickString(user, [
      'username',
      'Username',
      'user_name',
      'UserName',
    ], _isLoggedIn ? '无用户名' : '点击下方登录');
    final role = _pickString(user, ['role', 'Role'], 'student');
    final avatarUrl = _pickString(user, [
      'avatar_url',
      'AvatarURL',
      'avatar',
    ], '');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.blueGrey.shade100,
              backgroundImage: avatarUrl.isEmpty
                  ? null
                  : NetworkImage(avatarUrl),
              child: avatarUrl.isEmpty
                  ? Icon(Icons.person, color: Colors.blueGrey.shade600)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    username,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  if (_isLoggedIn)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F7F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(role, style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login').then((_) => _loadUser());
              },
              child: Text(_isLoggedIn ? '切换账号' : '去登录'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryItem({required String title, required VoidCallback onTap}) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _openFavorites() async {
    if (_isLoggedIn) {
      Navigator.pushNamed(context, '/favorites');
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('需要登录后查看收藏')));
    }
    final result = await Navigator.pushNamed(context, '/login');
    await _loadUser();
    if (result == true && _isLoggedIn && mounted) {
      Navigator.pushNamed(context, '/favorites');
    }
  }

  void _openPlaceholder(String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const Center(child: Text('功能开发中')),
        ),
      ),
    );
  }

  Widget _buildLinksFooter(BuildContext context) {
    return TDFooter(
      TDFooterType.link,
      links: [
        TDLink(
          label: '底部链接1',
          style: TDLinkStyle.primary,
          uri: Uri.parse('https://example.com'),
          linkClick: (link) {
            print('点击了链接1 $link');
          },
        ),
        TDLink(
          label: '底部链接2',
          style: TDLinkStyle.primary,
          uri: Uri.parse('https://example.com'),
          linkClick: (link) {
            print('点击了链接2 $link');
          },
        ),
      ],
      text: 'Copyright © 2019-2023 TDesign.All Rights Reserved.',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      children: [
        _userCard(),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            '常用功能',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _entryItem(title: '我的收藏', onTap: _openFavorites),
              const Divider(height: 1),
              _entryItem(title: '学习记录', onTap: () => _openPlaceholder('学习记录')),
            ],
          ),
        ),
        _buildLinksFooter(context),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
