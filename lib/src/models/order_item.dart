import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prisma_flutter_connector/src/models/product.dart';

part 'order_item.freezed.dart';
part 'order_item.g.dart';

@freezed
class OrderItem with _$OrderItem {
  const factory OrderItem({
    required String id,
    required String orderId,
    required String productId,
    required int quantity,
    required double price,
    // Relations (optional, loaded when needed)
    Product? product,
  }) = _OrderItem;

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
}

/// Input for creating a new order item (used within CreateOrderInput)
@freezed
class OrderItemInput with _$OrderItemInput {
  const factory OrderItemInput({
    required String productId,
    required int quantity,
  }) = _OrderItemInput;

  factory OrderItemInput.fromJson(Map<String, dynamic> json) =>
      _$OrderItemInputFromJson(json);
}
