import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  String? _role;
  bool _loadingRole = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await _storageService.getUserRole();
    if (mounted) {
      setState(() {
        _role = role;
        _loadingRole = false;
      });
    }
  }

  bool get _isAdmin => (_role ?? '').toLowerCase() == 'admin';

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('管理后台')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('当前账号无管理权限'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.pushNamed(context, '/login');
                  await _loadRole();
                },
                child: const Text('切换账号'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理后台'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '课程'),
            Tab(text: '视频'),
            Tab(text: '分类'),
            Tab(text: '评论'),
            Tab(text: '用户'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AdminCoursesTab(),
          _AdminVideosTab(),
          _AdminCategoriesTab(),
          _AdminCommentsTab(),
          _AdminUsersTab(),
        ],
      ),
    );
  }
}

class _AdminCoursesTab extends StatefulWidget {
  const _AdminCoursesTab();

  @override
  State<_AdminCoursesTab> createState() => _AdminCoursesTabState();
}

class _AdminCoursesTabState extends State<_AdminCoursesTab> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  bool _error = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final resp = await _apiService.get<Map<String, dynamic>>(
        '/courses',
        queryParameters: const {'page': 1, 'page_size': 50},
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      if (resp.code != 0 && resp.code != 200) {
        throw Exception(resp.msg);
      }
      final raw = resp.data['courses'];
      final List<Map<String, dynamic>> items = [];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            items.add(item);
          }
        }
      }
      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? initial}) async {
    final isEdit = initial != null;
    final categoryCtrl = TextEditingController(
      text: initial?['category_id']?.toString() ?? '',
    );
    final titleCtrl = TextEditingController(
      text: initial?['title']?.toString() ?? '',
    );
    final summaryCtrl = TextEditingController(
      text: initial?['summary']?.toString() ?? '',
    );
    final coverCtrl = TextEditingController(
      text: initial?['cover_url']?.toString() ?? '',
    );
    final instructorCtrl = TextEditingController(
      text: initial?['instructor_name']?.toString() ?? '',
    );
    final levelCtrl = TextEditingController(
      text: initial?['level']?.toString() ?? '',
    );
    final statusCtrl = TextEditingController(
      text: initial?['status']?.toString() ?? 'published',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? '编辑课程' : '新增课程'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: categoryCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '分类ID'),
                ),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '标题'),
                ),
                TextField(
                  controller: summaryCtrl,
                  decoration: const InputDecoration(labelText: '简介'),
                ),
                TextField(
                  controller: coverCtrl,
                  decoration: const InputDecoration(labelText: '封面URL/Key'),
                ),
                TextField(
                  controller: instructorCtrl,
                  decoration: const InputDecoration(labelText: '讲师名称'),
                ),
                TextField(
                  controller: levelCtrl,
                  decoration: const InputDecoration(labelText: '难度等级'),
                ),
                TextField(
                  controller: statusCtrl,
                  decoration: const InputDecoration(
                    labelText: '状态(如 published)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final data = <String, dynamic>{
                  'category_id': categoryCtrl.text.trim(),
                  'title': titleCtrl.text.trim(),
                  'summary': summaryCtrl.text.trim(),
                  'cover_url': coverCtrl.text.trim(),
                  'instructor_name': instructorCtrl.text.trim(),
                  'level': levelCtrl.text.trim(),
                  'status': statusCtrl.text.trim(),
                };
                try {
                  final resp = isEdit
                      ? await _apiService.putForm<Map<String, dynamic>>(
                          '/admin/courses/${initial['id']}',
                          data: data,
                          fromJson: (raw) => raw is Map<String, dynamic>
                              ? raw
                              : <String, dynamic>{},
                        )
                      : await _apiService.postForm<Map<String, dynamic>>(
                          '/admin/courses',
                          data: data,
                          fromJson: (raw) => raw is Map<String, dynamic>
                              ? raw
                              : <String, dynamic>{},
                        );
                  if (resp.code != 0 && resp.code != 200) {
                    throw Exception(resp.msg);
                  }
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('提交失败：$e')));
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _load();
    }
  }

  Future<void> _deleteCourse(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除课程'),
        content: Text('确认删除课程 #$id 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final resp = await _apiService.delete<Map<String, dynamic>>(
        '/admin/courses/$id',
        fromJson: (raw) =>
            raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );
      if (resp.code != 0 && resp.code != 200) {
        throw Exception(resp.msg);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
      }
    }
  }

  List<Map<String, dynamic>> _courseTableData() {
    return _items
        .map(
          (item) => <String, dynamic>{
            'id': '${item['id'] ?? '-'}',
            'title': item['title']?.toString() ?? '未命名课程',
            'category': '${item['category_id'] ?? '-'}',
            'instructor': item['instructor_name']?.toString() ?? '-',
            'status': item['status']?.toString() ?? '-',
          },
        )
        .toList();
  }

  Widget _buildCourseTable() {
    final data = _courseTableData();
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: TDTable(
              width: constraints.maxWidth,
              bordered: true,
              stripe: true,
              columns: [
                TDTableCol(
                  title: 'ID',
                  colKey: 'id',
                  width: 82,
                  fixed: TDTableColFixed.left,
                ),
                TDTableCol(title: '标题', colKey: 'title', width: 180),
                TDTableCol(title: '分类', colKey: 'category', width: 90),
                TDTableCol(title: '讲师', colKey: 'instructor', width: 120),
                TDTableCol(title: '状态', colKey: 'status', width: 100),
                TDTableCol(
                  title: '操作',
                  colKey: 'action',
                  width: 128,
                  cellBuilder: (context, index) {
                    final item = _items[index];
                    final id = item['id'];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => _openEditor(initial: item),
                          child: TDText(
                            '编辑',
                            style: TextStyle(
                              color: TDTheme.of(context).brandNormalColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => id is num
                              ? _deleteCourse(id.toInt())
                              : _showToast('无效课程ID'),
                          child: TDText(
                            '删除',
                            style: TextStyle(
                              color: TDTheme.of(context).errorNormalColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              data: data,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error) {
      return Center(
        child: TextButton(onPressed: _load, child: const Text('加载失败，点击重试')),
      );
    }
    return Column(
      children: [
        _AdminToolbar(
          title: '课程管理',
          onAdd: () => _openEditor(),
          onRefresh: _load,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _buildCourseTable(),
          ),
        ),
      ],
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _AdminVideosTab extends StatefulWidget {
  const _AdminVideosTab();

  @override
  State<_AdminVideosTab> createState() => _AdminVideosTabState();
}

class _AdminVideosTabState extends State<_AdminVideosTab> {
  final ApiService _apiService = ApiService();
  final TextEditingController _courseIdCtrl = TextEditingController();
  bool _loading = false;
  bool _error = false;
  String? _courseTitle;
  List<Map<String, dynamic>> _videos = [];

  String _normalizeObjectKey(String value) {
    final text = value.trim();
    if (text.isEmpty) return text;
    if (!text.startsWith('http')) return text;
    try {
      final uri = Uri.parse(text);
      var path = uri.path;
      if (path.startsWith('/')) {
        path = path.substring(1);
      }
      if (path.startsWith('moochub-video/')) {
        return path.substring('moochub-video/'.length);
      }
      if (path.startsWith('uploads/')) {
        return path.substring('uploads/'.length);
      }
      return path;
    } catch (_) {
      final noQuery = text.split('?').first;
      return noQuery;
    }
  }

  Future<void> _loadByCourse() async {
    final courseId = _courseIdCtrl.text.trim();
    if (courseId.isEmpty) {
      _toast('请输入课程ID');
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final resp = await _apiService.get<Map<String, dynamic>>(
        '/courses/$courseId',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      if (resp.code != 0 && resp.code != 200) {
        throw Exception(resp.msg);
      }
      String? courseTitle;
      final coursesRaw = resp.data['courses'];
      if (coursesRaw is List && coursesRaw.isNotEmpty) {
        final first = coursesRaw.first;
        if (first is Map<String, dynamic>) {
          courseTitle = first['title']?.toString();
        }
      }
      final raw = resp.data['videos'];
      final List<Map<String, dynamic>> items = [];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            items.add(item);
          }
        }
      }
      if (mounted) {
        setState(() {
          _videos = items;
          _courseTitle = courseTitle;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openVideoEditor({Map<String, dynamic>? initial}) async {
    final isEdit = initial != null;
    final courseCtrl = TextEditingController(
      text: initial?['course_id']?.toString() ?? _courseIdCtrl.text.trim(),
    );
    final titleCtrl = TextEditingController(
      text: initial?['title']?.toString() ?? '',
    );
    final descCtrl = TextEditingController(
      text: initial?['description']?.toString() ?? '',
    );
    final durationCtrl = TextEditingController(
      text: initial?['duration_sec']?.toString() ?? '',
    );
    final videoUrlCtrl = TextEditingController(
      text: initial?['video_url'] != null
          ? _normalizeObjectKey(initial?['video_url']?.toString() ?? '')
          : '',
    );
    final thumbUrlCtrl = TextEditingController(
      text: initial?['thumb_url'] != null
          ? _normalizeObjectKey(initial?['thumb_url']?.toString() ?? '')
          : '',
    );
    final sortCtrl = TextEditingController(
      text: initial?['sort_order']?.toString() ?? '0',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? '编辑视频' : '新增视频'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: courseCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '课程ID'),
                ),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '标题'),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: '简介'),
                ),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '时长(秒)'),
                ),
                TextField(
                  controller: videoUrlCtrl,
                  decoration: const InputDecoration(labelText: '视频URL/Key'),
                ),
                TextField(
                  controller: thumbUrlCtrl,
                  decoration: const InputDecoration(labelText: '封面URL/Key'),
                ),
                TextField(
                  controller: sortCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '排序'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final data = <String, dynamic>{
                  'course_id': courseCtrl.text.trim(),
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'duration_sec': durationCtrl.text.trim(),
                  'video_url': _normalizeObjectKey(videoUrlCtrl.text),
                  'thumb_url': _normalizeObjectKey(thumbUrlCtrl.text),
                  'sort_order': sortCtrl.text.trim(),
                };
                try {
                  final resp = isEdit
                      ? await _apiService.putForm<Map<String, dynamic>>(
                          '/admin/videos/${initial['id']}',
                          data: data,
                          fromJson: (raw) => raw is Map<String, dynamic>
                              ? raw
                              : <String, dynamic>{},
                        )
                      : await _apiService.postForm<Map<String, dynamic>>(
                          '/admin/videos',
                          data: data,
                          fromJson: (raw) => raw is Map<String, dynamic>
                              ? raw
                              : <String, dynamic>{},
                        );
                  if (resp.code != 0 && resp.code != 200) {
                    throw Exception(resp.msg);
                  }
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('提交失败：$e')));
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _loadByCourse();
    }
  }

  Future<void> _deleteVideo(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除视频'),
        content: Text('确认删除视频 #$id 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final resp = await _apiService.delete<Map<String, dynamic>>(
        '/admin/videos/$id',
        fromJson: (raw) =>
            raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );
      if (resp.code != 0 && resp.code != 200) {
        throw Exception(resp.msg);
      }
      await _loadByCourse();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
      }
    }
  }

  List<Map<String, dynamic>> _videoTableData() {
    return _videos
        .map(
          (item) => <String, dynamic>{
            'id': '${item['id'] ?? '-'}',
            'title': item['title']?.toString() ?? '未命名视频',
            'sort_order': '${item['sort_order'] ?? '-'}',
            'duration': '${item['duration_sec'] ?? '-'}',
          },
        )
        .toList();
  }

  Widget _buildVideoTable() {
    final data = _videoTableData();
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: TDTable(
              width: constraints.maxWidth,
              bordered: true,
              stripe: true,
              columns: [
                TDTableCol(
                  title: 'ID',
                  colKey: 'id',
                  width: 82,
                  fixed: TDTableColFixed.left,
                ),
                TDTableCol(title: '标题', colKey: 'title', width: 200),
                TDTableCol(title: '排序', colKey: 'sort_order', width: 90),
                TDTableCol(title: '时长(秒)', colKey: 'duration', width: 100),
                TDTableCol(
                  title: '操作',
                  colKey: 'action',
                  width: 128,
                  cellBuilder: (context, index) {
                    final item = _videos[index];
                    final id = item['id'];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => _openVideoEditor(initial: item),
                          child: TDText(
                            '编辑',
                            style: TextStyle(
                              color: TDTheme.of(context).brandNormalColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => id is num
                              ? _deleteVideo(id.toInt())
                              : _toast('无效视频ID'),
                          child: TDText(
                            '删除',
                            style: TextStyle(
                              color: TDTheme.of(context).errorNormalColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              data: data,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _courseIdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '课程ID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _loadByCourse, child: const Text('查询')),
            ],
          ),
        ),
        _AdminToolbar(
          title: '视频管理',
          onAdd: () => _openVideoEditor(),
          onRefresh: _loadByCourse,
        ),
        if (_courseTitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('当前课程：$_courseTitle'),
            ),
          ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error)
          Expanded(
            child: Center(
              child: TextButton(
                onPressed: _loadByCourse,
                child: const Text('加载失败，点击重试'),
              ),
            ),
          )
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildVideoTable(),
            ),
          ),
      ],
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _AdminCategoriesTab extends StatefulWidget {
  const _AdminCategoriesTab();

  @override
  State<_AdminCategoriesTab> createState() => _AdminCategoriesTabState();
}

class _AdminCategoriesTabState extends State<_AdminCategoriesTab> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  bool _error = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final resp = await _apiService.get<Map<String, dynamic>>(
        '/categories',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      if (resp.code != 0 && resp.code != 200) {
        throw Exception(resp.msg);
      }
      final raw = resp.data['categories'];
      final List<Map<String, dynamic>> items = [];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            items.add(item);
          }
        }
      }
      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _categoryTableData() {
    return _items
        .map(
          (item) => <String, dynamic>{
            'id': '${item['id'] ?? '-'}',
            'name': item['name']?.toString() ?? '未命名分类',
          },
        )
        .toList();
  }

  Widget _buildCategoryTable() {
    final data = _categoryTableData();
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: TDTable(
              width: constraints.maxWidth,
              bordered: true,
              stripe: true,
              columns: [
                TDTableCol(
                  title: 'ID',
                  colKey: 'id',
                  width: 96,
                  fixed: TDTableColFixed.left,
                ),
                TDTableCol(title: '分类名称', colKey: 'name', width: 260),
              ],
              data: data,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error) {
      return Center(
        child: TextButton(onPressed: _load, child: const Text('加载失败，点击重试')),
      );
    }
    return Column(
      children: [
        _AdminToolbar(title: '分类管理', onAdd: null, onRefresh: _load),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _buildCategoryTable(),
          ),
        ),
      ],
    );
  }
}

