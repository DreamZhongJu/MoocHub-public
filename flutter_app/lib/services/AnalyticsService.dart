import 'dart:math';

import 'package:MoocHub/services/ApiService.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;

  AnalyticsService._internal();

  final ApiService _apiService = ApiService();
  final Set<String> _exposureKeys = <String>{};
  final String _sessionId = _buildSessionId();

  static String _buildSessionId() {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    final rand = Random().nextInt(1 << 32).toRadixString(16);
    return '$now$rand';
  }

  void resetSceneExposure(String scene) {
    _exposureKeys.removeWhere((key) => key.startsWith('$scene|'));
  }

  Future<bool> trackExposure({
    required String contentType,
    required int contentId,
    required String scene,
    int position = 0,
  }) async {
    final key = '$scene|$contentType|$contentId';
    if (_exposureKeys.contains(key)) {
      return true;
    }
    _exposureKeys.add(key);
    final ok = await _postTrack('/events/exposure', {
      'content_type': contentType,
      'content_id': contentId.toString(),
      'scene': scene,
      'session_id': _sessionId,
      'position': position.toString(),
    });
    if (!ok) {
      _exposureKeys.remove(key);
    }
    return ok;
  }

  Future<bool> trackClick({
    required String contentType,
    required int contentId,
    required String scene,
    int position = 0,
  }) async {
    return _postTrack('/events/click', {
      'content_type': contentType,
      'content_id': contentId.toString(),
      'scene': scene,
      'session_id': _sessionId,
      'position': position.toString(),
    });
  }

  Future<bool> trackPlayStart({
    required int videoId,
    String scene = 'video_detail',
    int position = 0,
  }) async {
    return _postTrack('/events/play', {
      'video_id': videoId.toString(),
      'scene': scene,
      'session_id': _sessionId,
      'position': position.toString(),
    });
  }

  Future<bool> trackPlayComplete({
    required int videoId,
    String scene = 'video_detail',
    int position = 0,
  }) async {
    return _postTrack('/events/complete', {
      'content_type': 'video',
      'content_id': videoId.toString(),
      'scene': scene,
      'session_id': _sessionId,
      'position': position.toString(),
    });
  }

  /// 页面浏览 — 用于课程/文章详情页打开时上报
  Future<bool> trackPageView({
    required String contentType,
    required int contentId,
    String scene = 'detail',
  }) async {
    final key = 'pv|$scene|$contentType|$contentId';
    if (_exposureKeys.contains(key)) return true;
    _exposureKeys.add(key);
    final ok = await _postTrack('/events/page_view', {
      'content_type': contentType,
      'content_id': contentId.toString(),
      'scene': scene,
      'session_id': _sessionId,
    });
    if (!ok) _exposureKeys.remove(key);
    return ok;
  }

  /// 收藏行为上报
  Future<bool> trackFavorite({
    required String contentType,
    required int contentId,
  }) async {
    return _postTrack('/events/favorite', {
      'content_type': contentType,
      'content_id': contentId.toString(),
      'session_id': _sessionId,
    });
  }

  /// 发表评论行为上报
  Future<bool> trackComment({
    required String contentType,
    required int contentId,
  }) async {
    return _postTrack('/events/comment', {
      'content_type': contentType,
      'content_id': contentId.toString(),
      'session_id': _sessionId,
    });
  }

  /// 分类点击上报
  Future<bool> trackCategoryClick({
    required int categoryId,
    String scene = 'category',
  }) async {
    return _postTrack('/events/click', {
      'content_type': 'category',
      'content_id': categoryId.toString(),
      'scene': scene,
      'session_id': _sessionId,
      'position': '0',
    });
  }

  Future<bool> _postTrack(String path, Map<String, String> payload) async {
    try {
      await _apiService.postForm<Map<String, dynamic>>(
        path,
        data: payload,
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      return true;
    } catch (e) {
      debugPrint('analytics track failed: $path $e');
      return false;
    }
  }
}
