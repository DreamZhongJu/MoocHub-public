class CategoryModel {
  final int id;
  final String name;
  final int? parentId;
  final int sortOrder;

  CategoryModel({
    required this.id,
    required this.name,
    required this.parentId,
    required this.sortOrder,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawParent = json['parent_id'];
    final rawSort = json['sort_order'];
    return CategoryModel(
      id: _intify(rawId),
      name: (json['name'] ?? '').toString(),
      parentId: rawParent == null ? null : _intify(rawParent),
      sortOrder: _intify(rawSort),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parent_id': parentId,
    'sort_order': sortOrder,
  };

  static int _intify(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
