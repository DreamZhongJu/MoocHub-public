import 'package:MoocHub/model/CoursesModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/widget/CoursesCard.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  List<CoursesModel> _recommendedProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendedProducts();
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
          onTap: () {},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SmartRefresher(
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
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Home Page Content',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 10),
            _buildRecommendedProducts(),
            const SizedBox(height: 800), // Added space to enable scrolling
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
