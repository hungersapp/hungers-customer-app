import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/orders/data/datasources/order_functions_datasource.dart';
import 'package:customer_app/features/orders/domain/exceptions/place_order_functions_exception.dart';

/// Throws a pre-built [FirebaseFunctionsException] from `.call()` instead of
/// making a real network request, so `FirebaseOrderFunctionsDatasource`'s
/// real (private) `_mapFunctionsError` runs against a genuine exception
/// instance rather than a hand-built [PlaceOrderFunctionsException] being
/// injected around it.
class _ThrowingHttpsCallable implements HttpsCallable {
  _ThrowingHttpsCallable(this._error);

  final FirebaseFunctionsException _error;

  @override
  get delegate => throw UnimplementedError();

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    throw _error;
  }

  @override
  Stream<StreamResponse<T, R>> stream<T, R>([Object? input]) {
    throw UnimplementedError();
  }
}

/// Minimal fake satisfying [FirebaseFunctions]'s interface. Every member
/// other than [httpsCallable] is unused by
/// `FirebaseOrderFunctionsDatasource.placeOrder` and throws if ever reached.
class _FakeFirebaseFunctions implements FirebaseFunctions {
  _FakeFirebaseFunctions(this._error);

  final FirebaseFunctionsException _error;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    return _ThrowingHttpsCallable(_error);
  }

  @override
  FirebaseApp get app => throw UnimplementedError();

  @override
  get delegate => throw UnimplementedError();

  @override
  HttpsCallable httpsCallableFromUrl(
    String url, {
    HttpsCallableOptions? options,
  }) => throw UnimplementedError();

  @override
  HttpsCallable httpsCallableFromUri(
    Uri uri, {
    HttpsCallableOptions? options,
  }) => throw UnimplementedError();

  @override
  void useFunctionsEmulator(
    String host,
    int port, {
    bool automaticHostMapping = true,
  }) => throw UnimplementedError();

  @override
  Map<dynamic, dynamic> get pluginConstants => <dynamic, dynamic>{};
}

/// Returns a successful [HttpsCallableResult] wrapping [_data] instead of
/// making a real network request, so `_readResult`'s handling of a
/// successful-but-malformed raw response (2.6-I) can be exercised directly,
/// the same way [_ThrowingHttpsCallable] exercises the failure surface.
class _SucceedingHttpsCallable implements HttpsCallable {
  _SucceedingHttpsCallable(this._data);

  final dynamic _data;

  @override
  get delegate => throw UnimplementedError();

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    return _FakeHttpsCallableResult<T>(_data as T);
  }

  @override
  Stream<StreamResponse<T, R>> stream<T, R>([Object? input]) {
    throw UnimplementedError();
  }
}

/// [HttpsCallableResult] has a private constructor, so this stands in for
/// it in tests, mirroring how [_FakeFirebaseFunctions] stands in for
/// [FirebaseFunctions] elsewhere in this file.
class _FakeHttpsCallableResult<T> implements HttpsCallableResult<T> {
  _FakeHttpsCallableResult(this._data);

  final T _data;

  @override
  T get data => _data;
}

/// Minimal fake satisfying [FirebaseFunctions]'s interface for a
/// *successful* callable response, mirroring [_FakeFirebaseFunctions]
/// (which is built only for the failure surface).
class _FakeFirebaseFunctionsSucceeding implements FirebaseFunctions {
  _FakeFirebaseFunctionsSucceeding(this._data);

  final dynamic _data;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    return _SucceedingHttpsCallable(_data);
  }

  @override
  FirebaseApp get app => throw UnimplementedError();

  @override
  get delegate => throw UnimplementedError();

  @override
  HttpsCallable httpsCallableFromUrl(
    String url, {
    HttpsCallableOptions? options,
  }) => throw UnimplementedError();

  @override
  HttpsCallable httpsCallableFromUri(
    Uri uri, {
    HttpsCallableOptions? options,
  }) => throw UnimplementedError();

  @override
  void useFunctionsEmulator(
    String host,
    int port, {
    bool automaticHostMapping = true,
  }) => throw UnimplementedError();

  @override
  Map<dynamic, dynamic> get pluginConstants => <dynamic, dynamic>{};
}

