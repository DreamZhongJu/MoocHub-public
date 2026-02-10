import 'package:MoocHub/config/Config.dart';

class CoursesModel {
  final String id;
  final String categoryId;
  final String title;
  final String summary;
  final String coverUrl;
  final String instructorName;
  final String level;
  final String status;
  final int viewCount;
  final int favoriteCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  CoursesModel({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.summary,
    required this.coverUrl,
    required this.viewCount,
    required this.favoriteCount,
    required this.instructorName,
    required this.level,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  CoursesModel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      categoryId = json['category_id'] as String,
      title = json['title'] as String,
      summary = json['summary'] as String,
      coverUrl = Config.resolveImage(json['cover_url']?.toString() ?? ''),
      viewCount = json['view_count'] as int,
      favoriteCount = json['favorite_count'] as int,
      instructorName = json['instructor_name'] as String,
      level = json['level'] as String,
      status = json['status'] as String,
      createdAt = DateTime.parse(json['created_at'] as String),
      updatedAt = DateTime.parse(json['updated_at'] as String);

  Map<String, dynamic> toJson() => {
    'id': id,
    'category_id': categoryId,
    'title': title,
    'summary': summary,
    'cover_url': coverUrl,
    'view_count': viewCount,
    'favorite_count': favoriteCount,
    'instructor_name': instructorName,
    'level': level,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
