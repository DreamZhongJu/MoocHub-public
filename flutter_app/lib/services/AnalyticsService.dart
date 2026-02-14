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
