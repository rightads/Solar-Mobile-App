import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/features/leads/data/models/lead_model.dart';

final leadRepositoryProvider = Provider<LeadRepository>((ref) {
  return LeadRepository();
});

class LeadRepository {
  final ApiClient _apiClient;

  LeadRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  String _parseDioError(DioException de, String fallback) {
    final data = de.response?.data;
    if (data is Map) {
      if (data['error'] is Map && data['error']['message'] != null) {
        return data['error']['message'].toString();
      }
      if (data['detail'] != null) {
        return data['detail'].toString();
      }
    }
    return de.message ?? fallback;
  }

  /// Fetch all leads accessible to the current user (salesman is auto-scoped by backend)
  Future<List<LeadModel>> getLeads({
    String? status,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
        // Map UI label to backend status
        switch (status.toLowerCase()) {
          case 'follow-up':
          case 'follow_up':
            queryParams['status'] = 'follow_up';
            break;
          case 'closed':
            queryParams['status'] = 'converted';
            break;
          case 'returned':
            queryParams['status'] = 'lost';
            break;
          default:
            queryParams['status'] = status.toLowerCase();
        }
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final res = await _apiClient.dio.get('/leads', queryParameters: queryParams);
      final data = res.data;

      List<dynamic> items = [];
      if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else if (data is List) {
        items = data;
      }

      return items.map((e) => LeadModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Failed to load leads');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error fetching leads: $e');
    }
  }

  /// Create a new lead auto-assigned to the current salesman
  Future<LeadModel> createLead({
    required String name,
    required String phone,
    String? address,
    double? expectedKw,
    String? reference,
    String? notes,
  }) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final source = (reference != null && reference.trim().isNotEmpty)
          ? 'Self: ${reference.trim()}'
          : 'Direct Sales';

      final res = await _apiClient.dio.post('/leads', data: {
        'name': name.trim(),
        'phone': cleanPhone,
        'address': address?.trim(),
        'expected_kw': expectedKw,
        'source': source,
        'notes': notes?.trim(),
      });

      return LeadModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Failed to create lead');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error creating lead: $e');
    }
  }

  /// Update lead details or schedule follow-up
  Future<LeadModel> updateLead(
    String leadId, {
    String? name,
    String? phone,
    String? address,
    double? expectedKw,
    String? status,
    DateTime? followUpDate,
    String? notes,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name.trim();
      if (phone != null) payload['phone'] = phone.replaceAll(RegExp(r'\D'), '');
      if (address != null) payload['address'] = address.trim();
      if (expectedKw != null) payload['expected_kw'] = expectedKw;
      if (status != null) payload['status'] = status;
      if (followUpDate != null) payload['follow_up_date'] = followUpDate.toIso8601String();
      if (notes != null) payload['notes'] = notes.trim();

      final res = await _apiClient.dio.patch('/leads/$leadId', data: payload);
      return LeadModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Failed to update lead');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error updating lead: $e');
    }
  }

  /// Mark lead as returned/lost with a required reason
  Future<LeadModel> markLeadLost(String leadId, {required String reason}) async {
    try {
      final res = await _apiClient.dio.post('/leads/$leadId/mark-lost', data: {
        'reason': reason.trim(),
      });
      return LeadModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Failed to return lead');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error marking lead lost: $e');
    }
  }
}
