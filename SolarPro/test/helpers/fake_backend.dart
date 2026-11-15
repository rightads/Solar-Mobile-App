import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solar_pro/core/network/api_client.dart';

/// In-memory stand-in for the SolarPro API, used by repository tests.
///
/// It is plugged into the shared [ApiClient] Dio instance, so the app code
/// under test runs unchanged. Responses follow the real backend's JSON shapes.
/// Call [FakeBackend.install] in `setUp` to get fresh data for every test.
class FakeBackend implements HttpClientAdapter {
  FakeBackend._() {
    _seed();
  }

  /// Installs a fresh fake on the shared [ApiClient] and returns it.
  static FakeBackend install() {
    FlutterSecureStorage.setMockInitialValues({});
    final fake = FakeBackend._();
    ApiClient().dio.httpClientAdapter = fake;
    return fake;
  }

  final List<Map<String, dynamic>> tickets = [];
  final List<Map<String, dynamic>> kedlFiles = [];
  final List<Map<String, dynamic>> workAssignments = [];
  final List<Map<String, dynamic>> notifications = [];
  final Map<String, Map<String, dynamic>> serials = {};
  String? registeredFcmToken;
  int _seq = 0;

  String _id(String prefix) => '${prefix}_${++_seq}';
  String _now() => DateTime.now().toUtc().toIso8601String();
  String _day(int offsetDays) =>
      DateTime.now().add(Duration(days: offsetDays)).toIso8601String().split('T').first;

  // ── Seed data ──────────────────────────────────────────────────────────────

  void _seed() {
    tickets.addAll([
      {
        'id': 'tck_1', 'ticket_no': 'TCK-0001', 'customer_id': 'cust_1',
        'customer_name': 'Test Customer A', 'customer_phone': '9000000101',
        'customer_address': 'Test Address A', 'type': 'inverter',
        'title': 'Inverter shows error', 'description': 'Display shows E-029',
        'error_code': 'E-029', 'status': 'assigned', 'priority': 'urgent',
        'assigned_to': 'emp_service_1', 'images': <Map<String, dynamic>>[],
        'comments': <Map<String, dynamic>>[], 'created_at': _now(),
      },
      {
        'id': 'tck_2', 'ticket_no': 'TCK-0002', 'customer_id': 'cust_2',
        'customer_name': 'Test Customer B', 'customer_phone': '9000000102',
        'customer_address': 'Test Address B', 'type': 'structure',
        'title': 'Loose mounting bracket', 'description': 'Rattles in wind',
        'status': 'open', 'priority': 'normal',
        'images': [
          {'id': 'img_1', 'ticket_id': 'tck_2', 'file_key': 'bracket.jpg', 'created_at': _now()},
        ],
        'comments': <Map<String, dynamic>>[], 'created_at': _now(),
      },
    ]);

    for (final type in ['name_change', 'load', 'net']) {
      kedlFiles.add({
        'id': 'kedl_$type', 'customer_id': 'cust_1', 'customer_name': 'Test Customer A',
        'customer_phone': '9000000101', 'customer_address': 'Test Address A',
        'file_type': type, 'status': type == 'load' ? 'demand_raised' : 'submitted',
        'submitted_on': _day(-10),
        'demands': type == 'load'
            ? [
                {
                  'id': 'dmd_seed', 'kedl_file_id': 'kedl_load', 'description': 'Load fee',
                  'amount': 450000, 'amount_paise': 450000, 'status': 'open',
                  'due_date': _day(-2), 'raised_on': _now(),
                },
              ]
            : <Map<String, dynamic>>[],
        'documents': <Map<String, dynamic>>[], 'status_logs': <Map<String, dynamic>>[],
        'created_at': _now(),
      });
    }

    var n = 0;
    for (final type in ['electrical', 'electrical', 'structure', 'civil']) {
      n++;
      workAssignments.add({
        'id': 'job_${type}_$n', 'customer_id': 'cust_1', 'customer_name': 'Test Customer A',
        'customer_mobile': '9000000101', 'customer_address': 'Test Address A',
        'work_type': type, 'team_id': 'team_$type', 'team_name': 'Team $type',
        'scheduled_start': _day(0), 'scheduled_end': _day(2),
        'status': 'pending', 'photos': <Map<String, dynamic>>[], 'status_logs': <Map<String, dynamic>>[],
      });
    }

    notifications.addAll([
      {'id': 'ntf_1', 'title': 'New job', 'body': 'Job assigned', 'type': 'job', 'is_read': false, 'created_at': _now()},
      {'id': 'ntf_2', 'title': 'Payment', 'body': 'Payment verified', 'type': 'payment', 'is_read': false, 'created_at': _now()},
    ]);

    serials['INV-ACTIVE-001'] = {
      'id': 'ser_1', 'serial_no': 'INV-ACTIVE-001', 'item_name': 'Hybrid Inverter 5kW',
      'category': 'inverter', 'brand': 'Growatt', 'model': 'SPH5000', 'status': 'installed',
      'customer_id': 'cust_1', 'customer_name': 'Test Customer A', 'customer_phone': '9000000101',
      'warranty_months': 60, 'installed_on': _day(-365),
      'warranty_until': _day(365 * 4), 'is_under_warranty': true,
    };
    serials['INV-EXPIRED-002'] = {
      'id': 'ser_2', 'serial_no': 'INV-EXPIRED-002', 'item_name': 'Grid-tie Inverter 3kW',
      'category': 'inverter', 'brand': 'Luminous', 'model': 'NXG3', 'status': 'installed',
      'customer_id': 'cust_2', 'customer_name': 'Test Customer B', 'customer_phone': '9000000102',
      'warranty_months': 12, 'installed_on': _day(-900),
      'warranty_until': _day(-535), 'is_under_warranty': false,
    };
  }

