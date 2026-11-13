import 'package:flutter/material.dart';
import 'package:solar_pro/core/constants/staff_departments.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class AdminEmployee {
  final String id;
  final String name;
  final String employeeNo;
  final String phone;
  final String? email;
  final String role;
  final String trade;
  final String team;
  final int taskCount;
  final bool isActive;

  const AdminEmployee({
    required this.id,
    required this.name,
    required this.employeeNo,
    required this.phone,
    this.email,
    required this.role,
    required this.trade,
    required this.team,
    this.taskCount = 0,
    this.isActive = true,
  });

  factory AdminEmployee.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? json['_id']?.toString() ?? '';
    final rawRole = json['role']?.toString().toLowerCase() ?? 'employee';
    final rawTrade = json['trade']?.toString().toLowerCase() ?? rawRole;
    final rawEmpNo = json['employee_no']?.toString() ??
        'EMP-${rawId.isNotEmpty ? rawId.substring(0, rawId.length > 4 ? 4 : rawId.length).toUpperCase() : '001'}';

    return AdminEmployee(
      id: rawId,
      name: json['name']?.toString() ?? 'Unnamed Staff',
      employeeNo: rawEmpNo,
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      role: rawRole,
      trade: rawTrade,
      team: (json['team']?.toString().trim().isNotEmpty ?? false) ? json['team'].toString() : (staffDepartment(rawRole)?.label ?? 'Staff'),
      taskCount: (json['task_count'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
    );
  }

  /// One of the four departments (sales, site, kedl, service), if known.
  StaffDepartment? get department => staffDepartment(role);

  String get roleDisplayName => role == 'admin' ? 'Administrator' : (department?.label ?? role.toUpperCase());

  Color get roleColor => department?.color ?? AppColors.grey400;

  IconData get roleIcon => department?.icon ?? Icons.badge_rounded;
}

class EmployeeTask {
  final String id;
  final String title;
  final String description;
  final String customerName;
  final String location;
  final String category;
  final String status;
  final String priority;
  final String startDate;
  final String endDate;
  final String assignedTo;
  final String type;
  final dynamic createdAt;

  const EmployeeTask({
    required this.id,
    required this.title,
    this.description = '',
    this.customerName = 'Customer',
    this.location = '',
    this.category = 'general',
    this.status = 'assigned',
    this.priority = 'normal',
    this.startDate = '',
    this.endDate = '',
    this.assignedTo = '',
    this.type = 'work_assignment',
    this.createdAt,
  });

  factory EmployeeTask.fromJson(Map<String, dynamic> json) {
    return EmployeeTask(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Task',
      description: json['description']?.toString() ?? json['notes']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Customer',
      location: json['location']?.toString() ?? json['customer_address']?.toString() ?? '',
      category: json['category']?.toString() ?? json['work_type']?.toString() ?? 'general',
      status: json['status']?.toString() ?? 'assigned',
      priority: json['priority']?.toString() ?? 'normal',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      assignedTo: json['assigned_to']?.toString() ?? '',
      type: json['type']?.toString() ?? 'work_assignment',
      createdAt: json['created_at'],
    );
  }

  String get statusDisplayName {
    switch (status.toLowerCase()) {
      case 'in_progress':
      case 'inprogress':
        return 'IN PROGRESS';
      case 'completed':
      case 'resolved':
      case 'closed':
        return 'COMPLETED';
      case 'assigned':
      case 'open':
      case 'pending':
      default:
        return 'ASSIGNED';
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'in_progress':
      case 'inprogress':
        return AppColors.info;
      case 'completed':
      case 'resolved':
      case 'closed':
        return AppColors.success;
      case 'assigned':
      case 'open':
      case 'pending':
      default:
        return AppColors.gold500;
    }
  }

  Color get priorityColor {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return Colors.orangeAccent;
      case 'normal':
      default:
        return AppColors.teal500;
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'structure':
        return Icons.foundation_rounded;
      case 'electrical':
      case 'wiring':
        return Icons.electric_bolt_rounded;
      case 'civil':
        return Icons.handyman_rounded;
      case 'service':
      case 'maintenance':
      case 'inverter':
        return Icons.support_agent_rounded;
      case 'sales':
      case 'lead':
        return Icons.person_search_rounded;
      case 'kedl':
        return Icons.receipt_long_rounded;
      default:
        return Icons.assignment_rounded;
    }
  }
}
