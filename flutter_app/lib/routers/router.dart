import 'package:MoocHub/pages/CourseDetailPage.dart';
import 'package:MoocHub/pages/ProductList.dart';
import 'package:flutter/material.dart';
import '../pages/tabs/Tabs.dart';

// 路由配置
var onGenerateRoute = (RouteSettings settings) {
  switch (settings.name) {
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
    default:
      return null;
  }
};
