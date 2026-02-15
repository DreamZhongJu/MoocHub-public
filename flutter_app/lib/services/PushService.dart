import 'dart:convert';

import 'package:MoocHub/routers/navigator_key.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';

final AndroidNotificationChannel _importantChannel = AndroidNotificationChannel(
  'important_channel',
  'Important Notifications',
  description: 'Account security and order status updates',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
  vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();
const DarwinInitializationSettings _darwinInitSettings =
    DarwinInitializationSettings();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(
    android: androidSettings,
    iOS: _darwinInitSettings,
  );
  await _localNotifications.initialize(settings);
  final androidPlugin = _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(_importantChannel);
  await PushService.instance._showLocalNotification(
    message,
    fromBackground: true,
  );
}

class PushService {
  PushService._();

  static final PushService instance = PushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) return;

    await _setupLocalNotifications();
    await _requestPermissions();
    await _registerToken();
    _listenTokenRefresh();
    _listenMessages();
    await _handleInitialMessage();
  }

  Future<void> refreshToken() async {
    await _registerToken();
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: _darwinInitSettings,
    );
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _handlePayloadTap(payload);
        }
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_importantChannel);
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsToken = await _messaging.getAPNSToken();
      debugPrint('APNs token: $apnsToken');
    }
  }

  Future<void> _registerToken() async {
    String? token;
    try {
      token = await _messaging.getToken().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('FCM token error: $e');
      return;
    }
    if (token == null || token.isEmpty) {
      debugPrint('FCM token empty');
      return;
    }
    debugPrint('FCM token: $token');
    await _sendTokenToServer(token);
  }

  void _listenTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      if (token.isEmpty) return;
      await _sendTokenToServer(token);
    });
  }

  void _listenMessages() {
    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint('FCM onMessage: ${message.messageId} ${message.data}');
      await _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleMessageTap(message);
    });
  }

  Future<void> _handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      _handleMessageTap(message);
    }
  }

  Future<void> _showLocalNotification(
    RemoteMessage message, {
    bool fromBackground = false,
  }) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _importantChannel.id,
        _importantChannel.name,
        channelDescription: _importantChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final payload = _buildPayload(message);
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title ?? 'New message',
      body ?? '',
      details,
      payload: payload,
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    final route = _routeFromMessage(message) ?? '/messages';
    final messageId = _messageIdFromMessage(message);
    _handleMessageRoute(route, messageId: messageId);
  }

  void _handleMessageRoute(String route, {String? messageId}) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    if (messageId != null && messageId.isNotEmpty) {
      _markMessageRead(messageId);
    }
    navigator.pushNamed(route);
  }

  String? _routeFromMessage(RemoteMessage message) {
    final route = message.data['route']?.toString();
    if (route != null && route.isNotEmpty) return route;
    final url = message.data['url']?.toString();
    if (url != null && url.isNotEmpty && url.startsWith('/')) {
      return url;
    }
    return null;
  }

  String? _messageIdFromMessage(RemoteMessage message) {
    final raw = message.data['message_id']?.toString();
    if (raw != null && raw.isNotEmpty) return raw;
    return null;
  }

  String _buildPayload(RemoteMessage message) {
    final route = _routeFromMessage(message) ?? '/messages';
    final messageId = _messageIdFromMessage(message);
    final payload = {
      'route': route,
      if (messageId != null && messageId.isNotEmpty) 'message_id': messageId,
    };
    return json.encode(payload);
  }

  void _handlePayloadTap(String payload) {
    try {
      final data = json.decode(payload);
      if (data is Map) {
        final route = data['route']?.toString() ?? '/messages';
        final messageId = data['message_id']?.toString();
        _handleMessageRoute(route, messageId: messageId);
        return;
      }
    } catch (_) {}
    _handleMessageRoute(payload);
  }

  Future<void> _markMessageRead(String messageId) async {
    try {
      await ApiService().post(
        '/messages/read',
        data: {
          'ids': [int.parse(messageId)],
        },
      );
    } catch (_) {}
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      await ApiService().post(
        '/device_tokens',
        data: {
          'token': token,
          'platform': !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
      );
      debugPrint('FCM token uploaded');
    } catch (e) {
      if (e is DioException) {
        debugPrint(
          'FCM token upload failed: ${e.response?.statusCode} ${e.response?.data}',
        );
      } else {
        debugPrint('FCM token upload failed: $e');
      }
    }
  }
}
