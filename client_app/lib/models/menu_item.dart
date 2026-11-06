class MenuItem {
  final int id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final String? categoryName;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    required this.isAvailable,
    this.categoryName,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      imageUrl: json['image_url'] as String?,
      isAvailable: json['is_available'] == 1 || json['is_available'] == true,
      categoryName: json['category_name'] as String?,
    );
  }
}
