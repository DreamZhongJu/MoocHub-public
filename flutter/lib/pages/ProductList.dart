import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jdshop/model/ProductModel.dart';
import 'package:flutter_jdshop/config/Config.dart';
import 'package:flutter_jdshop/services/ApiService.dart';
import 'package:flutter_jdshop/services/ScreenAdaper.dart';
import 'package:flutter_jdshop/widget/LoadingWidget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProductListPage extends StatefulWidget {
  final Map arguments;
  const ProductListPage({super.key, required this.arguments});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();

  int _page = 1;
  String _sort = 'default';
  bool _isLoading = false;
  bool _hasMore = true;
  List<ProductModel> _productList = [];

  @override
  void initState() {
    super.initState();
    _getProductListData(reset: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 20) {
        if (_hasMore && !_isLoading) {
          _getProductListData();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getProductListData({bool reset = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    if (reset) {
      _page = 1;
      _productList = [];
      _hasMore = true;
    }

    try {
      final cid = widget.arguments['cid'];
      final response = await _apiService.get<List<ProductModel>>(
        '/categories/level2/$cid/products',
        queryParameters: {
          'page': _page,
          'sort': _sort,
        },
        fromJson: (raw) => (raw as List)
            .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

      if (response.code != 0) {
        throw Exception(response.msg);
      }

      final newItems = response.data;
      setState(() {
        _productList.addAll(newItems);
        _page++;
        if (response.count != null) {
          _hasMore = _productList.length < response.count!;
        } else {
          _hasMore = newItems.isNotEmpty;
        }
      });
    } catch (_) {
      setState(() {
        _hasMore = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setSort(String value) {
    if (_sort == value) return;
    setState(() {
      _sort = value;
    });
    _getProductListData(reset: true);
  }

  Widget _sortItem(String label, String value) {
    final active = _sort == value;
    return Expanded(
      child: InkWell(
        onTap: () => _setSort(value),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 16.h, 0, 20.h),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.red : Colors.black87,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _subHeaderWidget() {
    return Positioned(
      top: 0,
      height: 80.h,
      width: 750.w,
      child: Container(
        height: 80.h,
        width: 750.w,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              width: 1,
              color: const Color.fromRGBO(233, 233, 233, 0.9),
            ),
          ),
        ),
        child: Row(
          children: [
            _sortItem('综合', 'default'),
            _sortItem('价格升序', 'price_asc'),
            _sortItem('价格降序', 'price_desc'),
            Expanded(
              child: InkWell(
                onTap: () {
                  _scaffoldkey.currentState?.openEndDrawer();
                },
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 16.h, 0, 20.h),
                  child: Text(
                    '筛选',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productListWidget() {
    if (_productList.isEmpty && _isLoading) {
      return const Loadingwidget();
    }

    if (_productList.isEmpty) {
      return const Center(
        child: Text('暂无商品'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      margin: EdgeInsets.only(top: 80.h),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _productList.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _productList.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Loadingwidget(),
            );
          }
          final item = _productList[index];
          return InkWell(
            onTap: item.id == null
                ? null
                : () {
                    Navigator.pushNamed(context, '/productDetail', arguments: {
                      'productId': item.id,
                    });
                  },
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 180.w,
                      height: 180.h,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: Config.resolveImage(item.imageUrl) == ''
                              ? 'https://picsum.photos/seed/p${item.id}/200'
                              : Config.resolveImage(item.imageUrl),
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Image.asset(
                            Config.defaultProductAsset,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 180.h,
                        margin: const EdgeInsets.only(left: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name ?? '未命名商品',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Text(
                                  '￥${item.price?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '库存：${item.stock ?? 0}',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenAdapter.init(
      child: Scaffold(
        key: _scaffoldkey,
        appBar: AppBar(title: const Text('商品列表'), actions: const [Text('')]),
        endDrawer: Drawer(
          child: Center(
            child: Text(
              '筛选功能开发中',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
        body: Stack(
          children: [_productListWidget(), _subHeaderWidget()],
        ),
      ),
    );
  }
}
