import 'package:MoocHub/model/ArticleModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class ArticleListPage extends StatefulWidget {
  const ArticleListPage({super.key});

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final List<ArticleModel> _articles = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadArticles(reset: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 20) {
        if (_hasMore && !_isLoading) {
          _loadArticles();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadArticles({bool reset = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    if (reset) {
      _page = 1;
      _hasMore = true;
      _articles.clear();
    }

    try {
      final resp = await _apiService.get<Map<String, dynamic>>(
        '/articles',
        queryParameters: {'page': _page, 'page_size': 10},
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final raw = resp.data['articles'];
      final List<ArticleModel> next = [];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            next.add(ArticleModel.fromJson(item));
          }
        }
      }
      setState(() {
        _articles.addAll(next);
        _page += 1;
        _hasMore = next.isNotEmpty;
      });
    } catch (_) {
      setState(() {
        _hasMore = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TDSkeleton(
          animation: TDSkeletonAnimation.gradient,
          theme: TDSkeletonTheme.paragraph,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(child: Text('暂无文章'));
  }

  Widget _buildItem(ArticleModel article) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: article.coverUrl.isEmpty
              ? Container(
                  width: 52,
                  height: 52,
                  color: Colors.grey.shade300,
                )
              : Image.network(
                  article.coverUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
        ),
        title: Text(
          article.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          article.summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          final id = int.tryParse(article.id);
          if (id == null) return;
          Navigator.pushNamed(context, '/articleDetail', arguments: id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文章'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushNamed(context, '/articlePublish')
                  .then((_) => _loadArticles(reset: true));
            },
          ),
        ],
      ),
      body: _isLoading && _articles.isEmpty
          ? _buildLoading()
          : _articles.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _articles.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _articles.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _buildItem(_articles[index]);
                  },
                ),
    );
  }
}
