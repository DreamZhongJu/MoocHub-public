import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/model/CategoriesModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/services/ScreenAdaper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage>
    with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final Map<int, List<CategoryModel>> _rightCache = {};
  final TDSideBarController _sideBarController = TDSideBarController();

  int _selectIndex = 0;
  List<CategoryModel> _leftCateList = [];
  List<CategoryModel> _rightCateList = [];
  List<CategoryModel> _allCategories = [];
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
              .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
              .toList();
          if (mounted) {
            setState(() {
              _allCategories = parsed;
              _leftCateList = parsed.where((c) => c.parentId == null).toList();
              _selectIndex = 0;
            });
          }
          if (_leftCateList.isNotEmpty) {
            await _loadRightCateData(_leftCateList.first.id);
          }
        }
      }
    } catch (_) {}

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/categories',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );

      if (response.code != 0 && response.code != 200) {
        throw Exception(response.msg);
      }

      final raw = response.data['categories'];
      final List<CategoryModel> categories = [];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            categories.add(CategoryModel.fromJson(item));
          }
        }
      }

      await _storageService.saveCategories(
        categories.map((e) => e.toJson()).toList(),
      );

      if (mounted) {
        setState(() {
          _allCategories = categories;
          _leftCateList = categories.where((c) => c.parentId == null).toList();
          _selectIndex = 0;
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
      final list = _allCategories.where((c) => c.parentId == pid).toList();
      _rightCache[pid] = list;
      if (mounted) {
        setState(() {
          _rightCateList = list;
        });
      }
    } catch (_) {
    } finally {
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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TDSkeleton(
                animation: TDSkeletonAnimation.gradient,
                theme: TDSkeletonTheme.paragraph,
              ),
            ],
          ),
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

    final icons = <IconData>[
      TDIcons.app,
      TDIcons.folder,
      TDIcons.book,
      TDIcons.tag,
      TDIcons.chart,
      TDIcons.star,
      TDIcons.store,
      TDIcons.book,
    ];

    return SizedBox(
      width: leftWidth,
      child: TDSideBar(
        style: TDSideBarStyle.normal,
        value: _selectIndex,
        controller: _sideBarController,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        selectedTextStyle: const TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
        children: _leftCateList.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return TDSideBarItem(
            label: item.name,
            value: index,
            icon: icons[index % icons.length],
            textStyle: const TextStyle(fontSize: 12, height: 1.2),
          );
        }).toList(),
        onSelected: (value) {
          if (value == _selectIndex) return;
          setState(() {
            _selectIndex = value;
          });
          _loadRightCateData(_leftCateList[value].id);
        },
      ),
    );
  }

  Widget _rightCateWidget(double rightItemWidth, double rightItemHeight) {
    if (_loadingRight) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TDSkeleton(
                animation: TDSkeletonAnimation.gradient,
                theme: TDSkeletonTheme.paragraph,
              ),
            ],
          ),
        ),
      );
    }

    if (_rightCateList.isEmpty) {
      return const Expanded(child: Center(child: Text('暂无分类')));
    }

    return Expanded(
      child: Container(
        padding: EdgeInsets.only(top: 2.h),
        decoration: const BoxDecoration(color: Color(0xFFF7F9F8)),
        child: GridView.builder(
          padding: EdgeInsets.all(8.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: rightItemWidth / rightItemHeight,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _rightCateList.length,
          itemBuilder: (context, index) {
            final item = _rightCateList[index];
            return InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/courseList',
                  arguments: {'categoryId': item.id},
                );
              },
              child: Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.15,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
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
                    SizedBox(height: 6.h),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey.shade500, size: 18),
            const SizedBox(width: 6),
            Text(
              '搜索分类',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = ScreenAdapter.width(context);
    final leftWidth = (screenWidth * 0.3).clamp(110.0, 140.0).toDouble();
    final rightItemWidth = (screenWidth - leftWidth - 24) / 3;
    final rightItemHeight = rightItemWidth + 32.h;

    return Container(
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
    );
  }

  @override
  bool get wantKeepAlive => true;
}
