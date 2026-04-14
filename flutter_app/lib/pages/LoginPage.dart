import 'dart:async';

import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/services/PushService.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:tencent_kit/tencent_kit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  bool _loading = false;
  bool _qqLoading = false;

  late final String _qqAppId;
  TencentKitPlatform? _tencent;
  StreamSubscription<TencentResp>? _qqLoginSub;

  @override
  void initState() {
    super.initState();
    _qqAppId = Config.qqAppId.trim();
    debugPrint('[login] QQ_APP_ID=$_qqAppId');
    if (_qqAppId.isNotEmpty && !kIsWeb) {
      _tencent = TencentKitPlatform.instance;
      _tencent!.registerApp(appId: _qqAppId);
      _qqLoginSub = _tencent!.respStream().listen(_handleQQLoginEvent);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _qqLoginSub?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入用户名和密码')));
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final resp = await _apiService.postForm<Map<String, dynamic>>(
        '/auth/login',
        data: {'username': username, 'password': password},
        fromJson: (raw) => raw as Map<String, dynamic>,
      );

      if (resp.code != 0 && resp.code != 200) {
        throw Exception(resp.msg);
      }

      await _storageService.saveUserData(resp.data);
      await PushService.instance.refreshToken();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      String message = '登录失败';
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = data['msg'] ?? data['message'];
        if (msg is String && msg.isNotEmpty) {
          message = msg;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('登录失败：$e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _qqLogin() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web 不支持 QQ SDK 登录，请使用 Android/iOS 端')),
      );
      return;
    }
    if (_qqAppId.isEmpty) {
      final fromEnv = Config.qqAppId.trim();
      debugPrint('[login] reload QQ_APP_ID=$fromEnv');
      if (fromEnv.isNotEmpty) {
        _qqAppId = fromEnv;
        _tencent ??= TencentKitPlatform.instance;
        _tencent!.registerApp(appId: _qqAppId);
      }
    }
    if (_qqAppId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('QQ AppID 未配置'),
        ),
      );
      return;
    }
    if (_tencent == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QQ SDK 未初始化')));
      return;
    }

    final installed = await _tencent!.isQQInstalled();
    if (!installed) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未检测到 QQ 客户端')));
      }
      return;
    }

    setState(() {
      _qqLoading = true;
    });

    _tencent!.login(scope: <String>[TencentScope.kGetSimpleUserInfo]);
  }

  Future<void> _handleQQLoginResp(TencentLoginResp resp) async {
    if (!_qqLoading) {
      return;
    }
    if (!resp.isSuccessful || resp.accessToken == null || resp.openid == null) {
      if (mounted) {
        String message = resp.msg ?? 'QQ 登录失败';
        final lower = message.toLowerCase();
        if (lower.contains('permission') || message.contains('授权')) {
          message = '未授权，暂时无法使用QQ登录及分享等功能';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        setState(() {
          _qqLoading = false;
        });
      }
      return;
    }

    try {
      final result = await _apiService.postForm<Map<String, dynamic>>(
        '/auth/qq/sdk_login',
        data: {'access_token': resp.accessToken, 'openid': resp.openid},
        fromJson: (raw) => raw as Map<String, dynamic>,
      );

      if (result.code != 0 && result.code != 200) {
        throw Exception(result.msg);
      }

      await _storageService.saveUserData(result.data);
      await PushService.instance.refreshToken();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      String message = 'QQ 登录失败';
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = data['msg'] ?? data['message'];
        if (msg is String && msg.isNotEmpty) {
          message = msg;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('QQ 登录失败：$e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _qqLoading = false;
        });
      }
    }
  }

  void _handleQQLoginEvent(TencentResp resp) {
    if (resp is TencentLoginResp) {
      _handleQQLoginResp(resp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 品牌头部（渐变背景）──────────────────────────────
                    Container(
                      height: size.height * 0.36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, primary.withValues(alpha: 0.72)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: Colors.white,
                                size: 42,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'MoocHub',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '随时随地，探索知识',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── 表单卡片（上移覆盖头部）────────────────────────────
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(0, -28),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(28, 36, 28, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '欢迎回来',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '登录以继续你的学习旅程',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // 用户名
                              TextField(
                                controller: _usernameController,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: '用户名',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 密码
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: '密码',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // 登录按钮
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          '登 录',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // QQ 登录
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: (_qqLoading || kIsWeb)
                                      ? null
                                      : _qqLogin,
                                  icon: Image.asset(
                                    'assets/icons/qq.png',
                                    width: 20,
                                    height: 20,
                                  ),
                                  label: _qqLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'QQ 登录',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF12B7F5),
                                    side: const BorderSide(
                                      color: Color(0xFF12B7F5),
                                      width: 1.4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),

                              const Spacer(),

                              // 注册入口
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '还没有账号？',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final result = await Navigator.pushNamed(
                                        context,
                                        '/register',
                                      );
                                      if (result == true && mounted) {
                                        Navigator.of(context).pop(true);
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      '立即注册',
                                      style: TextStyle(
                                        color: primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
