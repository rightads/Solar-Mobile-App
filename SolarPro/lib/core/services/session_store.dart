import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';

/// Access/refresh tokens live only in the platform's encrypted store
/// (Android Keystore-backed EncryptedSharedPreferences, iOS/macOS Keychain,
/// Windows DPAPI) — never in plain SharedPreferences.
class SessionStore {
  SessionStore._();

  // Android: AES-GCM data encrypted with a Keystore-held RSA key (package default).
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static String? _access;
  static String? _refresh;
  static bool _loaded = false;

  static Future<void> _load() async {
    if (_loaded) return;
    _access = await _storage.read(key: AppConstants.kAccessToken);
    _refresh = await _storage.read(key: AppConstants.kRefreshToken);
    // One-time cleanup of tokens written by older builds in plain preferences.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(AppConstants.kAccessToken) || prefs.containsKey(AppConstants.kRefreshToken)) {
      await prefs.remove(AppConstants.kAccessToken);
      await prefs.remove(AppConstants.kRefreshToken);
    }
    _loaded = true;
  }

  static Future<String?> accessToken() async {
    await _load();
    return _access;
  }

  static Future<String?> refreshToken() async {
    await _load();
    return _refresh;
  }

  static Future<bool> hasSession() async => (await accessToken())?.isNotEmpty == true || (await refreshToken())?.isNotEmpty == true;

  static Future<void> save({required String access, String? refresh}) async {
    _access = access;
    await _storage.write(key: AppConstants.kAccessToken, value: access);
    if (refresh != null) {
      _refresh = refresh;
      await _storage.write(key: AppConstants.kRefreshToken, value: refresh);
    }
    _loaded = true;
  }

  /// Clears tokens and cached profile/role data.
  static Future<void> clear() async {
    _access = null;
    _refresh = null;
    _loaded = true;
    await _storage.delete(key: AppConstants.kAccessToken);
    await _storage.delete(key: AppConstants.kRefreshToken);
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      AppConstants.kAccessToken,
      AppConstants.kRefreshToken,
      AppConstants.kUserRole,
      AppConstants.kUserId,
      AppConstants.kUserName,
      AppConstants.kUserPhone,
      'user_email',
      'user_team',
      'user_team_type',
      'user_employee_no',
    ]) {
      await prefs.remove(key);
    }
  }
}
