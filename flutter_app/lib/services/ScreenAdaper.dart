import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';

class ScreenAdapter {
  static Widget init({required Widget child}) {
    return ScreenUtilInit(
      designSize: const Size(750, 1334), // 设计稿尺寸
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) => child,
    );
  }
  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;
}
