import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:flutter/material.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage>
    with AutomaticKeepAliveClientMixin<UserPage>, WidgetsBindingObserver {
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();
  final PageController _featureController = PageController();
  int _featurePage = 0;
  Map<String, dynamic> _userData = {};
  String _userRole = '';
  bool _loading = true;
  int _balance = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _featureController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadUser();
  }

  Future<void> _loadUser() async {
    final userData = await _storageService.getUserData();
    final role = await _storageService.getUserRole();
    if (mounted) {
      setState(() {
        _userData = userData;
        _userRole = role ?? '';
        _loading = false;
      });
    }
    // Load points if logged in
    final token = _userData['token'] ?? _userData['Token'];
    final loggedIn =
        token != null && token.toString().isNotEmpty && token != 'null';
    if (loggedIn) {
      try {
        final resp = await _apiService.getWithRetry<Map<String, dynamic>>(
          '/points/balance',
          fromJson: (data) => Map<String, dynamic>.from(data as Map),
          retries: 2,
          baseDelay: const Duration(milliseconds: 300),
        );
        final balance = (resp.data['points_balance'] as num?)?.toInt() ?? 0;
        if (mounted) setState(() => _balance = balance);
      } catch (_) {}
    } else {
      if (mounted) setState(() => _balance = 0);
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

  String _currentRole() {
    if (_userRole.isNotEmpty) return _userRole;
    final dynamic rawUser = _userData['user'] ?? _userData['User'] ?? _userData;
    final user = rawUser is Map<String, dynamic>
        ? rawUser
        : <String, dynamic>{};
    return _pickString(user, ['role', 'Role'], 'student');
  }

  Widget _userCard() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        height: 100,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF171A21) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: primary),
        ),
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
    ], _isLoggedIn ? '无用户名' : '点击登录以探索更多');
    final role = _pickString(user, ['role', 'Role'], 'student');
    final avatarUrl = _pickString(user, [
      'avatar_url',
      'AvatarURL',
      'avatar',
    ], '');

    String roleLabel(String r) {
      switch (r.toLowerCase()) {
        case 'admin':
          return '管理员';
        case 'teacher':
          return '讲师';
        default:
          return '学员';
      }
    }

    return GestureDetector(
      onTap: _isLoggedIn ? null : () => Navigator.pushNamed(context, '/login'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A2535), const Color(0xFF171A21)]
                : [primary.withValues(alpha: 0.08), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primary.withValues(alpha: isDark ? 0.18 : 0.12),
          ),
        ),
        child: Row(
          children: [
            // 头像
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [primary, primary.withValues(alpha: 0.4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: isDark
                        ? const Color(0xFF0F1115)
                        : Colors.white,
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Icon(Icons.person_rounded, color: primary, size: 32)
                        : null,
                  ),
                ),
                if (_isLoggedIn)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // 昵称 + 用户名 + 角色徽章
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    username,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (_isLoggedIn)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            roleLabel(role),
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.stars_rounded,
                                size: 11,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$_balance',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '登录后查看完整功能 →',
                      style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'MoocHub © 2025  ·  版权所有',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
      ),
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
          canManageContent: () {
            final role = _currentRole().toLowerCase().trim();
            return role == 'admin' || role == 'teacher';
          }(),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isDark
                  ? color.withValues(alpha: 0.18)
                  : color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
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
        icon: Icons.favorite_rounded,
        label: '我的收藏',
        color: const Color(0xFFFF6B6B),
        onTap: _openFavorites,
      ),
      _FeatureItem(
        icon: Icons.history_rounded,
        label: '学习记录',
        color: const Color(0xFF4ECDC4),
        onTap: () => _openPlaceholder('学习记录'),
      ),
      _FeatureItem(
        icon: Icons.stars_rounded,
        label: '我的积分',
        color: const Color(0xFFFFB347),
        onTap: () => Navigator.pushNamed(context, '/pointsDetail'),
      ),
      _FeatureItem(
        icon: Icons.notifications_outlined,
        label: '通知设置',
        color: const Color(0xFF7C4DFF),
        onTap: () => Navigator.pushNamed(context, '/notificationSettings'),
      ),
      _FeatureItem(
        icon: Icons.settings_rounded,
        label: '设置',
        color: const Color(0xFF95A5A6),
        onTap: _openSettings,
      ),
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

    double _pageHeightForCount(int count) {
      final rows = (count / 4).ceil().clamp(1, 2);
      return rows * 78.0;
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF171A21) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        child: Column(
          children: [
            if (pages.length == 1)
              GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 6,
                crossAxisSpacing: 2,
                childAspectRatio: 1,
                children: pages.first
                    .map(
                      (item) => _buildFeatureItem(
                        icon: item.icon,
                        label: item.label,
                        onTap: item.onTap,
                        color: item.color,
                      ),
                    )
                    .toList(),
              )
            else
              SizedBox(
                height: _pageHeightForCount(perPage),
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
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 2,
                      childAspectRatio: 1,
                      children: pageItems
                          .map(
                            (item) => _buildFeatureItem(
                              icon: item.icon,
                              label: item.label,
                              onTap: item.onTap,
                              color: item.color,
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
                color: primary.withValues(alpha: isDark ? 0.12 : 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: _loadUser,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
    this.canManageContent = false,
  });

  final Future<void> Function() onSwitchAccount;
  final Widget Function(BuildContext context) footer;
  final bool canManageContent;

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
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.notifications_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('通知设置'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pushNamed(context, '/notificationSettings');
                    },
                  ),
                  if (canManageContent) const Divider(height: 1),
                  if (canManageContent)
                    ListTile(
                      leading: Icon(
                        Icons.admin_panel_settings,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('课程管理后台'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pushNamed(context, '/admin');
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
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
}
