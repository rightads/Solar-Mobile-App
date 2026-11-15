import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';

enum OfflineActionType {
  startWork,
  uploadPhotos,
  completeWork;

  static OfflineActionType fromString(String val) {
    switch (val) {
      case 'start_work':
        return OfflineActionType.startWork;
      case 'upload_photos':
        return OfflineActionType.uploadPhotos;
      case 'complete_work':
        return OfflineActionType.completeWork;
      default:
        return OfflineActionType.startWork;
    }
  }

  String toBackendString() {
    switch (this) {
      case OfflineActionType.startWork:
        return 'start_work';
      case OfflineActionType.uploadPhotos:
        return 'upload_photos';
      case OfflineActionType.completeWork:
        return 'complete_work';
    }
  }

  String get displayName {
    switch (this) {
      case OfflineActionType.startWork:
        return 'Start Work';
      case OfflineActionType.uploadPhotos:
        return 'Upload Photos';
      case OfflineActionType.completeWork:
        return 'Complete Work';
    }
  }
}

class QueuedOfflineAction {
  final String id;
  final String assignmentId;
  final OfflineActionType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  /// User who queued the action. Only that user's session may replay it, so a
  /// different person signing in on the same device never submits it.
  final String ownerId;

  const QueuedOfflineAction({
    required this.id,
    required this.assignmentId,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.ownerId = '',
  });

  factory QueuedOfflineAction.fromJson(Map<String, dynamic> json) {
    return QueuedOfflineAction(
      id: json['id']?.toString() ?? '',
      assignmentId: json['assignment_id']?.toString() ?? '',
      type: OfflineActionType.fromString(json['type']?.toString() ?? ''),
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      retryCount: json['retry_count'] as int? ?? 0,
      ownerId: json['owner_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'assignment_id': assignmentId,
        'type': type.toBackendString(),
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
        'owner_id': ownerId,
      };

  QueuedOfflineAction copyWith({int? retryCount}) {
    return QueuedOfflineAction(
      id: id,
      assignmentId: assignmentId,
      type: type,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      ownerId: ownerId,
    );
  }
}

/// Service that maintains a persistent queue of site work status updates and photo uploads
/// when operating in low-connectivity or offline site environments.
class SiteOfflineQueueService extends ChangeNotifier {
  static const String _kQueueKey = 'site_work_offline_queue_v1';
  static final SiteOfflineQueueService _instance = SiteOfflineQueueService._internal();

  factory SiteOfflineQueueService() => _instance;
  SiteOfflineQueueService._internal();

  List<QueuedOfflineAction> _actions = [];
  bool _isSyncing = false;

  List<QueuedOfflineAction> get actions => List.unmodifiable(_actions);
  int get pendingCount => _actions.length;
  bool get hasPending => _actions.isNotEmpty;
  bool get isSyncing => _isSyncing;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kQueueKey);
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        _actions = decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => QueuedOfflineAction.fromJson(item))
            .toList();
      }
    } catch (_) {
      _actions = [];
    }
    notifyListeners();
  }

  static Future<String> currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.kUserId) ?? '';
  }

  /// Actions the signed-in user may replay (legacy untagged actions included).
  List<QueuedOfflineAction> actionsFor(String userId) =>
      _actions.where((a) => a.ownerId.isEmpty || a.ownerId == userId).toList();

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_actions.map((a) => a.toJson()).toList());
    await prefs.setString(_kQueueKey, encoded);
    notifyListeners();
  }

  /// Queues a work start action
  Future<void> queueStartWork(String assignmentId) async {
    final action = QueuedOfflineAction(
      id: 'queue_start_${DateTime.now().millisecondsSinceEpoch}',
      assignmentId: assignmentId,
      type: OfflineActionType.startWork,
      payload: {'timestamp': DateTime.now().toIso8601String()},
      createdAt: DateTime.now(),
      ownerId: await currentUserId(),
    );
    _actions.add(action);
    await _persist();
  }

  /// Queues photo uploads
  Future<void> queuePhotoUpload(
    String assignmentId,
    List<String> filePaths, {
    List<String>? captions,
  }) async {
    final action = QueuedOfflineAction(
      id: 'queue_photo_${DateTime.now().millisecondsSinceEpoch}',
      assignmentId: assignmentId,
      type: OfflineActionType.uploadPhotos,
      payload: {
        'file_paths': filePaths,
        if (captions != null) 'captions': captions,
      },
      createdAt: DateTime.now(),
      ownerId: await currentUserId(),
    );
    _actions.add(action);
    await _persist();
  }

  /// Queues work completion
  Future<void> queueCompleteWork(String assignmentId) async {
    final action = QueuedOfflineAction(
      id: 'queue_complete_${DateTime.now().millisecondsSinceEpoch}',
      assignmentId: assignmentId,
      type: OfflineActionType.completeWork,
      payload: {'timestamp': DateTime.now().toIso8601String()},
      createdAt: DateTime.now(),
      ownerId: await currentUserId(),
    );
    _actions.add(action);
    await _persist();
  }

  /// Check if a specific assignment has pending offline actions
  bool hasPendingForAssignment(String assignmentId) {
    return _actions.any((a) => a.assignmentId == assignmentId);
  }

  /// Remove action by ID
  Future<void> removeAction(String actionId) async {
    _actions.removeWhere((a) => a.id == actionId);
    await _persist();
  }

  /// Clear all queued actions
  Future<void> clearAll() async {
    _actions.clear();
    await _persist();
  }

  /// Set syncing flag
  void setSyncing(bool value) {
    _isSyncing = value;
    notifyListeners();
  }
}
