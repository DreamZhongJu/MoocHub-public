import 'dart:async';

import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/model/CoursesModel.dart';
import 'package:MoocHub/model/VideoModel.dart';
import 'package:MoocHub/pages/ArticleDetailPage.dart';
import 'package:MoocHub/pages/VideoDetailPage.dart';
import 'package:MoocHub/services/AnalyticsService.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/widget/CommentsPanel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tencent_kit/tencent_kit.dart';

class CourseDetailPage extends StatefulWidget {
  final int courseId;

  const CourseDetailPage({super.key, required this.courseId});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final TextEditingController _aiQuestionController = TextEditingController();
  CoursesModel? _product;
  List<VideoModel> _videos = [];
  bool _isLoading = true;
  bool _loadError = false;
  bool _disposed = false;
  bool _favoriteLoading = false;
  bool _isFavorite = false;
  int _favoriteCount = 0;
  bool _loggedIn = false;
  bool _aiLoading = false;
  String _aiError = '';
  String _aiAnswer = '';
  String _aiTaskLabel = '';
  List<_CourseAISource> _aiSources = const [];
  List<String> _aiEntities = const [];
  bool _aiExpanded = false;

  static const int _aiPreviewChars = 1200;

  late final String _qqAppId;
  TencentKitPlatform? _tencent;
  StreamSubscription<TencentResp>? _qqShareSub;

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
    _bootstrap();
    _initTencent();
    _loadProductDetail();
    _analyticsService.trackPageView(
      contentType: 'course',
      contentId: widget.courseId,
      scene: 'course_detail',
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _qqShareSub?.cancel();
    _aiQuestionController.dispose();
    super.dispose();
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
    if (loggedIn) {
      _loadFavoriteState();
    }
  }

  void _initTencent() {
    _qqAppId = (dotenv.env['QQ_APP_ID'] ?? dotenv.env['TENCENT_APP_ID'] ?? '')
        .trim();
    if (_qqAppId.isNotEmpty && !kIsWeb) {
      _tencent = TencentKitPlatform.instance;
      _tencent!.registerApp(appId: _qqAppId);
      _qqShareSub = _tencent!.respStream().listen(_handleTencentResp);
    }
  }

