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
  final PageController _featureController = PageController();
  int _featurePage = 0;
  Map<String, dynamic> _userData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _featureController.dispose();
    super.dispose();
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

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F6F8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withOpacity(0.12),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: surface,
              backgroundImage: avatarUrl.isEmpty
                  ? null
                  : NetworkImage(avatarUrl),
              child: avatarUrl.isEmpty
                  ? Icon(Icons.person, color: primary)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  username,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_isLoggedIn)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          role,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
          ),
        ],
      ),
    );
  }

  Widget _entryItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconBg = isDark ? const Color(0xFF1F2430) : const Color(0xFFF3F6FB);
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
      ),
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

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          onSwitchAccount: () async {
            await Navigator.pushNamed(context, '/login');
            _loadUser();
          },
          footer: _buildLinksFooter,
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconBg = isDark ? const Color(0xFF1F2430) : const Color(0xFFF1F4F9);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 32),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePager() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final items = [
      _FeatureItem(
        icon: Icons.favorite_border,
        label: '收藏',
        onTap: _openFavorites,
      ),
      _FeatureItem(
        icon: Icons.history,
        label: '学习记录',
        onTap: () => _openPlaceholder('学习记录'),
      ),
      _FeatureItem(icon: Icons.settings, label: '设置', onTap: _openSettings),
    ];
    const int perPage = 8;
    final pages = <List<_FeatureItem>>[];
    for (var i = 0; i < items.length; i += perPage) {
      pages.add(
        items.sublist(
          i,
          i + perPage > items.length ? items.length : i + perPage,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF171A21) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              child: PageView.builder(
                controller: _featureController,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _featurePage = index;
                  });
                },
                itemBuilder: (context, pageIndex) {
                  final pageItems = pages[pageIndex];
                  return GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 2,
                    childAspectRatio: 1,
                    children: pageItems
                        .map(
                          (item) => _buildFeatureItem(
                            icon: item.icon,
                            label: item.label,
                            onTap: item.onTap,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
            if (pages.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _featurePage == index ? 14 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _featurePage == index
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F6F8);
    return Container(
      color: pageBg,
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: primary.withOpacity(isDark ? 0.12 : 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _userCard(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    '常用功能',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleSmall?.color,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildFeaturePager()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.onSwitchAccount,
    required this.footer,
  });

  final Future<void> Function() onSwitchAccount;
  final Widget Function(BuildContext context) footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F6F8);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Container(
        color: pageBg,
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isDark ? const Color(0xFF171A21) : Colors.white,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.swap_horiz,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('切换账号'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await onSwitchAccount();
                    },
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: footer(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
