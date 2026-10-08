import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/customer_orders_page.dart';
import '../../domain/entities/placed_order.dart';
import '../models/order_model.dart';

class OrderFirestoreDatasource {
  const OrderFirestoreDatasource(this.firestore);

  final FirebaseFirestore firestore;

  /// Unused by live checkout (`PlaceOrderUseCase` calls `placeOrder`).
  /// Kept as a rollback helper; Firestore rules deny this client write.
  Future<PlacedOrder> createOrder(PlaceOrderRequest request) async {
    final restaurantName = request.items.first.restaurantName;
    final restaurantId = request.items.first.restaurantId;
    final lineItems = request.items
        .map(
          (item) => OrderLineItem(
            foodId: item.foodId,
            foodName: item.foodName,
            quantity: item.quantity,
            price: item.price,
            offerPrice: item.offerPrice,
            foodImage: item.foodImage,
            isVeg: item.isVeg,
          ),
        )
        .toList();
    final itemCount = lineItems.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
    final createdAt = DateTime.now();
    final location = request.deliveryLocation;

    final payload = OrderModel.toCreateDocument(
      userId: request.userId,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      summary: request.summary,
      items: request.items,
      deliveryLocation: location,
      orderForOther: request.orderForOther,
      recipientName: request.recipientName,
      recipientPhone: request.recipientPhone,
    );

    final doc = await firestore.collection('orders').add(payload);

    return PlacedOrder(
      id: doc.id,
      userId: request.userId,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      grandTotal: request.summary.grandTotal,
      itemCount: itemCount,
      createdAt: createdAt,
      updatedAt: createdAt,
      status: OrderStatus.placed,
      paymentMethod: request.paymentMethod,
      paymentStatus: 'pending',
      itemTotal: request.summary.itemTotal,
      deliveryFee: request.summary.deliveryFee,
      platformFee: request.summary.platformFee,
      gstAmount: request.summary.gstAmount,
      items: lineItems,
      orderForOther: request.orderForOther,
      recipientName: request.recipientName,
      recipientPhone: request.recipientPhone,
      deliveryAddress: location == null
          ? null
          : OrderDeliveryAddress(
              address: location.detailedAddressLine.trim().isNotEmpty
                  ? location.detailedAddressLine
                  : location.displayAddress,
              city: location.city,
              state: location.state,
              pincode: location.pincode,
              latitude: location.latitude,
              longitude: location.longitude,
            ),
    );
  }

  Future<List<PlacedOrder>> getOrdersByUserId(String userId) async {
    final page = await getOrdersPage(userId: userId);
    return page.orders;
  }

  Future<CustomerOrdersPage> getOrdersPage({
    required String userId,
    int limit = 20,
    Object? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit + 1);
    if (startAfter is QueryDocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final hasMore = snapshot.docs.length > limit;
    final pageDocs = hasMore
        ? snapshot.docs.take(limit).toList()
        : snapshot.docs;
    final orders = pageDocs
        .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
        .where((order) => order.userId == userId)
        .toList();
    return CustomerOrdersPage(
      orders: orders,
      cursor: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: hasMore,
    );
  }

  Future<PlacedOrder> getOrderById({
    required String orderId,
    required String userId,
  }) async {
    final doc = await firestore.collection('orders').doc(orderId).get();
    if (!doc.exists || doc.data() == null) {
      throw StateError('Order not found');
    }

    final order = OrderModel.fromMap(doc.data()!, doc.id);
    if (order.userId != userId) {
      throw StateError('Order not found');
    }
    return order;
  }
}
