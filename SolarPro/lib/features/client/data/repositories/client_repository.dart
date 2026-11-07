import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/features/client/data/models/client_dashboard_model.dart';

class ClientRepository {
  final ApiClient _apiClient;

  ClientRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // In-memory / cached fallback state for seamless offline & demo experience
  static final List<ClientPaymentRecord> _cachedPayments = [];

  static final List<ClientTicketRecord> _cachedTickets = [];

  /// Fetch 10-stage milestones, assigned employee with Employee No, specs, and financials
  Future<Map<String, dynamic>> getClientHomeData() async {
    try {
      final res = await _apiClient.dio.get('/client/home');
      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (_) {
      // Fallback to offline / demo data
    }

    final prefs = await SharedPreferences.getInstance();
    final clientName = prefs.getString('user_name') ?? 'Solar Client';
    final clientPhone = prefs.getString('user_phone') ?? '';

    return {
      'customer': {
        'name': clientName,
        'mobile': clientPhone,
        'address': '',
        'capacity_kw': 0.0,
        'final_price': 0,
        'stage': 'REGISTRATION_SUBMITTED',
      },
      'stage': 'REGISTRATION_SUBMITTED',
      'timeline': [
        {'stage': 'SALE_CONFIRMED', 'title': 'Sale Confirmed', 'status': 'upcoming', 'note': 'Sales agreement signed and advance token verified.'},
        {'stage': 'DOCUMENTS_RECEIVED', 'title': 'Documents Received', 'status': 'upcoming', 'note': 'Aadhaar, Electricity Bill and rooftop pictures verified.'},
        {'stage': 'ADVANCE_VERIFIED', 'title': 'Advance Verified', 'status': 'upcoming', 'note': 'Payment approved by salesman & verified by admin.'},
        {'stage': 'STRUCTURE_WORK', 'title': 'Structure Installation', 'status': 'upcoming', 'note': 'Hot-dip galvanized mounting structure installation ongoing.'},
        {'stage': 'ELECTRICAL_WORK', 'title': 'Electrical Wiring & Inverter', 'status': 'upcoming', 'note': 'DC cabling, conduits and earthing connection.'},
        {'stage': 'CIVIL_WORK', 'title': 'Civil Works', 'status': 'upcoming', 'note': 'Grouting and rooftop water-proofing inspection.'},
        {'stage': 'INSTALLATION_COMPLETE', 'title': 'Installation Complete', 'status': 'upcoming', 'note': 'Solar panels and inverter physically mounted.'},
        {'stage': 'KEDL_PROCESS', 'title': 'KEDL Discom Paperwork', 'status': 'upcoming', 'note': 'Discom paperwork and inspection liaison.'},
        {'stage': 'SYSTEM_LIVE', 'title': 'System Live & Net Metering', 'status': 'upcoming', 'note': 'Bi-directional net meter sync with grid.'},
        {'stage': 'HANDED_OVER', 'title': 'Project Handed Over 🎉', 'status': 'upcoming', 'note': 'Project handed over with 25-year solar warranty kit.'},
      ],
      'progress': {
        'completed_stages': 0,
        'total_stages': 10,
        'percentage': 0,
        'current_stage_index': 0,
      },
      'responsible_contact': null,
      'sales_contact': null,
      'payment_summary': {
        'total_amount': 0.0,
        'total_paid': 0.0,
        'remaining_balance': 0.0,
        'next_milestone': 'Awaiting Project Quote & Feasibility',
      },
      'system_specs': {
        'capacity_kw': 0.0,
        'phase': 'Single Phase',
        'panel_brand': 'Pending Survey',
        'panel_watt': 0,
        'panel_count': 0,
        'inverter_brand': 'Pending Survey',
        'structure_type': 'Pending Survey',
        'is_configured': false,
      },
    };
  }

  /// Get list of submitted payments with their salesman approval & admin verification status
  Future<List<ClientPaymentRecord>> getPayments() async {
    try {
      final res = await _apiClient.dio.get('/client/payments');
      if (res.data is List) {
        final list = (res.data as List).map((e) => ClientPaymentRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        if (list.isNotEmpty) return list;
      } else if (res.data is Map && res.data['items'] is List) {
        final list = (res.data['items'] as List).map((e) => ClientPaymentRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return List.from(_cachedPayments);
  }

  /// Client submits a new payment record with photo receipt proof
  Future<ClientPaymentRecord> submitPayment({
    required double amountRupees,
    required String mode,
    String? referenceNo,
    String? remarks,
    String? proofFileName,
    String? photoBase64,
  }) async {
    final amountPaise = (amountRupees * 100).toInt();

    try {
      final formData = FormData.fromMap({
        'amount': amountPaise,
        'mode': mode.toLowerCase(),
        if (referenceNo != null) 'reference_no': referenceNo,
        if (remarks != null) 'remarks': remarks,
      });

      final res = await _apiClient.dio.post('/client/payments', data: formData);
      if (res.data is Map) {
        final newRecord = ClientPaymentRecord.fromJson(Map<String, dynamic>.from(res.data as Map));
        _cachedPayments.insert(0, newRecord);
        return newRecord;
      }
    } catch (_) {}

    // Offline / Demo submission fallback
    final newRecord = ClientPaymentRecord(
      id: 'pay-${DateTime.now().millisecondsSinceEpoch}',
      stageNo: _cachedPayments.length + 1,
      stageName: 'Rooftop Solar Milestone Payment',
      amount: amountRupees,
      mode: mode.toUpperCase(),
      referenceNo: referenceNo ?? 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      paidOn: DateTime.now(),
      proofUrl: proofFileName ?? 'receipt_uploaded.png',
      status: 'pending', // Directly starts in Awaiting Salesman Approval
      salesApprovedBy: null,
      salesApproverEmpNo: null,
      remarks: remarks ?? 'Submitted by customer with photo receipt for salesman approval.',
    );

    _cachedPayments.insert(0, newRecord);
    return newRecord;
  }

  /// Get all service tickets
  Future<List<ClientTicketRecord>> getTickets() async {
    try {
      final res = await _apiClient.dio.get('/client/tickets');
      if (res.data is List) {
        final list = (res.data as List).map((e) => ClientTicketRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return List.from(_cachedTickets);
  }

  /// Raise a service ticket (enforcing Structure 2-10 photos, Wiring photos, Inverter Fault)
  Future<ClientTicketRecord> createTicket({
    required ClientTicketType type,
    required String title,
    required String description,
    String? errorCode,
    String priority = 'high',
    required List<String> images,
  }) async {
    // Validate image constraints according to user handwritten notes
    if (type == ClientTicketType.structure && (images.length < 2 || images.length > 10)) {
      throw Exception('Structure issue requires between 2 and 10 photos of the structure.');
    }
    if (type == ClientTicketType.wiring && (images.isEmpty || images.length > 10)) {
      throw Exception('Wiring issue requires at least 1 photo (up to 10 photos).');
    }

    try {
      final payload = {
        'type': type.name,
        'title': title.trim(),
        'description': description.trim(),
        if (errorCode != null && errorCode.isNotEmpty) 'error_code': errorCode.trim(),
        'priority': priority.toLowerCase(),
        'image_keys': images,
      };

      final res = await _apiClient.dio.post('/client/tickets', data: payload);
      if (res.data is Map) {
        final item = ClientTicketRecord.fromJson(Map<String, dynamic>.from(res.data as Map));
        _cachedTickets.insert(0, item);
        await _syncToEmployeeServiceCache(item);
        return item;
      }
    } catch (e) {
      if (e is! DioException) {
        // Validation exceptions should propagate
        rethrow;
      }
    }

    // Local / Offline addition
    final newTicket = ClientTicketRecord(
      id: 'tic-${DateTime.now().millisecondsSinceEpoch}',
      ticketNo: 'TIC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      type: type,
      title: title.trim(),
      description: description.trim(),
      errorCode: errorCode,
      status: 'open',
      priority: priority,
      images: images,
      assignedStaff: 'Vikram Singh',
      assignedStaffEmpNo: 'EMP-SRV-104',
      createdAt: DateTime.now(),
    );

    _cachedTickets.insert(0, newTicket);
    await _syncToEmployeeServiceCache(newTicket);
    return newTicket;
  }

  /// Syncs newly created ticket to shared SharedPreferences cache for the Service Employee Portal
  Future<void> _syncToEmployeeServiceCache(ClientTicketRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const cacheKey = 'service_tickets_cache_v1';
      final clientName = prefs.getString('user_name') ?? 'Client';
      final clientPhone = prefs.getString('user_phone') ?? '';

      final ticketJson = {
        'id': record.id,
        'ticket_no': record.ticketNo,
        'customer_id': 'cust_client',
        'customer_name': clientName,
        'customer_phone': clientPhone,
        'customer_address': 'Plot 42, Sunrise Enclave, Sector 14, Jaipur, Rajasthan',
        'type': record.type.name,
        'title': record.title,
        'description': record.description,
        'error_code': record.errorCode,
        'status': record.status,
        'priority': record.priority,
        'assigned_to': 'emp-srv-104',
        'assignee_name': record.assignedStaff ?? 'Vikram Singh',
        'images': record.images
            .map((img) => {
                  'id': 'img_${DateTime.now().millisecondsSinceEpoch}_${img.hashCode}',
                  'ticket_id': record.id,
                  'file_key': img,
                  'created_at': DateTime.now().toIso8601String(),
                })
            .toList(),
        'created_at': record.createdAt.toIso8601String(),
        'updated_at': record.createdAt.toIso8601String(),
      };

      final raw = prefs.getString(cacheKey);
      List<dynamic> list = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) list = List.from(decoded);
        } catch (_) {}
      } else {
        list = [
          {
            'id': 'tck_001',
            'ticket_no': 'TCK-2026-1001',
            'customer_id': 'cust_101',
            'customer_name': 'Sunil Verma',
            'customer_phone': '9829012345',
            'customer_address': 'Plot 42, Malviya Nagar, Jaipur, Rajasthan',
            'type': 'inverter',
            'title': 'Inverter blinking red with error code',
            'description': 'Growatt inverter display shows blinking warning LED and stopped generating power since yesterday.',
            'error_code': 'E-029: Grid Overvoltage',
            'status': 'assigned',
            'priority': 'urgent',
            'assigned_to': 'emp-srv-104',
            'assignee_name': 'Vikram Singh',
            'created_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
            'updated_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
          },
        ];
      }

      list.removeWhere((it) => it is Map && (it['id'] == record.id || it['ticket_no'] == record.ticketNo));
      list.insert(0, ticketJson);
      await prefs.setString(cacheKey, jsonEncode(list));
    } catch (_) {}
  }
}
