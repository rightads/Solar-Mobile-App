import 'package:flutter/material.dart';

enum WorkType {
  structure,
  electrical,
  civil;

  static WorkType fromString(String? val) {
    final clean = val?.trim().toLowerCase() ?? '';
    switch (clean) {
      case 'structure':
        return WorkType.structure;
      case 'electrical':
      case 'electrician':
        return WorkType.electrical;
      case 'civil':
        return WorkType.civil;
      default:
        return WorkType.structure;
    }
  }

  String toBackendString() {
    switch (this) {
      case WorkType.structure:
        return 'structure';
      case WorkType.electrical:
        return 'electrical';
      case WorkType.civil:
        return 'civil';
    }
  }

  String get displayName {
    switch (this) {
      case WorkType.structure:
        return 'Structure';
      case WorkType.electrical:
        return 'Electrical';
      case WorkType.civil:
        return 'Civil';
    }
  }

  IconData get icon {
    switch (this) {
      case WorkType.structure:
        return Icons.foundation_rounded;
      case WorkType.electrical:
        return Icons.electric_bolt_rounded;
      case WorkType.civil:
        return Icons.handyman_rounded;
    }
  }

  Color get color {
    switch (this) {
      case WorkType.structure:
        return const Color(0xFF38BDF8); // sky
      case WorkType.electrical:
        return const Color(0xFFF7A21B); // gold / amber
      case WorkType.civil:
        return const Color(0xFF10B981); // emerald / teal
    }
  }
}

enum WorkStatus {
  pending,
  inProgress,
  completed,
  cancelled;

  static WorkStatus fromString(String? val) {
    final clean = val?.trim().toLowerCase() ?? '';
    switch (clean) {
      case 'in_progress':
      case 'inprogress':
        return WorkStatus.inProgress;
      case 'completed':
        return WorkStatus.completed;
      case 'cancelled':
      case 'canceled':
        return WorkStatus.cancelled;
      case 'pending':
      default:
        return WorkStatus.pending;
    }
  }