/// Drives the real `FirebaseOrderFunctionsDatasource.placeOrder` with a
/// successful callable call whose raw response body is [rawData], so
/// `_readResult`'s own parsing/validation runs for real.
Future<PlaceOrderFunctionResult> _placeOrderWithRawData(dynamic rawData) {
  final datasource = FirebaseOrderFunctionsDatasource(
    functions: _FakeFirebaseFunctionsSucceeding(rawData),
  );
  return datasource.placeOrder(
    restaurantId: 'r1',
    items: const [PlaceOrderLineRequest(foodId: 'f1', quantity: 1)],
    deliveryAddress: const PlaceOrderDeliveryAddressRequest(
      address: '12 Main Road',
      city: 'Chennai',
      state: 'Tamil Nadu',
      pincode: '600001',
      latitude: 13.08,
      longitude: 80.27,
      doorNumber: '12',
      street: 'Main Road',
    ),
  );
}

/// Drives the real `FirebaseOrderFunctionsDatasource.placeOrder` with a
/// [FirebaseFunctionsException] carrying [code]/[message]/[details] exactly
/// as a real callable failure would, and returns whatever
/// [PlaceOrderFunctionsException] the production `_mapFunctionsError`
/// actually produces.
Future<PlaceOrderFunctionsException> _mappedError({
  required String code,
  String message = 'error',
  Map<String, dynamic>? details,
}) async {
  final datasource = FirebaseOrderFunctionsDatasource(
    functions: _FakeFirebaseFunctions(
      FirebaseFunctionsException(
        message: message,
        code: code,
        details: details,
      ),
    ),
  );

  try {
    await datasource.placeOrder(
      restaurantId: 'r1',
      items: const [PlaceOrderLineRequest(foodId: 'f1', quantity: 1)],
      deliveryAddress: const PlaceOrderDeliveryAddressRequest(
        address: '12 Main Road',
        city: 'Chennai',
        state: 'Tamil Nadu',
        pincode: '600001',
        latitude: 13.08,
        longitude: 80.27,
        doorNumber: '12',
        street: 'Main Road',
      ),
    );
  } on PlaceOrderFunctionsException catch (error) {
    return error;
  }
  fail('expected placeOrder to throw a PlaceOrderFunctionsException');
}

