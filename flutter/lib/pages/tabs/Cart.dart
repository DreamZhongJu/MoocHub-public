import 'package:flutter/material.dart';
import 'package:flutter_jdshop/model/ProductModel.dart';
import 'package:flutter_jdshop/config/Config.dart';
import 'package:flutter_jdshop/services/ApiService.dart';
import 'package:flutter_jdshop/services/StorageService.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  CartPageState createState() => CartPageState();
}

class _CartItemView {
  final int productId;
  int quantity;
  ProductModel? product;

  _CartItemView({
    required this.productId,
    required this.quantity,
    this.product,
  });
}

class CartPageState extends State<CartPage> with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final Map<int, ProductModel> _productCache = {};

  List<_CartItemView> _items = [];
  bool _isLoading = false;
  bool _isGuest = false;
  int? _userId;
  bool _checkingLogin = false;

  @override
  void initState() {
    super.initState();
    _loadCart(force: true);
  }

  Future<void> refresh() async {
    await _loadCart(force: true);
  }

  Future<void> _loadCart({bool force = false}) async {
    setState(() {
      _isLoading = true;
      _isGuest = false;
    });

    try {
      if (!force) {
        try {
          final cached = await _storageService.getCartItems();
          if (cached.isNotEmpty) {
            final parsed = cached
                .map((e) => e as Map<String, dynamic>)
                .map((item) => _CartItemView(
                      productId: (item['product_id'] as num?)?.toInt() ?? 0,
                      quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                    ))
                .toList();
            if (mounted) {
              setState(() {
                _items = parsed;
              });
            }
            await _loadProductDetails(parsed);
          }
        } catch (_) {
          await _storageService.saveCartItems([]);
        }
      }

    final token = await _storageService.getUserToken();
    _userId = await _storageService.getUserId();

      if (token == null || _userId == null) {
        if (mounted) {
          setState(() {
            _isGuest = true;
          });
        }
        return;
      }

      try {
        final response = await _apiService.get<List<dynamic>>(
          '/cart/list/$_userId',
          fromJson: (raw) => raw as List,
        );

        if (response.code != 0) {
          throw Exception(response.msg);
        }

        await _storageService.saveCartItems(response.data);
        final parsed = response.data
            .map((e) => e as Map<String, dynamic>)
            .map((item) => _CartItemView(
                  productId: (item['product_id'] as num?)?.toInt() ?? 0,
                  quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                ))
            .toList();

        if (mounted) {
          setState(() {
            _items = parsed;
          });
        }
        await _loadProductDetails(parsed);
      } catch (_) {
        if (mounted) {
          setState(() {
            _isGuest = false;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkLoginAndReload() async {
    if (_checkingLogin) return;
    _checkingLogin = true;
    final token = await _storageService.getUserToken();
    final userId = await _storageService.getUserId();
    if (token != null && userId != null) {
      _userId = userId;
      await _loadCart(force: true);
    }
    _checkingLogin = false;
  }

  Future<void> _loadProductDetails(List<_CartItemView> items) async {
    final ids = items.map((e) => e.productId).toSet();
    final missing = ids.where((id) => !_productCache.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      final results = await Future.wait(
        missing.map(
          (id) async {
            try {
              return await _apiService.get<ProductModel>(
                '/search/detail/$id',
                fromJson: (raw) => ProductModel.fromJson(raw),
              );
            } catch (_) {
              return null;
            }
          },
        ),
      );

      for (final result in results) {
        if (result != null && result.code == 0 && result.data.id != null) {
          _productCache[result.data.id!] = result.data;
        }
      }
    }

    if (mounted) {
      setState(() {
        _items = items
            .map((item) => _CartItemView(
                  productId: item.productId,
                  quantity: item.quantity,
                  product: _productCache[item.productId],
                ))
            .toList();
      });
    }
  }

  Future<void> _updateQuantity(_CartItemView item, int newQuantity) async {
    if (newQuantity < 1) return;
    setState(() {
      item.quantity = newQuantity;
    });
    await _storageService.saveCartItems(_items.map((e) {
      return {
        'product_id': e.productId,
        'quantity': e.quantity,
      };
    }).toList());

    if (_userId != null) {
      try {
        final token = await _storageService.getUserToken();
        await _apiService.putForm(
          '/cart/update',
          data: {
            'uid': _userId.toString(),
            'pid': item.productId.toString(),
            'quantity': newQuantity.toString(),
          },
          headers: token != null ? {'Authorization': token.toString()} : null,
        );
      } catch (_) {}
    }
  }

  Future<void> _removeItem(_CartItemView item) async {
    setState(() {
      _items.removeWhere((e) => e.productId == item.productId);
    });
    await _storageService.saveCartItems(_items.map((e) {
      return {
        'product_id': e.productId,
        'quantity': e.quantity,
      };
    }).toList());

    if (_userId != null) {
      try {
        final token = await _storageService.getUserToken();
        await _apiService.postForm(
          '/cart/delete',
          data: {
            'uid': _userId.toString(),
            'pid': item.productId.toString(),
          },
          headers: token != null ? {'Authorization': token.toString()} : null,
        );
      } catch (_) {}
    }
  }

  double get _totalPrice {
    double total = 0;
    for (final item in _items) {
      final price = item.product?.price ?? 0;
      total += price * item.quantity;
    }
    return total;
  }

  Widget _emptyState(String title, String subtitle,
      {VoidCallback? onAction, String? actionText}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAction ?? _loadCart,
            child: Text(actionText ?? '刷新购物车'),
          ),
        ],
      ),
    );
  }

  Widget _quantityControls(_CartItemView item) {
    return Row(
      children: [
        IconButton(
          onPressed: () => _updateQuantity(item, item.quantity - 1),
          icon: const Icon(Icons.remove),
          splashRadius: 18,
        ),
        Text(
          item.quantity.toString(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: () => _updateQuantity(item, item.quantity + 1),
          icon: const Icon(Icons.add),
          splashRadius: 18,
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '共 ${_items.length} 件商品',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '合计：￥${_totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isGuest) {
      return _emptyState(
        '请先登录',
        '登录后同步云端购物车',
        actionText: '去登录',
        onAction: () async {
          final result = await Navigator.pushNamed(context, '/login');
          if (result == true) {
            _loadCart(force: true);
          }
        },
      );
    }

    if (_items.isEmpty) {
      return _emptyState('购物车为空', '挑选喜欢的商品加入购物车');
    }

    return RefreshIndicator(
      onRefresh: () => _loadCart(force: true),
      child: Column(
        children: [
          _buildSummary(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  '购物车清单',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  '左滑删除',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _items[index];
                final product = item.product;
                return Dismissible(
                  key: ValueKey(item.productId),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _removeItem(item),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: Image.network(
                              Config.resolveImage(product?.imageUrl) == ''
                                  ? 'https://picsum.photos/seed/cart${item.productId}/200'
                                  : Config.resolveImage(product?.imageUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  Config.defaultProductAsset,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: product?.id == null
                                ? null
                                : () {
                                    Navigator.pushNamed(
                                      context,
                                      '/productDetail',
                                      arguments: {'productId': product!.id},
                                    );
                                  },
                            child: Text(
                              product?.name ?? '商品加载中',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                              const SizedBox(height: 6),
                              Text(
                                '库存：${product?.stock ?? 0}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _quantityControls(item),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '￥${(product?.price ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '小计：￥${((product?.price ?? 0) * item.quantity).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '合计：￥${_totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('结算'),
                ),
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
