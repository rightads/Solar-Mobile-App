import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/services/session_store.dart';

class EmailVerificationRequiredException implements Exception {
  final String message;
  final String? email;
  final String? role;

  EmailVerificationRequiredException({
    required this.message,
    this.email,
    this.role,
  });

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    if (kReleaseMode && !AppConstants.baseUrl.startsWith('https://')) {
      throw StateError('Release builds must use an https:// API_BASE_URL.');
    }

    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SessionStore.accessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (kDebugMode) dev.log('API Request: [${options.method}] ${options.uri.path}');
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final req = error.requestOptions;
          final isAuthCall = req.path.startsWith('/auth/');
          if (error.response?.statusCode == 401 && !isAuthCall && req.extra['retried'] != true) {
            if (await _refreshSession()) {
              req.extra['retried'] = true;
              req.headers['Authorization'] = 'Bearer ${await SessionStore.accessToken()}';
              try {
                return handler.resolve(await _dio.fetch(req));
              } on DioException catch (e) {
                return handler.next(e);
              }
            }
            await SessionStore.clear();
            onSessionExpired?.call();
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Invoked when the session can no longer be refreshed (route to login).
  static void Function()? onSessionExpired;

  final Dio _refreshDio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
    receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
  ));

  Future<bool> _refreshSession() async {
    final refresh = await SessionStore.refreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _refreshDio.post('/auth/refresh', data: {'refresh_token': refresh});
      final data = res.data;
      if (data is Map<String, dynamic> && data['access_token'] is String) {
        await _persistSession(data);
        return true;
      }
    } catch (e) {
      dev.log('session refresh failed');
    }
    return false;
  }

  /// Stores tokens securely and caches non-secret profile fields for routing.
  Future<void> _persistSession(Map<String, dynamic>? data) async {
    if (data == null || data['access_token'] is! String) return;
    await SessionStore.save(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String?,
    );
    final user = data['user'];
    if (user is! Map) return;
    final prefs = await SharedPreferences.getInstance();
    Future<void> put(String key, Object? v) async {
      if (v == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, v.toString());
      }
    }
    await put(AppConstants.kUserRole, user['role']);
    await put(AppConstants.kUserId, user['id']);
    await put(AppConstants.kUserName, user['name']);
    await put(AppConstants.kUserPhone, user['phone']);
    await put('user_email', user['email']);
    await put('user_team', user['team'] ?? user['team_type']);
    await put('user_employee_no', user['employee_no']);
  }

  String _formatDioError(DioException de, {String fallback = 'An error occurred.'}) {
    if (de.type == DioExceptionType.receiveTimeout || de.type == DioExceptionType.connectionTimeout) {
      return 'Server is waking up from idle state. Please try again in a few moments.';
    }
    if (de.type == DioExceptionType.connectionError) {
      return 'Unable to reach the server. Please check your network connection.';
    }
    final rawData = de.response?.data;
    if (rawData is Map) {
      final errData = rawData['error'];
      if (errData is Map && errData['message'] != null) {
        return errData['message'].toString();
      }
      final detail = rawData['detail'];
      if (detail != null) {
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString().replaceFirst('Value error, ', '');
          }
          return detail.toString();
        }
        return detail.toString();
      }
      final msg = rawData['message'];
      if (msg != null) return msg.toString();
    } else if (rawData is String && rawData.isNotEmpty) {
      final trimmed = rawData.trim();
      if (!trimmed.startsWith('<') && !trimmed.startsWith('<!DOCTYPE')) {
        return trimmed;
      }
    }
    return fallback;
  }

  Dio get dio => _dio;

  /// User-facing message for any API failure (server message when available).
  static Exception toFriendly(Object e, {String fallback = 'Something went wrong. Please try again.'}) {
    if (e is DioException) return Exception(_instance._formatDioError(e, fallback: fallback));
    if (e is Exception) return e;
    return Exception(fallback);
  }

  // ── Authentication ─────────────────────────────────────────────────────────

  /// Login with email or phone + password (salted bcrypt verification)
  Future<Map<String, dynamic>?> loginWithPassword(String identifier, String password) async {
    try {
      final res = await _dio.post('/auth/login', data: {
        'identifier': identifier,
        'password': password,
      });
      final data = res.data as Map<String, dynamic>?;
      await _persistSession(data);
      return data;
    } on DioException catch (de) {
      final rawData = de.response?.data;
      final errData = rawData is Map && rawData['error'] is Map ? rawData['error'] as Map : null;
      final errCode = errData?['code']?.toString();
      if (errCode == 'EMAIL_NOT_VERIFIED') {
        final details = errData?['details'] is Map ? errData!['details'] as Map : null;
        final email = details?['email']?.toString() ?? (identifier.contains('@') ? identifier : null);
        throw EmailVerificationRequiredException(
          message: errData?['message']?.toString() ??
              'Email verification is required before logging in.',
          email: email,
          role: details?['role']?.toString() ?? 'client',
        );
      }
      final msg = _formatDioError(de, fallback: 'Invalid credentials');
      dev.log('loginWithPassword DioException: $msg');
      throw Exception(msg);
    } catch (e) {
      dev.log('loginWithPassword error: $e');
      rethrow;
    }
  }

  /// Request 6-digit OTP for login
  Future<Map<String, dynamic>?> requestOtp(String phone) async {
    try {
      final res = await _dio.post('/auth/request-otp', data: {'phone': phone});
      return res.data as Map<String, dynamic>?;
    } on DioException catch (de) {
      final msg = _formatDioError(de, fallback: 'Failed to request OTP');
      dev.log('requestOtp DioException: $msg');
      throw Exception(msg);
    } catch (e) {
      dev.log('requestOtp error: $e');
      rethrow;
    }
  }

  /// Verify OTP and store tokens
  Future<Map<String, dynamic>?> verifyOtp(String phone, String otp) async {
    try {
      final res = await _dio.post('/auth/verify-otp', data: {
        'phone': phone,
        'otp': otp,
      });
      final data = res.data as Map<String, dynamic>?;
      await _persistSession(data);
      return data;
    } on DioException catch (de) {
      final rawData = de.response?.data;
      final errData = rawData is Map && rawData['error'] is Map ? rawData['error'] as Map : null;
      final errCode = errData?['code']?.toString();
      if (errCode == 'EMAIL_NOT_VERIFIED') {
        final details = errData?['details'] is Map ? errData!['details'] as Map : null;
        final email = details?['email']?.toString();
        throw EmailVerificationRequiredException(
          message: errData?['message']?.toString() ??
              'Email verification is required before logging in.',
          email: email,
          role: details?['role']?.toString() ?? 'client',
        );
      }
      final msg = _formatDioError(de, fallback: 'Invalid or expired OTP.');
      dev.log('verifyOtp DioException: $msg');
      throw Exception(msg);
    } catch (e) {
      dev.log('verifyOtp error: $e');
      rethrow;
    }
  }

  /// Request a 6-digit email verification code dispatched to email
  Future<bool> sendEmailVerification(String email) async {
    try {
      final res = await _dio.post('/auth/send-verification-email', data: {
        'email': email.trim().toLowerCase(),
      });
      return res.statusCode == 200;
    } catch (e) {
      dev.log('sendEmailVerification error: $e');
      return false;
    }
  }

  /// Verify 6-digit email code and activate client account
  Future<Map<String, dynamic>?> verifyEmail(String email, String code) async {
    try {
      final res = await _dio.post('/auth/verify-email', data: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
      });
      final data = res.data as Map<String, dynamic>?;
      await _persistSession(data);
      return data;
    } on DioException catch (de) {
      final msg = _formatDioError(de, fallback: 'Invalid or expired verification code.');
      throw Exception(msg);
    } catch (e) {
      dev.log('verifyEmail error: $e');
      rethrow;
    }
  }

  /// Get current user profile
  Future<Map<String, dynamic>?> getMe() async {

    try {
      final res = await _dio.get('/auth/me');
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('getMe error: $e');
      return null;
    }
  }

  /// Logout: revoke the refresh token server-side, then wipe local session.
  Future<void> logout() async {
    try {
      final refreshToken = await SessionStore.refreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _refreshDio.post('/auth/logout', data: {'refresh_token': refreshToken});
      }
    } catch (e) {
      dev.log('logout request failed');
    } finally {
      await SessionStore.clear();
    }
  }

  /// Register a new user account (client, vendor, sales)
  Future<Map<String, dynamic>?> registerUser({
    required String name,
    required String phone,
    required String password,
    String? email,
    String role = 'client',
  }) async {
    try {
      final res = await _dio.post('/auth/register', data: {
        'name': name.trim(),
        'phone': phone.trim(),
        'password': password,
        'email': email?.trim().toLowerCase(),
        'role': role.trim().toLowerCase(),
      });
      return res.data as Map<String, dynamic>?;
    } on DioException catch (de) {
      String msg = _formatDioError(de, fallback: 'Registration failed.');
      final data = de.response?.data;
      if (data is Map) {
        if (data['error'] is Map && data['error']['message'] != null) {
          msg = data['error']['message'].toString();
        } else if (data['detail'] is String) {
          msg = data['detail'];
        } else if (data['detail'] is List && (data['detail'] as List).isNotEmpty) {
          final first = (data['detail'] as List).first;
          if (first is Map && first['msg'] != null) {
            msg = first['msg'].toString().replaceFirst('Value error, ', '');
          } else {
            msg = data['detail'].toString();
          }
        }
      }
      throw Exception(msg);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch all active leads from cloud backend
  Future<List<Map<String, dynamic>>> getLeads() async {
    try {
      final res = await _dio.get('/leads');
      if (res.data is Map && res.data['items'] is List) {
        return List<Map<String, dynamic>>.from(res.data['items']);
      } else if (res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      dev.log('getLeads error: $e');
      return [];
    }
  }

  /// Create a new real lead on cloud backend
  Future<Map<String, dynamic>?> createLead({
    required String name,
    required String phone,
    String? area,
    double kw = 3.0,
    String status = 'new',
    String source = 'Direct',
  }) async {
    try {
      final res = await _dio.post('/leads', data: {
        'name': name.trim(),
        'phone': phone.trim(),
        'area': area?.trim() ?? '',
        'kw': kw,
        'status': status,
        'source': source,
      });
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('createLead error: $e');
      rethrow;
    }
  }

  /// Fetch all real customers from cloud backend
  Future<List<Map<String, dynamic>>> getCustomers() async {
    try {
      final res = await _dio.get('/customers');
      if (res.data is Map && res.data['items'] is List) {
        return List<Map<String, dynamic>>.from(res.data['items']);
      } else if (res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      dev.log('getCustomers error: $e');
      return [];
    }
  }

  /// Get customer details by ID
  Future<Map<String, dynamic>?> getCustomerById(String customerId) async {
    try {
      final res = await _dio.get('/customers/$customerId');
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('getCustomerById error: $e');
      return null;
    }
  }

  /// Update customer details
  Future<Map<String, dynamic>?> updateCustomer({
    required String customerId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final res = await _dio.patch('/customers/$customerId', data: data);
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('updateCustomer error: $e');
      rethrow;
    }
  }

  /// Create a new real customer on cloud backend (Page 1 requirement)
  Future<Map<String, dynamic>?> createCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? locationGps,
    double kw = 5.0,
    int finalPrice = 250000,
    List<Map<String, dynamic>>? milestones,
    Map<String, dynamic>? documents,
    String? salesId,
    String? salesName,
  }) async {
    try {
      final res = await _dio.post('/customers', data: {
        'name': name.trim(),
        'phone': phone.trim(),
        'mobile': phone.trim(),
        'email': email?.trim().toLowerCase(),
        'address': address?.trim() ?? '',
        'location_gps': locationGps ?? '',
        'kw': kw,
        'final_price': finalPrice,
        'total_amount': finalPrice,
        'milestones': milestones ?? [],
        'documents': documents ?? {},
        'sales_id': salesId,
        'sales_name': salesName,
      });
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('createCustomer error: $e');
      rethrow;
    }
  }

  /// Update customer milestone verification
  Future<Map<String, dynamic>?> updateCustomerMilestone({
    required String customerId,
    required String milestoneId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final res = await _dio.post('/customers/$customerId/milestones', data: {
        'id': milestoneId,
        ...data,
      });
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('updateCustomerMilestone error: $e');
      rethrow;
    }
  }

  // ── Page 1: Sales Person Assign & Lead Management ─────────────────────────

  /// Fetch salespersons list for assignment
  Future<List<Map<String, dynamic>>> getSalespersons() async {
    try {
      final res = await _dio.get('/leads/salespersons');
      if (res.data is List) {
        return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      dev.log('getSalespersons error: $e');
      return [];
    }
  }

  /// Assign sales person to a lead
  Future<Map<String, dynamic>?> assignLead({
    required String leadId,
    required String salesId,
    required String salesName,
  }) async {
    try {
      final res = await _dio.post('/leads/$leadId/assign', data: {
        'sales_id': salesId,
        'sales_name': salesName,
      });
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('assignLead error: $e');
      rethrow;
    }
  }

  /// Convert lead to Sales Closed
  Future<Map<String, dynamic>?> closeSaleLead({
    required String leadId,
    Map<String, dynamic>? customerData,
  }) async {
    try {
      final res = await _dio.post('/leads/$leadId/convert', data: customerData ?? {});
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('closeSaleLead error: $e');
      rethrow;
    }
  }

  // ── Page 1 & 2: Employees Add Like Labour ─────────────────────────────────

  /// Add employee or labour team member (Labour, Electrician, Civil, Sales, KEDL)
  Future<Map<String, dynamic>?> createEmployee({
    required String name,
    required String phone,
    required String trade,
    String team = 'Team A',
    String role = 'employee',
  }) async {
    try {
      final res = await _dio.post('/teams/employees', data: {
        'name': name.trim(),
        'phone': phone.trim(),
        'trade': trade.trim().toLowerCase(),
        'team': team.trim(),
        'role': role,
      });
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('createEmployee error: $e');
      rethrow;
    }
  }

  /// List employees and labour
  Future<List<Map<String, dynamic>>> getEmployees({String? trade, String? team}) async {
    try {
      final res = await _dio.get('/teams/employees', queryParameters: {
        if (trade != null) 'trade': trade,
        if (team != null) 'team': team,
      });
      if (res.data is List) {
        return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      dev.log('getEmployees error: $e');
      return [];
    }
  }

  /// Get all assigned tasks for an employee
  Future<List<Map<String, dynamic>>> getEmployeeTasks(String employeeId) async {
    try {
      final res = await _dio.get('/teams/employees/$employeeId/tasks');
      if (res.data is List) {
        return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      dev.log('getEmployeeTasks error: $e');
      return [];
    }
  }

  /// Assign a task to an employee
  Future<Map<String, dynamic>?> assignTaskToEmployee({
    required String employeeId,
    required String title,
    String? customerId,
    String? customerName,
    String? location,
    String? category,
    String? priority,
    String? startDate,
    String? endDate,
    String? notes,
  }) async {
    try {
      final res = await _dio.post('/teams/employees/$employeeId/tasks', data: {
        'title': title.trim(),
        if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
        'customer_name': customerName?.trim() ?? 'Direct Assignment',
        'location': location?.trim() ?? '',
        'category': (category ?? 'general').trim().toLowerCase(),
        'work_type': (category ?? 'general').trim().toLowerCase(),
        'priority': (priority ?? 'normal').trim().toLowerCase(),
        'start_date': startDate ?? DateTime.now().toIso8601String().split('T').first,
        'end_date': endDate ?? DateTime.now().toIso8601String().split('T').first,
        'notes': notes?.trim() ?? '',
        'status': 'assigned',
      });
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('assignTaskToEmployee error: $e');
      rethrow;
    }
  }

  /// List labour teams (Structure, Electrical, Civil)
  Future<List<Map<String, dynamic>>> getLabourTeams({String? tradeType}) async {
    try {
      final res = await _dio.get('/teams', queryParameters: {
        if (tradeType != null) 'type': tradeType,
      });
      if (res.data is List) {
        return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      dev.log('getLabourTeams error: $e');
      return [];
    }
  }

  /// Create new labour team (Team A, Team B, Team C, etc.)
  Future<Map<String, dynamic>?> createLabourTeam({
    required String name,
    required String tradeType,
    String? leadName,
    String? leadPhone,
    int memberCount = 3,
  }) async {
    try {
      final res = await _dio.post('/teams', data: {
        'name': name.trim(),
        'trade_type': tradeType.trim().toLowerCase(),
        'lead_name': leadName?.trim() ?? '',
        'lead_phone': leadPhone?.trim() ?? '',
        'member_count': memberCount,
      });
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('createLabourTeam error: $e');
      rethrow;
    }
  }

  // ── Page 2: Work Assignments ──────────────────────────────────────────────

  /// Assign work to Structure, Electrical or Civil Labour team
  Future<Map<String, dynamic>?> assignWork({
    required String customerId,
    required String customerName,
    required String workType,
    required String teamName,
    required String startDate,
    required String endDate,
    String? location,
    String? leadName,
    String? leadPhone,
    String? notes,
  }) async {
    try {
      final res = await _dio.post('/work-assignments', data: {
        'customer_id': customerId,
        'customer_name': customerName,
        'location': location ?? '',
        'work_type': workType.toLowerCase(),
        'team_name': teamName,
        'lead_name': leadName ?? '',
        'lead_phone': leadPhone ?? '',
        'start_date': startDate,
        'end_date': endDate,
        'notes': notes ?? '',
        'status': 'assigned',
      });
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('assignWork error: $e');
      rethrow;
    }
  }

  /// List work assignments from cloud backend
  Future<List<Map<String, dynamic>>> getWorkAssignments({
    String? customerId,
    String? workType,
    String? status,
  }) async {
    try {
      final res = await _dio.get('/work-assignments', queryParameters: {
        if (customerId != null) 'customer_id': customerId,
        if (workType != null) 'work_type': workType,
        if (status != null) 'status': status,
      });
      if (res.data is List) {
        return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      dev.log('getWorkAssignments error: $e');
      return [];
    }
  }

  /// Update work assignment status
  Future<Map<String, dynamic>?> updateWorkAssignmentStatus({
    required String assignmentId,
    required String status,
  }) async {
    try {
      final res = await _dio.patch('/work-assignments/$assignmentId', data: {
        'status': status,
      });
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('updateWorkAssignmentStatus error: $e');
      rethrow;
    }
  }

  // ── Page 3: KEDL Work Employee (Name Change, Load, Net Meter Files) ────────

  /// Initialize KEDL tracking files for customer
  Future<List<Map<String, dynamic>>> initKedlFiles(String customerId) async {
    try {
      final res = await _dio.post('/customers/$customerId/kedl-files/init');
      if (res.data is List) {
        return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      dev.log('initKedlFiles error: $e');
      return [];
    }
  }

  /// List KEDL files
  Future<List<Map<String, dynamic>>> getKedlFiles({String? customerId, String? fileType}) async {
    try {
      final res = await _dio.get('/kedl-files', queryParameters: {
        if (customerId != null) 'customer_id': customerId,
        if (fileType != null) 'file_type': fileType,
      });
      if (res.data is List) {
        return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      dev.log('getKedlFiles error: $e');
      return [];
    }
  }

  /// Create or update KEDL file
  Future<Map<String, dynamic>?> saveKedlFile(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/kedl-files', data: data);
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('saveKedlFile error: $e');
      rethrow;
    }
  }

  /// Update demand notice for a KEDL file
  Future<Map<String, dynamic>?> updateKedlDemand({
    required String fileId,
    required int demandAmount,
    required String status,
    String? demandRef,
  }) async {
    try {
      final res = await _dio.post('/kedl-files/$fileId/demands', data: {
        'demand_amount': demandAmount,
        'status': status,
        if (demandRef != null) 'demand_notice_ref': demandRef,
      });
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('updateKedlDemand error: $e');
      rethrow;
    }
  }


  // ── Super Admin Approvals ────────────────────────────────────────────────

  /// Get pending registration approvals for Super Admin
  Future<List<Map<String, dynamic>>> getPendingApprovals({String status = 'pending'}) async {
    try {
      final res = await _dio.get('/users/approvals/list', queryParameters: {'status': status});
      if (res.data is List && (res.data as List).isNotEmpty) {
        return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      dev.log('getPendingApprovals /users/approvals/list: $e');
    }

    // Fallback: Query /teams/employees with status filter
    try {
      final res = await _dio.get('/teams/employees', queryParameters: {'status': status});
      if (res.data is List) {
        return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      dev.log('getPendingApprovals /teams/employees: $e');
    }
    return [];
  }

  /// Approve employee or admin registration request
  Future<Map<String, dynamic>?> approveRegistration(String userId) async {
    try {
      final res = await _dio.post('/users/approvals/$userId/approve');
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('approveRegistration error: $e');
      rethrow;
    }
  }

  /// Reject employee or admin registration request
  Future<Map<String, dynamic>?> rejectRegistration(String userId) async {
    try {
      final res = await _dio.post('/users/approvals/$userId/reject');
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      dev.log('rejectRegistration error: $e');
      rethrow;
    }
  }

  // ── Generic GET/POST/PATCH/DELETE Helpers ─────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.patch<T>(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.delete<T>(path, data: data, queryParameters: queryParameters);
  }
}
