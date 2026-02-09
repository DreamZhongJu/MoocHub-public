import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/model/CoursesModel.dart';
import 'package:MoocHub/model/VideoModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/widget/CommentsPanel.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter_swiper_null_safety/flutter_swiper_null_safety.dart';

class CourseDetailPage extends StatefulWidget {
  final int courseId;

  const CourseDetailPage({super.key, required this.courseId});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  final ApiService _apiService = ApiService();
  CoursesModel? _product;
  List<VideoModel> _videos = [];
  bool _isLoading = true;
  bool _loadError = false;
  int _selectedImageIndex = 0;
  List<String> _imageUrls = [];

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
    _loadProductDetail();
  }

  Future<void> _loadProductDetail() async {
    setState(() {
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
        final rawCourses = data is Map<String, dynamic> ? data['courses'] : null;
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
            setState(() {
              _product = product;
              _imageUrls = resolvedImage.isEmpty ? [] : [resolvedImage];
              _videos = videos;
              _isLoading = false;
            });
            return;
          }
        }
        setState(() {
          _loadError = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _loadError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('load product detail failed: $e');
      setState(() {
        _loadError = true;
        _isLoading = false;
      });
    }
  }

  Widget _buildImageGallery() {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 220,
          width: double.infinity,
          color: Colors.white,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(width: 200, height: 24, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(width: 150, height: 20, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                width: double.infinity,
                height: 60,
                color: Colors.white,
              ),
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
              badges.Badge(
                badgeStyle: const badges.BadgeStyle(
                  badgeColor: Color(0xFF1B9AAA),
                ),
                badgeContent: const Text(
                  '4.8',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                child: const Icon(Icons.star, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 4),
              const Text(
                '4.8 (128 reviews)',
                style: TextStyle(color: Colors.grey, fontSize: 14),
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
              _pill('收藏', product.favoriteCount.toString()),
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
            Navigator.pushNamed(
              context,
              '/videoDetail',
              arguments: id,
            );
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
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
          IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
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
                  SingleChildScrollView(
                    child: _buildProductInfo(),
                  ),
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

