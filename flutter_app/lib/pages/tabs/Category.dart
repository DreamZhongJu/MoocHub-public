import 'package:MoocHub/model/CategoriesModel.dart';
import 'package:MoocHub/services/AnalyticsService.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/services/ScreenAdaper.dart';
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
  final AnalyticsService _analyticsService = AnalyticsService();
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
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

  // 根据 index 循环取预设颜色/图标，让每个分类有独立的色彩
  static const List<Color> _cateColors = [
    Color(0xFF4ECDC4), Color(0xFFFF6B6B), Color(0xFF7C4DFF),
    Color(0xFFFFB347), Color(0xFF45B7D1), Color(0xFF96CEB4),
    Color(0xFFFF8B94), Color(0xFF6C5CE7), Color(0xFFFDCB6E),
    Color(0xFF00B894),
  ];
  static const List<IconData> _cateIcons = [
    Icons.computer_rounded,       // 编程
    Icons.design_services_rounded,// 设计
    Icons.science_rounded,        // 理科
    Icons.business_center_rounded,// 商业
    Icons.language_rounded,       // 语言
    Icons.music_note_rounded,     // 音乐
    Icons.fitness_center_rounded, // 健身
    Icons.camera_alt_rounded,     // 摄影
    Icons.psychology_rounded,     // 心理
    Icons.auto_stories_rounded,   // 阅读
  ];

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
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('暂无子分类', style: TextStyle(color: Colors.grey.shade400)),
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF7F9F8),
        child: GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: rightItemWidth / rightItemHeight,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _rightCateList.length,
          itemBuilder: (context, index) {
            final item = _rightCateList[index];
            final color = _cateColors[index % _cateColors.length];
            final icon = _cateIcons[index % _cateIcons.length];
            return GestureDetector(
              onTap: () {
                _analyticsService.trackCategoryClick(categoryId: item.id);
                Navigator.pushNamed(
                  context,
                  '/courseList',
                  arguments: {'categoryId': item.id},
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171A21) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.05,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/search'),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2430) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                '搜索课程、讲师…',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ],
          ),
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
