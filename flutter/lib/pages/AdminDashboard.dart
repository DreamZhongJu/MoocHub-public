import 'package:flutter/material.dart';
import 'package:flutter_jdshop/config/Config.dart';
import 'package:flutter_jdshop/services/ApiService.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool _loadingUsers = false;
  bool _loadingProducts = false;
  int _userPage = 1;
  int _userTotalPages = 1;
  int _productPage = 1;
  int _productTotalPages = 1;
  final int _pageSize = 20;
  final List<Map<String, dynamic>> _users = [];
  final List<Map<String, dynamic>> _products = [];
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabIndex != _tabController.index) {
        setState(() {
          _tabIndex = _tabController.index;
        });
      }
    });
    _loadUsers(refresh: true);
    _loadProducts(refresh: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (_loadingUsers) return;
    setState(() {
      _loadingUsers = true;
    });
    if (refresh) {
      _userPage = 1;
      _users.clear();
    }
    try {
      final response = await _apiService.getRaw(
        '/admin/users',
        queryParameters: {'page': _userPage, 'pageSize': _pageSize},
      );
      final body = response.data;
      final data = body['data'] as Map<String, dynamic>;
      final list = List<Map<String, dynamic>>.from(data['users'] as List);
      final totalPages = data['totalPages'] as num?;
      setState(() {
        _users.addAll(list);
        _userTotalPages = totalPages?.toInt() ?? 1;
        _loadingUsers = false;
      });
    } catch (_) {
      setState(() {
        _loadingUsers = false;
      });
    }
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (_loadingProducts) return;
    setState(() {
      _loadingProducts = true;
    });
    if (refresh) {
      _productPage = 1;
      _products.clear();
    }
    try {
      final response = await _apiService.getRaw(
        '/admin/products',
        queryParameters: {'page': _productPage, 'pageSize': _pageSize},
      );
      final body = response.data as Map<String, dynamic>;
      final payload = body['data'];
      Map<String, dynamic>? data;
      if (payload is Map<String, dynamic> && payload['data'] is List) {
        data = payload;
      } else if (payload is List) {
        data = {'data': payload, 'pagination': {}};
      }
      final list = List<Map<String, dynamic>>.from(
        (data?['data'] as List? ?? const <dynamic>[]),
      );
      final pagination = Map<String, dynamic>.from(
        data?['pagination'] as Map? ?? const {},
      );
      final totalPages = pagination['totalPages'] as num?;
      setState(() {
        _products.addAll(list);
        _productTotalPages = totalPages?.toInt() ?? 1;
        _loadingProducts = false;
      });
    } catch (_) {
      setState(() {
        _loadingProducts = false;
      });
    }
  }

  Future<void> _updateUserRole(int userId, String role) async {
    try {
      await _apiService.putRaw(
        '/admin/users/$userId',
        data: {'role': role},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('角色已更新')),
      );
      _loadUsers(refresh: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新失败')),
      );
    }
  }

  Future<void> _deleteUser(int userId) async {
    try {
      await _apiService.deleteRaw('/admin/users/$userId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户已删除')),
      );
      _loadUsers(refresh: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除失败')),
      );
    }
  }

  Future<void> _saveProduct({
    Map<String, dynamic>? existing,
  }) async {
    final nameController =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final priceController =
        TextEditingController(text: existing?['price']?.toString() ?? '');
    final stockController =
        TextEditingController(text: existing?['stock']?.toString() ?? '');
    final categoryController =
        TextEditingController(text: existing?['category']?.toString() ?? '');
    final imageController =
        TextEditingController(text: existing?['image_url']?.toString() ?? '');
    final descController =
        TextEditingController(text: existing?['description']?.toString() ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? '新建商品' : '编辑商品'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '商品名称'),
                ),
                TextField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '价格'),
                ),
                TextField(
                  controller: stockController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  decoration: const InputDecoration(labelText: '库存'),
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: '分类'),
                ),
                TextField(
                  controller: imageController,
                  decoration: const InputDecoration(labelText: '图片URL'),
                ),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '描述'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final payload = {
      'name': nameController.text.trim(),
      'price': double.tryParse(priceController.text.trim()) ?? 0,
      'stock': int.tryParse(stockController.text.trim()) ?? 0,
      'category': categoryController.text.trim(),
      'image_url': imageController.text.trim(),
      'description': descController.text.trim(),
    };
    if (existing != null && existing['created_at'] != null) {
      payload['created_at'] = existing['created_at'];
    }

    try {
      if (existing == null) {
        await _apiService.postRaw('/admin/products', data: payload);
      } else {
        final id = existing['id'] as num?;
        if (id != null) {
          await _apiService.putRaw('/admin/products/${id.toInt()}',
              data: payload);
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
      _loadProducts(refresh: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败')),
      );
    }
  }

  Future<void> _deleteProduct(int productId) async {
    try {
      await _apiService.deleteRaw('/admin/products/$productId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品已删除')),
      );
      _loadProducts(refresh: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除失败')),
      );
    }
  }

  Widget _buildUserList() {
    if (_loadingUsers && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_users.isEmpty) {
      return const Center(child: Text('暂无用户'));
    }
    return RefreshIndicator(
      onRefresh: () => _loadUsers(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length + 1,
        itemBuilder: (context, index) {
          if (index == _users.length) {
            if (_userPage >= _userTotalPages) {
              return const SizedBox(height: 16);
            }
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                onPressed: () {
                  _userPage += 1;
                  _loadUsers();
                },
                child: _loadingUsers
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('加载更多'),
              ),
            );
          }
          final user = _users[index];
          final userId =
              (user['user_id'] ?? user['UserID'] ?? user['id']) as num?;
          final username =
              (user['username'] ?? user['Username'] ?? '-')?.toString() ?? '-';
          final role = (user['role'] ?? user['Role'] ?? 'common').toString();
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    username.isNotEmpty ? username.substring(0, 1) : 'U',
                    style: TextStyle(color: Colors.blue.shade600),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${userId?.toInt() ?? '-'} · $role',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'admin' || value == 'common') {
                      if (userId != null) {
                        _updateUserRole(userId.toInt(), value);
                      }
                    }
                    if (value == 'delete' && userId != null) {
                      _confirmDeleteUser(userId.toInt());
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'admin',
                      child: Text('设为管理员'),
                    ),
                    const PopupMenuItem(
                      value: 'common',
                      child: Text('设为普通用户'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('删除用户'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteUser(int userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除用户'),
          content: const Text('确定要删除该用户吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      _deleteUser(userId);
    }
  }

  Widget _buildProductList() {
    if (_loadingProducts && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products.isEmpty) {
      return const Center(child: Text('暂无商品'));
    }
    return RefreshIndicator(
      onRefresh: () => _loadProducts(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length + 1,
        itemBuilder: (context, index) {
          if (index == _products.length) {
            if (_productPage >= _productTotalPages) {
              return const SizedBox(height: 16);
            }
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                onPressed: () {
                  _productPage += 1;
                  _loadProducts();
                },
                child: _loadingProducts
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('加载更多'),
              ),
            );
          }
          final product = _products[index];
          final id = (product['id'] as num?)?.toInt() ?? 0;
          final name = product['name']?.toString() ?? '-';
          final category = product['category']?.toString() ?? '-';
          final price = product['price']?.toString() ?? '0';
          final stock = product['stock']?.toString() ?? '0';
          final imageUrl = Config.resolveImage(product['image_url']?.toString());
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl.isEmpty
                      ? Image.asset(
                          Config.defaultProductAsset,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              Config.defaultProductAsset,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '分类：$category',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '￥$price · 库存 $stock',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _saveProduct(existing: product);
                    }
                    if (value == 'delete') {
                      _confirmDeleteProduct(id);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('编辑'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('删除'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteProduct(int productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除商品'),
          content: const Text('确定要删除该商品吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      _deleteProduct(productId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理后台'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '用户管理'),
            Tab(text: '商品管理'),
          ],
        ),
      ),
      floatingActionButton: _tabIndex == 1
          ? FloatingActionButton(
              onPressed: () => _saveProduct(),
              child: const Icon(Icons.add),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(),
          _buildProductList(),
        ],
      ),
    );
  }
}