  // ── HttpClientAdapter ──────────────────────────────────────────────────────

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var path = options.uri.path;
    final apiIdx = path.indexOf('/api/v1');
    if (apiIdx >= 0) path = path.substring(apiIdx + '/api/v1'.length);
    final query = options.uri.queryParameters;
    final body = _body(options.data);
    final (status, data) = _route(options.method.toUpperCase(), path, query, body);
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  Map<String, dynamic> _body(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is FormData) return {for (final f in data.fields) f.key: f.value};
    if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return {};
  }

  (int, Object?) _notFound() => (404, {'detail': 'Not found'});

  Map<String, dynamic>? _find(List<Map<String, dynamic>> list, String id) {
    for (final item in list) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  (int, Object?) _route(String method, String path, Map<String, String> q, Map<String, dynamic> body) {
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();

    // Auth / session
    if (path == '/auth/logout') return (200, {'message': 'Logged out'});
    if (path == '/auth/me/fcm-token' && method == 'PUT') {
      registeredFcmToken = body['fcm_token']?.toString();
      return (200, {'message': 'Device registered.'});
    }
    if (path.startsWith('/users/approvals')) return (200, <Object>[]);

    // Tickets
    if (seg.isNotEmpty && seg[0] == 'tickets') return _tickets(method, seg, q, body);
    if (seg.length == 2 && seg[0] == 'serials' && method == 'GET') {
      final s = serials[seg[1]];
      return s == null ? _notFound() : (200, s);
    }

    // KEDL
    if (path == '/kedl/dashboard') return (200, _kedlDashboard());
    if (seg.isNotEmpty && seg[0] == 'kedl-files') return _kedl(method, seg, q, body);
    if (seg.length == 2 && seg[0] == 'kedl-demands' && method == 'PATCH') {
      for (final file in kedlFiles) {
        final demands = (file['demands'] as List).cast<Map<String, dynamic>>();
        final d = _find(demands, seg[1]);
        if (d == null) continue;
        d['status'] = body['status'] ?? d['status'];
        if (d['status'] == 'paid') d['paid_on'] = body['paid_on'] ?? _now();
        if (demands.every((x) => x['status'] != 'open')) file['status'] = 'demand_paid';
        return (200, d);
      }
      return _notFound();
    }

    // Work assignments
    if (seg.isNotEmpty && seg[0] == 'work-assignments') return _works(method, seg, q, body);

    // Notifications
    if (seg.isNotEmpty && seg[0] == 'notifications') return _notifications(method, seg);

    return _notFound();
  }

  (int, Object?) _tickets(String method, List<String> seg, Map<String, String> q, Map<String, dynamic> body) {
    if (seg.length == 1 && method == 'GET') {
      return (
        200,
        tickets.where((t) {
          if (q['type'] != null && t['type'] != q['type']) return false;
          if (q['status'] != null && t['status'] != q['status']) return false;
          if (q['customer_id'] != null && t['customer_id'] != q['customer_id']) return false;
          return true;
        }).toList(),
      );
    }
    final t = seg.length >= 2 ? _find(tickets, seg[1]) : null;
    if (t == null) return _notFound();
    if (seg.length == 2 && method == 'GET') return (200, t);
    if (seg.length == 3 && seg[2] == 'status' && method == 'POST') {
      final status = body['status']?.toString() ?? t['status'];
      if (status == 'resolved') {
        final note = body['resolution_note']?.toString().trim() ?? '';
        if (note.isEmpty) return (400, {'detail': 'A resolution note is required.'});
        t['resolution_note'] = note;
        t['resolved_at'] = _now();
      }
      t['status'] = status;
      return (200, t);
    }
    if (seg.length == 3 && seg[2] == 'comments' && method == 'POST') {
      final c = {
        'id': _id('cmt'), 'ticket_id': t['id'], 'author_name': 'Test Technician',
        'author_role': 'service', 'message': body['message'], 'created_at': _now(),
      };
      (t['comments'] as List).add(c);
      return (201, c);
    }
    return _notFound();
  }

  (int, Object?) _kedl(String method, List<String> seg, Map<String, String> q, Map<String, dynamic> body) {
    if (seg.length == 1 && method == 'GET') {
      return (
        200,
        kedlFiles.where((f) {
          if (q['file_type'] != null && f['file_type'] != q['file_type']) return false;
          if (q['status'] != null && f['status'] != q['status']) return false;
          if (q['has_open_demand'] == 'true' &&
              !(f['demands'] as List).any((d) => (d as Map)['status'] == 'open')) {
            return false;
          }
          return true;
        }).toList(),
      );
    }
    final f = seg.length >= 2 ? _find(kedlFiles, seg[1]) : null;
    if (f == null) return _notFound();
    if (seg.length == 2 && method == 'GET') return (200, f);
    if (seg.length == 2 && method == 'PATCH') {
      f.addAll(body);
      return (200, f);
    }
    if (seg.length == 3 && seg[2] == 'status' && method == 'POST') {
      f['status'] = body['status'] ?? f['status'];
      if (f['status'] == 'approved') f['approved_on'] = _now();
      return (200, f);
    }
    if (seg.length == 3 && seg[2] == 'demands' && method == 'POST') {
      final amount = (body['amount'] as num?)?.toInt() ?? 0;
      final d = {
        'id': _id('dmd'), 'kedl_file_id': f['id'], 'description': body['description'],
        'amount': amount, 'amount_paise': amount, 'due_date': body['due_date'],
        'status': 'open', 'raised_by': 'Test KEDL Officer', 'raised_on': _now(),
      };
      (f['demands'] as List).add(d);
      f['status'] = 'demand_raised';
      return (201, d);
    }
    return _notFound();
  }

  Map<String, dynamic> _kedlDashboard() {
    final byType = <String, int>{};
    final byStatus = <String, int>{};
    var open = 0;
    var overdue = 0;
    final today = DateTime.now();
    for (final f in kedlFiles) {
      byType[f['file_type'] as String] = (byType[f['file_type']] ?? 0) + 1;
      byStatus[f['status'] as String] = (byStatus[f['status']] ?? 0) + 1;
      for (final d in (f['demands'] as List).cast<Map<String, dynamic>>()) {
        if (d['status'] != 'open') continue;
        open++;
        final due = DateTime.tryParse(d['due_date']?.toString() ?? '');
        if (due != null && due.isBefore(today)) overdue++;
      }
    }
    return {
      'total_files': kedlFiles.length,
      'by_file_type': byType,
      'by_status': byStatus,
      'open_demands_count': open,
      'overdue_demands_count': overdue,
    };
  }

  (int, Object?) _works(String method, List<String> seg, Map<String, String> q, Map<String, dynamic> body) {
    if (seg.length == 1 && method == 'GET') {
      return (
        200,
        workAssignments.where((w) {
          if (q['work_type'] != null && w['work_type'] != q['work_type']) return false;
          if (q['status'] != null && w['status'] != q['status']) return false;
          return true;
        }).toList(),
      );
    }
    final w = seg.length >= 2 ? _find(workAssignments, seg[1]) : null;
    if (w == null) return _notFound();
    if (seg.length == 2 && method == 'GET') return (200, w);
    if (seg.length == 3 && seg[2] == 'start' && method == 'POST') {
      w['status'] = 'in_progress';
      w['actual_start'] = _now();
      return (200, w);
    }
    if (seg.length == 3 && seg[2] == 'complete' && method == 'POST') {
      // Same rule as the real backend: no photo proof, no completion.
      if ((w['photos'] as List).isEmpty) {
        return (400, {'detail': 'Upload at least one site photo before marking the job complete.'});
      }
      w['status'] = 'completed';
      w['actual_end'] = _now();
      return (200, w);
    }
    return _notFound();
  }

  /// Attaches a photo to a seeded job, as if it had been uploaded earlier.
  void addJobPhoto(String jobId) {
    final w = _find(workAssignments, jobId)!;
    (w['photos'] as List).add({
      'id': _id('photo'), 'work_assignment_id': jobId, 'file_key': 'proof.jpg', 'created_at': _now(),
    });
  }

  (int, Object?) _notifications(String method, List<String> seg) {
    if (seg.length == 1 && method == 'GET') return (200, notifications);
    if (seg.length == 2 && seg[1] == 'unread-count') {
      final c = notifications.where((n) => n['is_read'] != true).length;
      return (200, {'unread_count': c, 'count': c});
    }
    if (seg.length == 2 && seg[1] == 'read-all' && method == 'POST') {
      for (final n in notifications) {
        n['is_read'] = true;
      }
      return (200, {'message': 'ok'});
    }
    if (seg.length == 3 && seg[2] == 'read' && method == 'POST') {
      final n = _find(notifications, seg[1]);
      if (n == null) return _notFound();
      n['is_read'] = true;
      return (200, {'message': 'ok'});
    }
    return _notFound();
  }
}
