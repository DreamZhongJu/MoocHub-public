import 'package:MoocHub/model/CoursesModel.dart';
import 'package:MoocHub/model/ArticleModel.dart';
import 'package:MoocHub/model/VideoModel.dart';
import 'package:MoocHub/routers/route_observer.dart';
import 'package:MoocHub/services/AnalyticsService.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/widget/ArticleCard.dart';
import 'package:MoocHub/widget/AppStateWidgets.dart';
import 'package:MoocHub/widget/CoursesCard.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin, RouteAware {
  final ScrollController controller = ScrollController();
  final ValueNotifier<bool> _showBackTop = ValueNotifier(false);
  List<CoursesModel> _recommendedProducts = [];
  List<ArticleModel> _articleItems = [];
  List<_HomeFeedItem> _feedItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 10;
  bool _pendingScrollUpdate = false;
  bool _continueLoading = false;
  bool _showContinue = true;
  VideoModel? _continueVideo;
  int _continuePositionSec = 0;
  double _continuePercent = 0;
  bool _weakNetwork = false;
  bool _usingOfflineCache = false;
  String _networkHint = '';
  int _recommendSeed = DateTime.now().millisecondsSinceEpoch;
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();
  final AnalyticsService _analyticsService = AnalyticsService();
  static const String _homeScene = 'home_feed';
  static const String _homeFeedCacheKey = 'home_feed_v2_page_1';
  final Set<String> _homeExposedKeys = <String>{};

  @override
  void initState() {
    super.initState();
    controller.addListener(_handleScroll);
    _loadRecommendedProducts(reset: true);
    _loadContinueWatching();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    controller.removeListener(_handleScroll);
    controller.dispose();
    _showBackTop.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadContinueWatching();
  }

  String _stringify(dynamic value) => value?.toString() ?? '';

  int _intify(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
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

  Map<String, dynamic> _normalizeArticleMap(Map<String, dynamic> json) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': _stringify(json['id']),
      'user_id': _stringify(json['user_id']),
      'title': _stringify(json['title']),
      'summary': _stringify(json['summary']),
      'cover_url': _stringify(json['cover_url']),
      'content': _stringify(json['content']),
      'status': _stringify(json['status']),
      'view_count': _intify(json['view_count']),
      'like_count': _intify(json['like_count']),
      'created_at': _stringify(json['created_at']).isEmpty
          ? now
          : _stringify(json['created_at']),
      'updated_at': _stringify(json['updated_at']).isEmpty
          ? now
          : _stringify(json['updated_at']),
    };
  }

  List<_HomeFeedItem> _mixFeedItems(
    List<CoursesModel> courses,
    List<ArticleModel> articles,
  ) {
    final List<_HomeFeedItem> result = [];
    int i = 0;
    int j = 0;
    while (i < courses.length || j < articles.length) {
      for (var k = 0; k < 2 && i < courses.length; k++) {
        result.add(_HomeFeedItem.course(courses[i]));
        i++;
      }
      if (j < articles.length) {
        result.add(_HomeFeedItem.article(articles[j]));
        j++;
      }
    }
    return result;
  }

  Future<bool> _applyHomeCache({Duration? maxAge}) async {
    final payload = await _storageService.getOfflinePayload(
      _homeFeedCacheKey,
      maxAge: maxAge,
    );
    if (payload == null) return false;

    final coursesRaw = payload['courses'];
    final articlesRaw = payload['articles'];

    final courses = <CoursesModel>[];
    if (coursesRaw is List) {
      for (final item in coursesRaw) {
        if (item is Map) {
          courses.add(
            CoursesModel.fromJson(
              _normalizeCourseMap(item.cast<String, dynamic>()),
            ),
          );
        }
      }
    }

    final articles = <ArticleModel>[];
    if (articlesRaw is List) {
      for (final item in articlesRaw) {
        if (item is Map) {
          articles.add(
            ArticleModel.fromJson(
              _normalizeArticleMap(item.cast<String, dynamic>()),
            ),
          );
        }
      }
    }

    if (courses.isEmpty && articles.isEmpty) return false;
    if (!mounted) return true;

    setState(() {
      _recommendedProducts = courses;
      _articleItems = articles;
      _feedItems = _mixFeedItems(courses, articles);
    });
    return true;
  }

  Future<void> _saveHomeCache(
    List<CoursesModel> courses,
    List<ArticleModel> articles,
  ) async {
    await _storageService.saveOfflinePayload(_homeFeedCacheKey, {
      'courses': courses.map((e) => e.toJson()).toList(),
      'articles': articles.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> _loadContinueWatching() async {
    final token = await _storageService.getUserToken();
    final loggedIn =
        token != null && token.toString().isNotEmpty && token != 'null';
    if (!loggedIn) {
      if (mounted) {
        setState(() {
          _continueVideo = null;
          _showContinue = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _continueLoading = true;
        _showContinue = true;
      });
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/progress/latest',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );

      final data = response.data;
      final videoRaw = data['video'];
      final progressRaw = data['progress'];
      if (videoRaw is Map<String, dynamic> &&
          progressRaw is Map<String, dynamic>) {
        final video = VideoModel.fromJson(videoRaw);
        int pos = 0;
        final lastPos = progressRaw['last_position_sec'];
        if (lastPos is num) {
          pos = lastPos.toInt();
        } else if (lastPos is String) {
          pos = int.tryParse(lastPos) ?? 0;
        }
        double percent = 0;
        final rawPercent = progressRaw['progress_percent'];
        if (rawPercent is num) {
          percent = rawPercent.toDouble();
        } else if (rawPercent is String) {
          percent = double.tryParse(rawPercent) ?? 0;
        }
        if (mounted) {
          setState(() {
            _continueVideo = video;
            _continuePositionSec = pos;
            _continuePercent = percent;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _continueVideo = null;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _continueVideo = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _continueLoading = false;
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    final m = minutes.toString().padLeft(2, '0');
    final s = remaining.toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildContinueWatching() {
    if (!_showContinue) {
      return const SizedBox.shrink();
    }
    if (_continueLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final video = _continueVideo;
    if (video == null) {
      return const SizedBox.shrink();
    }
    final percentText = _continuePercent <= 0
        ? '未开始'
        : '${_continuePercent.toStringAsFixed(1)}%';

    final primary = Theme.of(context).colorScheme.primary;
    final maxWidth = MediaQuery.sizeOf(context).width - 32;
    final cardWidth = maxWidth.clamp(240.0, 340.0);

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条顶部装饰
            LinearProgressIndicator(
              value: (_continuePercent / 100).clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  // 缩略图
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: video.thumbUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: video.thumbUrl,
                            width: 80,
                            height: 46,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 80,
                              height: 46,
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          )
                        : Container(
                            width: 80,
                            height: 46,
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.grey.shade400,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  // 标题和进度
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.play_circle_filled,
                              size: 12,
                              color: primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '继续观看',
                              style: TextStyle(
                                fontSize: 11,
                                color: primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '已看 $percentText · ${_formatDuration(_continuePositionSec)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 操作区
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _showContinue = false),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          final id = int.tryParse(video.id);
                          if (id == null) return;
                          Navigator.pushNamed(
                            context,
                            '/videoDetail',
                            arguments: id,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '继续',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRecommendedProducts({
    required bool reset,
    bool fromLoadMore = false,
    bool useOfflineCache = true,
  }) async {
    if (!reset && _isLoadingMore) return;
    if (!reset && !_hasMore) return;

    bool loadMoreFailed = false;
    bool usedOfflineCache = false;

    if (mounted) {
      setState(() {
        if (reset) {
          _isLoading = true;
          _isLoadingMore = false;
          _weakNetwork = false;
          _usingOfflineCache = false;
          _networkHint = '';
        } else {
          _isLoadingMore = true;
        }
      });
    }

    if (reset) {
      _page = 1;
      _hasMore = true;
      _recommendSeed = DateTime.now().millisecondsSinceEpoch;
      _homeExposedKeys.clear();
      _analyticsService.resetSceneExposure(_homeScene);
      if (useOfflineCache) {
        usedOfflineCache = await _applyHomeCache(
          maxAge: const Duration(hours: 8),
        );
      }
      if (usedOfflineCache && mounted) {
        setState(() {
          _usingOfflineCache = true;
        });
      }
    }
    try {
      final results = await Future.wait([
        _apiService.getWithRetry<Map<String, dynamic>>(
          '/recommend/courses',
          queryParameters: {
            'page': _page,
            'page_size': _pageSize,
            'seed': _recommendSeed,
          },
          fromJson: (raw) => raw as Map<String, dynamic>,
          retries: 2,
          baseDelay: const Duration(milliseconds: 300),
        ),
        _apiService.getWithRetry<Map<String, dynamic>>(
          '/articles',
          queryParameters: {
            'page': _page,
            'page_size': _pageSize,
            'sort': 'created_at',
          },
          fromJson: (raw) => raw as Map<String, dynamic>,
          retries: 2,
          baseDelay: const Duration(milliseconds: 300),
        ),
      ]);

      final coursesRaw = results[0].data['courses'];
      final articlesRaw = results[1].data['articles'];

      final List<CoursesModel> nextCourses = [];
      if (coursesRaw is List) {
        for (final item in coursesRaw) {
          if (item is Map<String, dynamic>) {
            nextCourses.add(CoursesModel.fromJson(_normalizeCourseMap(item)));
          }
        }
      }

      final List<ArticleModel> nextArticles = [];
      if (articlesRaw is List) {
        for (final item in articlesRaw) {
          if (item is Map<String, dynamic>) {
            nextArticles.add(ArticleModel.fromJson(_normalizeArticleMap(item)));
          }
        }
      }

      if (mounted) {
        setState(() {
          if (reset) {
            _recommendedProducts = nextCourses;
            _articleItems = nextArticles;
            _usingOfflineCache = false;
            _weakNetwork = false;
            _networkHint = '';
          } else {
            _recommendedProducts.addAll(nextCourses);
            _articleItems.addAll(nextArticles);
          }
          _feedItems = _mixFeedItems(_recommendedProducts, _articleItems);
        });
      }

      if (reset) {
        await _saveHomeCache(nextCourses, nextArticles);
      }

      final hasMoreCourses = nextCourses.length == _pageSize;
      final hasMoreArticles = nextArticles.length == _pageSize;
      if (!hasMoreCourses && !hasMoreArticles) {
        _hasMore = false;
      } else {
        _hasMore = true;
        _page += 1;
      }
    } catch (_) {
      if (reset) {
        final fallbackLoaded = usedOfflineCache
            ? true
            : await _applyHomeCache(maxAge: const Duration(days: 7));
        if (mounted) {
          setState(() {
            _weakNetwork = true;
            _usingOfflineCache = fallbackLoaded;
            _networkHint = fallbackLoaded ? '网络较弱，已展示离线缓存内容' : '网络不可用，请下拉重试';
            if (!fallbackLoaded) {
              _recommendedProducts = [];
              _articleItems = [];
              _feedItems = [];
            }
          });
        }
      } else {
        loadMoreFailed = true;
        if (mounted) {
          setState(() {
            _weakNetwork = true;
            _networkHint = '加载下一页失败，请稍后重试';
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
      if (fromLoadMore && loadMoreFailed && mounted) {
        setState(() {
          _networkHint = '加载下一页失败，请稍后重试';
        });
      }
    }
  }

  void _handleScroll() {
    if (_pendingScrollUpdate) return;
    _pendingScrollUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScrollUpdate = false;
      if (!mounted || !controller.hasClients) return;
      final shouldShow = controller.offset > 120;
      _showBackTop.value = shouldShow;
      if (_isLoading || _isLoadingMore || !_hasMore) return;
      if (controller.position.maxScrollExtent <= 0 ||
          controller.position.pixels <= 0) {
        return;
      }
      final remain =
          controller.position.maxScrollExtent - controller.position.pixels;
      if (remain <= 200) {
        _loadRecommendedProducts(reset: false, fromLoadMore: true);
      }
    });
  }

  SliverGridDelegate _gridDelegate() {
    return const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
    );
  }

  Widget _buildEmptyRecommended() {
    return AppEmptyState(
      icon: Icons.school_outlined,
      title: '暂无推荐内容',
      subtitle: _weakNetwork ? '请检查网络后下拉重试' : '稍后再来看看',
      actionText: '立即刷新',
      onAction: () => _loadRecommendedProducts(reset: true),
    );
  }

  void _reportHomeExposure({
    required String contentType,
    required String contentIdText,
    required int position,
  }) {
    final contentId = int.tryParse(contentIdText);
    if (contentId == null) return;

    final key = '$contentType|$contentId';
    if (_homeExposedKeys.contains(key)) return;
    _homeExposedKeys.add(key);

    // 直接上报，由调用方（_ExposureWrapper.initState）保证在帧结束后执行
    _analyticsService.trackExposure(
      contentType: contentType,
      contentId: contentId,
      scene: _homeScene,
      position: position,
    );
  }

  Widget _buildRecommendedItem(CoursesModel product, int position) {
    return _ExposureWrapper(
      key: ValueKey('exp-course-${product.id}'),
      onExposed: () => _reportHomeExposure(
        contentType: 'course',
        contentIdText: product.id,
        position: position,
      ),
      child: CoursesCard(
        key: ValueKey(product.id),
        title: product.title,
        summary: product.summary,
        coverUrl: product.coverUrl,
        viewCount: product.viewCount,
        favoriteCount: product.favoriteCount,
        onTap: () {
          final id = int.tryParse(product.id);
          if (id == null) return;
          _analyticsService.trackClick(
            contentType: 'course',
            contentId: id,
            scene: _homeScene,
            position: position,
          );
          Navigator.pushNamed(context, '/courseDetail', arguments: id);
        },
      ),
    );
  }

  Widget _buildArticleItem(ArticleModel article, int position) {
    return _ExposureWrapper(
      key: ValueKey('exp-article-${article.id}'),
      onExposed: () => _reportHomeExposure(
        contentType: 'article',
        contentIdText: article.id,
        position: position,
      ),
      child: ArticleCard(
        key: ValueKey('article-${article.id}'),
        title: article.title,
        summary: article.summary,
        coverUrl: article.coverUrl,
        viewCount: article.viewCount,
        likeCount: article.likeCount,
        onTap: () {
          final id = int.tryParse(article.id);
          if (id == null) return;
          _analyticsService.trackClick(
            contentType: 'article',
            contentId: id,
            scene: _homeScene,
            position: position,
          );
          Navigator.pushNamed(context, '/articleDetail', arguments: id);
        },
      ),
    );
  }

  Widget _buildFeedItem(_HomeFeedItem item, int index) {
    final position = index + 1;
    if (item.isArticle && item.article != null) {
      return _buildArticleItem(item.article!, position);
    }
    if (item.course != null) {
      return _buildRecommendedItem(item.course!, position);
    }
    return const SizedBox.shrink();
  }

  Widget _buildRecommendedSliver() {
    if (_isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: _gridDelegate(),
          delegate: SliverChildBuilderDelegate(
            (context, index) => const CoursesCardSkeleton(),
            childCount: 6,
          ),
        ),
      );
    }

    if (_feedItems.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyRecommended());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate(),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildFeedItem(_feedItems[index], index),
          childCount: _feedItems.length,
          addRepaintBoundaries: false, // 卡片内已有 RepaintBoundary，避免双层包裹
        ),
      ),
    );
  }

  Widget _buildTDesignHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 顶部标题栏 ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '发现好课程',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '每天进步一点点',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/articles'),
                icon: Icon(
                  Icons.article_outlined,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
                tooltip: '文章',
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/messages'),
                tooltip: '消息',
                icon: Stack(
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── 搜索框 ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/search'),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2430) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(
                    Icons.search_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '搜索课程、讲师、关键词…',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                  const Spacer(),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '搜索',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── 快捷入口标签 ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickTag(
                  label: '🔥 热门课程',
                  color: const Color(0xFFFF6B6B),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/search',
                    arguments: const {
                      'keyword': '课程',
                      'scope': 'course',
                      'sort': 'view_count',
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickTag(
                  label: '✨ 最新上线',
                  color: const Color(0xFF4ECDC4),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/search',
                    arguments: const {
                      'keyword': '最新',
                      'scope': 'all',
                      'sort': 'created_at',
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickTag(
                  label: '📖 精选文章',
                  color: const Color(0xFF7C4DFF),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/search',
                    arguments: const {
                      'keyword': '文章',
                      'scope': 'article',
                      'sort': 'view_count',
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccess() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      (
        Icons.grid_view_rounded,
        '全部课程',
        const Color(0xFF4ECDC4),
        () => Navigator.pushNamed(
          context,
          '/search',
          arguments: const {'scope': 'course', 'sort': 'view_count'},
        ),
      ),
      (
        Icons.article_outlined,
        '精选文章',
        const Color(0xFF7C4DFF),
        () => Navigator.pushNamed(context, '/articles'),
      ),
      (
        Icons.favorite_border_rounded,
        '我的收藏',
        const Color(0xFFFF6B6B),
        () => Navigator.pushNamed(context, '/favorites'),
      ),
      (
        Icons.chat_bubble_outline_rounded,
        '消息',
        const Color(0xFFFFB347),
        () => Navigator.pushNamed(context, '/chat'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((item) {
          final (icon, label, color, onTap) = item;
          return GestureDetector(
            onTap: onTap,
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark
                        ? color.withValues(alpha: 0.18)
                        : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeedSectionHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '为你推荐',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () =>
                _loadRecommendedProducts(reset: true, useOfflineCache: false),
            child: Row(
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 14,
                  color: isDark ? Colors.white54 : Colors.grey.shade500,
                ),
                const SizedBox(width: 3),
                Text(
                  '换一批',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTag({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingMoreSliver() {
    if (!_isLoadingMore) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: const Column(
          children: [
            AppShimmerBlock(height: 14),
            SizedBox(height: 10),
            AppShimmerBlock(height: 14, width: 220),
            SizedBox(height: 10),
            AppShimmerBlock(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkStateSliver() {
    if (!_weakNetwork && !_usingOfflineCache) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final text = _networkHint.isNotEmpty
        ? _networkHint
        : (_usingOfflineCache ? '已展示离线缓存内容' : '当前网络较弱');
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppWeakNetworkBanner(text: text),
      ),
    );
  }

  Widget _buildHalfCircleBackTop(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () async {
        if (controller.hasClients) {
          await controller.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
        _showBackTop.value = false;
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(20),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.arrow_upward, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Text('返回顶部', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  double _backTopBottomOffset() {
    if (_showContinue && !_continueLoading && _continueVideo != null) {
      return 120;
    }
    return 24;
  }

  Widget _buildBackTopButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showBackTop,
      builder: (context, show, _) {
        if (!show) return const SizedBox.shrink();
        return Positioned(
          right: 0,
          bottom: _backTopBottomOffset(),
          child: _buildHalfCircleBackTop(context),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            await _loadRecommendedProducts(reset: true, useOfflineCache: false);
          },
          child: ScrollConfiguration(
            behavior: const _NoScrollbarBehavior(),
            child: CustomScrollView(
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildTDesignHeader()),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                SliverToBoxAdapter(child: _buildQuickAccess()),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                _buildNetworkStateSliver(),
                SliverToBoxAdapter(child: _buildFeedSectionHeader()),
                _buildRecommendedSliver(),
                _buildLoadingMoreSliver(),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ),
        if (_showContinue && !_continueLoading && _continueVideo != null)
          Positioned(left: 16, bottom: 16, child: _buildContinueWatching()),
        _buildBackTopButton(),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _HomeFeedItem {
  final CoursesModel? course;
  final ArticleModel? article;
  bool get isArticle => article != null;

  const _HomeFeedItem._({this.course, this.article});

  factory _HomeFeedItem.course(CoursesModel course) =>
      _HomeFeedItem._(course: course);

  factory _HomeFeedItem.article(ArticleModel article) =>
      _HomeFeedItem._(article: article);
}

class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// 曝光追踪包装器：在 initState（首次进入视口）时触发一次 onExposed，
/// 后续 rebuild 不会重复上报，避免在 build 方法里调用带副作用的函数。
class _ExposureWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onExposed;

  const _ExposureWrapper({
    super.key,
    required this.child,
    required this.onExposed,
  });

  @override
  State<_ExposureWrapper> createState() => _ExposureWrapperState();
}

class _ExposureWrapperState extends State<_ExposureWrapper> {
  @override
  void initState() {
    super.initState();
    // addPostFrameCallback 确保在 layout 完成后上报，不阻塞当前帧
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onExposed();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
