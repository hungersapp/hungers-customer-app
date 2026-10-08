import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class VerifyPhoneOtpUseCase {
  const VerifyPhoneOtpUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthUser> call(String smsCode) {
    final code = smsCode.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      throw Exception('Please enter the 6-digit OTP.');
    }
    return _repository.verifyPhoneOtp(smsCode: code);
  }
}
