import 'package:MoocHub/model/CoursesModel.dart';
import 'package:MoocHub/model/VideoModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/widget/CoursesCard.dart';
import 'package:flutter/material.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();

  late final TabController _tabController;
  bool _loading = true;
  bool _loggedIn = false;
  List<CoursesModel> _courses = [];
  List<VideoModel> _videos = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await _storageService.getUserToken();
    final loggedIn = token != null && token.toString().isNotEmpty && token != 'null';
    if (mounted) {
      setState(() {
        _loggedIn = loggedIn;
      });
    }
    if (!loggedIn) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }
    await _loadFavorites();
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

  Future<void> _loadFavorites() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/favorites',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      if (response.code != 0 && response.code != 200) {
        throw Exception(response.msg);
      }

      final coursesRaw = response.data['courses'];
      final videosRaw = response.data['videos'];

      final List<CoursesModel> nextCourses = [];
      if (coursesRaw is List) {
        for (final item in coursesRaw) {
          if (item is Map<String, dynamic>) {
            nextCourses.add(CoursesModel.fromJson(_normalizeCourseMap(item)));
          }
        }
      }

      final List<VideoModel> nextVideos = [];
      if (videosRaw is List) {
        for (final item in videosRaw) {
          if (item is Map<String, dynamic>) {
            nextVideos.add(VideoModel.fromJson(item));
          }
        }
      }

      if (mounted) {
        setState(() {
          _courses = nextCourses;
          _videos = nextVideos;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _courses = [];
          _videos = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _buildEmpty(String text) {
    return Center(
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildCourses() {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: CoursesCardSkeleton(),
        ),
      );
    }

    if (_courses.isEmpty) {
      return _buildEmpty('暂无收藏课程');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CoursesCard(
            title: course.title,
            summary: course.summary,
            coverUrl: course.coverUrl,
            viewCount: course.viewCount,
            favoriteCount: course.favoriteCount,
            onTap: () {
              final id = int.tryParse(course.id);
              if (id == null) return;
              Navigator.pushNamed(context, '/courseDetail', arguments: id);
            },
          ),
        );
      },
    );
  }

  Widget _buildVideos() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_videos.isEmpty) {
      return _buildEmpty('暂无收藏视频');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _videos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final video = _videos[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: video.thumbUrl.isNotEmpty
                  ? Image.network(
                      video.thumbUrl,
                      width: 60,
                      height: 40,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 60,
                      height: 40,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.play_arrow, size: 20),
                    ),
            ),
            title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              video.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final id = int.tryParse(video.id);
              if (id == null) return;
              Navigator.pushNamed(context, '/videoDetail', arguments: id);
            },
          ),
        );
      },
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('需要登录后查看收藏'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/login');
              if (result == true) {
                await _bootstrap();
              }
            },
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '课程'),
            Tab(text: '视频'),
          ],
        ),
      ),
      body: !_loggedIn
          ? _buildLoginRequired()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCourses(),
                _buildVideos(),
              ],
            ),
    );
  }
}