void main() {
  group('FirebaseOrderFunctionsDatasource error mapping', () {
    test('deadline-exceeded maps to PlaceOrderServerException', () async {
      final error = await _mappedError(code: 'deadline-exceeded');
      expect(error, isA<PlaceOrderServerException>());
    });

    test('unavailable maps to PlaceOrderServerException', () async {
      final error = await _mappedError(code: 'unavailable');
      expect(error, isA<PlaceOrderServerException>());
    });

    test('internal maps to PlaceOrderServerException', () async {
      final error = await _mappedError(code: 'internal');
      expect(error, isA<PlaceOrderServerException>());
    });

    test(
      'an unrecognized/unknown code maps to PlaceOrderServerException',
      () async {
        final error = await _mappedError(code: 'some-future-code');
        expect(error, isA<PlaceOrderServerException>());
      },
    );

    test(
      'unauthenticated maps to PlaceOrderUnauthenticatedException',
      () async {
        final error = await _mappedError(code: 'unauthenticated');
        expect(error, isA<PlaceOrderUnauthenticatedException>());
      },
    );

    test(
      'permission-denied maps to PlaceOrderPermissionDeniedException',
      () async {
        // Production reuses the generic INVALID_ARGUMENT detail label here
        // for an unrelated condition (idempotency key reuse) - the mapper
        // must ignore the detail for this code and key off error.code alone.
        final error = await _mappedError(
          code: 'permission-denied',
          details: {'code': 'INVALID_ARGUMENT'},
        );
        expect(error, isA<PlaceOrderPermissionDeniedException>());
      },
    );

    group('not-found (production detail codes)', () {
      test(
        'FOOD_NOT_FOUND maps to PlaceOrderItemsUnavailableException',
        () async {
          final error = await _mappedError(
            code: 'not-found',
            details: {'code': 'FOOD_NOT_FOUND'},
          );
          expect(error, isA<PlaceOrderItemsUnavailableException>());
        },
      );

      test(
        'RESTAURANT_NOT_FOUND maps to PlaceOrderRestaurantNotFoundException',
        () async {
          final error = await _mappedError(
            code: 'not-found',
            details: {'code': 'RESTAURANT_NOT_FOUND'},
          );
          expect(error, isA<PlaceOrderRestaurantNotFoundException>());
        },
      );

      test('a missing detail code falls back to '
          'PlaceOrderRestaurantNotFoundException', () async {
        final error = await _mappedError(code: 'not-found');
        expect(error, isA<PlaceOrderRestaurantNotFoundException>());
      });
    });

    group('failed-precondition (production detail codes)', () {
      test('RESTAURANT_NOT_ACCEPTING maps to '
          'PlaceOrderRestaurantNotAcceptingException', () async {
        final error = await _mappedError(
          code: 'failed-precondition',
          details: {'code': 'RESTAURANT_NOT_ACCEPTING'},
        );
        expect(error, isA<PlaceOrderRestaurantNotAcceptingException>());
      });

      test(
        'NOT_SERVICEABLE maps to PlaceOrderNotServiceableException',
        () async {
          final error = await _mappedError(
            code: 'failed-precondition',
            details: {'code': 'NOT_SERVICEABLE'},
          );
          expect(error, isA<PlaceOrderNotServiceableException>());
        },
      );

      test(
        'INVALID_ADDRESS maps to PlaceOrderInvalidAddressException',
        () async {
          final error = await _mappedError(
            code: 'failed-precondition',
            details: {'code': 'INVALID_ADDRESS'},
          );
          expect(error, isA<PlaceOrderInvalidAddressException>());
        },
      );

      test(
        'PINCODE_NOT_SERVICEABLE maps to '
        'PlaceOrderPincodeNotServiceableException, distinct from '
        'PlaceOrderNotServiceableException (the restaurant-distance case)',
        () async {
          final error = await _mappedError(
            code: 'failed-precondition',
            details: {'code': 'PINCODE_NOT_SERVICEABLE'},
          );
          expect(error, isA<PlaceOrderPincodeNotServiceableException>());
          expect(error, isNot(isA<PlaceOrderNotServiceableException>()));
        },
      );

      for (final detail in [
        'FOOD_RESTAURANT_MISMATCH',
        'FOOD_NOT_APPROVED',
        'FOOD_UNAVAILABLE',
        'INVALID_PRICING_DATA',
      ]) {
        test('$detail maps to PlaceOrderItemsUnavailableException', () async {
          final error = await _mappedError(
            code: 'failed-precondition',
            details: {'code': detail},
          );
          expect(error, isA<PlaceOrderItemsUnavailableException>());
        });
      }

      test('a missing detail code falls back to '
          'PlaceOrderItemsUnavailableException', () async {
        final error = await _mappedError(code: 'failed-precondition');
        expect(error, isA<PlaceOrderItemsUnavailableException>());
      });
    });

    group('invalid-argument (production detail codes)', () {
      test(
        'INVALID_ADDRESS maps to PlaceOrderInvalidAddressException',
        () async {
          final error = await _mappedError(
            code: 'invalid-argument',
            details: {'code': 'INVALID_ADDRESS'},
          );
          expect(error, isA<PlaceOrderInvalidAddressException>());
        },
      );

      test('INVALID_RECIPIENT maps to PlaceOrderInvalidRecipientException '
          'carrying the server message', () async {
        final error = await _mappedError(
          code: 'invalid-argument',
          message: 'Please enter a valid 10-digit mobile number.',
          details: {'code': 'INVALID_RECIPIENT'},
        );
        expect(error, isA<PlaceOrderInvalidRecipientException>());
        expect(error.message, 'Please enter a valid 10-digit mobile number.');
      });

      test(
        'INVALID_ARGUMENT maps to PlaceOrderInvalidArgumentException',
        () async {
          final error = await _mappedError(
            code: 'invalid-argument',
            details: {'code': 'INVALID_ARGUMENT'},
          );
          expect(error, isA<PlaceOrderInvalidArgumentException>());
        },
      );

      test('a missing detail code falls back to '
          'PlaceOrderInvalidArgumentException', () async {
        final error = await _mappedError(code: 'invalid-argument');
        expect(error, isA<PlaceOrderInvalidArgumentException>());
      });
    });
  });

  group('FirebaseOrderFunctionsDatasource malformed successful response '
      'handling (2.6-I)', () {
    test('a valid response is parsed unchanged', () async {
      final result = await _placeOrderWithRawData({
        'orderId': 'order-123',
        'replayed': false,
        'summary': {
          'itemTotal': 100,
          'deliveryFee': 25,
          'platformFee': 5,
          'gstAmount': 6.5,
          'grandTotal': 136.5,
          'distanceKm': 0,
        },
      });
      expect(result.orderId, 'order-123');
      expect(result.replayed, false);
      expect(result.itemTotal, 100);
      expect(result.deliveryFee, 25);
      expect(result.platformFee, 5);
      expect(result.gstAmount, 6.5);
      expect(result.grandTotal, 136.5);
      expect(result.distanceKm, 0);
    });

    test('a null result throws PlaceOrderServerException', () async {
      await expectLater(
        _placeOrderWithRawData(null),
        throwsA(isA<PlaceOrderServerException>()),
      );
    });

    test(
      'a non-map result (e.g. a List) throws PlaceOrderServerException',
      () async {
        await expectLater(
          _placeOrderWithRawData(<dynamic>['unexpected', 'shape']),
          throwsA(isA<PlaceOrderServerException>()),
        );
      },
    );

    test('a missing orderId throws PlaceOrderServerException', () async {
      await expectLater(
        _placeOrderWithRawData({
          'replayed': false,
          'summary': <String, dynamic>{},
        }),
        throwsA(isA<PlaceOrderServerException>()),
      );
    });

    test('an empty orderId throws PlaceOrderServerException', () async {
      await expectLater(
        _placeOrderWithRawData({
          'orderId': '',
          'replayed': false,
          'summary': <String, dynamic>{},
        }),
        throwsA(isA<PlaceOrderServerException>()),
      );
    });

    test(
      'a whitespace-only orderId throws PlaceOrderServerException',
      () async {
        await expectLater(
          _placeOrderWithRawData({
            'orderId': '   ',
            'replayed': false,
            'summary': <String, dynamic>{},
          }),
          throwsA(isA<PlaceOrderServerException>()),
        );
      },
    );

    // 2.6-I follow-up fix: `orderId` is now guarded with an `is String`
    // check before use, matching every other field `_readResult` reads
    // (`data is! Map`, `summaryRaw is! Map`, `_readDouble`'s `value is
    // num`). A non-string, non-null `orderId` (e.g. a number) is now
    // treated the same as a missing/empty one, producing the same clean
    // PlaceOrderServerException as every other malformed-response case
    // above, instead of the raw TypeError this used to throw.
    test(
      'a non-string orderId (e.g. a number) throws PlaceOrderServerException, '
      'not a raw TypeError',
      () async {
        await expectLater(
          _placeOrderWithRawData({
            'orderId': 12345,
            'replayed': false,
            'summary': <String, dynamic>{},
          }),
          throwsA(isA<PlaceOrderServerException>()),
        );
      },
    );

    test('a non-string, non-numeric orderId (e.g. a bool or a list) also '
        'throws PlaceOrderServerException', () async {
      await expectLater(
        _placeOrderWithRawData({
          'orderId': true,
          'replayed': false,
          'summary': <String, dynamic>{},
        }),
        throwsA(isA<PlaceOrderServerException>()),
      );
      await expectLater(
        _placeOrderWithRawData({
          'orderId': <dynamic>['not', 'a', 'string'],
          'replayed': false,
          'summary': <String, dynamic>{},
        }),
        throwsA(isA<PlaceOrderServerException>()),
      );
    });
  });
}
