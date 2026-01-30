import 'package:flutter/material.dart';
import 'package:flutter_jdshop/services/ApiService.dart';
import 'package:flutter_jdshop/services/StorageService.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  Map<String, dynamic> _userData = {};
  int _userCount = 0;
  int _cartCount = 0;
  bool _loading = false;
  String? _token;
  int? _userId;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
    });

    final data = await _storageService.getUserData();
    _token = await _storageService.getUserToken();
    _userId = _extractUserId(data);
    _userRole = await _storageService.getUserRole();
    final cartItems = await _storageService.getCartItems();
    _cartCount = cartItems.length;

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/user/count',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      if (response.code == 0) {
        _userCount = (response.data['count'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _userData = data;
        _loading = false;
      });
    }
  }

  bool get _isLoggedIn =>
      _userData.isNotEmpty || (_token != null && _token!.isNotEmpty);

  bool get _isAdmin => (_userRole ?? '').toLowerCase() == 'admin';

  String get _displayName {
    final user = _userData['user'];
    if (user is Map<String, dynamic>) {
      final username = user['username'] ?? user['Username'];
      if (username != null) {
        return username.toString();
      }
    }
    final topLevel = _userData['username'] ?? _userData['Username'];
    if (topLevel != null) {
      return topLevel.toString();
    }
    if (_isLoggedIn && _userId != null) {
      return '用户$_userId';
    }
    return '游客';
  }

  int? _extractUserId(Map<String, dynamic> userData) {
    final user = userData['user'];
    if (user is Map<String, dynamic>) {
      final raw = user['user_id'] ?? user['UserID'] ?? user['id'] ?? user['ID'];
      if (raw is num) {
        return raw.toInt();
      }
      if (raw is String) {
        return int.tryParse(raw);
      }
    }
    final raw =
        userData['user_id'] ?? userData['UserID'] ?? userData['id'] ?? userData['ID'];
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  String get _initial {
    final name = _displayName;
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';
  }

  Future<void> _logout() async {
    await _storageService.clearUserData();
    await _storageService.clearAllCache();
    if (mounted) {
      setState(() {
        _userData = {};
        _cartCount = 0;
        _token = null;
        _userId = null;
        _userRole = null;
      });
    }
  }

  void _showTodo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('功能开发中')),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _profileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.teal.shade300],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  _initial,
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLoggedIn ? '会员' : '游客模式',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              TextButton(
                onPressed: _isLoggedIn
                    ? _logout
                    : () async {
                        final result =
                            await Navigator.pushNamed(context, '/login');
                        if (result == true) {
                          _loadProfile();
                        }
                      },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
                child: Text(_isLoggedIn ? '退出登录' : '去登录'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('用户数', _userCount.toString()),
              _statItem('购物车', _cartCount.toString()),
              _statItem('订单', '0'),
            ],
          ),
          if (_userId != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '用户ID: $_userId',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueGrey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
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
    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        children: [
          _profileHeader(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              '我的服务',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          _menuItem(Icons.receipt_long, '我的订单', onTap: _showTodo),
          _menuItem(Icons.location_on_outlined, '收货地址', onTap: _showTodo),
          _menuItem(Icons.favorite_border, '收藏夹', onTap: _showTodo),
          _menuItem(Icons.support_agent, '客服与帮助', onTap: _showTodo),
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                '管理入口',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          if (_isAdmin)
            _menuItem(
              Icons.admin_panel_settings_outlined,
              '进入后台',
              onTap: () async {
                await Navigator.pushNamed(context, '/admin');
                _loadProfile();
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              '账号设置',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          _menuItem(Icons.settings_outlined, '设置', onTap: _showTodo),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
