import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/offer.dart';
import '../models/offer_model.dart';

/// Reads the offers a customer may be shown. Read-only: customers can never
/// create or change an offer (firestore.rules), and what an offer is worth on
/// an order is decided by `quoteOrder` / `placeOrder`.
abstract class OfferDatasource {
  Future<List<Offer>> getActiveOffers();
}

class FirestoreOfferDatasource implements OfferDatasource {
  FirestoreOfferDatasource({this._firestore});

  final FirebaseFirestore? _firestore;

  static const int _limit = 100;

  @override
  Future<List<Offer>> getActiveOffers() async {
    final snapshot = await (_firestore ?? FirebaseFirestore.instance)
        .collection('offers')
        .where('isActive', isEqualTo: true)
        .limit(_limit)
        .get();
    return [
      for (final doc in snapshot.docs) ?OfferModel.fromMap(doc.id, doc.data()),
    ];
  }
}
