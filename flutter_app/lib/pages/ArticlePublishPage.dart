import 'dart:io';

import 'package:MoocHub/services/ApiService.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ArticlePublishPage extends StatefulWidget {
  const ArticlePublishPage({super.key});

  @override
  State<ArticlePublishPage> createState() => _ArticlePublishPageState();
}

class _ArticlePublishPageState extends State<ArticlePublishPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _submitting = false;
  bool _uploadingCover = false;
  String _coverUrl = '';
  String _coverKey = '';
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _coverCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  String _normalizeCoverInput(String input) {
    if (input.isEmpty) return '';
    if (input.startsWith('minio://')) return input;
    if (input.startsWith('http://') || input.startsWith('https://')) {
      try {
        final uri = Uri.parse(input);
        final segments = uri.pathSegments
            .where((segment) => segment.isNotEmpty)
            .toList();
        if (segments.length >= 2) {
          return segments.sublist(1).join('/');
        }
        if (segments.length == 1) {
          return segments.first;
        }
      } catch (_) {
        return input;
      }
    }
    return input;
  }

  Future<void> _pickCover() async {
    if (_uploadingCover) return;
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _uploadCover(File(file.path));
  }

  Future<void> _uploadCover(File file) async {
    setState(() => _uploadingCover = true);
    try {
      final filename = file.path.split(Platform.pathSeparator).last;
      final form = FormData.fromMap({
        'dir': 'articles',
        'file': await MultipartFile.fromFile(file.path, filename: filename),
      });
      final resp = await ApiService().postMultipart<Map<String, dynamic>>(
        '/uploads',
        data: form,
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final key = resp.data['key']?.toString() ?? '';
      final url = resp.data['url']?.toString() ?? '';
      if (key.isNotEmpty && mounted) {
        setState(() {
          _coverKey = key;
          _coverUrl = url;
          _coverCtrl.text = key;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('封面上传失败')));
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingCover = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final coverInput = _coverCtrl.text.trim();
      final coverKey = _coverKey.isNotEmpty
          ? _coverKey
          : _normalizeCoverInput(coverInput);
      final resp = await ApiService().postForm<Map<String, dynamic>>(
        '/articles',
        data: {
          'title': _titleCtrl.text.trim(),
          'summary': _summaryCtrl.text.trim(),
          'cover_url': coverKey,
          'content': _contentCtrl.text.trim(),
        },
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      if (resp.code == 200 || resp.code == 0) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('发布成功')));
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(resp.msg.toString())));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('发布失败')));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发布文章')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: '标题'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入标题' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _summaryCtrl,
              decoration: const InputDecoration(labelText: '摘要'),
              maxLines: 2,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入摘要' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _coverCtrl,
                    decoration: const InputDecoration(labelText: '封面URL（可选）'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _uploadingCover ? null : _pickCover,
                  child: Text(_uploadingCover ? '上传中' : '上传封面'),
                ),
              ],
            ),
            if (_coverUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _coverUrl,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _contentCtrl,
              decoration: const InputDecoration(
                labelText: '正文内容（Markdown）',
                hintText: '支持 Markdown 语法，例如：\n\n# 标题\n\n- 列表项\n\n**加粗**',
              ),
              maxLines: 10,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入内容' : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '发布中...' : '发布'),
            ),
          ],
        ),
      ),
    );
  }
}
