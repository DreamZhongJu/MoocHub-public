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
  List<CoursesModel> _recommendedProducts = [];
  bool _isLoading = true;
  bool _continueLoading = false;
  bool _showContinue = true;
  VideoModel? _continueVideo;
  int _continuePositionSec = 0;
  double _continuePercent = 0;
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _loadRecommendedProducts();
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

  Future<void> _loadRecommendedProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final response = await ApiService().get<Map<String, dynamic>>(
        '/courses',
        queryParameters: {'page': 1, 'page_size': 10, 'sort': 'view_count'},
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
          _recommendedProducts = next;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recommendedProducts = [];
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
          return const CoursesCardSkeleton();
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
            '暂无推荐视频',
            style: TextStyle(color: Colors.grey, fontSize: 16),
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
      },
    );
  }

  Widget _buildTDesignHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        SmartRefresher(
          enablePullDown: true,
          header: const WaterDropHeader(
            complete: Icon(Icons.done, color: Colors.grey),
            waterDropColor: Colors.blue,
          ),
          controller: RefreshController(),
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 1000));
            if (mounted) {
              setState(() {});
            }
          },
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildTDesignHeader(),
                const SizedBox(height: 12),
                _buildRecommendedProducts(),
                const SizedBox(height: 800),
              ],
            ),
          ),
        ),
        if (_showContinue && !_continueLoading && _continueVideo != null)
          Positioned(left: 16, bottom: 16, child: _buildContinueWatching()),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