class _AdminCommentsTab extends StatefulWidget {
  const _AdminCommentsTab();

  @override
  State<_AdminCommentsTab> createState() => _AdminCommentsTabState();
}

class _AdminCommentsTabState extends State<_AdminCommentsTab> {
  final ApiService _apiService = ApiService();
  final TextEditingController _targetIdCtrl = TextEditingController();
  String _targetType = 'course';
  bool _loading = false;
  bool _error = false;
  List<Map<String, dynamic>> _items = [];

  String _extractId(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    if (raw is Map) {
      final oid = raw[r'$oid'];
      if (oid is String) return oid;
    }
    return raw.toString();
  }

  Future<void> _load() async {
    final targetId = _targetIdCtrl.text.trim();
    if (targetId.isEmpty) {
      _toast('请输入目标ID');
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final resp = await _apiService.get<Map<String, dynamic>>(
        '/comments',
        queryParameters: {
          'target_type': _targetType,
          'target_id': targetId,
          'page': 1,
          'page_size': 50,
        },
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      if (resp.code != 0 && resp.code != 200) {
        throw Exception(resp.msg);
      }
      final raw = resp.data['items'];
      final List<Map<String, dynamic>> items = [];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            items.add(item);
          }
        }
      }
      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteComment(String id) async {
    try {
      final resp = await _apiService.delete<Map<String, dynamic>>(
        '/admin/comments/$id',
        fromJson: (raw) =>
            raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );
      if (resp.code != 0 && resp.code != 200) {
        throw Exception(resp.msg);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
      }
    }
  }

