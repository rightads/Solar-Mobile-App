import 'dart:convert';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/features/work_assignment/data/models/work_assignment_model.dart';
import 'package:solar_pro/features/work_assignment/data/services/site_offline_queue_service.dart';

class WorkAssignmentRepository {
  final ApiClient _apiClient;
  final SiteOfflineQueueService _offlineQueue;
  static const String _kAssignmentsCacheKey = 'site_work_assignments_cache_v1';

  WorkAssignmentRepository({
    ApiClient? apiClient,
    SiteOfflineQueueService? offlineQueue,
  })  : _apiClient = apiClient ?? ApiClient(),
        _offlineQueue = offlineQueue ?? SiteOfflineQueueService();

  // ── List Work Assignments ──────────────────────────────────────────────────

  Future<List<WorkAssignmentModel>> listWorkAssignments({
    WorkType? workType,
    WorkStatus? status,
    String? customerId,
    String? teamId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final queryParams = <String, dynamic>{};
    if (workType != null) queryParams['work_type'] = workType.toBackendString();
    if (status != null) queryParams['status'] = status.toBackendString();
    if (customerId != null) queryParams['customer_id'] = customerId;
    if (teamId != null) queryParams['team_id'] = teamId;
    if (dateFrom != null) {
      queryParams['date_from'] = dateFrom.toIso8601String().split('T').first;
    }
    if (dateTo != null) {
      queryParams['date_to'] = dateTo.toIso8601String().split('T').first;
    }

    try {
      final response = await _apiClient.dio.get(
        '/work-assignments',
        queryParameters: queryParams,
      );

      final List<WorkAssignmentModel> result = [];
      if (response.data is List) {
        for (final item in response.data) {
          if (item is Map<String, dynamic>) {
            final model = WorkAssignmentModel.fromJson(item);
            // Strict role scoping check
            if (workType == null || model.workType == workType) {
              final isPending = _offlineQueue.hasPendingForAssignment(model.id);
              result.add(model.copyWith(isPendingSync: isPending));
            }
          }
        }
      }

      // Update local cache
      await _cacheAssignments(result);
      return result;
    } catch (e) {
      dev.log('Error fetching work assignments from API: $e. Falling back to local cache.');
      return _loadCachedOrMockAssignments(workType: workType, status: status);
    }
  }

  // ── Get Single Assignment ──────────────────────────────────────────────────

  Future<WorkAssignmentModel> getWorkAssignmentById(String id) async {
    try {
      final response = await _apiClient.dio.get('/work-assignments/$id');
      if (response.data is Map<String, dynamic>) {
        final model = WorkAssignmentModel.fromJson(response.data as Map<String, dynamic>);
        final isPending = _offlineQueue.hasPendingForAssignment(id);
        return model.copyWith(isPendingSync: isPending);
      }
    } catch (e) {
      dev.log('Error fetching single assignment $id from API: $e');
    }

    final cached = await _loadCachedOrMockAssignments();
    final match = cached.where((a) => a.id == id).firstOrNull;
    if (match != null) {
      return match;
    }
    throw Exception('Work assignment not found ($id)');
  }

  // ── Start Work Action ──────────────────────────────────────────────────────

  Future<WorkAssignmentModel> startWork(String id) async {
    try {
      final response = await _apiClient.dio.post('/work-assignments/$id/start');
      if (response.data is Map<String, dynamic>) {
        final updated = WorkAssignmentModel.fromJson(response.data as Map<String, dynamic>);
        await _updateCachedAssignment(updated);
        return updated;
      }
    } catch (e) {
      dev.log('Network error starting work $id: $e. Queueing offline action.');
      // Queue offline
      await _offlineQueue.queueStartWork(id);

      // Optimistic update in cache
      final current = await getWorkAssignmentById(id);
      final optimistic = current.copyWith(
        status: WorkStatus.inProgress,
        actualStart: DateTime.now(),
        isPendingSync: true,
      );
      await _updateCachedAssignment(optimistic);
      return optimistic;
    }

    final current = await getWorkAssignmentById(id);
    return current;
  }

  // ── Upload Photos Action ───────────────────────────────────────────────────

  Future<List<WorkPhotoModel>> uploadPhotos(
    String id,
    List<String> filePaths, {
    List<String>? captions,
  }) async {
    if (filePaths.isEmpty) {
      return [];
    }
    if (filePaths.length > 10) {
      throw ArgumentError('Maximum 10 photos allowed per upload.');
    }

    try {
      final formData = FormData();
      for (int i = 0; i < filePaths.length; i++) {
        final path = filePaths[i];
        final filename = path.split('/').last.split('\\').last;
        formData.files.add(
          MapEntry(
            'files',
            MultipartFile.fromFileSync(path, filename: filename),
          ),
        );
      }
      if (captions != null && captions.isNotEmpty) {
        for (final caption in captions) {
          formData.fields.add(MapEntry('captions', caption));
        }
      }

      final response = await _apiClient.dio.post(
        '/work-assignments/$id/photos',
        data: formData,
      );

      final List<WorkPhotoModel> uploaded = [];
      if (response.data is List) {
        for (final item in response.data) {
          if (item is Map<String, dynamic>) {
            uploaded.add(WorkPhotoModel.fromJson(item));
          }
        }
      }

      // Update cached assignment with new photos
      final current = await getWorkAssignmentById(id);
      final updatedPhotos = [...current.photos, ...uploaded];
      await _updateCachedAssignment(current.copyWith(photos: updatedPhotos));

      return uploaded;
    } catch (e) {
      dev.log('Network error uploading photos: $e. Queueing offline action.');
      // Queue offline
      await _offlineQueue.queuePhotoUpload(id, filePaths, captions: captions);

      // Create local photo models for immediate preview
      final List<WorkPhotoModel> localPhotos = [];
      for (int i = 0; i < filePaths.length; i++) {
        final path = filePaths[i];
        final caption = (captions != null && i < captions.length) ? captions[i] : null;
        localPhotos.add(
          WorkPhotoModel(
            id: 'local_photo_${DateTime.now().millisecondsSinceEpoch}_$i',
            workAssignmentId: id,
            fileKey: path.split('/').last.split('\\').last,
            caption: caption,
            createdAt: DateTime.now(),
            isLocal: true,
            localFilePath: path,
          ),
        );
      }

      final current = await getWorkAssignmentById(id);
      final updatedPhotos = [...current.photos, ...localPhotos];
      await _updateCachedAssignment(
        current.copyWith(photos: updatedPhotos, isPendingSync: true),
      );

      return localPhotos;
    }
  }

  // ── Complete Work Action ───────────────────────────────────────────────────

  Future<WorkAssignmentModel> completeWork(
    String id, {
    required List<WorkPhotoModel> existingPhotos,
  }) async {
    // CRITICAL BACKEND RULE: Completing requires at least 1 photo uploaded
    if (existingPhotos.isEmpty) {
      throw StateError(
        'Completing work requires at least 1 uploaded photo proof. Please add photos first.',
      );
    }

    try {
      final response = await _apiClient.dio.post('/work-assignments/$id/complete');
      if (response.data is Map<String, dynamic>) {
        final updated = WorkAssignmentModel.fromJson(response.data as Map<String, dynamic>);
        await _updateCachedAssignment(updated);
        return updated;
      }
    } catch (e) {
      dev.log('Network error completing work $id: $e. Queueing offline action.');
      // Queue offline
      await _offlineQueue.queueCompleteWork(id);

      // Optimistic update in cache
      final current = await getWorkAssignmentById(id);
      final optimistic = current.copyWith(
        status: WorkStatus.completed,
        actualEnd: DateTime.now(),
        isPendingSync: true,
      );
      await _updateCachedAssignment(optimistic);
      return optimistic;
    }

    final current = await getWorkAssignmentById(id);
    return current;
  }

  // ── Calendar Schedule ──────────────────────────────────────────────────────

  Future<CalendarScheduleModel> getCalendarSchedule(
    DateTime fromDate,
    DateTime toDate, {
    String? teamId,
    WorkType? workType,
  }) async {
    final fromStr = fromDate.toIso8601String().split('T').first;
    final toStr = toDate.toIso8601String().split('T').first;

    try {
      final queryParams = <String, dynamic>{
        'from_date': fromStr,
        'to_date': toStr,
      };
      if (teamId != null) queryParams['team_id'] = teamId;

      final response = await _apiClient.dio.get(
        '/work-assignments/calendar',
        queryParameters: queryParams,
      );

      if (response.data is Map<String, dynamic>) {
        final model = CalendarScheduleModel.fromJson(response.data as Map<String, dynamic>);
        if (workType == null) return model;

        // Scoping: filter items by workType
        final filteredByDate = <String, List<CalendarScheduleItemModel>>{};
        model.byDate.forEach((dateKey, items) {
          final matched = items.where((it) => it.workType == workType).toList();
          if (matched.isNotEmpty) {
            filteredByDate[dateKey] = matched;
          }
        });

        final filteredByTeam = <String, List<CalendarScheduleItemModel>>{};
        model.byTeam.forEach((teamKey, items) {
          final matched = items.where((it) => it.workType == workType).toList();
          if (matched.isNotEmpty) {
            filteredByTeam[teamKey] = matched;
          }
        });

        return CalendarScheduleModel(
          fromDate: model.fromDate,
          toDate: model.toDate,
          totalAssignments: filteredByDate.values.fold(0, (acc, l) => acc + l.length),
          byDate: filteredByDate,
          byTeam: filteredByTeam,
        );
      }
    } catch (e) {
      dev.log('Error fetching calendar schedule: $e. Generating from cached jobs.');
    }

    // Fallback: build calendar from cached / mock assignments
    final assignments = await _loadCachedOrMockAssignments(workType: workType);
    final byDate = <String, List<CalendarScheduleItemModel>>{};
    final byTeam = <String, List<CalendarScheduleItemModel>>{};

    for (final a in assignments) {
      final dKey = a.scheduledStart.toIso8601String().split('T').first;
      final item = CalendarScheduleItemModel(
        assignmentId: a.id,
        customerId: a.customerId,
        customerName: a.customer?.name ?? 'Customer',
        customerAddress: a.customer?.address ?? 'On-Site Location',
        workType: a.workType,
        teamId: a.teamId,
        teamName: a.teamName ?? '${a.workType.displayName} Team',
        scheduledStart: a.scheduledStart,
        scheduledEnd: a.scheduledEnd,
        status: a.status,
      );

      byDate.putIfAbsent(dKey, () => []).add(item);
      byTeam.putIfAbsent(item.teamName, () => []).add(item);
    }

    return CalendarScheduleModel(
      fromDate: fromDate,
      toDate: toDate,
      totalAssignments: assignments.length,
      byDate: byDate,
      byTeam: byTeam,
    );
  }

  // ── Sync Offline Queue ─────────────────────────────────────────────────────

  Future<int> syncPendingQueue() async {
    if (_offlineQueue.actions.isEmpty) return 0;
    _offlineQueue.setSyncing(true);

    int successCount = 0;
    final actionsToProcess = List<QueuedOfflineAction>.from(_offlineQueue.actions);

    for (final action in actionsToProcess) {
      try {
        switch (action.type) {
          case OfflineActionType.startWork:
            await _apiClient.dio.post('/work-assignments/${action.assignmentId}/start');
            await _offlineQueue.removeAction(action.id);
            successCount++;
            break;

          case OfflineActionType.uploadPhotos:
            final filePaths = (action.payload['file_paths'] as List?)?.cast<String>() ?? [];
            final captions = (action.payload['captions'] as List?)?.cast<String>();
            if (filePaths.isNotEmpty) {
              final formData = FormData();
              for (final path in filePaths) {
                final filename = path.split('/').last.split('\\').last;
                formData.files.add(
                  MapEntry('files', MultipartFile.fromFileSync(path, filename: filename)),
                );
              }
              if (captions != null) {
                for (final c in captions) {
                  formData.fields.add(MapEntry('captions', c));
                }
              }
              await _apiClient.dio.post(
                '/work-assignments/${action.assignmentId}/photos',
                data: formData,
              );
            }
            await _offlineQueue.removeAction(action.id);
            successCount++;
            break;

          case OfflineActionType.completeWork:
            await _apiClient.dio.post('/work-assignments/${action.assignmentId}/complete');
            await _offlineQueue.removeAction(action.id);
            successCount++;
            break;
        }
      } catch (e) {
        dev.log('Sync error for action ${action.id}: $e');
        // Stop batch on network error
        break;
      }
    }

    _offlineQueue.setSyncing(false);
    return successCount;
  }

  // ── Persistence & Mock Helpers ─────────────────────────────────────────────

  Future<void> _cacheAssignments(List<WorkAssignmentModel> assignments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(assignments.map((a) => a.toJson()).toList());
      await prefs.setString(_kAssignmentsCacheKey, encoded);
    } catch (_) {}
  }

  Future<void> _updateCachedAssignment(WorkAssignmentModel updated) async {
    final list = await _loadCachedOrMockAssignments();
    final idx = list.indexWhere((a) => a.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
    } else {
      list.insert(0, updated);
    }
    await _cacheAssignments(list);
  }

  Future<List<WorkAssignmentModel>> _loadCachedOrMockAssignments({
    WorkType? workType,
    WorkStatus? status,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kAssignmentsCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        final list = decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => WorkAssignmentModel.fromJson(item))
            .toList();

        return _applyFilters(list, workType, status);
      }
    } catch (_) {}

    return [];
  }

  List<WorkAssignmentModel> _applyFilters(
    List<WorkAssignmentModel> list,
    WorkType? workType,
    WorkStatus? status,
  ) {
    return list.where((a) {
      if (workType != null && a.workType != workType) return false;
      if (status != null && a.status != status) return false;
      return true;
    }).map((a) {
      final isPending = _offlineQueue.hasPendingForAssignment(a.id);
      return a.copyWith(isPendingSync: isPending);
    }).toList();
  }

}
