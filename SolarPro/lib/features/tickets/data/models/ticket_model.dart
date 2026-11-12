import 'package:flutter/material.dart';

enum TicketType {
  structure,
  wiring,
  inverter;

  static TicketType fromBackendString(String? val) {
    final clean = val?.trim().toLowerCase() ?? '';
    switch (clean) {
      case 'structure':
        return TicketType.structure;
      case 'wiring':
        return TicketType.wiring;
      case 'inverter':
      default:
        return TicketType.inverter;
    }
  }

  String toBackendString() {
    switch (this) {
      case TicketType.structure:
        return 'structure';
      case TicketType.wiring:
        return 'wiring';
      case TicketType.inverter:
        return 'inverter';
    }
  }

  String get displayName {
    switch (this) {
      case TicketType.structure:
        return 'Structure Issue';
      case TicketType.wiring:
        return 'Wiring Issue';
      case TicketType.inverter:
        return 'Inverter Fault';
    }
  }

  IconData get icon {
    switch (this) {
      case TicketType.structure:
        return Icons.foundation_rounded;
      case TicketType.wiring:
        return Icons.cable_rounded;
      case TicketType.inverter:
        return Icons.electric_bolt_rounded;
    }
  }

  Color get color {
    switch (this) {
      case TicketType.structure:
        return const Color(0xFF38BDF8); // Sky
      case TicketType.wiring:
        return const Color(0xFFF7A21B); // Amber
      case TicketType.inverter:
        return const Color(0xFFEF4444); // Red
    }
  }
}

enum TicketStatus {
  open,
  assigned,
  inProgress,
  resolved,
  closed,
  reopened;

  static TicketStatus fromBackendString(String? val) {
    final clean = val?.trim().toLowerCase() ?? '';
    switch (clean) {
      case 'assigned':
        return TicketStatus.assigned;
      case 'in_progress':
      case 'inprogress':
        return TicketStatus.inProgress;
      case 'resolved':
        return TicketStatus.resolved;
      case 'closed':
        return TicketStatus.closed;
      case 'reopened':
        return TicketStatus.reopened;
      case 'open':
      default:
        return TicketStatus.open;
    }
  }

  String toBackendString() {
    switch (this) {
      case TicketStatus.open:
        return 'open';
      case TicketStatus.assigned:
        return 'assigned';
      case TicketStatus.inProgress:
        return 'in_progress';
      case TicketStatus.resolved:
        return 'resolved';
      case TicketStatus.closed:
        return 'closed';
      case TicketStatus.reopened:
        return 'reopened';
    }
  }

  String get displayName {
    switch (this) {
      case TicketStatus.open:
        return 'Open';
      case TicketStatus.assigned:
        return 'Assigned';
      case TicketStatus.inProgress:
        return 'In Progress';
      case TicketStatus.resolved:
        return 'Resolved';
      case TicketStatus.closed:
        return 'Closed';
      case TicketStatus.reopened:
        return 'Reopened';
    }
  }

  Color get color {
    switch (this) {
      case TicketStatus.open:
        return const Color(0xFFF7A21B); // Amber
      case TicketStatus.assigned:
        return const Color(0xFF38BDF8); // Sky
      case TicketStatus.inProgress:
        return const Color(0xFF8B5CF6); // Violet
      case TicketStatus.resolved:
        return const Color(0xFF10B981); // Emerald
      case TicketStatus.closed:
        return const Color(0xFF8A84AE); // Slate
      case TicketStatus.reopened:
        return const Color(0xFFEF4444); // Red
    }
  }
}

enum TicketPriority {
  low,
  normal,
  high,
  urgent;

  static TicketPriority fromBackendString(String? val) {
    final clean = val?.trim().toLowerCase() ?? '';
    switch (clean) {
      case 'low':
        return TicketPriority.low;
      case 'high':
        return TicketPriority.high;
      case 'urgent':
        return TicketPriority.urgent;
      case 'normal':
      default:
        return TicketPriority.normal;
    }
  }

  String toBackendString() {
    switch (this) {
      case TicketPriority.low:
        return 'low';
      case TicketPriority.normal:
        return 'normal';
      case TicketPriority.high:
        return 'high';
      case TicketPriority.urgent:
        return 'urgent';
    }
  }

