import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/features/tickets/data/models/ticket_model.dart';

class TicketRepository {
  final ApiClient _apiClient;
  static const String _kTicketsCacheKey = 'service_tickets_cache_v1';

  TicketRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // ── List Tickets ───────────────────────────────────────────────────────────

  Future<List<TicketModel>> listTickets({
    String? customerId,
    TicketStatus? status,
    TicketType? type,
    String? assignedTo,
    TicketPriority? priority,
    String? search,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(AppConstants.kUserRole)?.toLowerCase() ?? '';
    final userId = prefs.getString(AppConstants.kUserId);

    // Rule: Service employees see only tickets assigned to them
    String? effectiveAssignedTo = assignedTo;
    if (effectiveAssignedTo == null && (role == 'service' || role == 'technician') && userId != null) {
      effectiveAssignedTo = userId;
    }

    final queryParams = <String, dynamic>{};
    if (customerId != null) queryParams['customer_id'] = customerId;
    if (status != null) queryParams['status'] = status.toBackendString();
    if (type != null) queryParams['type'] = type.toBackendString();
    if (effectiveAssignedTo != null) queryParams['assigned_to'] = effectiveAssignedTo;

    try {
      final response = await _apiClient.dio.get('/tickets', queryParameters: queryParams);
      final List<TicketModel> result = [];
      if (response.data is List) {
        for (final item in response.data) {
          if (item is Map<String, dynamic>) {
            result.add(TicketModel.fromJson(item));
          }
        }
      }

      await _cacheTickets(result);
      return _applyFilters(result, customerId, status, type, effectiveAssignedTo, priority, search);
    } catch (e) {
      dev.log('Error fetching tickets from API: $e. Using local cache.');
      return _loadCachedOrMockTickets(
        customerId: customerId,
        status: status,
        type: type,
        assignedTo: effectiveAssignedTo,
        priority: priority,
        search: search,
      );
    }
  }

  // ── Get Single Ticket ──────────────────────────────────────────────────────

  Future<TicketModel> getTicketById(String id) async {
    try {
      final response = await _apiClient.dio.get('/tickets/$id');
      if (response.data is Map<String, dynamic>) {
        return TicketModel.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      dev.log('Error fetching ticket $id from API: $e');
    }

    final cached = await _loadCachedOrMockTickets();
    final match = cached.where((t) => t.id == id).firstOrNull;
    if (match != null) return match;
    throw Exception('Ticket not found ($id)');
  }

  // ── Update Ticket Status ───────────────────────────────────────────────────

  Future<TicketModel> updateTicketStatus(
    String id,
    TicketStatus status, {
    String? resolutionNote,
  }) async {
    // CRITICAL BACKEND & PROMPT RULE: Resolve strictly requires a resolution note
    if (status == TicketStatus.resolved && (resolutionNote == null || resolutionNote.trim().isEmpty)) {
      throw ArgumentError('A resolution note is strictly required before resolving a ticket.');
    }

    final payload = <String, dynamic>{
      'status': status.toBackendString(),
      if (resolutionNote != null) 'resolution_note': resolutionNote,
    };

    try {
      final response = await _apiClient.dio.post('/tickets/$id/status', data: payload);
      if (response.data is Map<String, dynamic>) {
        final updated = TicketModel.fromJson(response.data as Map<String, dynamic>);
        await _updateCachedTicket(updated);
        return updated;
      }
    } catch (e) {
      throw ApiClient.toFriendly(e);
    }
    throw Exception('Unexpected response from server.');
  }

  // ── Assign Ticket (Admin) ──────────────────────────────────────────────────

  Future<TicketModel> assignTicket(String id, String employeeId) async {
    try {
      final response = await _apiClient.dio.post('/tickets/$id/assign', data: {'assigned_to': employeeId});
      if (response.data is Map<String, dynamic>) {
        final updated = TicketModel.fromJson(response.data as Map<String, dynamic>);
        await _updateCachedTicket(updated);
        return updated;
      }
    } catch (e) {
      throw ApiClient.toFriendly(e);
    }
    throw Exception('Unexpected response from server.');
  }

  // ── Add Ticket Comment ─────────────────────────────────────────────────────

  Future<TicketCommentModel> addTicketComment(String id, String message) async {
    if (message.trim().isEmpty) {
      throw ArgumentError('Comment message cannot be empty');
    }

    try {
      final response = await _apiClient.dio.post(
        '/tickets/$id/comments',
        data: {'message': message.trim()},
      );
      if (response.data is Map<String, dynamic>) {
        final comment = TicketCommentModel.fromJson(response.data as Map<String, dynamic>);
        final current = await getTicketById(id);
        await _updateCachedTicket(current.copyWith(comments: [...current.comments, comment]));
        return comment;
      }
    } catch (e) {
      throw ApiClient.toFriendly(e);
    }
    throw Exception('Unexpected response from server.');
  }

  // ── Add Visit Photos ───────────────────────────────────────────────────────

  Future<List<TicketImageModel>> addVisitPhotos(String id, List<String> filePaths) async {
    final List<TicketImageModel> newPhotos = [];
    final now = DateTime.now();

    for (int i = 0; i < filePaths.length; i++) {
      final path = filePaths[i];
      newPhotos.add(
        TicketImageModel(
          id: 'img_${now.millisecondsSinceEpoch}_$i',
          ticketId: id,
          fileKey: path.split('/').last.split('\\').last,
          createdAt: now,
        ),
      );
    }

    final current = await getTicketById(id);
    final updated = current.copyWith(images: [...current.images, ...newPhotos]);
    await _updateCachedTicket(updated);
    return newPhotos;
  }

  // ── Reverse Serial Lookup ──────────────────────────────────────────────────

  Future<SerialDetailModel> lookupSerial(String serialNo) async {
    final cleanSerial = serialNo.trim().toUpperCase();
    try {
      final response = await _apiClient.dio.get('/serials/$cleanSerial');
      if (response.data is Map<String, dynamic>) {
        return SerialDetailModel.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      throw ApiClient.toFriendly(e, fallback: 'Serial number not found.');
    }
    throw Exception('Serial number not found.');
  }

  // ── Cache & Mock Persistence ───────────────────────────────────────────────

  Future<void> _cacheTickets(List<TicketModel> tickets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(tickets.map((t) => t.toJson()).toList());
      await prefs.setString(_kTicketsCacheKey, encoded);
    } catch (_) {}
  }

  Future<void> _updateCachedTicket(TicketModel updated) async {
    final list = await _loadCachedOrMockTickets();
    final idx = list.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
    } else {
      list.insert(0, updated);
    }
    await _cacheTickets(list);
  }

  Future<List<TicketModel>> _loadCachedOrMockTickets({
    String? customerId,
    TicketStatus? status,
    TicketType? type,
    String? assignedTo,
    TicketPriority? priority,
    String? search,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTicketsCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        final list = decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => TicketModel.fromJson(item))
            .toList();

        return _applyFilters(list, customerId, status, type, assignedTo, priority, search);
      }
    } catch (_) {}

    return [];
  }

  List<TicketModel> _applyFilters(
    List<TicketModel> list,
    String? customerId,
    TicketStatus? status,
    TicketType? type,
    String? assignedTo,
    TicketPriority? priority,
    String? search,
  ) {
    return list.where((t) {
      if (customerId != null && t.customerId != customerId) return false;
      if (status != null && t.status != status) return false;
      if (type != null && t.type != type) return false;
      if (priority != null && t.priority != priority) return false;
      if (search != null && search.trim().isNotEmpty) {
        final q = search.toLowerCase();
        final match = t.ticketNo.toLowerCase().contains(q) ||
            t.customerName.toLowerCase().contains(q) ||
            t.title.toLowerCase().contains(q) ||
            (t.errorCode?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      return true;
    }).toList();
  }


}
