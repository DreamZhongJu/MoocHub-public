import 'package:flutter/material.dart';
import 'package:flutter_jdshop/pages/ProductList.dart';
import 'package:flutter_jdshop/pages/search.dart';
import 'package:flutter_jdshop/pages/ProductDetail.dart';
import 'package:flutter_jdshop/pages/Login.dart';
import 'package:flutter_jdshop/pages/AdminDashboard.dart';
import '../pages/tabs/Tabs.dart';

// 配置路由
final Map<String, WidgetBuilder> routes = {
  '/': (context) => Tabs(),
  '/login': (context) => const LoginPage(),
  '/admin': (context) => const AdminDashboardPage(),
  '/search':(context) => SearchPage(),
  '/productList':(context,{arguments}) => ProductListPage(arguments:arguments),
  '/productDetail':(context,{arguments}) => ProductDetailPage(productId: arguments['productId']),
};

// 固定写法
var onGenerateRoute = (RouteSettings settings) {
  // 统一处理
  final String? name = settings.name;
  final Function? pageContentBuilder = routes[name];

  if (pageContentBuilder != null) {
    // 参数处理
    if (settings.arguments != null) {
      final Route route = MaterialPageRoute(
        builder: (context) => pageContentBuilder(context, arguments: settings.arguments),
      );
      return route;
    } else {
      final Route route = MaterialPageRoute(
        builder: (context) => pageContentBuilder(context),
      );
      return route;
    }
  }
  return null;
};
