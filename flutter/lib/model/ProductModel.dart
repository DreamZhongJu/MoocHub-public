class ProductModel {
  int? id;
  String? name;
  String? description;
  double? price;
  int? stock;
  String? imageUrl;
  String? category;
  String? createdAt;
  String? updatedAt;

  ProductModel(
      {this.id,
        this.name,
        this.description,
        this.price,
        this.stock,
        this.imageUrl,
        this.category,
        this.createdAt,
        this.updatedAt});

  ProductModel.fromJson(Map<String, dynamic> json) {
    id = (json['id'] ?? json['ID']) as int?;
    name = (json['name'] ?? json['Name']) as String?;
    description = (json['description'] ?? json['Description']) as String?;
    final rawPrice = json['price'] ?? json['Price'];
    price = rawPrice is num ? rawPrice.toDouble() : null;
    final rawStock = json['stock'] ?? json['Stock'];
    stock = rawStock is num ? rawStock.toInt() : null;
    imageUrl = (json['image_url'] ?? json['ImageURL']) as String?;
    category = (json['category'] ?? json['Category']) as String?;
    createdAt = (json['created_at'] ?? json['CreatedAt'])?.toString();
    updatedAt = (json['updated_at'] ?? json['UpdatedAt'])?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['description'] = this.description;
    data['price'] = this.price;
    data['stock'] = this.stock;
    data['image_url'] = this.imageUrl;
    data['category'] = this.category;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}
