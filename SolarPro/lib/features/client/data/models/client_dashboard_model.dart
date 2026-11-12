import 'package:flutter/material.dart';

enum ClientTicketType {
  structure,
  wiring,
  inverter;

  String get label {
    switch (this) {
      case ClientTicketType.structure:
        return 'Structure Issue';
      case ClientTicketType.wiring:
        return 'Wiring Issue';
      case ClientTicketType.inverter:
        return 'Inverter Fault';
    }
  }

  IconData get icon {
    switch (this) {
      case ClientTicketType.structure:
        return Icons.foundation_rounded;
      case ClientTicketType.wiring:
        return Icons.electrical_services_rounded;
      case ClientTicketType.inverter:
        return Icons.power_rounded;
    }
  }

  String get imageHint {
    switch (this) {
      case ClientTicketType.structure:
        return 'Upload 2 to 10 photos of structure, mounting clamps, rust or foundation (Min 2 required)';
      case ClientTicketType.wiring:
        return 'Upload photos of DC/AC cables, earthing or junction box';
      case ClientTicketType.inverter:
        return 'Upload photos of inverter display, LEDs or error screen';
    }
  }

  int get minImages {
    switch (this) {
      case ClientTicketType.structure:
        return 2;
      case ClientTicketType.wiring:
        return 1;
      case ClientTicketType.inverter:
        return 0;
    }
  }

  int get maxImages => 10;
}

class ClientMilestoneStage {
  final String stage;
  final String title;
  final String status; // 'done', 'current', 'upcoming'
  final DateTime? date;
  final String? note;
  final IconData icon;

  const ClientMilestoneStage({
    required this.stage,
    required this.title,
    required this.status,
    this.date,
    this.note,
    required this.icon,
  });

  bool get isDone => status == 'done';
  bool get isCurrent => status == 'current';
  bool get isUpcoming => status == 'upcoming';
}

class AssignedEmployeeInfo {
  final String name;
  final String phone;
  final String roleTitle;
  final String employeeNo;
  final String email;

  const AssignedEmployeeInfo({
    required this.name,
    required this.phone,
    required this.roleTitle,
    required this.employeeNo,
    this.email = 'support@solarpro.com',
  });

  factory AssignedEmployeeInfo.fromJson(Map<String, dynamic> json) {
    return AssignedEmployeeInfo(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '+91 98765 43210',
      roleTitle: json['role_title']?.toString() ?? 'Sales Executive',
      employeeNo: json['employee_no']?.toString() ?? '',
      email: json['email']?.toString() ?? 'support@solarpro.com',
    );
  }
}

class ClientPaymentRecord {
  final String id;
  final int stageNo;
  final String stageName;
  final double amount; // in ₹
  final String mode;
  final String? referenceNo;
  final DateTime paidOn;
  final String? proofUrl;
  final String status; // 'pending', 'sales_approved', 'verified', 'rejected'
  final String? salesApprovedBy;
  final String? salesApproverEmpNo;
  final String? verifiedBy;
  final String? rejectionReason;
  final String? remarks;

  const ClientPaymentRecord({
    required this.id,
    required this.stageNo,
    required this.stageName,
    required this.amount,
    required this.mode,
    this.referenceNo,
    required this.paidOn,
    this.proofUrl,
    required this.status,
    this.salesApprovedBy,
    this.salesApproverEmpNo,
    this.verifiedBy,
    this.rejectionReason,
    this.remarks,
  });

  bool get isPendingSalesApproval => status == 'pending';
  bool get isSalesApproved => status == 'sales_approved';
  bool get isVerified => status == 'verified';
  bool get isRejected => status == 'rejected';

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending Salesman Approval';
      case 'sales_approved':
        return 'Approved by Salesman (Admin Pending)';
      case 'verified':
        return 'Verified by Admin';
      case 'rejected':
        return 'Rejected';
      default:
        return status.toUpperCase();
    }
  }

  factory ClientPaymentRecord.fromJson(Map<String, dynamic> json) {
    final amountPaise = json['amount'] is int ? json['amount'] as int : (json['amount_paise'] as int? ?? 0);
    return ClientPaymentRecord(
      id: json['id']?.toString() ?? '',
      stageNo: json['stage_no'] as int? ?? 1,
      stageName: json['stage_name']?.toString() ?? 'Milestone Advance',
      amount: amountPaise > 0 ? amountPaise / 100.0 : (json['amount_rupees'] as num? ?? 0.0).toDouble(),
      mode: json['mode']?.toString().toUpperCase() ?? 'UPI',
      referenceNo: json['reference_no']?.toString(),
      paidOn: json['paid_on'] != null ? DateTime.tryParse(json['paid_on'].toString()) ?? DateTime.now() : DateTime.now(),
      proofUrl: json['proof_url']?.toString() ?? json['proof_key']?.toString(),
      status: json['status']?.toString().toLowerCase() ?? 'pending',
      salesApprovedBy: json['sales_approved_by_name']?.toString(),
      salesApproverEmpNo: json['sales_approver_emp_no']?.toString(),
      verifiedBy: json['verified_by_name']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      remarks: json['remarks']?.toString(),
    );
  }
}

class ClientTicketRecord {
  final String id;
  final String ticketNo;
  final ClientTicketType type;
  final String title;
  final String description;
  final String? errorCode;
  final String status; // 'open', 'assigned', 'in_progress', 'resolved', 'closed'
  final String priority;
  final List<String> images;
  final String? assignedStaff;
  final String? assignedStaffEmpNo;
  final DateTime createdAt;

  const ClientTicketRecord({
    required this.id,
    required this.ticketNo,
    required this.type,
    required this.title,
    required this.description,
    this.errorCode,
    required this.status,
    required this.priority,
    required this.images,
    this.assignedStaff,
    this.assignedStaffEmpNo,
    required this.createdAt,
  });

  factory ClientTicketRecord.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type']?.toString().toLowerCase() ?? 'structure';
    ClientTicketType t;
    if (typeStr.contains('wiring')) {
      t = ClientTicketType.wiring;
    } else if (typeStr.contains('inverter')) {
      t = ClientTicketType.inverter;
    } else {
      t = ClientTicketType.structure;
    }

    final rawImages = json['images'];
    List<String> imgList = [];
    if (rawImages is List) {
      imgList = rawImages.map((e) => e is Map ? (e['download_url'] ?? e['file_key'] ?? '').toString() : e.toString()).where((e) => e.isNotEmpty).toList();
    }

    return ClientTicketRecord(
      id: json['id']?.toString() ?? '',
      ticketNo: json['ticket_no']?.toString() ?? 'TIC-000000',
      type: t,
      title: json['title']?.toString() ?? 'Service Issue',
      description: json['description']?.toString() ?? '',
      errorCode: json['error_code']?.toString(),
      status: json['status']?.toString().toLowerCase() ?? 'open',
      priority: json['priority']?.toString().toLowerCase() ?? 'normal',
      images: imgList,
      assignedStaff: json['assignee']?['name']?.toString(),
      assignedStaffEmpNo: json['assignee']?['employee_no']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
