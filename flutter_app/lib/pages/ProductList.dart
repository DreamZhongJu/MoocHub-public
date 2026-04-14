import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/model/CoursesModel.dart';
import 'package:MoocHub/services/AnalyticsService.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/widget/AppStateWidgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProductListPage extends StatefulWidget {
  final int categoryId;
  const ProductListPage({super.key, required this.categoryId});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final AnalyticsService _analyticsService = AnalyticsService();

  int _page = 1;
  String _sort = 'default';
  String _level = 'all';
  bool _isLoading = false;
  bool _hasMore = true;
  bool _weakNetwork = false;
  bool _usingOfflineCache = false;
  String _networkHint = '';
  List<CoursesModel> _courseList = [];

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _stringify(dynamic v) => v?.toString() ?? '';

  int _intify(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _normalizeCourseMap(Map<String, dynamic> json) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': _stringify(json['id']),
      'category_id': _stringify(json['category_id']),
      'title': _stringify(json['title']),
      'summary': _stringify(json['summary']),
      'cover_url': _stringify(json['cover_url']),
      'view_count': _intify(json['view_count']),
      'favorite_count': _intify(json['favorite_count']),
      'instructor_name': _stringify(json['instructor_name']),
      'level': _stringify(json['level']),
      'status': _stringify(json['status']),
      'created_at': _stringify(json['created_at']).isEmpty
          ? now
          : _stringify(json['created_at']),
      'updated_at': _stringify(json['updated_at']).isEmpty
          ? now
          : _stringify(json['updated_at']),
    };
  }

  // ── Cache ──────────────────────────────────────────────────────────────────

  String _cacheKey() =>
      'category_courses_v2_${widget.categoryId}_${_sort}_$_level';

  Future<bool> _applyCache({Duration? maxAge}) async {
    final payload = await _storageService.getOfflinePayload(
      _cacheKey(),
      maxAge: maxAge,
    );
    if (payload == null) return false;
    final raw = payload['courses'];
    if (raw is! List) return false;
    final items = <CoursesModel>[];
    for (final item in raw) {
      if (item is Map) {
        items.add(
          CoursesModel.fromJson(
            _normalizeCourseMap(item.cast<String, dynamic>()),
          ),
        );
      }
    }
    if (items.isEmpty) return false;
    if (!mounted) return true;
    setState(() {
      _courseList = items;
    });
    return true;
  }

  Future<void> _saveCache(List<CoursesModel> items) async {
    await _storageService.saveOfflinePayload(_cacheKey(), {
      'courses': items.map((e) => e.toJson()).toList(),
    });
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _getProductListData(reset: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 100) {
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

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _getProductListData({bool reset = false}) async {
    if (_isLoading) return;
    bool usedCache = false;
    setState(() {
      _isLoading = true;
      if (reset) {
        _weakNetwork = false;
        _usingOfflineCache = false;
        _networkHint = '';
      }
    });

    if (reset) {
      _page = 1;
      _courseList = [];
      _hasMore = true;
      usedCache = await _applyCache(maxAge: const Duration(hours: 8));
      if (usedCache && mounted) {
        setState(() {
          _usingOfflineCache = true;
        });
      }
    }

    try {
      final qp = <String, dynamic>{
        'page': _page,
        'page_size': 12,
        'sort': _sort,
      };
      if (_level != 'all') qp['level'] = _level;

      final response = await _apiService.getWithRetry<Map<String, dynamic>>(
        '/categories/${widget.categoryId}/courses',
        queryParameters: qp,
        fromJson: (raw) => raw as Map<String, dynamic>,
        retries: 2,
        baseDelay: const Duration(milliseconds: 300),
      );

      if (response.code != 0 && response.code != 200) {
        throw Exception(response.msg);
      }

      final raw = response.data['courses'];
      final List<CoursesModel> newItems = [];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            newItems.add(CoursesModel.fromJson(_normalizeCourseMap(item)));
          }
        }
      }
      setState(() {
        _courseList.addAll(newItems);
        _page++;
        _weakNetwork = false;
        _usingOfflineCache = false;
        _networkHint = '';
        if (response.count != null) {
          _hasMore = _courseList.length < response.count!;
        } else {
          _hasMore = newItems.isNotEmpty;
        }
      });
      if (reset) await _saveCache(newItems);
    } catch (_) {
      if (reset) {
        final loaded = usedCache
            ? true
            : await _applyCache(maxAge: const Duration(days: 3));
        if (mounted) {
          setState(() {
            _usingOfflineCache = loaded;
            _weakNetwork = true;
            _networkHint = loaded ? '网络较弱，已展示离线缓存' : '网络异常，请重试';
            if (!loaded) _hasMore = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _weakNetwork = true;
          _networkHint = '网络较弱，下一页加载失败';
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

  // ── Sort / Filter ──────────────────────────────────────────────────────────

  void _setSort(String value) {
    if (_sort == value) return;
    setState(() => _sort = value);
    _getProductListData(reset: true);
  }

  void _setLevel(String value) {
    if (_level == value) return;
    setState(() => _level = value);
    _getProductListData(reset: true);
  }

  // ── Level styling ──────────────────────────────────────────────────────────

  static const _levelLabels = {
    'beginner': '入门',
    'intermediate': '进阶',
    'advanced': '高级',
  };

  static const _levelColors = {
    'beginner': Color(0xFF26A69A),
    'intermediate': Color(0xFF5C6BC0),
    'advanced': Color(0xFFEF5350),
  };

  Color _levelColor(String level) =>
      _levelColors[level] ?? const Color(0xFF78909C);
  String _levelLabel(String level) => _levelLabels[level] ?? level;

  // ── UI Builders ────────────────────────────────────────────────────────────

  Widget _buildSortBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? const Color(0xFF151820) : Colors.white;
    final options = [
      ('default', '综合'),
      ('view_count', '最热'),
      ('favorite_count', '收藏'),
      ('created_at', '最新'),
    ];

    return Container(
      height: 48,
      color: barColor,
      child: Row(
        children: [
          ...options.map((entry) {
            final active = _sort == entry.$1;
            final primary = Theme.of(context).colorScheme.primary;
            return Expanded(
              child: InkWell(
                onTap: () => _setSort(entry.$1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.$2,
                      style: TextStyle(
                        fontSize: 13,
                        color: active ? primary : Colors.grey.shade600,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 2.5,
                      width: active ? 24 : 0,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Filter trigger
          InkWell(
            onTap: _showFilterSheet,
            child: Container(
              width: 52,
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  if (_level != 'all')
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2230) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    '难度筛选',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _filterChip(ctx, 'all', '全部难度', Colors.grey),
                      ..._levelLabels.entries.map(
                        (e) => _filterChip(
                          ctx,
                          e.key,
                          e.value,
                          _levelColor(e.key),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filterChip(
    BuildContext ctx,
    String value,
    String label,
    Color color,
  ) {
    final active = _level == value;
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        _setLevel(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? color : Colors.grey.shade300,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? color : Colors.grey.shade600,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(CoursesModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF171A21) : Colors.white;
    final levelColor = _levelColor(item.level);
    final levelLabel = _levelLabel(item.level);

    return GestureDetector(
      onTap: () {
        final id = int.tryParse(item.id);
        if (id == null) return;
        _analyticsService.trackPageView(
          contentType: 'course',
          contentId: id,
          scene: 'course_list',
        );
        Navigator.pushNamed(context, '/courseDetail', arguments: id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cover image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 110,
                height: 90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: Config.resolveImage(item.coverUrl).isEmpty
                          ? 'https://picsum.photos/seed/p${item.id}/200'
                          : Config.resolveImage(item.coverUrl),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Image.asset(
                        Config.defaultProductAsset,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Play overlay
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Instructor + level badge
                    Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 13,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            item.instructorName.isEmpty
                                ? '未知讲师'
                                : item.instructorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        if (item.level.isNotEmpty && item.level != 'unknown')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: levelColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              levelLabel,
                              style: TextStyle(
                                fontSize: 10,
                                color: levelColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Stats
                    Row(
                      children: [
                        Icon(
                          Icons.remove_red_eye_outlined,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatCount(item.viewCount),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.bookmark_outline_rounded,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatCount(item.favoriteCount),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
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
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  Widget _buildList() {
    if (_courseList.isEmpty && _isLoading) {
      return const AppListSkeleton(
        itemCount: 6,
        itemHeight: 90,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
      );
    }

    if (_courseList.isEmpty) {
      return AppEmptyState(
        icon: Icons.menu_book_outlined,
        title: '暂无课程',
        subtitle: _level != 'all' ? '试试切换难度筛选' : '可尝试切换排序条件',
        actionText: _level != 'all' ? '查看全部难度' : null,
        onAction: _level != 'all' ? () => _setLevel('all') : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _getProductListData(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _courseList.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _courseList.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _buildCourseCard(_courseList[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('课程列表'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Column(
        children: [
          _buildSortBar(),
          if (_weakNetwork || _usingOfflineCache)
            AppWeakNetworkBanner(
              text: _networkHint.isNotEmpty
                  ? _networkHint
                  : (_usingOfflineCache ? '已展示离线缓存内容' : '当前网络较弱'),
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }
}
