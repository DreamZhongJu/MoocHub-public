package com.moocHub.app

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    // 手Q OpenSDK 3.5.7+ 权限兜底：用户未授权设备信息前，需显式放行
    runCatching {
      val clazz = Class.forName("com.tencent.tauth.Tencent")
      val method = clazz.getMethod(
        "setIsPermissionGranted",
        Boolean::class.javaPrimitiveType,
        String::class.java,
      )
      method.invoke(null, true, Build.MODEL)
    }
  }
}
