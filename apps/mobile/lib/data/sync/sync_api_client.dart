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
  }) async {
    await _dio.post<Map<String, Object?>>(
      '/auth/register',
      data: {'email': email.trim(), 'password': password},
    );
    return const AuthSession.empty();
  }

  Future<void> requestRegistrationCode({
    required String email,
    required String password,
  }) async {
    await _dio.post<Map<String, Object?>>(
      '/auth/register',
      data: {'email': email.trim(), 'password': password},
    );
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

  Future<void> requestPasswordResetCode({required String email}) async {
    await _dio.post<Map<String, Object?>>(
      '/auth/password-reset',
      data: {'email': email.trim()},
    );
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
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.email,
  });

  const AuthSession.empty() : token = '', userId = '', email = '';

  factory AuthSession.fromJson(Map<String, Object?> json) {
    final user = (json['user'] as Map?)?.cast<String, Object?>() ?? {};
    return AuthSession(
      token: json['token']?.toString() ?? '',
      userId: user['id']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
    );
  }

  final String token;
  final String userId;
  final String email;
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
