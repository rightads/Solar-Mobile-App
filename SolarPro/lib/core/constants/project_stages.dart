import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// The 8 project stages, in order. Mirrors the backend
/// (app/core/constants.py STAGE_FLOW): each stage belongs to one department,
/// and finishing it hands the project to the next stage's department.
class ProjectStage {
  final String key;
  final String label;
  final String department;
  final IconData icon;
  final Color color;
  const ProjectStage(this.key, this.label, this.department, this.icon, this.color);
}

const kProjectStages = [
  ProjectStage('DOCUMENTS_COLLECTION', 'Client Documents Collection', 'sales', Icons.folder_shared_rounded, AppColors.teal500),
  ProjectStage('DISCOM_NAME_CHANGE', 'Discom: Name Change & Other Changes', 'discom', Icons.description_rounded, AppColors.purple500),
  ProjectStage('STRUCTURE_WORK', 'Structure Work', 'structure', Icons.foundation_rounded, AppColors.orange400),
  ProjectStage('WIRING_WORK', 'Wiring Work', 'wiring', Icons.electrical_services_rounded, AppColors.gold500),
  ProjectStage('CIVIL_WORK', 'Civil Work', 'civil', Icons.construction_rounded, AppColors.orange500),
  ProjectStage('SUBSIDY_WORK', 'Subsidy Work', 'subsidy', Icons.savings_rounded, AppColors.success),
  ProjectStage('DISCOM_NET_METERING', 'Discom: Net Metering', 'discom', Icons.bolt_rounded, AppColors.purple500),
  ProjectStage('ACCOUNT_BILL', 'Account / Bill', 'account', Icons.receipt_long_rounded, AppColors.info),
];

/// Shown before a sign-up's project is taken on by sales.
const kStageRegistration = 'REGISTRATION_SUBMITTED';

/// All 8 stages done.
const kStageCompleted = 'COMPLETED';

ProjectStage? projectStage(String? key) {
  final k = (key ?? '').toUpperCase();
  for (final s in kProjectStages) {
    if (s.key == k) return s;
  }
  return null;
}

/// Short label for a customer's current stage (list badges, filters).
String projectStageLabel(String? key) {
  final k = (key ?? '').toUpperCase();
  if (k == kStageCompleted) return 'Completed ✓';
  if (k == kStageRegistration) return 'Awaiting Sales';
  final s = projectStage(k);
  if (s != null) return s.label;
  return k.isEmpty ? 'Not started' : k.replaceAll('_', ' ');
}

Color projectStageColor(String? key) {
  final k = (key ?? '').toUpperCase();
  if (k == kStageCompleted) return AppColors.success;
  return projectStage(k)?.color ?? AppColors.grey500;
}

/// 1-based position of a stage, 9 when completed, 0 when unknown.
int projectStageIndex(String? key) {
  final k = (key ?? '').toUpperCase();
  if (k == kStageCompleted) return kProjectStages.length + 1;
  final i = kProjectStages.indexWhere((s) => s.key == k);
  return i < 0 ? 0 : i + 1;
}
