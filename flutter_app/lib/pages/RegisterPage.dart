import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/PushService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final nickname = _nicknameController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入用户名和密码')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final resp = await _apiService.postForm<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'username': username,
          'password': password,
          'nickname': nickname,
        },
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
      String message = '注册失败';
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = data['msg'] ?? data['message'];
        if (msg is String && msg.isNotEmpty) {
          message = msg;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注册失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
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
            const SizedBox(height: 12),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(labelText: '昵称（可选）'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('注册并登录'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
