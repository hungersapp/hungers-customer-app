import '../../../../core/validators/indian_mobile.dart';
import '../phone_otp_session.dart';
import '../repositories/auth_repository.dart';

class SendPhoneOtpUseCase {
  const SendPhoneOtpUseCase(this._repository);

  final AuthRepository _repository;

  Future<PhoneOtpSession> call({
    required String mobileNumber,
    bool resend = false,
    String? existingE164,
  }) {
    final e164 = existingE164 ?? _requireE164(mobileNumber);
    return _repository.sendPhoneOtp(
      phoneE164: e164,
      resend: resend,
    );
  }

  String _requireE164(String mobileNumber) {
    final digits = IndianMobile.normalize(mobileNumber);
    if (digits == null) {
      throw Exception(IndianMobile.invalidMessage);
    }
    return IndianMobile.toE164(digits);
  }
}