  List<Map<String, dynamic>> _commentTableData() {
    return _items
        .map(
          (item) => <String, dynamic>{
            'id': _extractId(item['id']),
            'content': item['content']?.toString() ?? '',
            'user_id': '${item['user_id'] ?? '-'}',
            'like_count': '${item['like_count'] ?? 0}',
          },
        )
        .toList();
  }

  Widget _buildCommentTable() {
    final data = _commentTableData();
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: TDTable(
              width: constraints.maxWidth,
              bordered: true,
              stripe: true,
              columns: [
                TDTableCol(
                  title: '评论ID',
                  colKey: 'id',
                  width: 140,
                  fixed: TDTableColFixed.left,
                ),
                TDTableCol(
                  title: '内容',
                  colKey: 'content',
                  width: 220,
                  ellipsis: true,
                ),
                TDTableCol(title: '用户ID', colKey: 'user_id', width: 92),
                TDTableCol(title: '点赞', colKey: 'like_count', width: 72),
                TDTableCol(
                  title: '操作',
                  colKey: 'action',
                  width: 82,
                  cellBuilder: (context, index) {
                    final item = _items[index];
                    final id = _extractId(item['id']);
                    return GestureDetector(
                      onTap: id.isEmpty ? null : () => _deleteComment(id),
                      child: TDText(
                        '删除',
                        style: TextStyle(
                          color: TDTheme.of(context).errorNormalColor,
                          fontSize: 14,
                        ),
                      ),
                    );
                  },
                ),
              ],
              data: data,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              DropdownButton<String>(
                value: _targetType,
                items: const [
                  DropdownMenuItem(value: 'course', child: Text('课程')),
                  DropdownMenuItem(value: 'video', child: Text('视频')),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _targetType = val);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _targetIdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '目标ID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _load, child: const Text('查询')),
            ],
          ),
        ),
        _AdminToolbar(title: '评论管理', onAdd: null, onRefresh: _load),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error)
          Expanded(
            child: Center(
              child: TextButton(
                onPressed: _load,
                child: const Text('加载失败，点击重试'),
              ),
            ),
          )
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildCommentTable(),
            ),
          ),
      ],
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _AdminUsersTab extends StatelessWidget {
  const _AdminUsersTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Text('用户管理暂未接入接口'),
        const SizedBox(height: 4),
        Text(
          '可后续补充：用户列表、封禁/解封、角色设置等。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AdminToolbar extends StatelessWidget {
  const _AdminToolbar({
    required this.title,
    required this.onAdd,
    required this.onRefresh,
  });

  final String title;
  final VoidCallback? onAdd;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (onRefresh != null)
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          if (onAdd != null)
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增'),
            ),
        ],
      ),
    );
  }
}
