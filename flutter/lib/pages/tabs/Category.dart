import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jdshop/model/CateModle.dart';
import 'package:flutter_jdshop/config/Config.dart';
import 'package:flutter_jdshop/services/ApiService.dart';
import 'package:flutter_jdshop/services/ScreenAdaper.dart';
import 'package:flutter_jdshop/services/StorageService.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage>
    with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final Map<int, List<CateLevel2ItemModel>> _rightCache = {};

  int _selectIndex = 0;
  List<CateItemModel> _leftCateList = [];
  List<CateLevel2ItemModel> _rightCateList = [];
  bool _loadingLeft = false;
  bool _loadingRight = false;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _loadLeftCateData();
  }

  Future<void> _loadLeftCateData() async {
    setState(() {
      _loadingLeft = true;
      _loadError = false;
    });

    try {
      final shouldRefresh = await _storageService.shouldRefreshCategories();
      if (!shouldRefresh) {
        final cached = await _storageService.getCategories();
        if (cached.isNotEmpty) {
          final parsed = cached
              .map((e) => CateItemModel.fromJson(e as Map<String, dynamic>))
              .toList();
          if (mounted) {
            setState(() {
              _leftCateList = parsed;
            });
          }
          if (parsed.isNotEmpty) {
            await _loadRightCateData(parsed.first.id);
          }
        }
      }
    } catch (_) {}

    try {
      final response = await _apiService.get<List<CateItemModel>>(
        '/categories',
        fromJson: (raw) => (raw as List)
            .map((e) => CateItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

      if (response.code != 0) {
        throw Exception(response.msg);
      }

      await _storageService.saveCategories(
        response.data.map((e) => e.toJson()).toList(),
      );

      if (mounted) {
        setState(() {
          _leftCateList = response.data;
        });
      }

      if (_leftCateList.isNotEmpty) {
        await _loadRightCateData(_leftCateList.first.id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = _leftCateList.isEmpty;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingLeft = false;
        });
      }
    }
  }

  Future<void> _loadRightCateData(int pid) async {
    if (_rightCache.containsKey(pid)) {
      setState(() {
        _rightCateList = _rightCache[pid] ?? [];
      });
      return;
    }

    setState(() {
      _loadingRight = true;
    });

    try {
      final response = await _apiService.get<List<CateLevel2ItemModel>>(
        '/categories/$pid/level2',
        fromJson: (raw) => (raw as List)
            .map((e) => CateLevel2ItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

      if (response.code != 0) {
        throw Exception(response.msg);
      }

      _rightCache[pid] = response.data;
      if (mounted) {
        setState(() {
          _rightCateList = response.data;
        });
      }
    } catch (_) {} finally {
      if (mounted) {
        setState(() {
          _loadingRight = false;
        });
      }
    }
  }

  Widget _leftCateWidget(double leftWidth) {
    if (_loadingLeft) {
      return SizedBox(
        width: leftWidth,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loadError) {
      return SizedBox(
        width: leftWidth,
        child: Center(
          child: TextButton(
            onPressed: _loadLeftCateData,
            child: const Text('点击重试'),
          ),
        ),
      );
    }

    return SizedBox(
      width: leftWidth,
      child: ListView.builder(
        itemCount: _leftCateList.length,
        itemBuilder: (context, index) {
          final selected = _selectIndex == index;
          return InkWell(
            onTap: () {
              setState(() {
                _selectIndex = index;
              });
              _loadRightCateData(_leftCateList[index].id);
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 10.w),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFEEF6F3) : Colors.white,
                border: Border(
                  left: BorderSide(
                    color: selected ? Colors.red : Colors.transparent,
                    width: 3,
                  ),
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Text(
                _leftCateList[index].name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? Colors.red.shade400 : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _rightCateWidget(double rightItemWidth, double rightItemHeight) {
    if (_loadingRight) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_rightCateList.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text('暂无分类'),
        ),
      );
    }

    return Expanded(
      child: Container(
        padding: EdgeInsets.only(top: 4.h),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F9F8),
        ),
        child: GridView.builder(
          padding: EdgeInsets.all(12.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: rightItemWidth / rightItemHeight,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _rightCateList.length,
          itemBuilder: (context, index) {
            final item = _rightCateList[index];
            return InkWell(
              onTap: () {
                Navigator.pushNamed(context, '/productList', arguments: {
                  'cid': item.id,
                });
              },
              child: Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1 / 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl:
                              'https://picsum.photos/seed/cate${item.id}/200/200',
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Image.asset(
                            Config.defaultProductAsset,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _searchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            Icon(Icons.search, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Text(
              '搜索分类',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
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
    final leftWidth = ScreenAdapter.width(context) / 4;
    final rightItemWidth = (ScreenAdapter.width(context) - leftWidth - 24) / 3;
    final rightItemHeight = rightItemWidth + 46.h;

    return ScreenAdapter.init(
      child: Container(
        color: const Color(0xFFF7F9F8),
        child: Column(
          children: [
            _searchHeader(),
            Expanded(
              child: Row(
                children: [
                  _leftCateWidget(leftWidth),
                  _rightCateWidget(rightItemWidth, rightItemHeight),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
