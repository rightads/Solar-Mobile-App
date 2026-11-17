import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/network/api_client.dart';

enum UploadStatus {
  pending,
  uploading,
  completed,
  failed,
  cancelled;

  String get displayName {
    switch (this) {
      case UploadStatus.pending:
        return 'Pending';
      case UploadStatus.uploading:
        return 'Uploading';
      case UploadStatus.completed:
        return 'Completed';
      case UploadStatus.failed:
        return 'Failed';
      case UploadStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class UploadItemModel {
  final String id;
  final String filePath;
  final String fileName;
  final String destinationEndpoint;
  final String description;
  final UploadStatus status;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic> extraData;

  const UploadItemModel({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.destinationEndpoint,
    required this.description,
    this.status = UploadStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    this.extraData = const {},
  });

  factory UploadItemModel.fromJson(Map<String, dynamic> json) {
    return UploadItemModel(
      id: json['id'] as String,
      filePath: json['file_path'] as String,
      fileName: json['file_name'] as String,
      destinationEndpoint: json['destination_endpoint'] as String,
      description: json['description'] as String,
      status: UploadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => UploadStatus.pending,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      extraData: json['extra_data'] is Map<String, dynamic> ? json['extra_data'] as Map<String, dynamic> : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_path': filePath,
      'file_name': fileName,
      'destination_endpoint': destinationEndpoint,
      'description': description,
      'status': status.name,
      'progress': progress,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'extra_data': extraData,
    };
  }

  UploadItemModel copyWith({
    String? id,
    String? filePath,
    String? fileName,
    String? destinationEndpoint,
    String? description,
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
    Map<String, dynamic>? extraData,
  }) {
    return UploadItemModel(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      destinationEndpoint: destinationEndpoint ?? this.destinationEndpoint,
      description: description ?? this.description,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      extraData: extraData ?? this.extraData,
    );
  }
}

class SharedUploadService extends ChangeNotifier {
  static final SharedUploadService _instance = SharedUploadService._internal();
  factory SharedUploadService() => _instance;

  static const String _kQueueKey = 'solar_shared_upload_queue_v1';
  final ApiClient _apiClient = ApiClient();
  final List<UploadItemModel> _queue = [];
  bool _isProcessing = false;
  final Set<String> _cancelledTaskIds = {};

  SharedUploadService._internal() {
    _loadQueue();
  }

  List<UploadItemModel> get queue => List.unmodifiable(_queue);
  int get pendingCount => _queue.where((item) => item.status == UploadStatus.pending || item.status == UploadStatus.uploading).length;
  bool get isProcessing => _isProcessing;

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kQueueKey);
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        _queue.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _queue.add(UploadItemModel.fromJson(item));
          }
        }
        notifyListeners();
      }
    } catch (e) {
      dev.log('Error loading upload queue: $e');
    }
  }

  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_queue.map((item) => item.toJson()).toList());
      await prefs.setString(_kQueueKey, encoded);
    } catch (e) {
      dev.log('Error persisting upload queue: $e');
    }
  }

  /// Enqueue a file for upload
  Future<UploadItemModel> enqueueUpload({
    required String filePath,
    required String destinationEndpoint,
    required String description,
    Map<String, dynamic> extraData = const {},
  }) async {
    final fileName = filePath.split('/').last.split('\\').last;
    final item = UploadItemModel(
      id: 'upl_${DateTime.now().millisecondsSinceEpoch}_${_queue.length}',
      filePath: filePath,
      fileName: fileName,
      destinationEndpoint: destinationEndpoint,
      description: description,
      status: UploadStatus.pending,
      progress: 0.0,
      createdAt: DateTime.now(),
      extraData: extraData,
    );

    _queue.insert(0, item);
    await _persistQueue();
    notifyListeners();

    // Auto-process queue in background
    processQueue();
    return item;
  }

  /// Cancel an ongoing or pending upload
  void cancelUpload(String id) {
    _cancelledTaskIds.add(id);
    final idx = _queue.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _queue[idx] = _queue[idx].copyWith(
        status: UploadStatus.cancelled,
        errorMessage: 'Upload cancelled by user',
      );
      _persistQueue();
      notifyListeners();
    }
  }

  /// Retry a failed or cancelled upload
  Future<void> retryUpload(String id) async {
    final idx = _queue.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _cancelledTaskIds.remove(id);
      _queue[idx] = _queue[idx].copyWith(
        status: UploadStatus.pending,
        progress: 0.0,
        errorMessage: null,
      );
      await _persistQueue();
      notifyListeners();
      processQueue();
    }
  }

  /// Clear all completed or cancelled uploads
  Future<void> clearCompleted() async {
    _queue.removeWhere((i) => i.status == UploadStatus.completed || i.status == UploadStatus.cancelled);
    await _persistQueue();
    notifyListeners();
  }

  /// Uploads pending files one by one; failures stay queued for retry.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    try {
      for (int i = 0; i < _queue.length; i++) {
        final item = _queue[i];
        if (item.status != UploadStatus.pending) continue;

        if (_cancelledTaskIds.contains(item.id)) {
          _queue[i] = item.copyWith(status: UploadStatus.cancelled);
          continue;
        }

        // Mark uploading
        _queue[i] = item.copyWith(status: UploadStatus.uploading, progress: 0.1);
        notifyListeners();

        try {
          // Real multipart upload of the file itself, with byte-level progress.
          final form = FormData.fromMap({
            ...item.extraData,
            'file': await MultipartFile.fromFile(item.filePath, filename: item.fileName),
          });
          await _apiClient.dio.post(
            item.destinationEndpoint,
            data: form,
            onSendProgress: (sent, total) {
              if (total <= 0) return;
              _queue[i] = _queue[i].copyWith(progress: (sent / total).clamp(0.0, 0.99));
              notifyListeners();
            },
          );
          _queue[i] = _queue[i].copyWith(
            status: UploadStatus.completed,
            progress: 1.0,
            completedAt: DateTime.now(),
          );
        } catch (e) {
          // Stays in the queue as failed so the user can retry; never reported as done.
          _queue[i] = _queue[i].copyWith(
            status: UploadStatus.failed,
            errorMessage: ApiClient.toFriendly(e, fallback: 'Upload failed. Check your connection and retry.')
                .toString()
                .replaceFirst('Exception: ', ''),
          );
        }

        await _persistQueue();
        notifyListeners();
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
