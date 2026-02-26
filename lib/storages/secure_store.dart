import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _storage = FlutterSecureStorage();

  static const _kAccessToken = 'accessToken';
  static const _kRefreshToken = 'refreshToken';
  static const _kUserId = 'userId';

  static Future<void> saveAuth({
    required String userId,
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  static Future<String?> readUserId() => _storage.read(key: _kUserId);
  static Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);
  static Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);

  static Future<void> clearAuth() async {
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }
}