import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.displayName,
    required this.bodyWeightKg,
    required this.userId,
    required this.email,
    required this.authToken,
    required this.localPasswordHash,
    required this.localAuthSalt,
    required this.passwordResetCodeHash,
    required this.passwordResetExpiresAt,
    required this.syncCode,
    required this.syncBaseUrl,
  });

  const UserProfile.empty()
    : displayName = '',
      bodyWeightKg = null,
      userId = '',
      email = '',
      authToken = '',
      localPasswordHash = '',
      localAuthSalt = '',
      passwordResetCodeHash = '',
      passwordResetExpiresAt = null,
      syncCode = '',
      syncBaseUrl = '';

  final String displayName;
  final double? bodyWeightKg;
  final String userId;
  final String email;
  final String authToken;
  final String localPasswordHash;
  final String localAuthSalt;
  final String passwordResetCodeHash;
  final DateTime? passwordResetExpiresAt;
  final String syncCode;
  final String syncBaseUrl;

  bool get isEmpty =>
      displayName.trim().isEmpty &&
      bodyWeightKg == null &&
      userId.trim().isEmpty &&
      email.trim().isEmpty &&
      authToken.trim().isEmpty &&
      localPasswordHash.trim().isEmpty &&
      localAuthSalt.trim().isEmpty &&
      passwordResetCodeHash.trim().isEmpty &&
      passwordResetExpiresAt == null &&
      syncCode.trim().isEmpty &&
      syncBaseUrl.trim().isEmpty;

  bool get isAuthenticated =>
      userId.trim().isNotEmpty && authToken.trim().isNotEmpty;

  bool get hasLocalPassword =>
      localPasswordHash.trim().isNotEmpty && localAuthSalt.trim().isNotEmpty;

  bool get canSyncRemotely =>
      isAuthenticated &&
      authToken.trim().isNotEmpty &&
      !authToken.trim().startsWith('local_') &&
      syncBaseUrl.trim().isNotEmpty;

  UserProfile copyWith({
    String? displayName,
    double? bodyWeightKg,
    bool clearBodyWeight = false,
    String? userId,
    String? email,
    String? authToken,
    String? localPasswordHash,
    String? localAuthSalt,
    String? passwordResetCodeHash,
    DateTime? passwordResetExpiresAt,
    bool clearPasswordResetExpiresAt = false,
    String? syncCode,
    String? syncBaseUrl,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      bodyWeightKg: clearBodyWeight ? null : bodyWeightKg ?? this.bodyWeightKg,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      authToken: authToken ?? this.authToken,
      localPasswordHash: localPasswordHash ?? this.localPasswordHash,
      localAuthSalt: localAuthSalt ?? this.localAuthSalt,
      passwordResetCodeHash:
          passwordResetCodeHash ?? this.passwordResetCodeHash,
      passwordResetExpiresAt: clearPasswordResetExpiresAt
          ? null
          : passwordResetExpiresAt ?? this.passwordResetExpiresAt,
      syncCode: syncCode ?? this.syncCode,
      syncBaseUrl: syncBaseUrl ?? this.syncBaseUrl,
    );
  }

  @override
  List<Object?> get props => [
    displayName,
    bodyWeightKg,
    userId,
    email,
    authToken,
    localPasswordHash,
    localAuthSalt,
    passwordResetCodeHash,
    passwordResetExpiresAt,
    syncCode,
    syncBaseUrl,
  ];
}
