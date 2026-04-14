import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/model/ArticleModel.dart';
import 'package:MoocHub/pages/CourseDetailPage.dart';
import 'package:MoocHub/services/AnalyticsService.dart';
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
  final AnalyticsService _analyticsService = AnalyticsService();
  final TextEditingController _aiQuestionController = TextEditingController();
  bool _loading = true;
  ArticleModel? _article;
  bool _viewRecorded = false;
  int _viewCount = 0;
  int _likeCount = 0;
  bool _favorite = false;
  bool _favoriteLoading = false;
  bool _likeLoading = false;
  bool _loggedIn = false;
  bool _aiLoading = false;
  String _aiError = '';
  String _aiAnswer = '';
  String _aiTaskLabel = '';
  List<_ArticleAISource> _aiSources = const [];
  List<String> _aiEntities = const [];
  bool _articleExpanded = false;
  bool _aiExpanded = false;

  static const int _articlePreviewChars = 1800;
  static const int _aiPreviewChars = 1200;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _loadDetail();
    _analyticsService.trackPageView(
      contentType: 'article',
      contentId: widget.articleId,
      scene: 'article_detail',
    );
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

  @override
  void dispose() {
    _aiQuestionController.dispose();
    super.dispose();
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
        _analyticsService.trackFavorite(
          contentType: 'article',
          contentId: widget.articleId,
        );
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
      _analyticsService.trackComment(
        contentType: 'article',
        contentId: widget.articleId,
      );
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

  Future<void> _submitAIQuery({
    String? questionOverride,
    String? taskLabel,
    bool syncInput = false,
  }) async {
    final question = (questionOverride ?? _aiQuestionController.text).trim();
    if (question.isEmpty || _aiLoading) return;
    if (syncInput && questionOverride != null) {
      _aiQuestionController.text = question;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _aiLoading = true;
      _aiError = '';
      _aiTaskLabel = taskLabel ?? '自定义提问';
    });
    try {
      final resp = await _apiService.post<Map<String, dynamic>>(
        '/ai/query',
        data: {
          'query': question,
          'mode': 'local',
          'scope': 'article',
          'article_id': widget.articleId,
          'top_k': 5,
        },
        receiveTimeout: const Duration(seconds: 130),
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final data = resp.data;
      final rawSources = data['sources'];
      final rawEntities = data['entities'];
      if (!mounted) return;
      setState(() {
        _aiAnswer = (data['answer']?.toString() ?? '').trim();
        _aiExpanded = false;
        _aiSources = rawSources is List
            ? rawSources
                  .where((item) => item is Map)
                  .map(
                    (item) => _ArticleAISource.fromJson(
                      Map<String, dynamic>.from(item as Map),
                    ),
                  )
                  .toList()
            : const [];
        _aiEntities = rawEntities is List
            ? rawEntities
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList()
            : const [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = '问答请求失败，请稍后重试';
      });
    } finally {
      if (mounted) {
        setState(() {
          _aiLoading = false;
        });
      }
    }
  }

  Future<void> _summarizeArticle() {
    return _submitAIQuery(
      questionOverride: '请基于当前文章提炼 5 条核心要点，并按有序列表输出，每条不超过 40 字。',
      taskLabel: '提炼要点',
      syncInput: true,
    );
  }

  Future<void> _generatePracticeQuestions() {
    return _submitAIQuery(
      questionOverride: '请基于当前文章生成 5 道练习题，其中包含 3 道简答题和 2 道判断题，并附参考答案。',
      taskLabel: '生成练习题',
      syncInput: true,
    );
  }

  Future<void> _openAISource(_ArticleAISource source) async {
    if (source.sourceType == 'article' && source.bizId > 0) {
      if (source.bizId == widget.articleId) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArticleDetailPage(articleId: source.bizId),
        ),
      );
      return;
    }
    if (source.sourceType == 'course' && source.bizId > 0) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CourseDetailPage(courseId: source.bizId),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前来源暂不支持跳转')));
  }

  String _sourceTypeLabel(String sourceType) {
    switch (sourceType) {
      case 'course':
        return '课程';
      case 'video':
        return '视频';
      case 'article':
        return '文章';
      default:
        return '来源';
    }
  }

  Color _sourceTypeColor(String sourceType) {
    switch (sourceType) {
      case 'course':
        return const Color(0xFF1B9AAA);
      case 'video':
        return const Color(0xFF7C4DFF);
      case 'article':
        return const Color(0xFFFF7A45);
      default:
        return const Color(0xFF7A7F87);
    }
  }

  String _buildPreviewText(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars).trimRight()}\n\n...';
  }

  List<String> _splitMarkdownSegments(String content) {
    final normalized = content.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const [];

    final parts = normalized
        .split(RegExp(r'\n\s*\n'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return const [];

    const maxSegmentLength = 420;
    final segments = <String>[];
    for (final part in parts) {
      if (part.length <= maxSegmentLength || part.contains('\n')) {
        segments.add(part);
        continue;
      }
      for (var i = 0; i < part.length; i += maxSegmentLength) {
        final end = (i + maxSegmentLength).clamp(0, part.length);
        segments.add(part.substring(i, end).trim());
      }
    }
    return segments.where((part) => part.isNotEmpty).toList();
  }

  Widget _buildMarkdownBlock({
    required String content,
    required bool expanded,
    required VoidCallback onToggle,
    required int previewChars,
    String expandLabel = '展开全文',
    String collapseLabel = '收起',
  }) {
    if (content.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final shouldCollapse = content.length > previewChars;
    final visibleContent = !shouldCollapse || expanded
        ? content
        : _buildPreviewText(content, previewChars);

    final segments = _splitMarkdownSegments(visibleContent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...segments.map(
          (segment) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MarkdownBody(data: segment, selectable: false),
          ),
        ),
        if (shouldCollapse)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: onToggle,
              child: Text(expanded ? collapseLabel : expandLabel),
            ),
          ),
      ],
    );
  }

  Widget _buildAISection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LightRAG 问答',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            '基于当前文章内容提问，回答会附带引用来源。',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _aiQuestionController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '例如：这篇文章如何解释汉朝的建立过程？',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _aiLoading ? null : _summarizeArticle,
                icon: const Icon(Icons.summarize_outlined, size: 18),
                label: const Text('提炼要点'),
              ),
              OutlinedButton.icon(
                onPressed: _aiLoading ? null : _generatePracticeQuestions,
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: const Text('生成练习题'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _aiLoading ? null : () => _submitAIQuery(),
                  child: Text(_aiLoading ? '回答生成中...' : '开始提问'),
                ),
              ),
            ],
          ),
          if (_aiError.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_aiError, style: const TextStyle(color: Colors.red)),
          ],
          if (_aiAnswer.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  '回答',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (_aiTaskLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B9AAA).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _aiTaskLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B9AAA),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _buildMarkdownBlock(
              content: _aiAnswer,
              expanded: _aiExpanded,
              onToggle: () {
                setState(() {
                  _aiExpanded = !_aiExpanded;
                });
              },
              previewChars: _aiPreviewChars,
              expandLabel: '展开完整回答',
            ),
          ],
          if (_aiEntities.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '识别到的实体',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _aiEntities
                  .map((item) => Chip(label: Text(item)))
                  .toList(),
            ),
          ],
          if (_aiSources.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '引用来源',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._aiSources.map(
              (source) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _sourceTypeColor(
                            source.sourceType,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _sourceTypeLabel(source.sourceType),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _sourceTypeColor(source.sourceType),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          source.title.isEmpty ? source.sourceId : source.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: source.snippet.isEmpty
                      ? Text(source.sourceId)
                      : Text(
                          source.snippet,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openAISource(source),
                ),
              ),
            ),
          ],
        ],
      ),
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
            _buildMarkdownBlock(
              content: article.content,
              expanded: _articleExpanded,
              onToggle: () {
                setState(() {
                  _articleExpanded = !_articleExpanded;
                });
              },
              previewChars: _articlePreviewChars,
            ),
            const SizedBox(height: 24),
            _buildAISection(),
          ],
        ),
      ),
    );
  }
}

class _ArticleAISource {
  final String sourceId;
  final String sourceType;
  final int bizId;
  final String title;
  final String sourceUrl;
  final String snippet;

  const _ArticleAISource({
    required this.sourceId,
    required this.sourceType,
    required this.bizId,
    required this.title,
    required this.sourceUrl,
    required this.snippet,
  });

  factory _ArticleAISource.fromJson(Map<String, dynamic> json) {
    return _ArticleAISource(
      sourceId: json['source_id']?.toString() ?? '',
      sourceType: json['source_type']?.toString() ?? '',
      bizId: json['biz_id'] is num
          ? (json['biz_id'] as num).toInt()
          : int.tryParse(json['biz_id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? '',
      sourceUrl: json['source_url']?.toString() ?? '',
      snippet: json['snippet']?.toString() ?? '',
    );
  }
}
