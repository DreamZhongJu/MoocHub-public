class FocusModel {
  /// 唯一 id（接口里是数字，这里转成 int）
  final int id;

  /// 标题
  final String title;

  /// 大图地址（轮播图用这个）
  final String url;

  /// 小图地址（比如做缩略图）
  final String thumbnailUrl;

  FocusModel({
    required this.id,
    required this.title,
    required this.url,
    required this.thumbnailUrl,
  });

  /// 从单个 json 对象构造
  factory FocusModel.fromJson(Map<String, dynamic> json) {
    final intId = (json['id'] as num?)?.toInt() ?? 0;

    return FocusModel(
      id: intId,
      title: json['title'] as String? ?? '',
      // ⚠️ 不用 json['url']，直接用你熟悉的 picsum
      // seed 用 id，这样每条数据的图片是稳定的
      url: 'https://picsum.photos/seed/$intId/600/300',
      thumbnailUrl: 'https://picsum.photos/seed/thumb$intId/300/150',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  static List<FocusModel> fromJsonList(List<dynamic> list) {
    return list
        .map((e) => FocusModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
