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
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin, RouteAware {
  final ScrollController controller = ScrollController();
  bool showBackTop = false;
  List<CoursesModel> _recommendedProducts = [];
  List<ArticleModel> _articleItems = [];
  List<_HomeFeedItem> _feedItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 10;
  bool _pendingScrollUpdate = false;
  bool _showNotice = true;
  bool _continueLoading = false;
  bool _showContinue = true;
  VideoModel? _continueVideo;
  int _continuePositionSec = 0;
  double _continuePercent = 0;
  bool _weakNetwork = false;
  bool _usingOfflineCache = false;
  String _networkHint = '';
  int _mockLoadCursor = 0;
  int _recommendSeed = DateTime.now().millisecondsSinceEpoch;
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();
  final AnalyticsService _analyticsService = AnalyticsService();
  static const String _homeScene = 'home_feed';
  static const String _homeFeedCacheKey = 'home_feed_v1_page_1';
  final Set<String> _homeExposedKeys = <String>{};

  Duration _nextMockDelay() {
    const fastDelaysMs = <int>[120, 180, 260];
    const slowDelaysMs = <int>[680, 920, 760];

    // 3 次快 -> 3 次慢，循环切换，模拟“时快时慢”的加载体验。
    final inSlowPhase = ((_mockLoadCursor ~/ 3) % 2) == 1;
    final indexInPhase = _mockLoadCursor % 3;
    _mockLoadCursor += 1;
    final ms = inSlowPhase
        ? slowDelaysMs[indexInPhase]
        : fastDelaysMs[indexInPhase];
    return Duration(milliseconds: ms);
  }

  Future<void> _waitMockLoadingDelay(DateTime startedAt) async {
    final target = _nextMockDelay();
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < target) {
      await Future.delayed(target - elapsed);
    }
  }

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

    return Container(
      width: 320,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: video.thumbUrl.isNotEmpty
                ? Image.network(
                    video.thumbUrl,
                    width: 88,
                    height: 50,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 88,
                    height: 50,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.play_arrow),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '继续观看',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatDuration(_continuePositionSec)} · $percentText',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  setState(() {
                    _showContinue = false;
                  });
                },
              ),
              ElevatedButton(
                onPressed: () {
                  final id = int.tryParse(video.id);
                  if (id == null) return;
                  Navigator.pushNamed(context, '/videoDetail', arguments: id);
                },
                child: const Text('继续'),
              ),
            ],
          ),
        ],
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
    final startedAt = DateTime.now();

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
      await _waitMockLoadingDelay(startedAt);
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
      if (shouldShow != showBackTop) {
        setState(() {
          showBackTop = shouldShow;
        });
      }
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyticsService.trackExposure(
        contentType: contentType,
        contentId: contentId,
        scene: _homeScene,
        position: position,
      );
    });
  }

  Widget _buildRecommendedItem(CoursesModel product, int position) {
    _reportHomeExposure(
      contentType: 'course',
      contentIdText: product.id,
      position: position,
    );
    return CoursesCard(
      key: ValueKey(product.id),
      title: product.title,
      summary: product.summary,
      coverUrl: product.coverUrl,
      viewCount: product.viewCount,
      favoriteCount: product.favoriteCount,
      onTap: () {
        final id = int.tryParse(product.id);
        if (id == null) {
          return;
        }
        _analyticsService.trackClick(
          contentType: 'course',
          contentId: id,
          scene: _homeScene,
          position: position,
        );
        Navigator.pushNamed(context, '/courseDetail', arguments: id);
      },
    );
  }

  Widget _buildArticleItem(ArticleModel article, int position) {
    _reportHomeExposure(
      contentType: 'article',
      contentIdText: article.id,
      position: position,
    );
    return ArticleCard(
      key: ValueKey('article-${article.id}'),
      title: article.title,
      summary: article.summary,
      coverUrl: article.coverUrl,
      viewCount: article.viewCount,
      likeCount: article.likeCount,
      onTap: () {
        final id = int.tryParse(article.id);
        if (id == null) {
          return;
        }
        _analyticsService.trackClick(
          contentType: 'article',
          contentId: id,
          scene: _homeScene,
          position: position,
        );
        Navigator.pushNamed(context, '/articleDetail', arguments: id);
      },
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
        ),
      ),
    );
  }

  Widget _buildTDesignHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '首页',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/articles'),
                icon: const Icon(Icons.article_outlined),
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/messages'),
                icon: Stack(
                  children: const [
                    Icon(TDIcons.notification),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.12),
                  colorScheme.primary.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MoocHub 学习推荐',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '今天想学点什么？试试搜索或看热门课程',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TDSearchBar(
                  placeHolder: '搜索课程/讲师/关键词',
                  readOnly: true,
                  action: '前往搜索',
                  onInputClick: () => Navigator.pushNamed(context, '/search'),
                  onActionClick: (_) => Navigator.pushNamed(context, '/search'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TDButton(
                      text: '热门课程',
                      size: TDButtonSize.small,
                      type: TDButtonType.fill,
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
                    TDButton(
                      text: '最新更新',
                      size: TDButtonSize.small,
                      type: TDButtonType.fill,
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
                    TDButton(
                      text: '推荐文章',
                      size: TDButtonSize.small,
                      type: TDButtonType.fill,
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
              ],
            ),
          ),
        ],
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
        if (mounted) {
          setState(() {
            showBackTop = false;
          });
        }
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
    if (!showBackTop) return const SizedBox.shrink();
    return Positioned(
      right: 0,
      bottom: _backTopBottomOffset(),
      child: _buildHalfCircleBackTop(context),
    );
  }

  Widget _closeNoticeBar(BuildContext context) {
    return TDNoticeBar(
      content: '这是一条普通的通知信息',
      prefixIcon: TDIcons.error_circle_filled,
      suffixIcon: TDIcons.close,
      onTap: (trigger) {
        if (trigger == 'suffix-icon') {
          setState(() {
            _showNotice = false;
          });
        }
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
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                if (_showNotice)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _closeNoticeBar(context),
                    ),
                  ),
                if (_showNotice)
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                _buildNetworkStateSliver(),
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
