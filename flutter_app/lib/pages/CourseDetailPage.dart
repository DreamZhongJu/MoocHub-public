import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/model/CoursesModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/widget/CommentsPanel.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:badges/badges.dart' as badges;

class CourseDetailPage extends StatefulWidget {
  final int courseId;

  const CourseDetailPage({super.key, required this.courseId});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  final ApiService _apiService = ApiService();
  CoursesModel? _product;
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
            setState(() {
              _product = product;
              _imageUrls = resolvedImage.isEmpty ? [] : [resolvedImage];
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
          height: 360,
          width: double.infinity,
          color: Colors.white,
        ),
      );
    }

    if (_loadError || _imageUrls.isEmpty) {
      return Container(
        height: 360,
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

    return Column(
      children: [
        Container(
          height: 320,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueGrey.shade50, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: _imageUrls[_selectedImageIndex],
                fit: BoxFit.cover,
                width: double.infinity,
                height: 300,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: double.infinity,
                    height: 300,
                    color: Colors.white,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade200,
                  child: Image.asset(
                    Config.defaultProductAsset,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _imageUrls.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedImageIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 70,
                  height: 70,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedImageIndex == index
                          ? const Color(0xFF1B9AAA)
                          : Colors.grey.shade300,
                      width: _selectedImageIndex == index ? 2 : 1,
                    ),
                    boxShadow: [
                      if (_selectedImageIndex == index)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: _imageUrls[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey.shade200),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: Image.asset(
                          Config.defaultProductAsset,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
                '播放量：${product.viewCount}',
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
        ],
      ),
    );
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
            const TabBar(
              tabs: [
                Tab(text: '课程详情'),
                Tab(text: '评论'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    child: _buildProductInfo(),
                  ),
                  CommentsPanel(
                    targetType: 'course',
                    targetId: widget.courseId,
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
