import 'dart:async';

import 'package:MoocHub/model/CoursesModel.dart';
import 'package:MoocHub/model/VideoModel.dart';
import 'package:MoocHub/routers/route_observer.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/widget/CoursesCard.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin, RouteAware {
  ScrollController controller = ScrollController();
  final RefreshController _refreshController = RefreshController();
  bool showBackTop = false;
  List<CoursesModel> _recommendedProducts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 10;
  DateTime? _lastLoadAt;
  int _slowDownMs = 0;
  Timer? _loadMoreTimer;
  bool _pendingScrollUpdate = false;
  bool _showNotice = true;
  bool _continueLoading = false;
  bool _showContinue = true;
  VideoModel? _continueVideo;
  int _continuePositionSec = 0;
  double _continuePercent = 0;
  final StorageService _storageService = StorageService();

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
    _loadMoreTimer?.cancel();
    controller.removeListener(_handleScroll);
    _refreshController.dispose();
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
      final response = await ApiService().get<Map<String, dynamic>>(
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

  Future<void> _loadRecommendedProducts({required bool reset}) async {
    if (_isLoadingMore) return;
    if (!reset && !_hasMore) return;

    if (mounted) {
      setState(() {
        if (reset) {
          _isLoading = true;
        } else {
          _isLoadingMore = true;
        }
      });
    }

    if (reset) {
      _page = 1;
      _hasMore = true;
    }

    try {
      final response = await ApiService().get<Map<String, dynamic>>(
        '/courses',
        queryParameters: {
          'page': _page,
          'page_size': _pageSize,
          'sort': 'view_count',
        },
        fromJson: (raw) => raw as Map<String, dynamic>,
      );

      final raw = response.data['courses'];
      final List<CoursesModel> next = [];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            next.add(CoursesModel.fromJson(_normalizeCourseMap(item)));
          }
        }
      }

      if (mounted) {
        setState(() {
          if (reset) {
            _recommendedProducts = next;
          } else {
            _recommendedProducts.addAll(next);
          }
        });
      }

      if (next.length < _pageSize) {
        _hasMore = false;
      } else {
        _hasMore = true;
        _page += 1;
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (reset) {
            _recommendedProducts = [];
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
      if (reset) {
        _refreshController.refreshCompleted();
      }
    }
  }

  void _tryLoadMore() {
    if (_isLoadingMore || !_hasMore) return;
    _loadMoreTimer?.cancel();
    final now = DateTime.now();
    if (_lastLoadAt != null) {
      final gapMs = now.difference(_lastLoadAt!).inMilliseconds;
      if (gapMs < 800) {
        _slowDownMs = (_slowDownMs + 300).clamp(0, 1500);
      } else {
        _slowDownMs = (_slowDownMs - 150).clamp(0, 1500);
      }
    }
    _lastLoadAt = now;
    _loadMoreTimer = Timer(
      Duration(milliseconds: _slowDownMs),
      () => _loadRecommendedProducts(reset: false),
    );
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
      if (controller.position.extentAfter < 60) {
        _tryLoadMore();
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
    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          '暂无推荐视频',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildRecommendedItem(CoursesModel product) {
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
        Navigator.pushNamed(context, '/courseDetail', arguments: id);
      },
    );
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

    if (_recommendedProducts.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyRecommended());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate(),
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              _buildRecommendedItem(_recommendedProducts[index]),
          childCount: _recommendedProducts.length,
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
                  onTextChanged: (_) {},
                  onSubmitted: (_) {},
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
                      onTap: () {},
                    ),
                    TDButton(
                      text: '最新更新',
                      size: TDButtonSize.small,
                      type: TDButtonType.fill,
                      onTap: () {},
                    ),
                    TDButton(
                      text: '高分课程',
                      size: TDButtonSize.small,
                      type: TDButtonType.fill,
                      onTap: () {},
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

  Widget _buildGradientSkeleton(BuildContext context) {
    return TDSkeleton(
      animation: TDSkeletonAnimation.gradient,
      theme: TDSkeletonTheme.paragraph,
    );
  }

  Widget _buildLoadingMoreSliver() {
    if (!_isLoadingMore)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          height: 120,
          child: Column(children: [_buildGradientSkeleton(context)]),
        ),
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
        SmartRefresher(
          enablePullDown: true,
          enablePullUp: false,
          header: const WaterDropHeader(
            complete: Icon(Icons.done, color: Colors.grey),
            waterDropColor: Colors.blue,
          ),
          controller: _refreshController,
          onRefresh: () async {
            await _loadRecommendedProducts(reset: true);
          },
          child: ScrollConfiguration(
            behavior: const _NoScrollbarBehavior(),
            child: CustomScrollView(
              controller: controller,
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
