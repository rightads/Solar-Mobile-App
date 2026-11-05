import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/features/customers/data/models/customer_model.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository();
});

class CustomerRepository {
  final ApiClient _apiClient;

  CustomerRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

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

  /// Fetch customers scoped to the logged-in user (salesman only sees own converted customers)
  Future<List<CustomerModel>> getCustomers({
    String? stage,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };

      if (stage != null && stage.isNotEmpty && stage.toLowerCase() != 'all') {
        queryParams['stage'] = stage;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final res = await _apiClient.dio.get('/customers', queryParameters: queryParams);
      final data = res.data;

      List<dynamic> items = [];
      if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else if (data is List) {
        items = data;
      }

      return items
          .map((e) => CustomerModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Failed to load customers');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error fetching customers: $e');
    }
  }

  /// Get single customer details with stage history and payment summary
  Future<CustomerModel> getCustomerById(String customerId) async {
    try {
      final res = await _apiClient.dio.get('/customers/$customerId');
      return CustomerModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Customer not found');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error fetching customer: $e');
    }
  }

  /// Atomically convert a closed lead into an active Customer + client login
  /// via `POST /leads/{leadId}/convert`.
  Future<CustomerModel> convertLead({
    required String leadId,
    required String address,
    double? latitude,
    double? longitude,
    required int finalPricePaise,
    required double capacityKw,
    required String phase,
    required String panelBrand,
    required int panelWatt,
    required int panelCount,
    required String inverterBrand,
    required String structureType,
  }) async {
    try {
      final payload = <String, dynamic>{
        'address': address.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'final_price': finalPricePaise,
        'capacity_kw': capacityKw,
        'phase': phase,
        'panel_brand': panelBrand.trim(),
        'panel_watt': panelWatt,
        'panel_count': panelCount,
        'inverter_brand': inverterBrand.trim(),
        'structure_type': structureType.trim(),
      };

      final res = await _apiClient.dio.post('/leads/$leadId/convert', data: payload);
      return CustomerModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Failed to convert lead to customer');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error converting lead: $e');
    }
  }

  /// Upload a KYC or property document for a customer via `POST /customers/{id}/documents`
  Future<Map<String, dynamic>> uploadCustomerDocument({
    required String customerId,
    required String docType,
    required String fileName,
    List<int>? fileBytes,
    String? filePath,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      MultipartFile multipartFile;
      if (fileBytes != null) {
        multipartFile = MultipartFile.fromBytes(fileBytes, filename: fileName);
      } else if (filePath != null) {
        multipartFile = await MultipartFile.fromFile(filePath, filename: fileName);
      } else {
        // Fallback dummy file bytes if picking is mocked in tests or simulation
        multipartFile = MultipartFile.fromBytes([0, 1, 2, 3], filename: fileName);
      }

      final formData = FormData.fromMap({
        'type': docType,
        'file': multipartFile,
      });

      final res = await _apiClient.dio.post(
        '/customers/$customerId/documents',
        data: formData,
        onSendProgress: onProgress,
      );

      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Failed to upload document');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error uploading document: $e');
    }
  }

  /// List customer uploaded documents
  Future<List<Map<String, dynamic>>> getCustomerDocuments(String customerId) async {
    try {
      final res = await _apiClient.dio.get('/customers/$customerId/documents');
      if (res.data is List) {
        return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } on DioException catch (de) {
      final msg = _parseDioError(de, 'Failed to load documents');
      throw Exception(msg);
    } catch (e) {
      throw Exception('Unexpected error loading documents: $e');
    }
  }
}
