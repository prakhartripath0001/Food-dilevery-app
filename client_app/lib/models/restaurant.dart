import 'menu_item.dart';

class Restaurant {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String address;
  final String? phone;
  final double rating;
  final bool isOpen;
  final List<MenuItem> menu;

  Restaurant({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.address,
    this.phone,
    required this.rating,
    required this.isOpen,
    this.menu = const [],
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    var menuList = <MenuItem>[];
    if (json['menu'] != null && json['menu'] is List) {
      menuList = (json['menu'] as List)
          .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return Restaurant(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String?,
      rating: double.tryParse(json['rating'].toString()) ?? 0.0,
      isOpen: json['is_open'] == 1 || json['is_open'] == true,
      menu: menuList,
    );
  }
}
