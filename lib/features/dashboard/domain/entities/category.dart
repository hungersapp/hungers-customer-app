class Category {
  final String id;
  final String name;
  final String imageUrl;
  final bool isActive;
  final int displayOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Category({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.isActive,
    required this.displayOrder,
    this.createdAt,
    this.updatedAt,
  });
}
