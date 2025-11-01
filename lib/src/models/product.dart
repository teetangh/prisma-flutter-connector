import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';
part 'product.g.dart';

@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String name,
    required String description,
    required double price,
    required int stock,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
}

/// Input for creating a new product
@freezed
class CreateProductInput with _$CreateProductInput {
  const factory CreateProductInput({
    required String name,
    required String description,
    required double price,
    @Default(0) int stock,
  }) = _CreateProductInput;

  factory CreateProductInput.fromJson(Map<String, dynamic> json) =>
      _$CreateProductInputFromJson(json);
}

/// Input for updating an existing product
@freezed
class UpdateProductInput with _$UpdateProductInput {
  const factory UpdateProductInput({
    String? name,
    String? description,
    double? price,
    int? stock,
  }) = _UpdateProductInput;

  factory UpdateProductInput.fromJson(Map<String, dynamic> json) =>
      _$UpdateProductInputFromJson(json);
}

/// Filter options for querying products
@freezed
class ProductFilter with _$ProductFilter {
  const factory ProductFilter({
    String? nameContains,
    double? priceUnder,
    double? priceOver,
    int? minStock,
    bool? inStock,
  }) = _ProductFilter;

  factory ProductFilter.fromJson(Map<String, dynamic> json) =>
      _$ProductFilterFromJson(json);
}

/// Sort options for products
enum ProductOrderBy {
  @JsonValue('name_ASC')
  nameAsc,
  @JsonValue('name_DESC')
  nameDesc,
  @JsonValue('price_ASC')
  priceAsc,
  @JsonValue('price_DESC')
  priceDesc,
  @JsonValue('createdAt_ASC')
  createdAtAsc,
  @JsonValue('createdAt_DESC')
  createdAtDesc,
}
