import 'package:flutter/material.dart';

enum KedlFileType {
  nameChange,
  loadIncrease,
  net;

  static KedlFileType fromBackendString(String? val) {
    final clean = val?.trim().toLowerCase() ?? '';
    switch (clean) {
      case 'name_change':
      case 'namechange':
        return KedlFileType.nameChange;
      case 'load':
      case 'load_increase':
      case 'loadincrease':
        return KedlFileType.loadIncrease;
      case 'net':
      case 'net_metering':
      default:
        return KedlFileType.net;
    }
  }

  String toBackendString() {
    switch (this) {
      case KedlFileType.nameChange:
        return 'name_change';
      case KedlFileType.loadIncrease:
        return 'load';
      case KedlFileType.net:
        return 'net';
    }
  }

  String get displayName {
    switch (this) {
      case KedlFileType.nameChange:
        return 'Name Change';
      case KedlFileType.loadIncrease:
        return 'Load Increase';
      case KedlFileType.net:
        return 'Net Metering';
    }
  }

  IconData get icon {
    switch (this) {
      case KedlFileType.nameChange:
        return Icons.badge_outlined;
      case KedlFileType.loadIncrease:
        return Icons.speed_rounded;
      case KedlFileType.net:
        return Icons.grid_goldenratio_rounded;
    }
  }

  Color get color {
    switch (this) {
      case KedlFileType.nameChange:
        return const Color(0xFF38BDF8); // Sky blue
      case KedlFileType.loadIncrease:
        return const Color(0xFFF7A21B); // Amber / Gold
      case KedlFileType.net:
        return const Color(0xFF10B981); // Emerald / Teal
    }
  }
}

enum KedlFileStatus {
  notStarted,
  submitted,
  demandRaised,
  demandPaid,
  approved,
  rejected;

  static KedlFileStatus fromBackendString(String? val) {
    final clean = val?.trim().toLowerCase() ?? '';
    switch (clean) {
      case 'submitted':
        return KedlFileStatus.submitted;
      case 'demand_raised':
      case 'demandraised':
        return KedlFileStatus.demandRaised;
      case 'demand_paid':
      case 'demandpaid':
        return KedlFileStatus.demandPaid;
      case 'approved':
        return KedlFileStatus.approved;
      case 'rejected':
        return KedlFileStatus.rejected;
      case 'not_started':
      default:
        return KedlFileStatus.notStarted;
    }
  }

  String toBackendString() {
    switch (this) {
      case KedlFileStatus.notStarted:
        return 'not_started';
      case KedlFileStatus.submitted:
        return 'submitted';
      case KedlFileStatus.demandRaised:
        return 'demand_raised';
      case KedlFileStatus.demandPaid:
        return 'demand_paid';
      case KedlFileStatus.approved:
        return 'approved';
      case KedlFileStatus.rejected:
        return 'rejected';
    }
  }

  String get displayName {
    switch (this) {
      case KedlFileStatus.notStarted:
        return 'Not Started';
      case KedlFileStatus.submitted:
        return 'Submitted';
      case KedlFileStatus.demandRaised:
        return 'Demand Raised';
      case KedlFileStatus.demandPaid:
        return 'Demand Paid';
      case KedlFileStatus.approved:
        return 'Approved';
      case KedlFileStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case KedlFileStatus.notStarted:
        return const Color(0xFF6C6596); // Slate
      case KedlFileStatus.submitted:
        return const Color(0xFF38BDF8); // Sky
      case KedlFileStatus.demandRaised:
        return const Color(0xFFF7A21B); // Amber
      case KedlFileStatus.demandPaid:
        return const Color(0xFF8B5CF6); // Violet
      case KedlFileStatus.approved:
        return const Color(0xFF10B981); // Emerald
      case KedlFileStatus.rejected:
        return const Color(0xFFEF4444); // Red
    }
  }

