import 'package:MoocHub/model/ArticleModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/widget/AppStateWidgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ArticleListPage extends StatefulWidget {
  const ArticleListPage({super.key});

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final ScrollController _scrollController = ScrollController();
  final List<ArticleModel> _articles = <ArticleModel>[];

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _weakNetwork = false;
  bool _usingOfflineCache = false;
  String _networkHint = '';

  int _page = 1;
  static const int _pageSize = 10;
  static const String _cacheKey = 'article_list_v1_page_1';

  @override
  void initState() {
    super.initState();
    _loadArticles(reset: true);
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 0) return;
      if (_scrollController.position.userScrollDirection !=
          ScrollDirection.reverse) {
        return;
      }
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 20) {
        if (_hasMore && !_isLoading && !_isLoadingMore) {
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

  Future<bool> _applyCache({Duration? maxAge}) async {
    final payload = await _storageService.getOfflinePayload(
      _cacheKey,
      maxAge: maxAge,
    );
    if (payload == null) return false;
    final raw = payload['articles'];
    if (raw is! List) return false;

    final list = <ArticleModel>[];
    for (final item in raw) {
      if (item is Map) {
        list.add(ArticleModel.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    if (list.isEmpty) return false;
    if (!mounted) return true;

    setState(() {
      _articles
        ..clear()
        ..addAll(list);
    });
    return true;
  }

  Future<void> _saveCache(List<ArticleModel> items) async {
    await _storageService.saveOfflinePayload(_cacheKey, {
      'articles': items.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> _loadArticles({bool reset = false}) async {
    if (_isLoading || _isLoadingMore) return;

    bool usedCache = false;
    if (mounted) {
      setState(() {
        if (reset) {
          _isLoading = true;
          _weakNetwork = false;
          _usingOfflineCache = false;
          _networkHint = '';
        } else {
          _isLoadingMore = true;
        }
      });
    }

    if (reset) {
      _page = 1;
      _hasMore = true;
      _articles.clear();
      usedCache = await _applyCache(maxAge: const Duration(hours: 8));
      if (usedCache && mounted) {
        setState(() {
          _usingOfflineCache = true;
        });
      }
    }

    try {
      final resp = await _apiService.getWithRetry<Map<String, dynamic>>(
        '/articles',
        queryParameters: {'page': _page, 'page_size': _pageSize},
        fromJson: (raw) => raw as Map<String, dynamic>,
        retries: 2,
        baseDelay: const Duration(milliseconds: 320),
      );
      final raw = resp.data['articles'];
      final next = <ArticleModel>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            next.add(ArticleModel.fromJson(item));
          }
        }
      }

      final existingIds = _articles.map((item) => item.id).toSet();
      final filtered = next
          .where((item) => !existingIds.contains(item.id))
          .toList();

      if (mounted) {
        setState(() {
          _articles.addAll(filtered);
          _page += 1;
          _hasMore = filtered.isNotEmpty && filtered.length == _pageSize;
          if (reset) {
            _weakNetwork = false;
            _usingOfflineCache = false;
            _networkHint = '';
          }
        });
      }

      if (reset) {
        await _saveCache(next);
      }
    } catch (_) {
      if (reset) {
        final fallback = usedCache
            ? true
            : await _applyCache(maxAge: const Duration(days: 3));
        if (mounted) {
          setState(() {
            _usingOfflineCache = fallback;
            _weakNetwork = true;
            _networkHint = fallback
                ? '\u7f51\u7edc\u8f83\u5f31\uff0c\u5df2\u5c55\u793a\u79bb\u7ebf\u7f13\u5b58\u6587\u7ae0'
                : '\u7f51\u7edc\u5f02\u5e38\uff0c\u8bf7\u4e0b\u62c9\u91cd\u8bd5';
            if (!fallback) {
              _hasMore = false;
            }
          });
        }
      } else if (mounted) {
        setState(() {
          _weakNetwork = true;
          _networkHint =
              '\u7f51\u7edc\u8f83\u5f31\uff0c\u4e0b\u4e00\u9875\u52a0\u8f7d\u5931\u8d25';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Widget _buildLoading() {
    return const AppListSkeleton(
      itemCount: 6,
      itemHeight: 96,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
    );
  }

  Widget _buildEmpty() {
    return AppEmptyState(
      icon: Icons.article_outlined,
      title: '\u6682\u65e0\u6587\u7ae0',
      subtitle: _weakNetwork
          ? '\u8bf7\u68c0\u67e5\u7f51\u7edc\u540e\u91cd\u8bd5'
          : '\u7a0d\u540e\u518d\u6765\u770b\u770b',
      actionText: '\u91cd\u65b0\u52a0\u8f7d',
      onAction: () => _loadArticles(reset: true),
    );
  }

  Widget _buildItem(ArticleModel article) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: article.coverUrl.isEmpty
              ? Container(width: 52, height: 52, color: Colors.grey.shade300)
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

  Widget _buildListBody() {
    if (_isLoading && _articles.isEmpty) {
      return _buildLoading();
    }
    if (_articles.isEmpty) {
      return _buildEmpty();
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: _articles.length + (_isLoadingMore && _hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _articles.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: AppShimmerBlock(height: 14),
          );
        }
        return _buildItem(_articles[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('\u6587\u7ae0'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/articlePublish',
              ).then((_) => _loadArticles(reset: true));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadArticles(reset: true),
        child: Column(
          children: [
            if (_weakNetwork || _usingOfflineCache)
              AppWeakNetworkBanner(
                text: _networkHint.isNotEmpty
                    ? _networkHint
                    : (_usingOfflineCache
                          ? '\u5df2\u5c55\u793a\u79bb\u7ebf\u7f13\u5b58\u5185\u5bb9'
                          : '\u5f53\u524d\u7f51\u7edc\u8f83\u5f31'),
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              ),
            Expanded(child: _buildListBody()),
          ],
        ),
      ),
    );
  }
}
