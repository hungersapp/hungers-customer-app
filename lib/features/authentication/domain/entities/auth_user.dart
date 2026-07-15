class AuthUser {
  final String uid;
  final String? name;
  final String? email;
  final String? mobileNumber;
  final String? photoUrl;
  final bool emailVerified;
  final bool isAnonymous;

  const AuthUser({
    required this.uid,
    this.name,
    this.email,
    this.mobileNumber,
    this.photoUrl,
    required this.emailVerified,
    required this.isAnonymous,
  });

  AuthUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? mobileNumber,
    String? photoUrl,
    bool? emailVerified,
    bool? isAnonymous,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  @override
  String toString() {
    return '''
AuthUser(
  uid: $uid,
  name: $name,
  email: $email,
  mobileNumber: $mobileNumber,
  photoUrl: $photoUrl,
  emailVerified: $emailVerified,
  isAnonymous: $isAnonymous,
)
''';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          name == other.name &&
          email == other.email &&
          mobileNumber == other.mobileNumber &&
          photoUrl == other.photoUrl &&
          emailVerified == other.emailVerified &&
          isAnonymous == other.isAnonymous;

  @override
  int get hashCode =>
      uid.hashCode ^
      name.hashCode ^
      email.hashCode ^
      mobileNumber.hashCode ^
      photoUrl.hashCode ^
      emailVerified.hashCode ^
      isAnonymous.hashCode;
}