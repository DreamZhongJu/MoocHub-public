import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static String _backendHost() {
    final ip = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
    final port = dotenv.env['BACKEND_PORT'] ?? '3000';
    final host = '$ip:$port';
    return 'http://$host';
  }

  static String get domain => '${_backendHost()}/api/v1';
  static String get imageHost => _backendHost();
  static const String defaultProductAsset = 'assets/images/default-product.png';

  static String resolveImage(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      try {
        final uri = Uri.parse(url);
        final hasAmzSignature = uri.queryParameters.keys
            .any((key) => key.toLowerCase().startsWith('x-amz-'));
        if (hasAmzSignature) {
          return url;
        }
        if (uri.host == '127.0.0.1' || uri.host == 'localhost') {
          final ip = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
          return uri.replace(host: ip).toString();
        }
      } catch (_) {
        return url;
      }
      return url;
    }
    if (url.startsWith('/')) {
      return '$imageHost$url';
    }
    return '$imageHost/$url';
  }
}
