import 'package:MoocHub/pages/CourseDetailPage.dart';
import 'package:MoocHub/pages/FavoritesPage.dart';
import 'package:MoocHub/pages/LoginPage.dart';
import 'package:MoocHub/pages/MessagePage.dart';
import 'package:MoocHub/pages/NotificationSettingsPage.dart';
import 'package:MoocHub/pages/ChatHomePage.dart';
import 'package:MoocHub/pages/ChatDetailPage.dart';
import 'package:MoocHub/pages/ArticleDetailPage.dart';
import 'package:MoocHub/pages/ArticleListPage.dart';
import 'package:MoocHub/pages/ArticlePublishPage.dart';
import 'package:MoocHub/pages/ProductList.dart';
import 'package:MoocHub/pages/SplashPage.dart';
import 'package:MoocHub/pages/VideoDetailPage.dart';
import 'package:MoocHub/pages/admin/AdminHomePage.dart';
import 'package:MoocHub/pages/RegisterPage.dart';
import 'package:flutter/material.dart';
import '../pages/tabs/Tabs.dart';

// 路由配置
var onGenerateRoute = (RouteSettings settings) {
  switch (settings.name) {
    case '/splash':
      return MaterialPageRoute(builder: (_) => const SplashPage());
    case '/':
      return MaterialPageRoute(builder: (_) => const Tabs());
    case '/courseDetail':
      final args = settings.arguments;
      int? courseId;
      if (args is int) {
        courseId = args;
      } else if (args is Map<String, dynamic>) {
        final raw = args['courseId'];
        if (raw is int) {
          courseId = raw;
        } else if (raw is String) {
          courseId = int.tryParse(raw);
        }
      }
      if (courseId == null) {
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: Text('课程ID无效'))),
        );
      }
      return MaterialPageRoute(
        builder: (_) => CourseDetailPage(courseId: courseId!),
      );
    case '/courseList':
      final args = settings.arguments;
      int? categoryId;
      if (args is int) {
        categoryId = args;
      } else if (args is Map<String, dynamic>) {
        final raw = args['categoryId'] ?? args['cid'];
        if (raw is int) {
          categoryId = raw;
        } else if (raw is String) {
          categoryId = int.tryParse(raw);
        }
      }
      if (categoryId == null) {
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('分类ID无效')),
          ),
        );
      }
      return MaterialPageRoute(
        builder: (_) => ProductListPage(categoryId: categoryId!),
      );
    case '/videoDetail':
      final args = settings.arguments;
      int? videoId;
      if (args is int) {
        videoId = args;
      } else if (args is Map<String, dynamic>) {
        final raw = args['videoId'] ?? args['id'];
        if (raw is int) {
          videoId = raw;
        } else if (raw is String) {
          videoId = int.tryParse(raw);
        }
      }
      if (videoId == null) {
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('视频ID无效')),
          ),
        );
      }
      return MaterialPageRoute(
        builder: (_) => VideoDetailPage(videoId: videoId!),
      );
    case '/login':
      return MaterialPageRoute(builder: (_) => const LoginPage());
    case '/register':
      return MaterialPageRoute(builder: (_) => const RegisterPage());
    case '/favorites':
      return MaterialPageRoute(builder: (_) => const FavoritesPage());
    case '/admin':
      return MaterialPageRoute(builder: (_) => const AdminHomePage());
    case '/messages':
      return MaterialPageRoute(builder: (_) => const MessagePage());
    case '/chat':
      return MaterialPageRoute(builder: (_) => const ChatHomePage());
    case '/chatDetail':
      final args = settings.arguments;
      String title = '聊天';
      String conversationId = '';
      bool isGroup = false;
      if (args is Map<String, dynamic>) {
        final rawTitle = args['title'];
        if (rawTitle is String && rawTitle.isNotEmpty) {
          title = rawTitle;
        }
        final rawId = args['conversationId'] ?? args['id'];
        if (rawId != null) {
          conversationId = rawId.toString();
        }
        final rawGroup = args['isGroup'];
        if (rawGroup is bool) {
          isGroup = rawGroup;
        } else if (rawGroup is String) {
          isGroup = rawGroup.toLowerCase() == 'true';
        }
      }
      return MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          conversationId: conversationId,
          title: title,
          isGroup: isGroup,
        ),
      );
    case '/notificationSettings':
      return MaterialPageRoute(
        builder: (_) => const NotificationSettingsPage(),
      );
    case '/articles':
      return MaterialPageRoute(builder: (_) => const ArticleListPage());
    case '/articleDetail':
      final args = settings.arguments;
      int? articleId;
      if (args is int) {
        articleId = args;
      } else if (args is Map<String, dynamic>) {
        final raw = args['articleId'] ?? args['id'];
        if (raw is int) {
          articleId = raw;
        } else if (raw is String) {
          articleId = int.tryParse(raw);
        }
      }
      if (articleId == null) {
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('文章ID无效')),
          ),
        );
      }
      return MaterialPageRoute(
        builder: (_) => ArticleDetailPage(articleId: articleId!),
      );
    case '/articlePublish':
      return MaterialPageRoute(builder: (_) => const ArticlePublishPage());
    default:
      return null;
  }
};
