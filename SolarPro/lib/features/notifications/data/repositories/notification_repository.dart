import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/features/notifications/data/models/notification_model.dart';

class NotificationRepository {
  final ApiClient _apiClient;
  static const String _kNotificationsCacheKey = 'solar_notifications_cache_v1';
  static const String _kFcmTokenKey = 'solar_registered_fcm_token';

  NotificationRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // ── List Notifications ─────────────────────────────────────────────────────

  Future<List<NotificationModel>> listNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(AppConstants.kUserRole)?.toLowerCase() ?? '';

    try {
      final response = await _apiClient.dio.get('/notifications');
      final List<NotificationModel> result = [];
      if (response.data is List) {
        for (final item in response.data) {
          if (item is Map<String, dynamic>) {
            result.add(NotificationModel.fromJson(item));
          }
        }
      }

      await _cacheNotifications(result);
      return _filterForRole(result, role);
    } catch (e) {
      dev.log('Error fetching notifications from API: $e. Using local cache/seed.');
      return _loadCachedOrSeed(role);
    }
  }

  // ── Get Unread Count ───────────────────────────────────────────────────────

  Future<int> getUnreadCount() async {
    try {
      final response = await _apiClient.dio.get('/notifications/unread-count');
      if (response.data is Map<String, dynamic> && response.data['count'] != null) {
        return (response.data['count'] as num).toInt();
      }
    } catch (_) {}

    final list = await listNotifications();
    return list.where((n) => !n.isRead).length;
  }

  // ── Mark As Read ───────────────────────────────────────────────────────────

  Future<void> markAsRead(String id) async {
    try {
      await _apiClient.dio.post('/notifications/$id/read');
    } catch (e) {
      throw ApiClient.toFriendly(e);
    }
    throw Exception('Unexpected response from server.');
  }

  // ── Mark All As Read ───────────────────────────────────────────────────────

  Future<void> markAllAsRead() async {
    try {
      await _apiClient.dio.post('/notifications/read-all');
    } catch (e) {
      throw ApiClient.toFriendly(e);
    }
    throw Exception('Unexpected response from server.');
  }

  // ── Register FCM Token ─────────────────────────────────────────────────────

  Future<bool> registerFcmToken(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFcmTokenKey, cleanToken);

    try {
      final response = await _apiClient.dio.post(
        '/auth/fcm-token',
        data: {
          'token': cleanToken,
          'platform': 'android',
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw ApiClient.toFriendly(e);
    }
  }

  // ── Deep Link Resolution (Enforcing strict portal isolation) ───────────────

  static String resolveDeepLinkForRole(String rawRole, NotificationModel notif) {
    final role = rawRole.toLowerCase();
    final type = notif.type.toLowerCase();
    final title = notif.title.toLowerCase();
    final body = notif.body.toLowerCase();

    // 0. Highest Priority: Any user approval / registration request routes directly to Staff Directory Approvals
    if (type == 'user_approval' ||
        type == 'approval' ||
        type.contains('approval') ||
        title.contains('registration') ||
        title.contains('applicant') ||
        body.contains('review and accept') ||
        body.contains('applied for')) {
      return '${AppRoutes.adminEmployees}?tab=pending';
    }

    // 1. Sales Executive
    if (role == 'salesman' || role == 'sales') {
      if (notif.type == 'lead') {
        return AppRoutes.employeeSalesman; // Lands on salesman portal leads tab
      }
      if (notif.type == 'payment') {
        return AppRoutes.employeeSalesman;
      }
      return AppRoutes.employeeSalesman;
    }

    // 2. Site Workers (Electrician, Structure, Civil)
    if (role == 'electrician' ||
        role == 'structure' ||
        role == 'civil' ||
        role == 'labour' ||
        role == 'site') {
      return AppRoutes.employeeSite; // Lands on site work portal
    }

    // 3. KEDL Discom Employee
    if (role == 'kedl') {
      return AppRoutes.employeeKedl; // Lands on KEDL portal
    }

    // 4. Service Employee
    if (role == 'service' || role == 'technician') {
      return AppRoutes.employeeService; // Lands on service desk
    }

    // 5. Client
    if (role == 'client') {
      return AppRoutes.clientDash;
    }

    // 6. Admin & Operations / Vendor
    if (role == 'main_admin' || role == 'co_admin' || role == 'admin' || role == 'vendor' || role == 'super_admin' || role.isEmpty) {
      if (type == 'lead') {
        return AppRoutes.vendorDash;
      }
      if (type == 'payment') {
        return AppRoutes.payments;
      }
      if (type == 'ticket') {
        return AppRoutes.vendorDash;
      }
      return AppRoutes.vendorDash;
    }

    // Default Fallback
    return AppRoutes.adminEmployees;
  }

  // ── Cache & Seed Helpers ───────────────────────────────────────────────────

  Future<List<NotificationModel>> _loadAllRaw() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kNotificationsCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => NotificationModel.fromJson(item))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<NotificationModel>> _loadCachedOrSeed(String role) async {
    final list = await _loadAllRaw();
    return _filterForRole(list, role);
  }

  List<NotificationModel> _filterForRole(List<NotificationModel> list, String role) {
    if (role.isEmpty) return list;
    return list.where((n) {
      if (n.targetRole == null || n.targetRole!.isEmpty) return true;
      return n.targetRole == role ||
          (role.contains('admin') && n.targetRole!.contains('admin')) ||
          ((role == 'electrician' || role == 'structure' || role == 'civil') && n.targetRole == 'site');
    }).toList();
  }

  Future<void> _cacheNotifications(List<NotificationModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(list.map((n) => n.toJson()).toList());
      await prefs.setString(_kNotificationsCacheKey, encoded);
    } catch (_) {}
  }

}
