import 'dart:convert';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/features/kedl/data/models/kedl_model.dart';

class KedlRepository {
  final ApiClient _apiClient;
  static const String _kKedlCacheKey = 'kedl_files_cache_v1';

  KedlRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // ── List Files ─────────────────────────────────────────────────────────────

  Future<List<KedlFileModel>> listKedlFiles({
    String? customerId,
    KedlFileType? fileType,
    KedlFileStatus? status,
    bool? hasOpenDemand,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{};
    if (customerId != null) queryParams['customer_id'] = customerId;
    if (fileType != null) queryParams['file_type'] = fileType.toBackendString();
    if (status != null) queryParams['status'] = status.toBackendString();
    if (hasOpenDemand != null) queryParams['has_open_demand'] = hasOpenDemand;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    try {
      final response = await _apiClient.dio.get(
        '/kedl-files',
        queryParameters: queryParams,
      );

      final List<KedlFileModel> result = [];
      if (response.data is List) {
        for (final item in response.data) {
          if (item is Map<String, dynamic>) {
            result.add(KedlFileModel.fromJson(item));
          }
        }
      }

      await _cacheFiles(result);
      return result;
    } catch (e) {
      dev.log('Error fetching KEDL files from API: $e. Falling back to local cache.');
      return _loadCachedOrMockFiles(
        customerId: customerId,
        fileType: fileType,
        status: status,
        hasOpenDemand: hasOpenDemand,
        search: search,
      );
    }
  }

  // ── Get Single File ────────────────────────────────────────────────────────

  Future<KedlFileModel> getKedlFileById(String id) async {
    try {
      final response = await _apiClient.dio.get('/kedl-files/$id');
      if (response.data is Map<String, dynamic>) {
        return KedlFileModel.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      dev.log('Error fetching KEDL file $id from API: $e');
    }

    final cached = await _loadCachedOrMockFiles();
    final match = cached.where((f) => f.id == id).firstOrNull;
    if (match != null) return match;
    throw Exception('KEDL file not found ($id)');
  }

  // ── Update File Info (Application No, Remarks) ─────────────────────────────

  Future<KedlFileModel> updateKedlFile(
    String id, {
    String? applicationNo,
    String? remarks,
  }) async {
    final payload = <String, dynamic>{};
    if (applicationNo != null) payload['application_no'] = applicationNo;
    if (remarks != null) payload['remarks'] = remarks;

    try {
      final response = await _apiClient.dio.patch('/kedl-files/$id', data: payload);
      if (response.data is Map<String, dynamic>) {
        final updated = KedlFileModel.fromJson(response.data as Map<String, dynamic>);
        await _updateCachedFile(updated);
        return updated;
      }
    } catch (e) {
      throw ApiClient.toFriendly(e);
    }
    throw Exception('Unexpected response from server.');
  }

  // ── Update File Status ─────────────────────────────────────────────────────

  Future<KedlFileModel> updateFileStatus(
    String id,
    KedlFileStatus newStatus, {
    String? note,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/kedl-files/$id/status',
        data: {
          'status': newStatus.toBackendString(),
          if (note != null) 'note': note,
        },
      );
      if (response.data is Map<String, dynamic>) {
        final updated = KedlFileModel.fromJson(response.data as Map<String, dynamic>);
        await _updateCachedFile(updated);
        return updated;
      }
    } catch (e) {
      throw ApiClient.toFriendly(e);
    }
    throw Exception('Unexpected response from server.');
  }

  // ── Raise Demand ───────────────────────────────────────────────────────────

  Future<KedlDemandModel> raiseDemand(
    String fileId, {
    required String description,
    int? amountPaise,
    DateTime? dueDate,
  }) async {
    final payload = <String, dynamic>{
      'description': description,
      if (amountPaise != null) 'amount': amountPaise,
      if (dueDate != null) 'due_date': dueDate.toIso8601String().split('T').first,
    };

    try {
      final response = await _apiClient.dio.post(
        '/kedl-files/$fileId/demands',
        data: payload,
      );
      if (response.data is Map<String, dynamic>) {
        final demand = KedlDemandModel.fromJson(response.data as Map<String, dynamic>);
        // Refresh file in cache
        final currentFile = await getKedlFileById(fileId);
        final updatedFile = currentFile.copyWith(
          status: KedlFileStatus.demandRaised,
          demands: [...currentFile.demands, demand],
        );
        await _updateCachedFile(updatedFile);
        return demand;
      }
    } catch (e) {
      throw ApiClient.toFriendly(e);
    }
    throw Exception('Unexpected response from server.');
  }

  // ── Mark Demand Paid / Waived ──────────────────────────────────────────────

  Future<KedlDemandModel> updateDemand(
    String demandId, {
    required KedlDemandStatus status,
    DateTime? paidOn,
    String? receiptFilePath,
  }) async {
    try {
      final formData = FormData();
      formData.fields.add(MapEntry('status', status.toBackendString()));
      if (paidOn != null) {
        formData.fields.add(MapEntry('paid_on', paidOn.toIso8601String()));
      }
      if (receiptFilePath != null) {
        final name = receiptFilePath.split('/').last.split('\\').last;
        formData.files.add(
          MapEntry('receipt_file', MultipartFile.fromFileSync(receiptFilePath, filename: name)),
        );
      }

      final response = await _apiClient.dio.patch(
        '/kedl-demands/$demandId',
        data: formData,
      );

      if (response.data is Map<String, dynamic>) {
        return KedlDemandModel.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      throw ApiClient.toFriendly(e);
    }
    throw Exception('Unexpected response from server.');
  }

  // ── Upload Document ────────────────────────────────────────────────────────

  Future<KedlDocumentModel> uploadDocument(
    String fileId, {
    required String docType,
    required String filePath,
    required String fileName,
  }) async {
    try {
      final formData = FormData();
      formData.fields.add(MapEntry('doc_type', docType));
      formData.files.add(
        MapEntry('file', MultipartFile.fromFileSync(filePath, filename: fileName)),
      );

      final response = await _apiClient.dio.post(
        '/kedl-files/$fileId/documents',
        data: formData,
      );

      if (response.data is Map<String, dynamic>) {
        final doc = KedlDocumentModel.fromJson(response.data as Map<String, dynamic>);
        final current = await getKedlFileById(fileId);
        await _updateCachedFile(current.copyWith(documents: [...current.documents, doc]));
        return doc;
      }
    } catch (e) {
      throw ApiClient.toFriendly(e);
    }
    throw Exception('Unexpected response from server.');
  }

  // ── Dashboard Metrics ──────────────────────────────────────────────────────

  Future<KedlDashboardMetricsModel> getDashboardMetrics() async {
    try {
      final response = await _apiClient.dio.get('/kedl/dashboard');
      if (response.data is Map<String, dynamic>) {
        return KedlDashboardMetricsModel.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      dev.log('Error fetching KEDL dashboard metrics: $e. Computing from cached files.');
    }

    final files = await _loadCachedOrMockFiles();
    final byType = <String, int>{};
    final byStatus = <String, int>{};
    int openCount = 0;
    int overdueCount = 0;

    for (final f in files) {
      byType[f.fileType.toBackendString()] = (byType[f.fileType.toBackendString()] ?? 0) + 1;
      byStatus[f.status.toBackendString()] = (byStatus[f.status.toBackendString()] ?? 0) + 1;

      for (final d in f.demands) {
        if (d.status == KedlDemandStatus.open) {
          openCount++;
          if (d.isOverdue) overdueCount++;
        }
      }
    }

    return KedlDashboardMetricsModel(
      totalFiles: files.length,
      byFileType: byType,
      byStatus: byStatus,
      openDemandsCount: openCount,
      overdueDemandsCount: overdueCount,
    );
  }

  // ── Group by Customer Helper ───────────────────────────────────────────────

  List<KedlCustomerGroupModel> groupFilesByCustomer(List<KedlFileModel> files) {
    final Map<String, List<KedlFileModel>> grouped = {};
    for (final f in files) {
      grouped.putIfAbsent(f.customerId, () => []).add(f);
    }

    return grouped.entries.map((entry) {
      final first = entry.value.first;
      return KedlCustomerGroupModel(
        customerId: entry.key,
        customerName: first.customerName,
        customerPhone: first.customerPhone,
        customerAddress: first.customerAddress,
        files: entry.value,
      );
    }).toList();
  }

  // ── Cache & Mock Helpers ───────────────────────────────────────────────────

  Future<void> _cacheFiles(List<KedlFileModel> files) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(files.map((f) => f.toJson()).toList());
      await prefs.setString(_kKedlCacheKey, encoded);
    } catch (_) {}
  }

  Future<void> _updateCachedFile(KedlFileModel updated) async {
    final list = await _loadCachedOrMockFiles();
    final idx = list.indexWhere((f) => f.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
    } else {
      list.insert(0, updated);
    }
    await _cacheFiles(list);
  }

  Future<List<KedlFileModel>> _loadCachedOrMockFiles({
    String? customerId,
    KedlFileType? fileType,
    KedlFileStatus? status,
    bool? hasOpenDemand,
    String? search,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKedlCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        final list = decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => KedlFileModel.fromJson(item))
            .toList();

        return _applyFilters(list, customerId, fileType, status, hasOpenDemand, search);
      }
    } catch (_) {}

    return [];
  }

  List<KedlFileModel> _applyFilters(
    List<KedlFileModel> list,
    String? customerId,
    KedlFileType? fileType,
    KedlFileStatus? status,
    bool? hasOpenDemand,
    String? search,
  ) {
    return list.where((f) {
      if (customerId != null && f.customerId != customerId) return false;
      if (fileType != null && f.fileType != fileType) return false;
      if (status != null && f.status != status) return false;
      if (hasOpenDemand == true && !f.hasOpenDemand) return false;
      if (search != null && search.trim().isNotEmpty) {
        final q = search.toLowerCase();
        final match = f.customerName.toLowerCase().contains(q) ||
            (f.applicationNo?.toLowerCase().contains(q) ?? false) ||
            f.customerAddress.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

}
