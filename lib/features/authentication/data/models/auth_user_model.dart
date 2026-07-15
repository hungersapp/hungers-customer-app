import '../../domain/entities/auth_user.dart';

class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required super.uid,
    super.name,
    super.email,
    super.mobileNumber,
    super.photoUrl,
    required super.emailVerified,
    required super.isAnonymous,
  });

  /// Firestore JSON → Model
  factory AuthUserModel.fromMap(Map<String, dynamic> map) {
    return AuthUserModel(
      uid: map['uid'] ?? '',
      name: map['name'],
      email: map['email'],
      mobileNumber: map['mobileNumber'],
      photoUrl: map['photoUrl'],
      emailVerified: map['emailVerified'] ?? false,
      isAnonymous: map['isAnonymous'] ?? false,
    );
  }

  /// Model → Firestore JSON
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'mobileNumber': mobileNumber,
      'photoUrl': photoUrl,
      'emailVerified': emailVerified,
      'isAnonymous': isAnonymous,
    };
  }

  /// Entity → Model
  factory AuthUserModel.fromEntity(AuthUser user) {
    return AuthUserModel(
      uid: user.uid,
      name: user.name,
      email: user.email,
      mobileNumber: user.mobileNumber,
      photoUrl: user.photoUrl,
      emailVerified: user.emailVerified,
      isAnonymous: user.isAnonymous,
    );
  }

  /// Model → Entity
  AuthUser toEntity() {
    return AuthUser(
      uid: uid,
      name: name,
      email: email,
      mobileNumber: mobileNumber,
      photoUrl: photoUrl,
      emailVerified: emailVerified,
      isAnonymous: isAnonymous,
    );
  }

  AuthUserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? mobileNumber,
    String? photoUrl,
    bool? emailVerified,
    bool? isAnonymous,
  }) {
    return AuthUserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }
}