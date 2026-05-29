import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  // Current demo network: phone hotspot / WLAN
  static const String defaultBackendIp = '192.168.10.2';
  static const String defaultBackendPort = '3000';
  static const String defaultQqAppId = '102846875';

  static String _envOrDefault(String key, String fallback) {
    try {
      final value = dotenv.env[key]?.trim() ?? '';
      return value.isEmpty ? fallback : value;
    } catch (_) {
      return fallback;
    }
  }

  static String _backendHost() {
    final ip = _envOrDefault('BACKEND_IP', defaultBackendIp);
    final port = _envOrDefault('BACKEND_PORT', defaultBackendPort);
    final host = '$ip:$port';
    return 'http://$host';
  }

  static String get domain => '${_backendHost()}/api/v1';
  static String get imageHost => _backendHost();
  static String get qqAppId => _envOrDefault(
    'QQ_APP_ID',
    _envOrDefault('TENCENT_APP_ID', defaultQqAppId),
  );
  static const String defaultProductAsset = 'assets/images/default-product.png';

  static String resolveImage(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }
    final raw = url.trim();
    if (raw.isEmpty) return '';

    if (raw.startsWith('file://')) {
      try {
        final uri = Uri.parse(raw);
        return _resolveLocalPath(uri.path);
      } catch (_) {
        return '';
      }
    }

    if (raw.startsWith('/thumbs/') ||
        raw.startsWith('/videos/') ||
        raw.startsWith('/articles/')) {
      return '$imageHost/uploads$raw';
    }
    if (raw.startsWith('thumbs/') ||
        raw.startsWith('videos/') ||
        raw.startsWith('articles/')) {
      return '$imageHost/uploads/$raw';
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      try {
        final uri = Uri.parse(raw);
        if (_needsUploadsPrefix(uri.path)) {
          return uri.replace(path: '/uploads${uri.path}').toString();
        }
        final hasAmzSignature = uri.queryParameters.keys.any(
          (key) => key.toLowerCase().startsWith('x-amz-'),
        );
        if (hasAmzSignature) {
          return raw;
        }
        if (uri.host == '127.0.0.1' || uri.host == 'localhost') {
          final ip = _envOrDefault('BACKEND_IP', defaultBackendIp);
          return uri.replace(host: ip).toString();
        }
      } catch (_) {
        return raw;
      }
      return raw;
    }
    if (raw.startsWith('/')) {
      return '$imageHost$raw';
    }
    return '$imageHost/$raw';
  }

  static String _resolveLocalPath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) return '';
    if (normalized.startsWith('/thumbs/') ||
        normalized.startsWith('/videos/') ||
        normalized.startsWith('/articles/')) {
      return '$imageHost/uploads$normalized';
    }
    if (normalized.startsWith('/uploads/')) {
      return '$imageHost$normalized';
    }
    return '$imageHost/$normalized';
  }

  static bool _needsUploadsPrefix(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith('/uploads/')) return false;
    return path.startsWith('/thumbs/') ||
        path.startsWith('/videos/') ||
        path.startsWith('/articles/');
  }
}
