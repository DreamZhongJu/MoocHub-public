import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/model/CoursesModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/widget/LoadingWidget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProductListPage extends StatefulWidget {
  final int categoryId;
  const ProductListPage({super.key, required this.categoryId});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();

  int _page = 1;
  String _sort = 'default';
  bool _isLoading = false;
  bool _hasMore = true;
  List<CoursesModel> _courseList = [];

  String _stringify(dynamic value) => value?.toString() ?? '';

  int _intify(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _normalizeCourseMap(Map<String, dynamic> json) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': _stringify(json['id']),
      'category_id': _stringify(json['category_id']),
      'title': _stringify(json['title']),
      'summary': _stringify(json['summary']),
      'cover_url': _stringify(json['cover_url']),
      'view_count': _intify(json['view_count']),
      'favorite_count': _intify(json['favorite_count']),
      'instructor_name': _stringify(json['instructor_name']),
      'level': _stringify(json['level']),
      'status': _stringify(json['status']),
      'created_at': _stringify(json['created_at']).isEmpty
          ? now
          : _stringify(json['created_at']),
      'updated_at': _stringify(json['updated_at']).isEmpty
          ? now
          : _stringify(json['updated_at']),
    };
  }

  @override
  void initState() {
    super.initState();
    _getProductListData(reset: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 20) {
        if (_hasMore && !_isLoading) {
          _getProductListData();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getProductListData({bool reset = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    if (reset) {
      _page = 1;
      _courseList = [];
      _hasMore = true;
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/categories/${widget.categoryId}/courses',
        queryParameters: {
          'page': _page,
          'page_size': 10,
          'sort': _sort,
        },
        fromJson: (raw) => raw as Map<String, dynamic>,
      );

      if (response.code != 0 && response.code != 200) {
        throw Exception(response.msg);
      }

      final raw = response.data['courses'];
      final List<CoursesModel> newItems = [];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            newItems.add(CoursesModel.fromJson(_normalizeCourseMap(item)));
          }
        }
      }
      setState(() {
        _courseList.addAll(newItems);
        _page++;
        if (response.count != null) {
          _hasMore = _courseList.length < response.count!;
        } else {
          _hasMore = newItems.isNotEmpty;
        }
      });
    } catch (_) {
      setState(() {
        _hasMore = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setSort(String value) {
    if (_sort == value) return;
    setState(() {
      _sort = value;
    });
    _getProductListData(reset: true);
  }

  Widget _sortItem(String label, String value) {
    final active = _sort == value;
    return Expanded(
      child: InkWell(
        onTap: () => _setSort(value),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 16.h, 0, 20.h),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.red : Colors.black87,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _subHeaderWidget() {
    return Positioned(
      top: 0,
      height: 80.h,
      width: 750.w,
      child: Container(
        height: 80.h,
        width: 750.w,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              width: 1,
              color: const Color.fromRGBO(233, 233, 233, 0.9),
            ),
          ),
        ),
        child: Row(
          children: [
            _sortItem('综合', 'default'),
            _sortItem('观看最多', 'view_count'),
            _sortItem('收藏最多', 'favorite_count'),
            Expanded(
              child: InkWell(
                onTap: () {
                  _scaffoldkey.currentState?.openEndDrawer();
                },
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 16.h, 0, 20.h),
                  child: Text(
                    '筛选',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productListWidget() {
    if (_courseList.isEmpty && _isLoading) {
      return const Loadingwidget();
    }

    if (_courseList.isEmpty) {
      return const Center(child: Text('暂无课程'));
    }

    return Container(
      padding: const EdgeInsets.all(10),
      margin: EdgeInsets.only(top: 80.h),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _courseList.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _courseList.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Loadingwidget(),
            );
          }
          final item = _courseList[index];
          return InkWell(
            onTap: () {
              final id = int.tryParse(item.id);
              if (id == null) {
                return;
              }
              Navigator.pushNamed(
                context,
                '/courseDetail',
                arguments: id,
              );
            },
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 180.w,
                      height: 180.h,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: Config.resolveImage(item.coverUrl) == ''
                              ? 'https://picsum.photos/seed/p${item.id}/200'
                              : Config.resolveImage(item.coverUrl),
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Image.asset(
                            Config.defaultProductAsset,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 180.h,
                        margin: const EdgeInsets.only(left: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Text(
                                  '讲师：${item.instructorName}',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '收藏：${item.favoriteCount}',
                                    style: const TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldkey,
      appBar: AppBar(title: const Text('课程列表'), actions: const [Text('')]),
      endDrawer: Drawer(
        child: Center(
          child: Text(
            '筛选功能开发中',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ),
      body: Stack(children: [_productListWidget(), _subHeaderWidget()]),
    );
  }
}