  String toBackendString() {
    switch (this) {
      case WorkStatus.pending:
        return 'pending';
      case WorkStatus.inProgress:
        return 'in_progress';
      case WorkStatus.completed:
        return 'completed';
      case WorkStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayName {
    switch (this) {
      case WorkStatus.pending:
        return 'Pending';
      case WorkStatus.inProgress:
        return 'In Progress';
      case WorkStatus.completed:
        return 'Completed';
      case WorkStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case WorkStatus.pending:
        return const Color(0xFF6C6596); // Slate 400
      case WorkStatus.inProgress:
        return const Color(0xFFF7A21B); // Amber / Gold
      case WorkStatus.completed:
        return const Color(0xFF10B981); // Emerald / Green
      case WorkStatus.cancelled:
        return const Color(0xFFEF4444); // Red
    }
  }
}

/// Short customer info for site labour workers.
/// IMPORTANT: Strictly limited to name, mobile, address, and coordinates.
/// No financial information, pricing, or customer documents are present here.
class CustomerShortForLabourModel {
  final String id;
  final String name;
  final String mobile;
  final String address;
  final double? latitude;
  final double? longitude;

  const CustomerShortForLabourModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory CustomerShortForLabourModel.fromJson(Map<String, dynamic> json) {
    return CustomerShortForLabourModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Customer',
      mobile: json['mobile']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'address': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

class WorkPhotoModel {
  final String id;
  final String workAssignmentId;
  final String fileKey;
  final String? caption;
  final String? uploadedBy;
  final String? downloadUrl;
  final DateTime createdAt;
  final bool isLocal;
  final String? localFilePath;

  const WorkPhotoModel({
    required this.id,
    required this.workAssignmentId,
    required this.fileKey,
    this.caption,
    this.uploadedBy,
    this.downloadUrl,
    required this.createdAt,
    this.isLocal = false,
    this.localFilePath,
  });

  factory WorkPhotoModel.fromJson(Map<String, dynamic> json) {
    return WorkPhotoModel(
      id: json['id']?.toString() ?? '',
      workAssignmentId: json['work_assignment_id']?.toString() ?? '',
      fileKey: json['file_key']?.toString() ?? '',
      caption: json['caption']?.toString(),
      uploadedBy: json['uploaded_by']?.toString(),
      downloadUrl: json['download_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isLocal: json['is_local'] == true,
      localFilePath: json['local_file_path']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'work_assignment_id': workAssignmentId,
        'file_key': fileKey,
        if (caption != null) 'caption': caption,
        if (uploadedBy != null) 'uploaded_by': uploadedBy,
        if (downloadUrl != null) 'download_url': downloadUrl,
        'created_at': createdAt.toIso8601String(),
        'is_local': isLocal,
        if (localFilePath != null) 'local_file_path': localFilePath,
      };
}

class WorkStatusLogModel {
  final String id;
  final String workAssignmentId;
  final WorkStatus? fromStatus;
  final WorkStatus toStatus;
  final String? changedBy;
  final String? note;
  final DateTime createdAt;

  const WorkStatusLogModel({
    required this.id,
    required this.workAssignmentId,
    this.fromStatus,
    required this.toStatus,
    this.changedBy,
    this.note,
    required this.createdAt,
  });

  factory WorkStatusLogModel.fromJson(Map<String, dynamic> json) {
    return WorkStatusLogModel(
      id: json['id']?.toString() ?? '',
      workAssignmentId: json['work_assignment_id']?.toString() ?? '',
      fromStatus: json['from_status'] != null
          ? WorkStatus.fromString(json['from_status'].toString())
          : null,
      toStatus: WorkStatus.fromString(json['to_status']?.toString()),
      changedBy: json['changed_by']?.toString(),
      note: json['note']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class WorkAssignmentModel {
  final String id;
  final String customerId;
  final WorkType workType;
  final String teamId;
  final String? teamName;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final WorkStatus status;
  final String? notes;
  final CustomerShortForLabourModel? customer;
  final List<WorkPhotoModel> photos;
  final List<WorkStatusLogModel> statusLogs;
  final bool isPendingSync;

  const WorkAssignmentModel({
    required this.id,
    required this.customerId,
    required this.workType,
    required this.teamId,
    this.teamName,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.actualStart,
    this.actualEnd,
    required this.status,
    this.notes,
    this.customer,
    this.photos = const [],
    this.statusLogs = const [],
    this.isPendingSync = false,
  });

  factory WorkAssignmentModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      return DateTime.tryParse(d.toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic d) {
      if (d == null) return null;
      return DateTime.tryParse(d.toString());
    }

    final rawCustomer = json['customer'];
    CustomerShortForLabourModel? customerModel;
    if (rawCustomer is Map<String, dynamic>) {
      customerModel = CustomerShortForLabourModel.fromJson(rawCustomer);
    } else if (json['customer_name'] != null) {
      customerModel = CustomerShortForLabourModel(
        id: json['customer_id']?.toString() ?? '',
        name: json['customer_name']?.toString() ?? 'Customer',
        mobile: json['customer_mobile']?.toString() ?? '',
        address: json['customer_address']?.toString() ?? '',
      );
    }

    final rawTeam = json['team'];
    String? teamName;
    if (rawTeam is Map<String, dynamic>) {
      teamName = rawTeam['name']?.toString();
    } else if (json['team_name'] != null) {
      teamName = json['team_name']?.toString();
    }

    final rawPhotos = json['photos'];
    List<WorkPhotoModel> photosList = [];
    if (rawPhotos is List) {
      photosList = rawPhotos
          .whereType<Map<String, dynamic>>()
          .map((p) => WorkPhotoModel.fromJson(p))
          .toList();
    }

    final rawLogs = json['status_logs'];
    List<WorkStatusLogModel> logsList = [];
    if (rawLogs is List) {
      logsList = rawLogs
          .whereType<Map<String, dynamic>>()
          .map((l) => WorkStatusLogModel.fromJson(l))
          .toList();
    }

    return WorkAssignmentModel(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      workType: WorkType.fromString(json['work_type']?.toString()),
      teamId: json['team_id']?.toString() ?? '',
      teamName: teamName,
      scheduledStart: parseDate(json['scheduled_start']),
      scheduledEnd: parseDate(json['scheduled_end']),
      actualStart: parseNullableDate(json['actual_start']),
      actualEnd: parseNullableDate(json['actual_end']),
      status: WorkStatus.fromString(json['status']?.toString()),
      notes: json['notes']?.toString(),
      customer: customerModel,
      photos: photosList,
      statusLogs: logsList,
      isPendingSync: json['is_pending_sync'] == true,
    );
  }

  WorkAssignmentModel copyWith({
    String? id,
    String? customerId,
    WorkType? workType,
    String? teamId,
    String? teamName,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    DateTime? actualStart,
    DateTime? actualEnd,
    WorkStatus? status,
    String? notes,
    CustomerShortForLabourModel? customer,
    List<WorkPhotoModel>? photos,
    List<WorkStatusLogModel>? statusLogs,
    bool? isPendingSync,
  }) {
    return WorkAssignmentModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      workType: workType ?? this.workType,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      customer: customer ?? this.customer,
      photos: photos ?? this.photos,
      statusLogs: statusLogs ?? this.statusLogs,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'work_type': workType.toBackendString(),
        'team_id': teamId,
        if (teamName != null) 'team_name': teamName,
        'scheduled_start': scheduledStart.toIso8601String().split('T').first,
        'scheduled_end': scheduledEnd.toIso8601String().split('T').first,
        if (actualStart != null) 'actual_start': actualStart!.toIso8601String(),
        if (actualEnd != null) 'actual_end': actualEnd!.toIso8601String(),
        'status': status.toBackendString(),
        if (notes != null) 'notes': notes,
        if (customer != null) 'customer': customer!.toJson(),
        'photos': photos.map((p) => p.toJson()).toList(),
        'is_pending_sync': isPendingSync,
      };
}

class CalendarScheduleItemModel {
  final String assignmentId;
  final String customerId;
  final String customerName;
  final String customerAddress;
  final WorkType workType;
  final String teamId;
  final String teamName;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final WorkStatus status;

  const CalendarScheduleItemModel({
    required this.assignmentId,
    required this.customerId,
    required this.customerName,
    required this.customerAddress,
    required this.workType,
    required this.teamId,
    required this.teamName,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.status,
  });

  factory CalendarScheduleItemModel.fromJson(Map<String, dynamic> json) {
    return CalendarScheduleItemModel(
      assignmentId: json['assignment_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Customer',
      customerAddress: json['customer_address']?.toString() ?? '',
      workType: WorkType.fromString(json['work_type']?.toString()),
      teamId: json['team_id']?.toString() ?? '',
      teamName: json['team_name']?.toString() ?? '',
      scheduledStart: DateTime.tryParse(json['scheduled_start']?.toString() ?? '') ?? DateTime.now(),
      scheduledEnd: DateTime.tryParse(json['scheduled_end']?.toString() ?? '') ?? DateTime.now(),
      status: WorkStatus.fromString(json['status']?.toString()),
    );
  }
}

class CalendarScheduleModel {
  final DateTime fromDate;
  final DateTime toDate;
  final int totalAssignments;
  final Map<String, List<CalendarScheduleItemModel>> byDate;
  final Map<String, List<CalendarScheduleItemModel>> byTeam;

  const CalendarScheduleModel({
    required this.fromDate,
    required this.toDate,
    required this.totalAssignments,
    required this.byDate,
    required this.byTeam,
  });

  factory CalendarScheduleModel.fromJson(Map<String, dynamic> json) {
    final rawByDate = json['by_date'];
    final Map<String, List<CalendarScheduleItemModel>> byDateMap = {};
    if (rawByDate is Map<String, dynamic>) {
      rawByDate.forEach((key, val) {
        if (val is List) {
          byDateMap[key] = val
              .whereType<Map<String, dynamic>>()
              .map((item) => CalendarScheduleItemModel.fromJson(item))
              .toList();
        }
      });
    }

    final rawByTeam = json['by_team'];
    final Map<String, List<CalendarScheduleItemModel>> byTeamMap = {};
    if (rawByTeam is Map<String, dynamic>) {
      rawByTeam.forEach((key, val) {
        if (val is List) {
          byTeamMap[key] = val
              .whereType<Map<String, dynamic>>()
              .map((item) => CalendarScheduleItemModel.fromJson(item))
              .toList();
        }
      });
    }

    return CalendarScheduleModel(
      fromDate: DateTime.tryParse(json['from_date']?.toString() ?? '') ?? DateTime.now(),
      toDate: DateTime.tryParse(json['to_date']?.toString() ?? '') ?? DateTime.now(),
      totalAssignments: json['total_assignments'] as int? ?? 0,
      byDate: byDateMap,
      byTeam: byTeamMap,
    );
  }
}
