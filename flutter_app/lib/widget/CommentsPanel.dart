import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class CommentsPanel extends StatefulWidget {
  final String targetType;
  final int targetId;
  final bool embedded;
  final bool showHeader;

  const CommentsPanel({
    super.key,
    required this.targetType,
    required this.targetId,
    this.embedded = false,
    this.showHeader = true,
  });

  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final PanelController _panelController = PanelController();
  final ScrollController _listController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  final Set<String> _likingIds = {};
  final Set<String> _likedIds = {};
  final Set<String> _expandedIds = {};
  final Map<String, GlobalKey> _itemKeys = {};

  bool _loading = true;
  bool _error = false;
  bool _sending = false;
  List<_CommentItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadLikedState();
    _loadComments();
  }

  @override
  void dispose() {
    _listController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _likedKey(String commentId) {
    return 'liked_${widget.targetType}_${widget.targetId}_$commentId';
  }

  Future<void> _loadLikedState() async {
    final box = await _storageService.getUserData();
    final liked = box['comment_likes'];
    if (liked is List) {
      _likedIds.addAll(liked.map((e) => e.toString()));
    }
  }

  Future<void> _persistLikedState() async {
    final data = await _storageService.getUserData();
    data['comment_likes'] = _likedIds.toList();
    await _storageService.saveUserData(data);
  }

  Future<void> _loadComments() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/comments',
        queryParameters: {
          'target_type': widget.targetType,
          'target_id': widget.targetId,
          'page': 1,
          'page_size': 20,
        },
        fromJson: (raw) => raw as Map<String, dynamic>,
      );

      if (response.code != 0 && response.code != 200) {
        throw Exception(response.msg);
      }

      final raw = response.data['items'];
      final List<_CommentItem> parsed = [];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            parsed.add(_CommentItem.fromJson(item));
          }
        }
      }

      if (mounted) {
        setState(() {
          _items = parsed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
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

  Future<void> _toggleLike(int index) async {
    final item = _items[index];
    if (item.id.isEmpty || _likingIds.contains(item.id)) return;

    final likedKey = _likedKey(item.id);
    final alreadyLiked = _likedIds.contains(likedKey);

    final token = await _storageService.getUserToken();
    if (token == null || token.toString().isEmpty || token == 'null') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录再点赞')),
        );
        await Navigator.pushNamed(context, '/login');
      }
      return;
    }

    if (alreadyLiked) {
      if (mounted) {
        setState(() {
          _likedIds.remove(likedKey);
          _items[index] =
              item.copyWith(likeCount: (item.likeCount - 1).clamp(0, 999999));
        });
      }
      await _persistLikedState();
      return;
    }

    setState(() {
      _likingIds.add(item.id);
    });

    try {
      final resp = await _apiService.post<Map<String, dynamic>>(
        '/comments/${item.id}/like',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      if (resp.code != 0 && resp.code != 200) {
        throw Exception(resp.msg);
      }
      int nextCount = item.likeCount + 1;
      final rawCount = resp.data['like_count'];
      if (rawCount is num) {
        nextCount = rawCount.toInt();
      } else if (rawCount is String) {
        nextCount = int.tryParse(rawCount) ?? nextCount;
      }

      if (mounted) {
        setState(() {
          _items[index] = item.copyWith(likeCount: nextCount);
          _likedIds.add(likedKey);
        });
      }
      await _persistLikedState();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('点赞失败，请稍后重试')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _likingIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _sending) return;

    final token = await _storageService.getUserToken();
    if (token == null || token.toString().isEmpty || token == 'null') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录再评论')),
        );
        await Navigator.pushNamed(context, '/login');
      }
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final resp = await _apiService.postForm<Map<String, dynamic>>(
        '/comments',
        data: {
          'target_type': widget.targetType,
          'target_id': widget.targetId.toString(),
          'content': content,
        },
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      if (resp.code != 0 && resp.code != 200) {
        throw Exception(resp.msg);
      }

      _commentController.clear();
      await _loadComments();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('评论发送失败')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _toggleReplies(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
    final key = _itemKeys[id];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 220),
        alignment: 0.1,
      );
    }
  }

  Widget _buildHeader() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 6) {
          _panelController.close();
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            if (widget.showHeader)
              Row(
                children: [
                  const Text(
                    '评论',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _panelController.close(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1115) : Colors.white;
    final border = isDark ? Colors.white12 : Colors.black12;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B1F28) : const Color(0xFFF3F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: '写下你的评论...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: _sending ? null : _sendComment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('发送'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ScrollController? controller) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error) {
      return Center(
        child: TextButton(
          onPressed: _loadComments,
          child: const Text('加载失败，点击重试'),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('暂无评论'));
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final item = _items[index];
        final likedKey = _likedKey(item.id);
        final expanded = _expandedIds.contains(item.id);
        final key = _itemKeys.putIfAbsent(item.id, () => GlobalKey());
        return Container(
          key: key,
          child: _CommentTile(
            item: item,
            liking: _likingIds.contains(item.id),
            liked: _likedIds.contains(likedKey),
            expanded: expanded,
            onLike: () => _toggleLike(index),
            onToggleReplies: () => _toggleReplies(item.id),
          ),
        );
      },
    );
  }

  Widget _buildPanel(ScrollController controller) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.only(bottom: bottom + 64),
            child: Column(
              children: [
                if (widget.showHeader) ...[
                  _buildHeader(),
                  const Divider(height: 1),
                ],
                Expanded(child: _buildList(controller)),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.only(bottom: bottom),
            child: _buildInputBar(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return SlidingUpPanel(
            controller: _panelController,
            minHeight: height,
            maxHeight: height,
            isDraggable: false,
            borderRadius: BorderRadius.zero,
            renderPanelSheet: false,
            color: Colors.transparent,
            panelSnapping: false,
            defaultPanelState: PanelState.OPEN,
            backdropEnabled: false,
            panelBuilder: (controller) {
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151820) : Colors.white,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildList(_listController)),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildInputBar(),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    return SlidingUpPanel(
      controller: _panelController,
      minHeight: 0,
      maxHeight: maxHeight,
      borderRadius: BorderRadius.zero,
      renderPanelSheet: false,
      color: Colors.transparent,
      panelSnapping: true,
      defaultPanelState: PanelState.OPEN,
      backdropEnabled: true,
      backdropOpacity: 0.25,
      panelBuilder: (controller) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151820) : Colors.white,
          ),
          child: _buildPanel(controller),
        );
      },
    );
  }
}

