import 'package:dio/dio.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/services/media_picker.dart';
import 'package:solar_pro/features/client/data/models/client_dashboard_model.dart';

class ClientRepository {
  final ApiClient _apiClient;

  ClientRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Fetch 10-stage milestones, assigned employee with Employee No, specs, and financials
  Future<Map<String, dynamic>> getClientHomeData() async {
    try {
      final res = await _apiClient.dio.get('/client/home');
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      throw Exception('Unexpected response from server.');
    } catch (e) {
      throw ApiClient.toFriendly(e, fallback: 'Could not load your project. Pull down to retry.');
    }
  }

  /// Get list of submitted payments with their salesman approval & admin verification status
  Future<List<ClientPaymentRecord>> getPayments() async {
    try {
      final res = await _apiClient.dio.get('/client/payments');
      if (res.data is List) {
        final list = (res.data as List).map((e) => ClientPaymentRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        return list;
      } else if (res.data is Map && res.data['items'] is List) {
        return (res.data['items'] as List).map((e) => ClientPaymentRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
      return [];
    } catch (e) {
      throw ApiClient.toFriendly(e, fallback: 'Could not load payments.');
    }
  }

  static String _backendMode(String label) {
    final m = label.toLowerCase().trim();
    if (m == 'upi' || m == 'cash' || m == 'cheque') return m;
    if (m.contains('bank') || m.contains('neft') || m.contains('rtgs')) return 'bank_transfer';
    return 'other';
  }

  /// Client submits a payment with its receipt photo for sales approval.
  Future<ClientPaymentRecord> submitPayment({
    required double amountRupees,
    required String mode,
    String? referenceNo,
    String? remarks,
    PickedMedia? proof,
  }) async {
    final amountPaise = (amountRupees * 100).round();
    try {
      final formData = FormData.fromMap({
        'amount': amountPaise,
        'mode': _backendMode(mode),
        if (referenceNo != null && referenceNo.isNotEmpty) 'reference_no': referenceNo,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        if (proof != null) 'file': MultipartFile.fromBytes(proof.bytes, filename: proof.name),
      });
      final res = await _apiClient.dio.post('/client/payments', data: formData);
      return ClientPaymentRecord.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw ApiClient.toFriendly(e, fallback: 'Payment could not be submitted. Please try again.');
    }
  }

  /// Get all service tickets
  Future<List<ClientTicketRecord>> getTickets() async {
    try {
      final res = await _apiClient.dio.get('/client/tickets');
      if (res.data is List) {
        final list = (res.data as List).map((e) => ClientTicketRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        return list;
      }
      return [];
    } catch (e) {
      throw ApiClient.toFriendly(e, fallback: 'Could not load tickets.');
    }
  }

  /// Raise a service ticket. Photos are uploaded first and attached by file id.
  Future<ClientTicketRecord> createTicket({
    required ClientTicketType type,
    required String title,
    required String description,
    String? errorCode,
    String priority = 'high',
    required List<PickedMedia> images,
  }) async {
    if (type == ClientTicketType.structure && (images.length < 2 || images.length > 10)) {
      throw Exception('Structure issue requires between 2 and 10 photos of the structure.');
    }
    if (type == ClientTicketType.wiring && (images.isEmpty || images.length > 10)) {
      throw Exception('Wiring issue requires at least 1 photo (up to 10 photos).');
    }
    try {
      final imageKeys = <String>[];
      for (final img in images) {
        final up = await _apiClient.dio.post('/files', data: FormData.fromMap({
          'purpose': 'ticket_image',
          'file': MultipartFile.fromBytes(img.bytes, filename: img.name),
        }));
        imageKeys.add((up.data as Map)['file_id'].toString());
      }
      final res = await _apiClient.dio.post('/client/tickets', data: {
        'type': type.name,
        'title': title.trim(),
        'description': description.trim(),
        if (errorCode != null && errorCode.isNotEmpty) 'error_code': errorCode.trim(),
        'priority': priority.toLowerCase(),
        'image_keys': imageKeys,
      });
      return ClientTicketRecord.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw ApiClient.toFriendly(e, fallback: 'Ticket could not be raised. Please try again.');
    }
  }
}
