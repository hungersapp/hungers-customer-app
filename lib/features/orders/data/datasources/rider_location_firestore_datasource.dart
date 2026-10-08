import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/rider_location.dart';
import '../models/rider_location_model.dart';

class RiderLocationFirestoreDatasource {
  const RiderLocationFirestoreDatasource(this.firestore);

  final FirebaseFirestore firestore;

  static const String collectionName = 'delivery_jobs';

  Stream<DeliveryJobRiderTracking?> watchByOrderId(String orderId) {
    return firestore
        .collection(collectionName)
        .doc(orderId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return null;
          }
          return RiderLocationModel.fromJobDocument(snapshot.id, snapshot.data());
        });
  }
}
