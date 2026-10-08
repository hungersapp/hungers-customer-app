import 'entities/placed_order.dart';

/// Visibility for the ONLY customer call action: Call Rider (direct tel:
/// dial). There is deliberately no Call Restaurant. Derived from the existing
/// [OrderStatus] and the customer-readable delivery job — no new lifecycle
/// state.
class OrderContactVisibility {
  const OrderContactVisibility._();

  /// Call Rider is offered only while the order is still ongoing AND the
  /// delivery job the customer may read shows an active rider assignment
  /// (assigned / picked_up / out_for_delivery). Never for placed-without-rider,
  /// delivered or cancelled orders.
  static bool showRiderCall({
    required OrderStatus status,
    required bool hasActiveRiderAssignment,
  }) {
    return hasActiveRiderAssignment && status.isOngoing;
  }
}
