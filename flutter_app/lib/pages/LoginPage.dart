import 'dart:async';

import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/services/PushService.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    _qqAppId = (dotenv.env['QQ_APP_ID'] ?? dotenv.env['TENCENT_APP_ID'] ?? '')
        .trim();
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
      final fromEnv =
          (dotenv.env['QQ_APP_ID'] ?? dotenv.env['TENCENT_APP_ID'] ?? '')
              .trim();
      debugPrint('[login] reload QQ_APP_ID=$fromEnv');
      if (fromEnv.isNotEmpty) {
        _qqAppId = fromEnv;
        _tencent ??= TencentKitPlatform.instance;
        _tencent!.registerApp(appId: _qqAppId);
      }
    }
    if (_qqAppId.isEmpty) {
      final envQq = (dotenv.env['QQ_APP_ID'] ?? '').trim();
      final envTencent = (dotenv.env['TENCENT_APP_ID'] ?? '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'QQ AppID 未配置（QQ_APP_ID=$envQq, TENCENT_APP_ID=$envTencent）',
          ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: '用户名'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('登录'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        '/register',
                      );
                      if (result == true && mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    child: const Text('注册'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_qqLoading || kIsWeb) ? null : _qqLogin,
                icon: Image.asset('assets/icons/qq.png', width: 20, height: 20),
                label: _qqLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('QQ 登录'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF12B7F5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
