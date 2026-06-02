import 'package:dio/dio.dart';

class SyncApiClient {
  SyncApiClient({required String baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: _normalizeBaseUrl(baseUrl),
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 20),
              headers: {'content-type': 'application/json'},
            ),
          );

  final Dio _dio;

  Future<AuthSession> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/auth/register',
      data: _authPayload(email: email, password: password, name: name),
    );
    return AuthSession.fromJson(response.data ?? {});
  }

  Future<AuthSession> requestRegistrationCode({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/auth/register',
      data: _authPayload(email: email, password: password, name: name),
    );
    return AuthSession.fromJson(response.data ?? {});
  }

  Future<AuthSession> verifyRegistrationCode({
    required String email,
    required String code,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/auth/register/verify',
      data: {'email': email.trim(), 'code': code.trim()},
    );
    return AuthSession.fromJson(response.data ?? {});
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/auth/login',
      data: {'email': email.trim(), 'password': password},
    );
    return AuthSession.fromJson(response.data ?? {});
  }

  Future<AuthSession> requestPasswordResetCode({required String email}) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/auth/password-reset',
      data: {'email': email.trim()},
    );
    return AuthSession.fromJson(response.data ?? {});
  }

  Future<AuthSession> confirmPasswordReset({
    required String email,
    required String code,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/auth/password-reset/confirm',
      data: {'email': email.trim(), 'code': code.trim(), 'password': password},
    );
    return AuthSession.fromJson(response.data ?? {});
  }

  Future<SyncUploadResult> uploadMine({
    required String token,
    required Map<String, Object?> snapshot,
  }) async {
    final response = await _dio.put<Map<String, Object?>>(
      '/sync/me',
      data: snapshot,
      options: Options(headers: _authHeaders(token)),
    );
    return SyncUploadResult.fromJson(response.data ?? {});
  }

  Future<Map<String, Object?>> downloadMine({required String token}) async {
    final response = await _dio.get<Map<String, Object?>>(
      '/sync/me',
      options: Options(headers: _authHeaders(token)),
    );
    return response.data ?? {};
  }

  Future<SyncUploadResult> upload({
    required String syncCode,
    required Map<String, Object?> snapshot,
  }) async {
    final response = await _dio.put<Map<String, Object?>>(
      '/sync/${_normalizeSyncCode(syncCode)}',
      data: snapshot,
    );
    return SyncUploadResult.fromJson(response.data ?? {});
  }

  Future<Map<String, Object?>> download({required String syncCode}) async {
    final response = await _dio.get<Map<String, Object?>>(
      '/sync/${_normalizeSyncCode(syncCode)}',
    );
    return response.data ?? {};
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    final withoutSlash = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return withoutSlash.endsWith('/api') ? withoutSlash : '$withoutSlash/api';
  }

  static String _normalizeSyncCode(String value) {
    return value.trim().toUpperCase().replaceAll(' ', '');
  }

  Map<String, String> _authHeaders(String token) {
    return {'authorization': 'Bearer ${token.trim()}'};
  }

  Map<String, Object?> _authPayload({
    required String email,
    required String password,
    String? name,
  }) {
    final trimmedName = name?.trim() ?? '';
    return {
      'email': email.trim(),
      'password': password,
      'confirmPassword': password,
      if (trimmedName.isNotEmpty) 'name': trimmedName,
    };
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.email,
    required this.message,
    required this.devCode,
  });

  const AuthSession.empty()
    : token = '',
      userId = '',
      email = '',
      message = '',
      devCode = '';

  factory AuthSession.fromJson(Map<String, Object?> json) {
    final user = (json['user'] as Map?)?.cast<String, Object?>() ?? {};
    return AuthSession(
      token: json['token']?.toString() ?? '',
      userId: user['id']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      devCode: json['devCode']?.toString() ?? '',
    );
  }

  final String token;
  final String userId;
  final String email;
  final String message;
  final String devCode;
}

class SyncUploadResult {
  const SyncUploadResult({
    required this.savedAt,
    required this.exerciseCount,
    required this.trainingDayCount,
    required this.sessionCount,
    required this.setCount,
  });

  factory SyncUploadResult.fromJson(Map<String, Object?> json) {
    final counts = (json['counts'] as Map?)?.cast<String, Object?>() ?? {};
    return SyncUploadResult(
      savedAt: json['savedAt']?.toString() ?? DateTime.now().toIso8601String(),
      exerciseCount: _intValue(counts['exercises']),
      trainingDayCount: _intValue(counts['trainingDays']),
      sessionCount: _intValue(counts['sessions']),
      setCount: _intValue(counts['sets']),
    );
  }

  final String savedAt;
  final int exerciseCount;
  final int trainingDayCount;
  final int sessionCount;
  final int setCount;
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}
