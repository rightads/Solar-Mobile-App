class LeadModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final double? expectedKw;
  final String? source;
  final String status;
  final String? assignedSalesId;
  final String? assignedSalesName;
  final String? approvedQuotationId;
  final DateTime? followUpDate;
  final String? notes;
  final String? lostReason;
  final DateTime? createdAt;

  const LeadModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.expectedKw,
    this.source,
    required this.status,
    this.assignedSalesId,
    this.assignedSalesName,
    this.approvedQuotationId,
    this.followUpDate,
    this.notes,
    this.lostReason,
    this.createdAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return LeadModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Lead',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      address: json['address']?.toString() ?? json['area']?.toString(),
      expectedKw: parseDouble(json['expected_kw'] ?? json['kw']),
      source: json['source']?.toString(),
      status: json['status']?.toString().toLowerCase() ?? 'new',
      assignedSalesId: json['assigned_sales_id']?.toString(),
      assignedSalesName: json['assigned_sales_name']?.toString(),
      approvedQuotationId: json['approved_quotation_id']?.toString(),
      followUpDate: parseDate(json['follow_up_date']),
      notes: json['notes']?.toString(),
      lostReason: json['lost_reason']?.toString(),
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'expected_kw': expectedKw,
      'source': source,
      'status': status,
      'assigned_sales_id': assignedSalesId,
      'assigned_sales_name': assignedSalesName,
      'approved_quotation_id': approvedQuotationId,
      'follow_up_date': followUpDate?.toIso8601String(),
      'notes': notes,
      'lost_reason': lostReason,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  LeadModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    double? expectedKw,
    String? source,
    String? status,
    String? assignedSalesId,
    String? assignedSalesName,
    String? approvedQuotationId,
    DateTime? followUpDate,
    String? notes,
    String? lostReason,
    DateTime? createdAt,
  }) {
    return LeadModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      expectedKw: expectedKw ?? this.expectedKw,
      source: source ?? this.source,
      status: status ?? this.status,
      assignedSalesId: assignedSalesId ?? this.assignedSalesId,
      assignedSalesName: assignedSalesName ?? this.assignedSalesName,
      approvedQuotationId: approvedQuotationId ?? this.approvedQuotationId,
      followUpDate: followUpDate ?? this.followUpDate,
      notes: notes ?? this.notes,
      lostReason: lostReason ?? this.lostReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Maps backend enum status to human-readable UI label
  String get uiStatusLabel {
    switch (status.toLowerCase()) {
      case 'new':
        return 'New';
      case 'contacted':
        return 'Contacted';
      case 'follow_up':
        return 'Follow-up';
      case 'converted':
        return 'Closed';
      case 'lost':
        return 'Returned';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  /// Checks if follow-up is scheduled for today
  bool get isFollowUpToday {
    if (followUpDate == null) return false;
    final now = DateTime.now();
    return followUpDate!.year == now.year &&
        followUpDate!.month == now.month &&
        followUpDate!.day == now.day;
  }

  /// Checks if follow-up date has passed and still in follow-up status
  bool get isFollowUpOverdue {
    if (followUpDate == null || status != 'follow_up') return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(followUpDate!.year, followUpDate!.month, followUpDate!.day);
    return target.isBefore(today);
  }

  /// Source tag: "Added by me" vs "Assigned by Admin"
  String sourceLabel(String? currentUserId) {
    if (source != null && source!.toLowerCase().startsWith('self')) {
      return 'Added by me';
    }
    if (currentUserId != null &&
        assignedSalesId == currentUserId &&
        source == 'Direct Sales') {
      return 'Added by me';
    }
    return 'Assigned by Admin';
  }
}
