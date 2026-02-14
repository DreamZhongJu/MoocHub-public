import 'dart:async';

import 'package:MoocHub/model/ArticleModel.dart';
import 'package:MoocHub/model/CoursesModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/widget/ArticleCard.dart';
import 'package:MoocHub/widget/CoursesCard.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class SearchPage extends StatefulWidget {
  final String initialKeyword;
  final String initialScope;
  final String initialSort;

  const SearchPage({
    super.key,
    this.initialKeyword = '',
    this.initialScope = 'all',
    this.initialSort = 'default',
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _suggestTimer;

  bool _loading = false;
  bool _searched = false;
  bool _showSuggest = false;
  String _keyword = '';
  String _scope = 'all';
  String _sort = 'default';

  int _totalCourses = 0;
  int _totalArticles = 0;
  List<String> _suggestions = [];
  List<_SearchFeedItem> _items = [];

  @override
  void initState() {
    super.initState();
    _scope = widget.initialScope;
    _sort = widget.initialSort;
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && mounted) {
        setState(() {
          _showSuggest = false;
        });
      }
    });
    if (widget.initialKeyword.trim().isNotEmpty) {
      _searchController.text = widget.initialKeyword.trim();
      _keyword = widget.initialKeyword.trim();
      _search(submit: true);
    }
  }

  @override
  void dispose() {
    _suggestTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

  Map<String, dynamic> _normalizeArticleMap(Map<String, dynamic> json) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': _stringify(json['id']),
      'user_id': _stringify(json['user_id']),
      'title': _stringify(json['title']),
      'summary': _stringify(json['summary']),
      'cover_url': _stringify(json['cover_url']),
      'content': _stringify(json['content']),
      'status': _stringify(json['status']),
      'view_count': _intify(json['view_count']),
      'like_count': _intify(json['like_count']),
      'created_at': _stringify(json['created_at']).isEmpty
          ? now
          : _stringify(json['created_at']),
      'updated_at': _stringify(json['updated_at']).isEmpty
          ? now
          : _stringify(json['updated_at']),
    };
  }

  List<_SearchFeedItem> _mixFeedItems(
    List<CoursesModel> courses,
    List<ArticleModel> articles,
  ) {
    if (_scope == 'course') {
      return courses.map(_SearchFeedItem.course).toList();
    }
    if (_scope == 'article') {
      return articles.map(_SearchFeedItem.article).toList();
    }

    final result = <_SearchFeedItem>[];
    int i = 0;
    int j = 0;
    while (i < courses.length || j < articles.length) {
      for (var k = 0; k < 2 && i < courses.length; k++) {
        result.add(_SearchFeedItem.course(courses[i]));
        i++;
      }
      if (j < articles.length) {
        result.add(_SearchFeedItem.article(articles[j]));
        j++;
      }
    }
    return result;
  }

  Future<void> _loadSuggestions(String keyword) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/search/suggest',
        queryParameters: {'keyword': keyword, 'limit': 8},
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final raw = response.data['suggestions'];
      final next = <String>[];
      if (raw is List) {
        for (final item in raw) {
          final text = item?.toString() ?? '';
          if (text.isNotEmpty) {
            next.add(text);
          }
        }
      }
      if (!mounted) return;
      if (_searchController.text.trim() != keyword) return;
      setState(() {
        _suggestions = next;
        _showSuggest = _searchFocusNode.hasFocus && next.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _showSuggest = false;
      });
    }
  }

  void _onSearchTextChanged(String value) {
    final keyword = value.trim();
    _suggestTimer?.cancel();
    setState(() {
      _keyword = keyword;
      if (keyword.isEmpty) {
        _searched = false;
        _showSuggest = false;
        _suggestions = [];
        _items = [];
        _totalCourses = 0;
        _totalArticles = 0;
      }
    });
    if (keyword.isEmpty) return;
    _suggestTimer = Timer(const Duration(milliseconds: 280), () {
      _loadSuggestions(keyword);
    });
  }

  Future<void> _search({bool submit = false, String? keyword}) async {
    final nextKeyword = (keyword ?? _searchController.text).trim();
    if (nextKeyword.isEmpty) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _keyword = nextKeyword;
      _loading = true;
      _showSuggest = false;
      if (submit) {
        _searched = true;
      }
    });

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/search',
        queryParameters: {
          'keyword': nextKeyword,
          'scope': _scope,
          'sort': _sort,
          'page': 1,
          'page_size': 30,
        },
        fromJson: (raw) => raw as Map<String, dynamic>,
      );

      final coursesRaw = response.data['courses'];
      final articlesRaw = response.data['articles'];

      final courses = <CoursesModel>[];
      if (coursesRaw is List) {
        for (final item in coursesRaw) {
          if (item is Map<String, dynamic>) {
            courses.add(CoursesModel.fromJson(_normalizeCourseMap(item)));
          }
        }
      }

      final articles = <ArticleModel>[];
      if (articlesRaw is List) {
        for (final item in articlesRaw) {
          if (item is Map<String, dynamic>) {
            articles.add(ArticleModel.fromJson(_normalizeArticleMap(item)));
          }
        }
      }

      int totalCourses = 0;
      final totalCoursesRaw = response.data['total_courses'];
      if (totalCoursesRaw is num) {
        totalCourses = totalCoursesRaw.toInt();
      } else {
        totalCourses = int.tryParse(totalCoursesRaw?.toString() ?? '') ?? 0;
      }

      int totalArticles = 0;
      final totalArticlesRaw = response.data['total_articles'];
      if (totalArticlesRaw is num) {
        totalArticles = totalArticlesRaw.toInt();
      } else {
        totalArticles = int.tryParse(totalArticlesRaw?.toString() ?? '') ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _searched = true;
        _items = _mixFeedItems(courses, articles);
        _totalCourses = totalCourses;
        _totalArticles = totalArticles;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searched = true;
        _items = [];
        _totalCourses = 0;
        _totalArticles = 0;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<MapEntry<String, String>> _sortOptions() {
    if (_scope == 'course') {
      return const [
        MapEntry('default', '综合'),
        MapEntry('view_count', '观看'),
        MapEntry('favorite_count', '收藏'),
        MapEntry('created_at', '最新'),
      ];
    }
    if (_scope == 'article') {
      return const [
        MapEntry('default', '综合'),
        MapEntry('view_count', '阅读'),
        MapEntry('like_count', '点赞'),
        MapEntry('created_at', '最新'),
      ];
    }
    return const [
      MapEntry('default', '综合'),
      MapEntry('view_count', '热度'),
      MapEntry('created_at', '最新'),
    ];
  }

  void _setScope(String scope) {
    if (_scope == scope) return;
    setState(() {
      _scope = scope;
      _sort = 'default';
    });
    if (_searched && _keyword.isNotEmpty) {
      _search();
    }
  }

  void _setSort(String sort) {
    if (_sort == sort) return;
    setState(() {
      _sort = sort;
    });
    if (_searched && _keyword.isNotEmpty) {
      _search();
    }
  }

  Widget _buildSuggestions() {
    if (!_showSuggest || _suggestions.isEmpty) return const SizedBox.shrink();
    final items = _suggestions.take(8).toList();
    final maxHeight = MediaQuery.of(context).size.height * 0.32;
    final estimatedHeight = items.length * 52.0;
    final panelHeight = estimatedHeight.clamp(52.0, maxHeight).toDouble();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SizedBox(
        height: panelHeight,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          physics: estimatedHeight > maxHeight
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.history, size: 18),
              title: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                _searchController.text = item;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: item.length),
                );
                _search(keyword: item, submit: true);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultItem(_SearchFeedItem item) {
    if (item.isArticle && item.article != null) {
      final article = item.article!;
      return SizedBox(
        height: 168,
        child: ArticleCard(
          title: article.title,
          summary: article.summary,
          coverUrl: article.coverUrl,
          viewCount: article.viewCount,
          likeCount: article.likeCount,
          highlightKeyword: _keyword,
          onTap: () {
            final id = int.tryParse(article.id);
            if (id == null) return;
            Navigator.pushNamed(context, '/articleDetail', arguments: id);
          },
        ),
      );
    }

    final course = item.course!;
    return SizedBox(
      height: 168,
      child: CoursesCard(
        title: course.title,
        summary: course.summary,
        coverUrl: course.coverUrl,
        viewCount: course.viewCount,
        favoriteCount: course.favoriteCount,
        highlightKeyword: _keyword,
        onTap: () {
          final id = int.tryParse(course.id);
          if (id == null) return;
          Navigator.pushNamed(context, '/courseDetail', arguments: id);
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_searched) {
      return const Center(
        child: Text('输入关键词后点击搜索', style: TextStyle(color: Colors.grey)),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          '没有找到“$_keyword”相关结果',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemBuilder: (context, index) => _buildResultItem(_items[index]),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: _items.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TDSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  placeHolder: '搜索课程/文章/讲师',
                  action: '搜索',
                  onTextChanged: _onSearchTextChanged,
                  onSubmitted: (value) => _search(keyword: value, submit: true),
                  onActionClick: (_) => _search(submit: true),
                ),
                _buildSuggestions(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('全部'),
                      selected: _scope == 'all',
                      onSelected: (_) => _setScope('all'),
                    ),
                    ChoiceChip(
                      label: const Text('课程'),
                      selected: _scope == 'course',
                      onSelected: (_) => _setScope('course'),
                    ),
                    ChoiceChip(
                      label: const Text('文章'),
                      selected: _scope == 'article',
                      onSelected: (_) => _setScope('article'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sortOptions()
                      .map(
                        (entry) => ChoiceChip(
                          label: Text(entry.value),
                          selected: _sort == entry.key,
                          onSelected: (_) => _setSort(entry.key),
                        ),
                      )
                      .toList(),
                ),
                if (_searched)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '课程$_totalCourses 条，文章$_totalArticles 条',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}

class _SearchFeedItem {
  final CoursesModel? course;
  final ArticleModel? article;
  bool get isArticle => article != null;

  const _SearchFeedItem._({this.course, this.article});

  factory _SearchFeedItem.course(CoursesModel course) =>
      _SearchFeedItem._(course: course);

  factory _SearchFeedItem.article(ArticleModel article) =>
      _SearchFeedItem._(article: article);
}
