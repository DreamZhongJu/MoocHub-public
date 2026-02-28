import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/model/ArticleModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class ArticleDetailPage extends StatefulWidget {
  final int articleId;
  const ArticleDetailPage({super.key, required this.articleId});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  bool _loading = true;
  ArticleModel? _article;
  bool _viewRecorded = false;
  int _viewCount = 0;
  int _likeCount = 0;
  bool _favorite = false;
  bool _favoriteLoading = false;
  bool _likeLoading = false;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _loadDetail();
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
  }

  Future<void> _loadDetail() async {
    try {
      final resp = await _apiService.get<Map<String, dynamic>>(
        '/articles/${widget.articleId}',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final raw = resp.data['article'];
      if (raw is Map<String, dynamic>) {
        final article = ArticleModel.fromJson(raw);
        setState(() {
          _article = article;
          _viewCount = article.viewCount;
          _likeCount = article.likeCount;
        });
        await _recordView();
        await _loadFavoriteState();
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _recordView() async {
    if (_viewRecorded) return;
    _viewRecorded = true;
    try {
      final resp = await _apiService.post<Map<String, dynamic>>(
        '/articles/${widget.articleId}/view',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      if (_article != null && mounted) {
        final viewCount = resp.data['view_count'];
        setState(() {
          _viewCount = viewCount is num ? viewCount.toInt() : _viewCount + 1;
        });
      }
    } catch (_) {
      if (mounted && _article != null) {
        setState(() {
          _viewCount += 1;
        });
      }
    }
  }

  Future<void> _loadFavoriteState() async {
    if (!_loggedIn) return;
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/favorites',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final articles = response.data['articles'];
      if (articles is List) {
        final exists = articles.any((item) {
          if (item is Map<String, dynamic>) {
            final id = item['id'];
            if (id is num) return id.toInt() == widget.articleId;
            return id?.toString() == widget.articleId.toString();
          }
          return false;
        });
        if (mounted) {
          setState(() {
            _favorite = exists;
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
    setState(() {
      _favoriteLoading = true;
    });
    try {
      if (_favorite) {
        await _apiService.delete<Map<String, dynamic>>(
          '/favorites/articles/${widget.articleId}',
          fromJson: (raw) =>
              (raw as Map<String, dynamic>?) ?? <String, dynamic>{},
        );
        if (mounted) {
          setState(() {
            _favorite = false;
          });
        }
      } else {
        await _apiService.postForm<Map<String, dynamic>>(
          '/favorites/articles',
          data: {'article_id': widget.articleId.toString()},
          fromJson: (raw) =>
              (raw as Map<String, dynamic>?) ?? <String, dynamic>{},
        );
        if (mounted) {
          setState(() {
            _favorite = true;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _favoriteLoading = false;
        });
      }
    }
  }

  Future<void> _likeArticle() async {
    if (!_loggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先登录')));
      }
      return;
    }
    if (_likeLoading) return;
    setState(() {
      _likeLoading = true;
    });
    try {
      final resp = await _apiService.post<Map<String, dynamic>>(
        '/articles/${widget.articleId}/like',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final likeCount = resp.data['like_count'];
      if (mounted && _article != null) {
        setState(() {
          _likeCount = likeCount is num ? likeCount.toInt() : _likeCount + 1;
        });
      }
    } catch (_) {
      if (mounted && _article != null) {
        setState(() {
          _likeCount += 1;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _likeLoading = false;
        });
      }
    }
  }

  Widget _buildCover(String coverUrl) {
    final resolved = Config.resolveImage(coverUrl);
    if (resolved.isEmpty) {
      return Container(
        height: 180,
        width: double.infinity,
        color: Colors.grey.shade100,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
          size: 48,
        ),
      );
    }

    return TDImage(
      imgUrl: resolved,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 180,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final article = _article;
    if (article == null) {
      return const Scaffold(body: Center(child: Text('文章加载失败')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('文章详情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildCover(article.coverUrl),
            ),
            const SizedBox(height: 12),
            Text(
              article.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '阅读 $_viewCount',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Text(
                  '点赞 $_likeCount',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Text(
                  article.createdAt.toLocal().toString().split(' ').first,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _likeLoading ? null : _likeArticle,
                  icon: const Icon(Icons.thumb_up),
                  label: const Text('点赞'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _favoriteLoading ? null : _toggleFavorite,
                  icon: Icon(
                    _favorite ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  label: Text(_favorite ? '已收藏' : '收藏'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MarkdownBody(data: article.content, selectable: true),
          ],
        ),
      ),
    );
  }
}