  String get displayName {
    switch (this) {
      case TicketPriority.low:
        return 'Low';
      case TicketPriority.normal:
        return 'Normal';
      case TicketPriority.high:
        return 'High';
      case TicketPriority.urgent:
        return 'Urgent';
    }
  }

  Color get color {
    switch (this) {
      case TicketPriority.low:
        return const Color(0xFF6C6596);
      case TicketPriority.normal:
        return const Color(0xFF38BDF8);
      case TicketPriority.high:
        return const Color(0xFFF7A21B);
      case TicketPriority.urgent:
        return const Color(0xFFEF4444);
    }
  }
}

class TicketImageModel {
  final String id;
  final String ticketId;
  final String fileKey;
  final String? downloadUrl;
  final String? uploadedBy;
  final DateTime createdAt;

  const TicketImageModel({
    required this.id,
    required this.ticketId,
    required this.fileKey,
    this.downloadUrl,
    this.uploadedBy,
    required this.createdAt,
  });

  factory TicketImageModel.fromJson(Map<String, dynamic> json) {
    return TicketImageModel(
      id: json['id']?.toString() ?? '',
      ticketId: json['ticket_id']?.toString() ?? '',
      fileKey: json['file_key']?.toString() ?? '',
      downloadUrl: json['download_url']?.toString(),
      uploadedBy: json['uploaded_by']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticket_id': ticketId,
        'file_key': fileKey,
        if (downloadUrl != null) 'download_url': downloadUrl,
        if (uploadedBy != null) 'uploaded_by': uploadedBy,
        'created_at': createdAt.toIso8601String(),
      };
}

class TicketCommentModel {
  final String id;
  final String ticketId;
  final String? authorId;
  final String authorName;
  final String authorRole;
  final String message;
  final DateTime createdAt;

  const TicketCommentModel({
    required this.id,
    required this.ticketId,
    this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.message,
    required this.createdAt,
  });

