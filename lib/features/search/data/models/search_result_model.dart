import '../../domain/entities/search_result_entity.dart';

class SearchResultModel extends SearchResultEntity {
  const SearchResultModel({
    required super.id,
    required super.title,
    required super.subtitle,
    required super.imageUrl,
    required super.type,
    super.restaurantId,
  });

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    return SearchResultModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      type: json['type'] == 'food'
          ? SearchResultType.food
          : json['type'] == 'category'
          ? SearchResultType.category
          : SearchResultType.restaurant,
      restaurantId: json['restaurantId'] ?? '',
    );
  }

  factory SearchResultModel.fromEntity(SearchResultEntity entity) {
    return SearchResultModel(
      id: entity.id,
      title: entity.title,
      subtitle: entity.subtitle,
      imageUrl: entity.imageUrl,
      type: entity.type,
      restaurantId: entity.restaurantId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'type': type.name,
      'restaurantId': restaurantId,
    };
  }

  SearchResultModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? imageUrl,
    SearchResultType? type,
    String? restaurantId,
  }) {
    return SearchResultModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      restaurantId: restaurantId ?? this.restaurantId,
    );
  }
}
