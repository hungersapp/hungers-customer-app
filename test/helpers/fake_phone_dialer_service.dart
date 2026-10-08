import 'package:customer_app/core/services/phone_dialer_service.dart';

class FakePhoneDialerService implements PhoneDialerService {
  FakePhoneDialerService({this.succeeds = true});

  bool succeeds;
  final List<String> calledNumbers = [];

  @override
  Future<bool> call(String phoneNumber) async {
    calledNumbers.add(phoneNumber);
    return succeeds;
  }
}
