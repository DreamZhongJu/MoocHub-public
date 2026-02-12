import 'package:MoocHub/config/Config.dart';

class ArticleModel {
  final String id;
  final String userId;
  final String title;
  final String summary;
  final String coverUrl;
  final String content;
  final String status;
  final int viewCount;
  final int likeCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ArticleModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.summary,
    required this.coverUrl,
    required this.content,
    required this.status,
    required this.viewCount,
    required this.likeCount,
    required this.createdAt,
    required this.updatedAt,
  });

  ArticleModel.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString() ?? '',
        userId = json['user_id']?.toString() ?? '',
        title = json['title']?.toString() ?? '',
        summary = json['summary']?.toString() ?? '',
        coverUrl = Config.resolveImage(json['cover_url']?.toString()),
        content = json['content']?.toString() ?? '',
        status = json['status']?.toString() ?? '',
        viewCount = (json['view_count'] is num)
            ? (json['view_count'] as num).toInt()
            : int.tryParse(json['view_count']?.toString() ?? '') ?? 0,
        likeCount = (json['like_count'] is num)
            ? (json['like_count'] as num).toInt()
            : int.tryParse(json['like_count']?.toString() ?? '') ?? 0,
        createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt = DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
            DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'summary': summary,
        'cover_url': coverUrl,
        'content': content,
        'status': status,
        'view_count': viewCount,
        'like_count': likeCount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
