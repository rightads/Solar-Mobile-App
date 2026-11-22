import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// The employee departments, in project order. Every staff account belongs to
/// exactly one. Older accounts may still carry legacy role names (kedl, site,
/// labour, electrician, technician, ...); [departmentOf] maps those onto a
/// department.
class StaffDepartment {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  /// Customer field holding this department's assigned employee.
  final String field;
  const StaffDepartment(this.key, this.label, this.icon, this.color, this.field);

  /// Customer field holding the assigned employee's name.
  String get nameField => field == 'sales_id' ? 'sales_name' : field.replaceFirst('_id', '_name');
}

const kStaffDepartments = [
  StaffDepartment('sales', 'Salesman', Icons.handshake_outlined, AppColors.teal500, 'sales_id'),
  StaffDepartment('discom', 'Discom', Icons.description_outlined, AppColors.purple500, 'discom_employee_id'),
  StaffDepartment('structure', 'Structure', Icons.foundation_rounded, AppColors.orange400, 'structure_employee_id'),
  StaffDepartment('wiring', 'Wiring', Icons.electrical_services_rounded, AppColors.gold500, 'wiring_employee_id'),
  StaffDepartment('civil', 'Civil Work', Icons.construction_outlined, AppColors.orange500, 'civil_employee_id'),
  StaffDepartment('subsidy', 'Subsidy', Icons.savings_outlined, AppColors.success, 'subsidy_employee_id'),
  StaffDepartment('account', 'Account / Bill', Icons.receipt_long_outlined, AppColors.info, 'account_employee_id'),
];

/// Department key for a role, or null (admins, clients, legacy service staff).
String? departmentOf(String? role) {
  switch ((role ?? '').trim().toLowerCase()) {
    case 'sales':
    case 'salesman':
    case 'employee':
    case 'office_staff':
      return 'sales';
    case 'discom':
    case 'kedl':
      return 'discom';
    case 'structure':
    case 'site':
    case 'site_ops':
    case 'labour':
      return 'structure';
    case 'wiring':
    case 'electrician':
    case 'electrical':
    case 'technician':
      return 'wiring';
    case 'civil':
      return 'civil';
    case 'subsidy':
      return 'subsidy';
    case 'account':
    case 'accounts':
    case 'billing':
      return 'account';
    default:
      return null;
  }
}

StaffDepartment? staffDepartment(String? role) {
  final key = departmentOf(role);
  for (final d in kStaffDepartments) {
    if (d.key == key) return d;
  }
  return null;
}