  void _handleTencentResp(TencentResp resp) {
    if (resp is TencentShareMsgResp && mounted) {
      if (resp.isSuccessful) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('分享成功')));
      } else if (resp.isCancelled) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消分享')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(resp.msg ?? '分享失败')));
      }
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _disposed) return;
    setState(fn);
  }

  Future<void> _loadProductDetail() async {
    _safeSetState(() {
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
        final rawCourses = data['courses'];
        if (rawCourses is List && rawCourses.isNotEmpty) {
          final first = rawCourses.first;
          if (first is Map<String, dynamic>) {
            final product = CoursesModel.fromJson(_normalizeCourseMap(first));
            final rawVideos = data['videos'];
            final List<VideoModel> videos = [];
            if (rawVideos is List) {
              for (final item in rawVideos) {
                if (item is Map<String, dynamic>) {
                  videos.add(VideoModel.fromJson(item));
                }
              }
            }
            _safeSetState(() {
              _product = product;
              _videos = videos;
              _favoriteCount = product.favoriteCount;
              _isLoading = false;
            });
            _loadFavoriteState();
            return;
          }
        }
        _safeSetState(() {
          _loadError = true;
          _isLoading = false;
        });
      } else {
        _safeSetState(() {
          _loadError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('load product detail failed: $e');
      _safeSetState(() {
        _loadError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFavoriteState() async {
    if (!_loggedIn) return;
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/favorites',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final coursesRaw = response.data['courses'];
      if (coursesRaw is List) {
        final matched = coursesRaw.any((item) {
          if (item is Map<String, dynamic>) {
            final id = item['id'];
            if (id is num) return id.toInt() == widget.courseId;
            return id?.toString() == widget.courseId.toString();
          }
          return false;
        });
        if (mounted) {
          setState(() {
            _isFavorite = matched;
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
    final bool next = !_isFavorite;
    if (next) {
      _analyticsService.trackFavorite(
        contentType: 'course',
        contentId: widget.courseId,
      );
    }
    setState(() {
      _favoriteLoading = true;
      _isFavorite = next;
      if (next) {
        _favoriteCount += 1;
      } else if (_favoriteCount > 0) {
        _favoriteCount -= 1;
      }
    });
    try {
      if (next) {
        final resp = await _apiService.postForm<Map<String, dynamic>>(
          '/favorites/courses',
          data: {'course_id': widget.courseId.toString()},
          fromJson: (raw) =>
              (raw as Map<String, dynamic>?) ?? <String, dynamic>{},
        );
        if (resp.code != 0 && resp.code != 200) {
          throw Exception(resp.msg);
        }
      } else {
        final resp = await _apiService.delete<Map<String, dynamic>>(
          '/favorites/courses/${widget.courseId}',
          fromJson: (raw) =>
              (raw as Map<String, dynamic>?) ?? <String, dynamic>{},
        );
        if (resp.code != 0 && resp.code != 200) {
          throw Exception(resp.msg);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFavorite = !next;
          if (next) {
            if (_favoriteCount > 0) _favoriteCount -= 1;
          } else {
            _favoriteCount += 1;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _favoriteLoading = false;
        });
      }
    }
  }

  void _showShareSheet() {
    if (kIsWeb) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Web 不支持 QQ 分享')));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('分享给 QQ 好友'),
                onTap: () {
                  Navigator.pop(context);
                  _shareToQQ(TencentScene.kScene_QQ);
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('分享到 QQ 空间'),
                onTap: () {
                  Navigator.pop(context);
                  _shareToQQ(TencentScene.kScene_QZone);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareToQQ(int scene) async {
    if (_qqAppId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QQ AppID 未配置（请检查 assets/.env）')),
      );
      return;
    }
    if (_tencent == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QQ SDK 未初始化')));
      return;
    }
    final installed = await _tencent!.isQQInstalled();
    if (!installed) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未检测到 QQ 客户端')));
      }
      return;
    }
    final product = _product;
    if (product == null) return;

    final title = product.title;
    final summary = product.summary;
    final cover = Config.resolveImage(product.coverUrl);
    final targetUrl = '${Config.imageHost}/courses/${widget.courseId}';

    await _tencent!.shareWebpage(
      scene: scene,
      title: title,
      summary: summary,
      imageUri: cover.isEmpty ? null : Uri.parse(cover),
      targetUrl: targetUrl,
      appName: 'MoocHub',
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
    _safeSetState(() {
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
          'scope': 'course',
          'course_id': widget.courseId,
          'top_k': 5,
        },
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final data = resp.data;
      final rawSources = data['sources'];
      final rawEntities = data['entities'];
      _safeSetState(() {
        _aiAnswer = (data['answer']?.toString() ?? '').trim();
        _aiExpanded = false;
        _aiSources = rawSources is List
            ? rawSources
                  .where((item) => item is Map)
                  .map(
                    (item) => _CourseAISource.fromJson(
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
    } catch (_) {
      _safeSetState(() {
        _aiError = '问答请求失败，请稍后重试';
      });
    } finally {
      _safeSetState(() {
        _aiLoading = false;
      });
    }
  }

  Future<void> _summarizeCourse() {
    return _submitAIQuery(
      questionOverride: '请基于当前课程内容输出一份课程总结，包含 5 个核心知识点和 3 条学习建议。',
      taskLabel: '课程总结',
      syncInput: true,
    );
  }

  Future<void> _generatePracticeQuestions() {
    return _submitAIQuery(
      questionOverride: '请基于当前课程生成 6 道练习题，其中包含 3 道选择题、2 道简答题和 1 道判断题，并附参考答案。',
      taskLabel: '生成练习题',
      syncInput: true,
    );
  }

  Future<void> _openAISource(_CourseAISource source) async {
    if (source.sourceType == 'course' && source.bizId > 0) {
      if (source.bizId == widget.courseId) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CourseDetailPage(courseId: source.bizId),
        ),
      );
      return;
    }
    if (source.sourceType == 'article' && source.bizId > 0) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArticleDetailPage(articleId: source.bizId),
        ),
      );
      return;
    }
    if (source.sourceType == 'video' && source.bizId > 0) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoDetailPage(videoId: source.bizId),
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
    String expandLabel = '展开完整回答',
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

  // ── AI 问答区 ──────────────────────────────────────────────────────────────
  Widget _buildAISection() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D3E) : const Color(0xFFE8EDF5),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 渐变头部
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withValues(alpha: 0.72)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 智能问答',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '基于课程知识，附带引用来源',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 表单区
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 输入框
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1F2430)
                        : const Color(0xFFF8FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2A2D3E)
                          : const Color(0xFFE5EAF2),
                    ),
                  ),
                  child: TextField(
                    controller: _aiQuestionController,
                    minLines: 2,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '例如：这门课的核心知识点是什么？',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 预设快捷键
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildAIChip(
                      icon: Icons.menu_book_outlined,
                      label: '课程总结',
                      onTap: _aiLoading ? null : _summarizeCourse,
                    ),
                    _buildAIChip(
                      icon: Icons.quiz_outlined,
                      label: '生成练习题',
                      onTap: _aiLoading ? null : _generatePracticeQuestions,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 提问按钮
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _aiLoading ? null : () => _submitAIQuery(),
                    icon: _aiLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _aiLoading ? '回答生成中…' : '开始提问',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                // 错误提示
                if (_aiError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade400,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _aiError,
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // AI 回答
                if (_aiAnswer.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A2535)
                          : primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'AI 回答',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: primary,
                              ),
                            ),
                            if (_aiTaskLabel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _aiTaskLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildMarkdownBlock(
                          content: _aiAnswer,
                          expanded: _aiExpanded,
                          onToggle: () => _safeSetState(
                            () => _aiExpanded = !_aiExpanded,
                          ),
                          previewChars: _aiPreviewChars,
                        ),
                      ],
                    ),
                  ),
                ],
                // 实体标签
                if (_aiEntities.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '识别到的实体',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _aiEntities
                        .map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1F2430)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                // 引用来源
                if (_aiSources.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '引用来源',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._aiSources.map((source) {
                    final color = _sourceTypeColor(source.sourceType);
                    return GestureDetector(
                      onTap: () => _openAISource(source),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1F2430)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF2A2D3E)
                                : const Color(0xFFEEF1F6),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _sourceTypeLabel(source.sourceType),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                source.title.isEmpty
                                    ? source.sourceId
                                    : source.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIChip({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? primary.withValues(alpha: 0.15)
              : primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 封面 SliverAppBar ─────────────────────────────────────────────────────
  Widget _buildSliverCover(BuildContext context, bool innerBoxIsScrolled) {
    final primary = Theme.of(context).colorScheme.primary;
    final resolvedCover =
        _product != null ? Config.resolveImage(_product!.coverUrl) : '';

    return SliverAppBar(
      expandedHeight: 248,
      pinned: true,
      stretch: true,
      backgroundColor: primary,
      foregroundColor: Colors.white,
      title: Text(
        _product?.title ?? '课程详情',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, color: Colors.white),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: _showShareSheet,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: IconButton(
            key: ValueKey(_isFavorite),
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color:
                  _isFavorite ? Colors.redAccent.shade100 : Colors.white,
            ),
            onPressed: _favoriteLoading ? null : _toggleFavorite,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (resolvedCover.isNotEmpty)
              CachedNetworkImage(
                imageUrl: resolvedCover,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: primary.withValues(alpha: 0.3)),
                errorWidget: (_, __, ___) => Container(
                  color: primary.withValues(alpha: 0.6),
                  child: const Center(
                    child: Icon(
                      Icons.school_outlined,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else
              Container(
                color: primary.withValues(alpha: 0.6),
                child: const Center(
                  child: Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            // 顶部暗渐变（保证返回按钮可见）
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xAA000000), Color(0x00000000)],
                  stops: [0.0, 0.45],
                ),
              ),
            ),
            // 底部暗渐变（信息区可读性）
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Color(0x00000000)],
                  stops: [0.0, 0.5],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 课程信息面板（封面下方，TabBar 上方）────────────────────────────────────
  Widget _buildCourseInfoPanel() {
    final product = _product!;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF171A21) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 课程标题
          Text(
            product.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          // 统计数据行
          Row(
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                size: 14,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                '${_formatCount(product.viewCount)} 播放',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 14),
              Icon(
                Icons.favorite_border,
                size: 14,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                '${_formatCount(_favoriteCount)} 收藏',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 14),
              Icon(
                Icons.video_library_outlined,
                size: 14,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                '${_videos.length} 节',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const Spacer(),
              // 难度徽章
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  product.level.isNotEmpty ? product.level : '通用',
                  style: TextStyle(
                    fontSize: 11,
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 讲师行
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: primary.withValues(alpha: 0.12),
                child: Icon(Icons.person_rounded, size: 16, color: primary),
              ),
              const SizedBox(width: 8),
              Text(
                product.instructorName.isNotEmpty
                    ? product.instructorName
                    : '未知讲师',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '讲师',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const Spacer(),
              const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
              const SizedBox(width: 3),
              Text(
                '4.8',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 简介 Tab ─────────────────────────────────────────────────────────────
  Widget _buildIntroTab() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_loadError || _product == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              '加载失败',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            TextButton(
              onPressed: _loadProductDetail,
              child: const Text('点击重试'),
            ),
          ],
        ),
      );
    }

    final product = _product!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('课程简介'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1F2430)
                  : const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              product.summary.isNotEmpty ? product.summary : '暂无简介',
              style: TextStyle(
                fontSize: 14,
                height: 1.75,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('课程信息'),
          const SizedBox(height: 8),
          _buildInfoCard([
            _buildInfoRow(
              Icons.person_outlined,
              '讲师',
              product.instructorName.isNotEmpty
                  ? product.instructorName
                  : '未知',
            ),
            _buildInfoRow(
              Icons.signal_cellular_alt_rounded,
              '难度',
              product.level.isNotEmpty ? product.level : '通用',
            ),
            _buildInfoRow(
              Icons.video_library_outlined,
              '视频数',
              '共 ${_videos.length} 节',
            ),
            _buildInfoRow(
              Icons.remove_red_eye_outlined,
              '播放量',
              _formatCount(product.viewCount),
            ),
          ]),
          _buildAISection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── 目录 Tab（B站风格）──────────────────────────────────────────────────
  Widget _buildChapterTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无视频',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        final cover = Config.resolveImage(video.thumbUrl);

        return InkWell(
          onTap: () {
            final id = int.tryParse(video.id);
            if (id == null) return;
            Navigator.pushNamed(context, '/videoDetail', arguments: id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 集数编号
                SizedBox(
                  width: 26,
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 缩略图 + 遮罩层
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CachedNetworkImage(
                        imageUrl: cover.isEmpty
                            ? 'https://picsum.photos/seed/v${video.id}/240/135'
                            : cover,
                        width: 116,
                        height: 66,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 116,
                          height: 66,
                          color: Colors.grey.shade200,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.grey.shade400,
                            size: 28,
                          ),
                        ),
                      ),
                      // 播放按钮
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      // 时长角标
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatDuration(video.durationSec),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 标题 + 描述
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                      if (video.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          video.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 底部固定操作栏 ─────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171A21) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildBarIconButton(
            icon: _isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border,
            label: _formatCount(_favoriteCount),
            color: _isFavorite ? Colors.redAccent : Colors.grey.shade600,
            onTap: _favoriteLoading ? null : _toggleFavorite,
          ),
          const SizedBox(width: 20),
          _buildBarIconButton(
            icon: Icons.share_outlined,
            label: '分享',
            color: Colors.grey.shade600,
            onTap: _showShareSheet,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _videos.isEmpty
                    ? null
                    : () {
                        final id = int.tryParse(_videos.first.id);
                        if (id == null) return;
                        Navigator.pushNamed(
                          context,
                          '/videoDetail',
                          arguments: id,
                        );
                      },
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text(
                  '开始学习',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarIconButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── 通用 UI 帮助方法 ───────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildInfoCard(List<Widget> rows) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2430) : const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: rows),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF2D3142),
            ),
          ),
        ],
      ),
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

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F6F8),
      bottomNavigationBar: _buildBottomBar(),
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildSliverCover(context, innerBoxIsScrolled),
            if (!_isLoading && !_loadError && _product != null)
              SliverToBoxAdapter(child: _buildCourseInfoPanel()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                tabBar: TabBar(
                  tabs: const [
                    Tab(text: '简介'),
                    Tab(text: '目录'),
                    Tab(text: '评论'),
                  ],
                  labelColor: primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                ),
                backgroundColor:
                    isDark ? const Color(0xFF171A21) : Colors.white,
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _buildIntroTab(),
              _buildChapterTab(),
              CommentsPanel(
                targetType: 'course',
                targetId: widget.courseId,
                embedded: true,
                showHeader: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseAISource {
  final String sourceId;
  final String sourceType;
  final int bizId;
  final String title;
  final String sourceUrl;
  final String snippet;

  const _CourseAISource({
    required this.sourceId,
    required this.sourceType,
    required this.bizId,
    required this.title,
    required this.sourceUrl,
    required this.snippet,
  });

  factory _CourseAISource.fromJson(Map<String, dynamic> json) {
    return _CourseAISource(
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

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) =>
      tabBar != old.tabBar || backgroundColor != old.backgroundColor;
}
