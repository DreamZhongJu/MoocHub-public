import 'package:MoocHub/services/ApiService.dart';
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
  bool _loading = true;
  bool _error = false;
  List<_CommentItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _CommentTile(item: item);
      },
    );
  }
}

class _CommentItem {
  final String content;
  final int likeCount;
  final String createdAt;

  _CommentItem({
    required this.content,
    required this.likeCount,
    required this.createdAt,
  });

  factory _CommentItem.fromJson(Map<String, dynamic> json) {
    return _CommentItem(
      content: (json['content'] ?? '').toString(),
      likeCount: _intify(json['like_count']),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  static int _intify(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _CommentTile extends StatelessWidget {
  final _CommentItem item;

  const _CommentTile({required this.item});

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
                  Icon(Icons.thumb_up_alt_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    item.likeCount.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
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
