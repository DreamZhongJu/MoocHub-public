import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jdshop/model/FocusModel.dart';
import 'package:flutter_jdshop/model/ProductModel.dart';
import 'package:flutter_jdshop/config/Config.dart';
import 'package:flutter_jdshop/services/ApiService.dart';
import 'package:flutter_jdshop/services/StorageService.dart';
import 'package:flutter_jdshop/widget/ProductCard.dart';
import 'package:provider/provider.dart';
import 'package:flutter_jdshop/services/AppState.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  final RefreshController _refreshController = RefreshController();
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  List<FocusModel> _focusData = [];
  List<ProductModel> _featuredProducts = [];
  List<ProductModel> _recommendedProducts = [];
  bool _isLoading = true;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = false;
    });

    try {
      await Future.wait([
        _loadFocusData(),
        _loadFeaturedProducts(),
        _loadRecommendedProducts(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is Map<String, dynamic>) {
      final list = data['data'];
      if (list is List) {
        return list;
      }
      return [];
    }
    if (data is List) {
      return data;
    }
    return [];
  }

  List<FocusModel> _buildFocusFromProducts(List<dynamic> products) {
    return products.take(5).map((raw) {
      final map = raw as Map<String, dynamic>;
      final id = (map['id'] as num?)?.toInt() ?? 0;
      final title = map['name'] as String? ?? '精选商品';
      final image = map['image_url'] as String?;
      final fallback = 'https://picsum.photos/seed/focus$id/800/400';
      final url = (image != null && image.isNotEmpty)
          ? Config.resolveImage(image)
          : fallback;
      return FocusModel(
        id: id,
        title: title,
        url: url,
        thumbnailUrl: url,
      );
    }).toList();
  }

  Future<void> _loadFocusData() async {
    try {
      final shouldRefresh = await _storageService.shouldRefreshProducts();
      if (!shouldRefresh) {
        final cachedData = await _storageService.getProducts();
        if (cachedData.isNotEmpty) {
          if (mounted) {
            setState(() {
              _focusData = _buildFocusFromProducts(cachedData);
            });
          }
        }
      }
    } catch (_) {}

    try {
      final response = await _apiService.get(
        '/search/all',
        queryParameters: {'page': 1, 'pageSize': 6},
      );
      final products = _extractList(response.data);
      if (response.code == 0 && products.isNotEmpty) {
        await _storageService.saveProducts(products);
        if (mounted) {
          setState(() {
            _focusData = _buildFocusFromProducts(products);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _focusData = [];
        });
      }
    }
  }

  Future<void> _loadFeaturedProducts() async {
    try {
      final response = await _apiService.get(
        '/search/all',
        queryParameters: {'page': 1, 'pageSize': 6},
      );

      final products = _extractList(response.data)
          .map((item) => ProductModel.fromJson(item))
          .toList();

      if (mounted) {
        setState(() {
          _featuredProducts = products;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _featuredProducts = [];
        });
      }
    }
  }

  Future<void> _loadRecommendedProducts() async {
    try {
      final response = await _apiService.get(
        '/search/all',
        queryParameters: {'page': 1, 'pageSize': 12},
      );

      final products = _extractList(response.data)
          .map((item) => ProductModel.fromJson(item))
          .toList();

      if (mounted) {
        setState(() {
          _recommendedProducts = products;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recommendedProducts = [];
        });
      }
    }
  }

  void _onRefresh() async {
    await _loadData();
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    _refreshController.loadComplete();
  }

  Widget _buildSwiper() {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    if (_loadError || _focusData.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.grey,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              '加载失败',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CarouselSlider.builder(
        itemCount: _focusData.length,
        itemBuilder: (context, index, realIndex) {
          final item = _focusData[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: item.url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (context, url, error) => Image.asset(
                    Config.defaultProductAsset,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        options: CarouselOptions(
          height: 200,
          viewportFraction: 1.0,
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 3),
          autoPlayAnimationDuration: const Duration(milliseconds: 800),
          autoPlayCurve: Curves.fastOutSlowIn,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 20,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedProducts() {
    if (_isLoading) {
      return SizedBox(
        height: 220,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 6,
          itemBuilder: (context, index) {
            return const Padding(
              padding: EdgeInsets.only(right: 12),
              child: ProductCardSkeleton(),
            );
          },
        ),
      );
    }

    if (_featuredProducts.isEmpty) {
      return Container(
        height: 220,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            '暂无特色商品',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _featuredProducts.length,
        itemBuilder: (context, index) {
          final product = _featuredProducts[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 140,
              child: ProductCard(
                imageUrl: Config.resolveImage(product.imageUrl) ==
                        ''
                    ? 'https://picsum.photos/seed/f$index/200'
                    : Config.resolveImage(product.imageUrl),
                title: product.name ?? '未命名商品',
                price: product.price ?? 0.0,
                originalPrice: (product.price ?? 0.0) * 1.2,
                rating: 4.5,
                reviewCount: 128,
                onTap: () {
                  Navigator.pushNamed(context, '/productDetail', arguments: {
                    'productId': product.id,
                  });
                },
                onFavoriteTap: () {
                  Provider.of<AppState>(context, listen: false);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommendedProducts() {
    if (_isLoading) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        itemBuilder: (context, index) {
          return const ProductCardSkeleton();
        },
      );
    }

    if (_recommendedProducts.isEmpty) {
      return Container(
        height: 300,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            '暂无推荐商品',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _recommendedProducts.length,
      itemBuilder: (context, index) {
        final product = _recommendedProducts[index];
        return ProductCard(
          imageUrl: Config.resolveImage(product.imageUrl) == ''
              ? 'https://picsum.photos/seed/r$index/200'
              : Config.resolveImage(product.imageUrl),
          title: product.name ?? '未命名商品',
          price: product.price ?? 0.0,
          originalPrice: (product.price ?? 0.0) * 1.3,
          rating: 4.0 + (index % 5) * 0.2,
          reviewCount: 50 + index * 10,
          onTap: () {
            Navigator.pushNamed(context, '/productDetail', arguments: {
              'productId': product.id,
            });
          },
          onFavoriteTap: () {
            Provider.of<AppState>(context, listen: false);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SmartRefresher(
      controller: _refreshController,
      onRefresh: _onRefresh,
      onLoading: _onLoading,
      enablePullDown: true,
      enablePullUp: false,
      header: const ClassicHeader(
        idleText: '下拉刷新',
        releaseText: '释放刷新',
        refreshingText: '刷新中...',
        completeText: '刷新完成',
        failedText: '刷新失败',
        idleIcon: Icon(Icons.arrow_downward, color: Colors.grey),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildSwiper(),
            const SizedBox(height: 20),
            _buildSectionTitle('特色商品', '查看全部'),
            const SizedBox(height: 10),
            _buildFeaturedProducts(),
            const SizedBox(height: 20),
            _buildSectionTitle('热门推荐', '更多推荐'),
            const SizedBox(height: 10),
            _buildRecommendedProducts(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