  int get stepIndex {
    switch (this) {
      case KedlFileStatus.notStarted:
        return 0;
      case KedlFileStatus.submitted:
        return 1;
      case KedlFileStatus.demandRaised:
        return 2;
      case KedlFileStatus.demandPaid:
        return 3;
      case KedlFileStatus.approved:
        return 4;
      case KedlFileStatus.rejected:
        return 4;
    }
  }
}

enum KedlDemandStatus {
  open,
  paid,
  waived;

  static KedlDemandStatus fromBackendString(String? val) {
    final clean = val?.trim().toLowerCase() ?? '';
    switch (clean) {
      case 'paid':
        return KedlDemandStatus.paid;
      case 'waived':
        return KedlDemandStatus.waived;
      case 'open':
      default:
        return KedlDemandStatus.open;
    }
  }

  String toBackendString() {
    switch (this) {
      case KedlDemandStatus.open:
        return 'open';
      case KedlDemandStatus.paid:
        return 'paid';
      case KedlDemandStatus.waived:
        return 'waived';
    }
  }

  String get displayName {
    switch (this) {
      case KedlDemandStatus.open:
        return 'Open';
      case KedlDemandStatus.paid:
        return 'Paid';
      case KedlDemandStatus.waived:
        return 'Waived';
    }
  }

  Color get color {
    switch (this) {
      case KedlDemandStatus.open:
        return const Color(0xFFF7A21B); // Amber
      case KedlDemandStatus.paid:
        return const Color(0xFF10B981); // Emerald
      case KedlDemandStatus.waived:
        return const Color(0xFF6C6596); // Slate
    }
  }
}

/// Represents a Discom demand / fee requirement.
/// Money values strictly stored as integer paise.
class KedlDemandModel {
  final String id;
  final String kedlFileId;
  final String customerName;
  final String description;
  final int? amountPaise;
  final DateTime? dueDate;
  final KedlDemandStatus status;
  final DateTime? paidOn;
  final String? receiptKey;
  final String? receiptUrl;
  final DateTime raisedOn;
  final String? raisedBy;

  const KedlDemandModel({
    required this.id,
    required this.kedlFileId,
    this.customerName = 'Customer',
    required this.description,
    this.amountPaise,
    this.dueDate,
    required this.status,
    this.paidOn,
    this.receiptKey,
    this.receiptUrl,
    required this.raisedOn,
    this.raisedBy,
  });

  bool get isOverdue {
    if (status != KedlDemandStatus.open) return false;
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  double get amountRupees => (amountPaise ?? 0) / 100.0;

  factory KedlDemandModel.fromJson(Map<String, dynamic> json, {String? defaultCustomerName}) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      return DateTime.tryParse(d.toString());
    }

