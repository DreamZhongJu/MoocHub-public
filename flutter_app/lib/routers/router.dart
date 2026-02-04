import 'package:MoocHub/pages/CourseDetailPage.dart';
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
    default:
      return null;
  }
};