class _CommentItem {
  final String id;
  final String content;
  final int likeCount;
  final String createdAt;
  final int replyCount;

  _CommentItem({
    required this.id,
    required this.content,
    required this.likeCount,
    required this.createdAt,
    required this.replyCount,
  });

  factory _CommentItem.fromJson(Map<String, dynamic> json) {
    return _CommentItem(
      id: (json['id'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      likeCount: _intify(json['like_count']),
      createdAt: (json['created_at'] ?? '').toString(),
      replyCount: _intify(json['reply_count']),
    );
  }

  _CommentItem copyWith({int? likeCount}) {
    return _CommentItem(
      id: id,
      content: content,
      likeCount: likeCount ?? this.likeCount,
      createdAt: createdAt,
      replyCount: replyCount,
    );
  }

  static int _intify(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _CommentTile extends StatelessWidget {
  final _CommentItem item;
  final VoidCallback onLike;
  final VoidCallback onToggleReplies;
  final bool liking;
  final bool liked;
  final bool expanded;

  const _CommentTile({
    required this.item,
    required this.onLike,
    required this.onToggleReplies,
    required this.liking,
    required this.liked,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
          child: Icon(Icons.person, color: theme.colorScheme.primary, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
              if (item.replyCount > 0) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: onToggleReplies,
                  child: Text(
                    expanded ? '收起回复' : '查看更多回复',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (expanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '共 ${item.replyCount} 条回复',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    item.createdAt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: liking ? null : onLike,
                    child: Row(
                      children: [
                        Icon(
                          liked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                          size: 15,
                          color: liking
                              ? theme.colorScheme.primary
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.likeCount.toString(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: liking
                                ? theme.colorScheme.primary
                                : Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