    return KedlDemandModel(
      id: json['id']?.toString() ?? '',
      kedlFileId: json['kedl_file_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? (defaultCustomerName ?? 'Customer'),
      description: json['description']?.toString() ?? '',
      amountPaise: json['amount'] as int? ?? json['amount_paise'] as int?,
      dueDate: parseDate(json['due_date']),
      status: KedlDemandStatus.fromBackendString(json['status']?.toString()),
      paidOn: parseDate(json['paid_on']),
      receiptKey: json['receipt_key']?.toString(),
      receiptUrl: json['receipt_url']?.toString(),
      raisedOn: parseDate(json['raised_on']) ?? parseDate(json['created_at']) ?? DateTime.now(),
      raisedBy: json['raised_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kedl_file_id': kedlFileId,
        'customer_name': customerName,
        'description': description,
        if (amountPaise != null) 'amount': amountPaise,
        if (dueDate != null) 'due_date': dueDate!.toIso8601String().split('T').first,
        'status': status.toBackendString(),
        if (paidOn != null) 'paid_on': paidOn!.toIso8601String(),
        if (receiptKey != null) 'receipt_key': receiptKey,
        if (receiptUrl != null) 'receipt_url': receiptUrl,
        'raised_on': raisedOn.toIso8601String(),
        if (raisedBy != null) 'raised_by': raisedBy,
      };

  KedlDemandModel copyWith({
    KedlDemandStatus? status,
    DateTime? paidOn,
    String? receiptKey,
    String? receiptUrl,
  }) {
    return KedlDemandModel(
      id: id,
      kedlFileId: kedlFileId,
      customerName: customerName,
      description: description,
      amountPaise: amountPaise,
      dueDate: dueDate,
      status: status ?? this.status,
      paidOn: paidOn ?? this.paidOn,
      receiptKey: receiptKey ?? this.receiptKey,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      raisedOn: raisedOn,
      raisedBy: raisedBy,
    );
  }
}

class KedlDocumentModel {
  final String id;
  final String kedlFileId;
  final String docType;
  final String fileKey;
  final String originalName;
  final String? downloadUrl;
  final DateTime createdAt;

  const KedlDocumentModel({
    required this.id,
    required this.kedlFileId,
    required this.docType,
    required this.fileKey,
    required this.originalName,
    this.downloadUrl,
    required this.createdAt,
  });

  factory KedlDocumentModel.fromJson(Map<String, dynamic> json) {
    return KedlDocumentModel(
      id: json['id']?.toString() ?? '',
      kedlFileId: json['kedl_file_id']?.toString() ?? '',
      docType: json['doc_type']?.toString() ?? 'other',
      fileKey: json['file_key']?.toString() ?? '',
      originalName: json['original_name']?.toString() ?? 'Document',
      downloadUrl: json['download_url']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kedl_file_id': kedlFileId,
        'doc_type': docType,
        'file_key': fileKey,
        'original_name': originalName,
        if (downloadUrl != null) 'download_url': downloadUrl,
        'created_at': createdAt.toIso8601String(),
      };
}

class KedlStatusLogModel {
  final String id;
  final String kedlFileId;
  final KedlFileStatus? fromStatus;
  final KedlFileStatus toStatus;
  final String? note;
  final DateTime createdAt;

  const KedlStatusLogModel({
    required this.id,
    required this.kedlFileId,
    this.fromStatus,
    required this.toStatus,
    this.note,
    required this.createdAt,
  });

  factory KedlStatusLogModel.fromJson(Map<String, dynamic> json) {
    return KedlStatusLogModel(
      id: json['id']?.toString() ?? '',
      kedlFileId: json['kedl_file_id']?.toString() ?? '',
      fromStatus: json['from_status'] != null
          ? KedlFileStatus.fromBackendString(json['from_status'].toString())
          : null,
      toStatus: KedlFileStatus.fromBackendString(json['to_status']?.toString()),
      note: json['note']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class KedlFileModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final KedlFileType fileType;
  final KedlFileStatus status;
  final String? applicationNo;
  final DateTime? submittedOn;
  final DateTime? approvedOn;
  final String? assignedTo;
  final String? remarks;
  final List<KedlDemandModel> demands;
  final List<KedlDocumentModel> documents;
  final List<KedlStatusLogModel> statusLogs;

  const KedlFileModel({
    required this.id,
    required this.customerId,
    this.customerName = 'Customer',
    this.customerPhone = '',
    this.customerAddress = '',
    required this.fileType,
    required this.status,
    this.applicationNo,
    this.submittedOn,
    this.approvedOn,
    this.assignedTo,
    this.remarks,
    this.demands = const [],
    this.documents = const [],
    this.statusLogs = const [],
  });

  bool get hasOpenDemand => demands.any((d) => d.status == KedlDemandStatus.open);
  bool get hasOverdueDemand => demands.any((d) => d.isOverdue);

  factory KedlFileModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      return DateTime.tryParse(d.toString());
    }

    final custName = json['customer_name']?.toString() ?? 'Customer';

    final rawDemands = json['demands'];
    List<KedlDemandModel> demandsList = [];
    if (rawDemands is List) {
      demandsList = rawDemands
          .whereType<Map<String, dynamic>>()
          .map((d) => KedlDemandModel.fromJson(d, defaultCustomerName: custName))
          .toList();
    }

    final rawDocs = json['documents'];
    List<KedlDocumentModel> docsList = [];
    if (rawDocs is List) {
      docsList = rawDocs
          .whereType<Map<String, dynamic>>()
          .map((d) => KedlDocumentModel.fromJson(d))
          .toList();
    }

    final rawLogs = json['status_logs'];
    List<KedlStatusLogModel> logsList = [];
    if (rawLogs is List) {
      logsList = rawLogs
          .whereType<Map<String, dynamic>>()
          .map((l) => KedlStatusLogModel.fromJson(l))
          .toList();
    }

    return KedlFileModel(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: custName,
      customerPhone: json['customer_phone']?.toString() ?? '',
      customerAddress: json['customer_address']?.toString() ?? '',
      fileType: KedlFileType.fromBackendString(json['file_type']?.toString()),
      status: KedlFileStatus.fromBackendString(json['status']?.toString()),
      applicationNo: json['application_no']?.toString(),
      submittedOn: parseDate(json['submitted_on']),
      approvedOn: parseDate(json['approved_on']),
      assignedTo: json['assigned_to']?.toString(),
      remarks: json['remarks']?.toString(),
      demands: demandsList,
      documents: docsList,
      statusLogs: logsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_address': customerAddress,
        'file_type': fileType.toBackendString(),
        'status': status.toBackendString(),
        if (applicationNo != null) 'application_no': applicationNo,
        if (submittedOn != null) 'submitted_on': submittedOn!.toIso8601String(),
        if (approvedOn != null) 'approved_on': approvedOn!.toIso8601String(),
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (remarks != null) 'remarks': remarks,
        'demands': demands.map((d) => d.toJson()).toList(),
        'documents': documents.map((d) => d.toJson()).toList(),
      };

  KedlFileModel copyWith({
    KedlFileStatus? status,
    String? applicationNo,
    DateTime? submittedOn,
    DateTime? approvedOn,
    String? remarks,
    List<KedlDemandModel>? demands,
    List<KedlDocumentModel>? documents,
    List<KedlStatusLogModel>? statusLogs,
  }) {
    return KedlFileModel(
      id: id,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      fileType: fileType,
      status: status ?? this.status,
      applicationNo: applicationNo ?? this.applicationNo,
      submittedOn: submittedOn ?? this.submittedOn,
      approvedOn: approvedOn ?? this.approvedOn,
      assignedTo: assignedTo,
      remarks: remarks ?? this.remarks,
      demands: demands ?? this.demands,
      documents: documents ?? this.documents,
      statusLogs: statusLogs ?? this.statusLogs,
    );
  }
}

class KedlCustomerGroupModel {
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final List<KedlFileModel> files;

  const KedlCustomerGroupModel({
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.files,
  });

  bool get hasOpenDemand => files.any((f) => f.hasOpenDemand);
  bool get hasOverdueDemand => files.any((f) => f.hasOverdueDemand);
}

class KedlDashboardMetricsModel {
  final int totalFiles;
  final Map<String, int> byFileType;
  final Map<String, int> byStatus;
  final int openDemandsCount;
  final int overdueDemandsCount;

  const KedlDashboardMetricsModel({
    required this.totalFiles,
    required this.byFileType,
    required this.byStatus,
    required this.openDemandsCount,
    required this.overdueDemandsCount,
  });

  factory KedlDashboardMetricsModel.fromJson(Map<String, dynamic> json) {
    Map<String, int> parseMap(dynamic m) {
      if (m is Map) {
        return m.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
      return {};
    }

    return KedlDashboardMetricsModel(
      totalFiles: json['total_files'] as int? ?? 0,
      byFileType: parseMap(json['by_file_type']),
      byStatus: parseMap(json['by_status']),
      openDemandsCount: json['open_demands_count'] as int? ?? 0,
      overdueDemandsCount: json['overdue_demands_count'] as int? ?? 0,
    );
  }
}