  factory TicketCommentModel.fromJson(Map<String, dynamic> json) {
    return TicketCommentModel(
      id: json['id']?.toString() ?? '',
      ticketId: json['ticket_id']?.toString() ?? '',
      authorId: json['author_id']?.toString(),
      authorName: json['author_name']?.toString() ?? (json['author']?['name']?.toString() ?? 'Support Staff'),
      authorRole: json['author_role']?.toString() ?? (json['author']?['role']?.toString() ?? 'staff'),
      message: json['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticket_id': ticketId,
        if (authorId != null) 'author_id': authorId,
        'author_name': authorName,
        'author_role': authorRole,
        'message': message,
        'created_at': createdAt.toIso8601String(),
      };
}

class TicketModel {
  final String id;
  final String ticketNo;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final TicketType type;
  final String title;
  final String description;
  final String? errorCode;
  final TicketStatus status;
  final TicketPriority priority;
  final String? assignedTo;
  final String? assigneeName;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TicketImageModel> images;
  final List<TicketCommentModel> comments;

  const TicketModel({
    required this.id,
    required this.ticketNo,
    required this.customerId,
    this.customerName = 'Customer',
    this.customerPhone = '',
    this.customerAddress = '',
    required this.type,
    required this.title,
    required this.description,
    this.errorCode,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.assigneeName,
    this.resolvedAt,
    this.resolutionNote,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
    this.comments = const [],
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      return DateTime.tryParse(d.toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic d) {
      if (d == null) return null;
      return DateTime.tryParse(d.toString());
    }

    final rawCust = json['customer'];
    String name = json['customer_name']?.toString() ?? 'Customer';
    String phone = json['customer_phone']?.toString() ?? '';
    String address = json['customer_address']?.toString() ?? '';

    if (rawCust is Map<String, dynamic>) {
      name = rawCust['name']?.toString() ?? name;
      phone = rawCust['mobile']?.toString() ?? phone;
      address = rawCust['address']?.toString() ?? address;
    }

    final rawImages = json['images'];
    List<TicketImageModel> imagesList = [];
    if (rawImages is List) {
      imagesList = rawImages
          .whereType<Map<String, dynamic>>()
          .map((img) => TicketImageModel.fromJson(img))
          .toList();
    }

    final rawComments = json['comments'];
    List<TicketCommentModel> commentsList = [];
    if (rawComments is List) {
      commentsList = rawComments
          .whereType<Map<String, dynamic>>()
          .map((c) => TicketCommentModel.fromJson(c))
          .toList();
    }

    return TicketModel(
      id: json['id']?.toString() ?? '',
      ticketNo: json['ticket_no']?.toString() ?? 'TCK-0000',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: name,
      customerPhone: phone,
      customerAddress: address,
      type: TicketType.fromBackendString(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      errorCode: json['error_code']?.toString(),
      status: TicketStatus.fromBackendString(json['status']?.toString()),
      priority: TicketPriority.fromBackendString(json['priority']?.toString()),
      assignedTo: json['assigned_to']?.toString(),
      assigneeName: json['assignee']?['name']?.toString() ?? json['assignee_name']?.toString(),
      resolvedAt: parseNullableDate(json['resolved_at']),
      resolutionNote: json['resolution_note']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      images: imagesList,
      comments: commentsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticket_no': ticketNo,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_address': customerAddress,
        'type': type.toBackendString(),
        'title': title,
        'description': description,
        if (errorCode != null) 'error_code': errorCode,
        'status': status.toBackendString(),
        'priority': priority.toBackendString(),
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (assigneeName != null) 'assignee_name': assigneeName,
        if (resolvedAt != null) 'resolved_at': resolvedAt!.toIso8601String(),
        if (resolutionNote != null) 'resolution_note': resolutionNote,
        if (createdBy != null) 'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'images': images.map((i) => i.toJson()).toList(),
        'comments': comments.map((c) => c.toJson()).toList(),
      };

  TicketModel copyWith({
    TicketStatus? status,
    String? assignedTo,
    String? assigneeName,
    DateTime? resolvedAt,
    String? resolutionNote,
    List<TicketImageModel>? images,
    List<TicketCommentModel>? comments,
  }) {
    return TicketModel(
      id: id,
      ticketNo: ticketNo,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      type: type,
      title: title,
      description: description,
      errorCode: errorCode,
      status: status ?? this.status,
      priority: priority,
      assignedTo: assignedTo ?? this.assignedTo,
      assigneeName: assigneeName ?? this.assigneeName,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      images: images ?? this.images,
      comments: comments ?? this.comments,
    );
  }
}

class SerialDetailModel {
  final String id;
  final String itemId;
  final String itemName;
  final String category;
  final String? brand;
  final String? model;
  final String serialNo;
  final String status;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? supplierName;
  final int warrantyMonths;
  final DateTime? installedOn;
  final DateTime? warrantyUntil;
  final bool isUnderWarranty;

  const SerialDetailModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.category,
    this.brand,
    this.model,
    required this.serialNo,
    required this.status,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.supplierName,
    required this.warrantyMonths,
    this.installedOn,
    this.warrantyUntil,
    required this.isUnderWarranty,
  });

  factory SerialDetailModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      return DateTime.tryParse(d.toString());
    }

    final until = parseDate(json['warranty_until']);
    final now = DateTime.now();
    final bool underWarranty = json['is_under_warranty'] as bool? ??
        (until != null ? until.isAfter(now) : false);

    return SerialDetailModel(
      id: json['id']?.toString() ?? '',
      itemId: json['item_id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? 'Solar Component',
      category: json['category']?.toString() ?? 'inverter',
      brand: json['brand']?.toString(),
      model: json['model']?.toString(),
      serialNo: json['serial_no']?.toString() ?? '',
      status: json['status']?.toString() ?? 'issued',
      customerId: json['customer_id']?.toString(),
      customerName: json['customer_name']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
      customerAddress: json['customer_address']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      warrantyMonths: json['warranty_months'] as int? ?? 60,
      installedOn: parseDate(json['installed_on']),
      warrantyUntil: until,
      isUnderWarranty: underWarranty,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_id': itemId,
        'item_name': itemName,
        'category': category,
        if (brand != null) 'brand': brand,
        if (model != null) 'model': model,
        'serial_no': serialNo,
        'status': status,
        if (customerId != null) 'customer_id': customerId,
        if (customerName != null) 'customer_name': customerName,
        if (customerPhone != null) 'customer_phone': customerPhone,
        if (customerAddress != null) 'customer_address': customerAddress,
        if (supplierName != null) 'supplier_name': supplierName,
        'warranty_months': warrantyMonths,
        if (installedOn != null) 'installed_on': installedOn!.toIso8601String(),
        if (warrantyUntil != null) 'warranty_until': warrantyUntil!.toIso8601String(),
        'is_under_warranty': isUnderWarranty,
      };
}
