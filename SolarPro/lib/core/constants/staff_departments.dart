import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// The four employee departments. Every staff account belongs to exactly one.
/// Older accounts may still carry legacy role names (labour, electrician,
/// technician, ...); [departmentOf] maps those onto a department.
class StaffDepartment {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const StaffDepartment(this.key, this.label, this.icon, this.color);
}

const kStaffDepartments = [
  StaffDepartment('sales', 'Sales', Icons.handshake_outlined, AppColors.teal500),
  StaffDepartment('site', 'Site Ops', Icons.construction_outlined, AppColors.orange400),
  StaffDepartment('kedl', 'KEDL', Icons.description_outlined, AppColors.purple500),
  StaffDepartment('service', 'Service', Icons.build_circle_outlined, AppColors.gold500),
];

/// Department key (sales / site / kedl / service) for a role, or null.
String? departmentOf(String? role) {
  switch ((role ?? '').trim().toLowerCase()) {
    case 'sales':
    case 'salesman':
    case 'employee':
    case 'office_staff':
      return 'sales';
    case 'site':
    case 'labour':
    case 'electrician':
    case 'electrical':
    case 'structure':
    case 'civil':
      return 'site';
    case 'kedl':
      return 'kedl';
    case 'service':
    case 'technician':
      return 'service';
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
