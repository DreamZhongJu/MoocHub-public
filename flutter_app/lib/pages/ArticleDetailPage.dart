import 'package:MoocHub/model/ArticleModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ArticleDetailPage extends StatefulWidget {
  final int articleId;
  const ArticleDetailPage({super.key, required this.articleId});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  ArticleModel? _article;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final resp = await _apiService.get<Map<String, dynamic>>(
        '/articles/${widget.articleId}',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final raw = resp.data['article'];
      if (raw is Map<String, dynamic>) {
        setState(() {
          _article = ArticleModel.fromJson(raw);
        });
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final article = _article;
    if (article == null) {
      return const Scaffold(
        body: Center(child: Text('文章加载失败')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('文章详情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.coverUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  article.coverUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
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
                  '阅读 ${article.viewCount}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Text(
                  '点赞 ${article.likeCount}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Text(
                  article.createdAt.toLocal().toString().split(' ').first,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MarkdownBody(
              data: article.content,
              selectable: true,
            ),
          ],
        ),
      ),
    );
  }
}
