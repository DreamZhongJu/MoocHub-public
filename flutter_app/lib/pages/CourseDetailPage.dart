import 'dart:async';

import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/model/CoursesModel.dart';
import 'package:MoocHub/model/VideoModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/widget/CommentsPanel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter_swiper_null_safety/flutter_swiper_null_safety.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tencent_kit/tencent_kit.dart';

class CourseDetailPage extends StatefulWidget {
  final int courseId;

  const CourseDetailPage({super.key, required this.courseId});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  CoursesModel? _product;
  List<VideoModel> _videos = [];
  bool _isLoading = true;
  bool _loadError = false;
  int _selectedImageIndex = 0;
  List<String> _imageUrls = [];
  bool _disposed = false;
  bool _favoriteLoading = false;
  bool _isFavorite = false;
  int _favoriteCount = 0;
  bool _loggedIn = false;

  late final String _qqAppId;
  TencentKitPlatform? _tencent;
  StreamSubscription<TencentResp>? _qqShareSub;

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

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _initTencent();
    _loadProductDetail();
  }

  @override
  void dispose() {
    _disposed = true;
    _qqShareSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await _storageService.getUserToken();
    final loggedIn =
        token != null && token.toString().isNotEmpty && token != 'null';
    if (mounted) {
      setState(() {
        _loggedIn = loggedIn;
      });
    }
    if (loggedIn) {
      _loadFavoriteState();
    }
  }

  void _initTencent() {
    _qqAppId = (dotenv.env['QQ_APP_ID'] ?? dotenv.env['TENCENT_APP_ID'] ?? '')
        .trim();
    if (_qqAppId.isNotEmpty && !kIsWeb) {
      _tencent = TencentKitPlatform.instance;
      _tencent!.registerApp(appId: _qqAppId);
      _qqShareSub = _tencent!.respStream().listen(_handleTencentResp);
    }
  }

  void _handleTencentResp(TencentResp resp) {
    if (resp is TencentShareMsgResp && mounted) {
      if (resp.isSuccessful) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('分享成功')));
      } else if (resp.isCancelled) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消分享')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(resp.msg ?? '分享失败')));
      }
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _disposed) return;
    setState(fn);
  }

  Future<void> _loadProductDetail() async {
    _safeSetState(() {
      _isLoading = true;
      _loadError = false;
    });

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/courses/${widget.courseId}',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );

      if (response.code == 0 || response.code == 200) {
        final data = response.data;
        final rawCourses = data is Map<String, dynamic>
            ? data['courses']
            : null;
        if (rawCourses is List && rawCourses.isNotEmpty) {
          final first = rawCourses.first;
          if (first is Map<String, dynamic>) {
            final product = CoursesModel.fromJson(_normalizeCourseMap(first));
            final resolvedImage = Config.resolveImage(product.coverUrl);
            final rawVideos = data['videos'];
            final List<VideoModel> videos = [];
            if (rawVideos is List) {
              for (final item in rawVideos) {
                if (item is Map<String, dynamic>) {
                  videos.add(VideoModel.fromJson(item));
                }
              }
            }
            _safeSetState(() {
              _product = product;
              _imageUrls = resolvedImage.isEmpty ? [] : [resolvedImage];
              _videos = videos;
              _favoriteCount = product.favoriteCount;
              _isLoading = false;
            });
            _loadFavoriteState();
            return;
          }
        }
        _safeSetState(() {
          _loadError = true;
          _isLoading = false;
        });
      } else {
        _safeSetState(() {
          _loadError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('load product detail failed: $e');
      _safeSetState(() {
        _loadError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFavoriteState() async {
    if (!_loggedIn) return;
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/favorites',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final coursesRaw = response.data['courses'];
      if (coursesRaw is List) {
        final matched = coursesRaw.any((item) {
          if (item is Map<String, dynamic>) {
            final id = item['id'];
            if (id is num) return id.toInt() == widget.courseId;
            return id?.toString() == widget.courseId.toString();
          }
          return false;
        });
        if (mounted) {
          setState(() {
            _isFavorite = matched;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (!_loggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先登录')));
      }
      return;
    }
    if (_favoriteLoading) return;
    final bool next = !_isFavorite;
    setState(() {
      _favoriteLoading = true;
      _isFavorite = next;
      if (next) {
        _favoriteCount += 1;
      } else if (_favoriteCount > 0) {
        _favoriteCount -= 1;
      }
    });
    try {
      if (next) {
        final resp = await _apiService.postForm<Map<String, dynamic>>(
          '/favorites/courses',
          data: {'course_id': widget.courseId.toString()},
          fromJson: (raw) =>
              (raw as Map<String, dynamic>?) ?? <String, dynamic>{},
        );
        if (resp.code != 0 && resp.code != 200) {
          throw Exception(resp.msg);
        }
      } else {
        final resp = await _apiService.delete<Map<String, dynamic>>(
          '/favorites/courses/${widget.courseId}',
          fromJson: (raw) =>
              (raw as Map<String, dynamic>?) ?? <String, dynamic>{},
        );
        if (resp.code != 0 && resp.code != 200) {
          throw Exception(resp.msg);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFavorite = !next;
          if (next) {
            if (_favoriteCount > 0) _favoriteCount -= 1;
          } else {
            _favoriteCount += 1;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _favoriteLoading = false;
        });
      }
    }
  }

  void _showShareSheet() {
    if (kIsWeb) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Web 不支持 QQ 分享')));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('分享给 QQ 好友'),
                onTap: () {
                  Navigator.pop(context);
                  _shareToQQ(TencentScene.kScene_QQ);
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('分享到 QQ 空间'),
                onTap: () {
                  Navigator.pop(context);
                  _shareToQQ(TencentScene.kScene_QZone);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareToQQ(int scene) async {
    if (_qqAppId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QQ AppID 未配置（请检查 assets/.env）')),
      );
      return;
    }
    if (_tencent == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QQ SDK 未初始化')));
      return;
    }
    final installed = await _tencent!.isQQInstalled();
    if (!installed) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未检测到 QQ 客户端')));
      }
      return;
    }
    final product = _product;
    if (product == null) return;

    final title = product.title;
    final summary = product.summary;
    final cover = Config.resolveImage(product.coverUrl);
    final targetUrl = '${Config.imageHost}/courses/${widget.courseId}';

    await _tencent!.shareWebpage(
      scene: scene,
      title: title,
      summary: summary,
      imageUri: cover.isEmpty ? null : Uri.parse(cover),
      targetUrl: targetUrl,
      appName: 'MoocHub',
    );
  }

  Widget _buildImageGallery() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            TDSkeleton(
              animation: TDSkeletonAnimation.gradient,
              theme: TDSkeletonTheme.image,
            ),
          ],
        ),
      );
    }

    if (_loadError || _imageUrls.isEmpty) {
      return Container(
        height: 220,
        color: Colors.grey.shade100,
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey,
            size: 64,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        height: 220,
        child: Swiper(
          autoplay: true,
          itemCount: _imageUrls.length,
          loop: _imageUrls.length > 1,
          pagination: SwiperPagination(
            alignment: Alignment.bottomRight,
            builder: TDSwiperPagination.fraction,
          ),
          itemBuilder: (BuildContext context, int index) {
            final url = _imageUrls[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: TDImage(
                imgUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 220,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            TDSkeleton(
              animation: TDSkeletonAnimation.gradient,
              theme: TDSkeletonTheme.paragraph,
            ),
          ],
        ),
      );
    }

    if (_loadError || _product == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            '课程信息加载失败',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    final product = _product!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B9AAA).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '4.8',
                      style: TextStyle(
                        color: Color(0xFF1B9AAA),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '128 条评价',
                style: TextStyle(color: Colors.black45, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '播放量：${_formatCount(product.viewCount)}',
                style: const TextStyle(
                  color: Color(0xFF1B9AAA),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('级别', product.level),
              _pill('讲师', product.instructorName),
              _pill('收藏', _favoriteCount.toString()),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '课程简介',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            product.summary,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '课程详情',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildSpecItem('概述', product.summary),
          _buildSpecItem('老师', product.instructorName),
          _buildSpecItem('级别', product.level),
          const SizedBox(height: 24),
          const Text(
            '视频列表',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildVideoList(),
        ],
      ),
    );
  }

  Widget _buildVideoList() {
    if (_videos.isEmpty) {
      return const Text(
        '暂无视频',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _videos.length,
      separatorBuilder: (_, __) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final video = _videos[index];
        final cover = Config.resolveImage(video.thumbUrl);
        return InkWell(
          onTap: () {
            final id = int.tryParse(video.id);
            if (id == null) {
              return;
            }
            Navigator.pushNamed(context, '/videoDetail', arguments: id);
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: cover.isEmpty
                      ? 'https://picsum.photos/seed/v${video.id}/240/135'
                      : cover,
                  width: 120,
                  height: 68,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    width: 120,
                    height: 68,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.play_circle_outline),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'P${index + 1}  ${video.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      video.description.isEmpty ? '暂无描述' : video.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(video.durationSec),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    final m = minutes.toString().padLeft(2, '0');
    final s = remaining.toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatCount(int value) {
    if (value >= 10000) {
      final v = value / 10000.0;
      return '${v.toStringAsFixed(1)}万';
    }
    return value.toString();
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }

  Widget _buildSpecItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课程详情'),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _showShareSheet),
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
            onPressed: _favoriteLoading ? null : _toggleFavorite,
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            _buildImageGallery(),
            TDTabBar(
              tabs: const [
                TDTab(text: '课程详情'),
                TDTab(text: '评论'),
              ],
              showIndicator: true,
            ),
            Expanded(
              child: TDTabBarView(
                children: [
                  SingleChildScrollView(child: _buildProductInfo()),
                  CommentsPanel(
                    targetType: 'course',
                    targetId: widget.courseId,
                    embedded: true,
                    showHeader: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
