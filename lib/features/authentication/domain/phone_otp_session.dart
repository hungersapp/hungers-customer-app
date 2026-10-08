import 'entities/auth_user.dart';

/// In-memory phone verification handle. Never contains an OTP code.
class PhoneOtpSession {
  const PhoneOtpSession({
    required this.phoneE164,
    this.verificationId,
    this.resendToken,
    this.autoVerifiedUser,
  });

  final String phoneE164;
  final String? verificationId;
  final int? resendToken;
  final AuthUser? autoVerifiedUser;

  bool get isAutoVerified => autoVerifiedUser != null;
}
