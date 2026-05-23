import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.displayName,
    required this.bodyWeightKg,
    required this.userId,
    required this.email,
    required this.authToken,
    required this.syncCode,
    required this.syncBaseUrl,
  });

  const UserProfile.empty()
    : displayName = '',
      bodyWeightKg = null,
      userId = '',
      email = '',
      authToken = '',
      syncCode = '',
      syncBaseUrl = '';

  final String displayName;
  final double? bodyWeightKg;
  final String userId;
  final String email;
  final String authToken;
  final String syncCode;
  final String syncBaseUrl;

  bool get isEmpty =>
      displayName.trim().isEmpty &&
      bodyWeightKg == null &&
      userId.trim().isEmpty &&
      email.trim().isEmpty &&
      authToken.trim().isEmpty &&
      syncCode.trim().isEmpty &&
      syncBaseUrl.trim().isEmpty;

  bool get isAuthenticated =>
      userId.trim().isNotEmpty && authToken.trim().isNotEmpty;

  UserProfile copyWith({
    String? displayName,
    double? bodyWeightKg,
    bool clearBodyWeight = false,
    String? userId,
    String? email,
    String? authToken,
    String? syncCode,
    String? syncBaseUrl,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      bodyWeightKg: clearBodyWeight ? null : bodyWeightKg ?? this.bodyWeightKg,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      authToken: authToken ?? this.authToken,
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
    syncCode,
    syncBaseUrl,
  ];
}
