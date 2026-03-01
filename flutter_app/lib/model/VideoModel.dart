import 'package:MoocHub/config/Config.dart';

class VideoModel {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final int durationSec;
  final String videoUrl;
  final String thumbUrl;
  final int sortOrder;

  VideoModel({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.durationSec,
    required this.videoUrl,
    required this.thumbUrl,
    required this.sortOrder,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: _stringify(json['id']),
      courseId: _stringify(json['course_id']),
      title: _stringify(json['title']),
      description: _stringify(json['description']),
      durationSec: _intify(json['duration_sec']),
      videoUrl: Config.resolveImage(_stringify(json['video_url'])),
      thumbUrl: Config.resolveImage(_stringify(json['thumb_url'])),
      sortOrder: _intify(json['sort_order']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'course_id': courseId,
    'title': title,
    'description': description,
    'duration_sec': durationSec,
    'video_url': videoUrl,
    'thumb_url': thumbUrl,
    'sort_order': sortOrder,
  };

  static String _stringify(dynamic value) => value?.toString() ?? '';

  static int _intify(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
