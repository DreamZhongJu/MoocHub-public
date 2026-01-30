import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static String _backendHost() {
    final host = dotenv.env['BACKEND_HOST'] ?? '0.0.0.0:8080';
    if (host.startsWith('http://') || host.startsWith('https://')) {
      return host;
    }
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
      return url;
    }
    if (url.startsWith('/')) {
      return '$imageHost$url';
    }
    return '$imageHost/$url';
  }
}
