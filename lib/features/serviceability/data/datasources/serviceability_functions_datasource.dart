import 'package:cloud_functions/cloud_functions.dart';

/// Trusted backend boundary. Never reads serviceability_* collections.
class ServiceabilityFunctionsDatasource {
  ServiceabilityFunctionsDatasource({
    FirebaseFunctions? functions,
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  static const String callableName = 'checkPincodeServiceability';

  Future<bool> checkPincode(String pincode) async {
    final callable = _functions.httpsCallable(callableName);
    final result = await callable.call(<String, dynamic>{
      'pincode': pincode,
    });

    final data = result.data;
    if (data is Map) {
      return data['serviceable'] == true;
    }
    return false;
  }
}
