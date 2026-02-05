import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:flutter/material.dart';

class CommentsPanel extends StatefulWidget {
  final String targetType;
  final int targetId;

  const CommentsPanel({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  bool _loading = true;
  bool _error = false;
  List<_CommentItem> _items = [];
  final Set<String> _likingIds = {};
  final Set<String> _likedIds = {};
  final TextEditingController _commentController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadLikedState();
    _loadComments();
  }

  @override
  void dispose() {
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
          _items[index] = item.copyWith(likeCount: (item.likeCount - 1).clamp(0, 999999));
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

  @override
  Widget build(BuildContext context) {
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: '写下你的评论...',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _sending ? null : _sendComment,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('发送'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final item = _items[index];
              final likedKey = _likedKey(item.id);
              return _CommentTile(
                item: item,
                liking: _likingIds.contains(item.id),
                liked: _likedIds.contains(likedKey),
                onLike: () => _toggleLike(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CommentItem {
  final String id;
  final String content;
  final int likeCount;
  final String createdAt;

  _CommentItem({
    required this.id,
    required this.content,
    required this.likeCount,
    required this.createdAt,
  });

  factory _CommentItem.fromJson(Map<String, dynamic> json) {
    return _CommentItem(
      id: (json['id'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      likeCount: _intify(json['like_count']),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  _CommentItem copyWith({int? likeCount}) {
    return _CommentItem(
      id: id,
      content: content,
      likeCount: likeCount ?? this.likeCount,
      createdAt: createdAt,
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
  final bool liking;
  final bool liked;

  const _CommentTile({
    required this.item,
    required this.onLike,
    required this.liking,
    required this.liked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
          child: Icon(Icons.person, color: theme.colorScheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.content,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    item.createdAt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: liking ? null : onLike,
                    child: Row(
                      children: [
                        Icon(
                          liked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                          size: 16,
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
