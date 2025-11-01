import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prisma_flutter_connector/src/models/order_item.dart';
import 'package:prisma_flutter_connector/src/models/user.dart';

part 'order.freezed.dart';
part 'order.g.dart';

enum OrderStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('PROCESSING')
  processing,
  @JsonValue('SHIPPED')
  shipped,
  @JsonValue('DELIVERED')
  delivered,
  @JsonValue('CANCELLED')
  cancelled,
}

@freezed
class Order with _$Order {
  const factory Order({
    required String id,
    required String userId,
    required OrderStatus status,
    required double total,
    DateTime? createdAt,
    DateTime? updatedAt,
    // Relations (optional, loaded when needed)
    User? user,
    List<OrderItem>? items,
  }) = _Order;

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
}

/// Input for creating a new order
@freezed
class CreateOrderInput with _$CreateOrderInput {
  const factory CreateOrderInput({
    required String userId,
    required List<OrderItemInput> items,
    @Default(OrderStatus.pending) OrderStatus status,
  }) = _CreateOrderInput;

  factory CreateOrderInput.fromJson(Map<String, dynamic> json) =>
      _$CreateOrderInputFromJson(json);
}

/// Input for updating an existing order
@freezed
class UpdateOrderInput with _$UpdateOrderInput {
  const factory UpdateOrderInput({
    OrderStatus? status,
  }) = _UpdateOrderInput;

  factory UpdateOrderInput.fromJson(Map<String, dynamic> json) =>
      _$UpdateOrderInputFromJson(json);
}

/// Filter options for querying orders
@freezed
class OrderFilter with _$OrderFilter {
  const factory OrderFilter({
    String? userId,
    OrderStatus? status,
    double? totalOver,
    double? totalUnder,
  }) = _OrderFilter;

  factory OrderFilter.fromJson(Map<String, dynamic> json) =>
      _$OrderFilterFromJson(json);
}

/// Sort options for orders
enum OrderOrderBy {
  @JsonValue('createdAt_ASC')
  createdAtAsc,
  @JsonValue('createdAt_DESC')
  createdAtDesc,
  @JsonValue('total_ASC')
  totalAsc,
  @JsonValue('total_DESC')
  totalDesc,
  @JsonValue('status_ASC')
  statusAsc,
  @JsonValue('status_DESC')
  statusDesc,
}
