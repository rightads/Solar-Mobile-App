import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/shared/animations/motion.dart';
import 'package:solar_pro/shared/widgets/sp_solar_system_card.dart';
import 'package:solar_pro/features/client/data/models/client_dashboard_model.dart';

class ClientStatusTab extends StatelessWidget {
  final Map<String, dynamic>? homeData;
  final AssignedEmployeeInfo? assignedEmployee;
  final Future<void> Function()? onRefresh;
  final VoidCallback onOpenPayment;
  final VoidCallback onOpenTicket;

  const ClientStatusTab({
    super.key,
    required this.homeData,
    required this.assignedEmployee,
    this.onRefresh,
    required this.onOpenPayment,
    required this.onOpenTicket,
  });

  @override
  Widget build(BuildContext context) {
    final customer = homeData?['customer'] as Map<String, dynamic>?;
    final timelineRaw = (homeData?['timeline'] as List?) ?? [];
    final specs = (homeData?['system_specs'] as Map<String, dynamic>?) ?? {};
    final currentStage = homeData?['stage']?.toString() ?? 'REGISTRATION_SUBMITTED';
    final progressData = homeData?['progress'] as Map<String, dynamic>?;

    final completedCount = progressData?['completed_stages'] as int? ??
        timelineRaw.where((t) => t is Map && t['status'] == 'done').length;
    final totalCount = progressData?['total_stages'] as int? ??
        (timelineRaw.isNotEmpty ? timelineRaw.length : 10);
    final progressFraction = totalCount > 0
        ? (completedCount / totalCount).clamp(0.0, 1.0)
        : 0.0;
    final progressPercentage = progressData?['percentage'] as int? ??
        (progressFraction * 100).toInt();

    final capacity = (customer?['capacity_kw'] as num?)?.toDouble() ??
        (specs['capacity_kw'] as num?)?.toDouble() ??
        0.0;

    final hasAssignedOfficer = assignedEmployee != null &&
        assignedEmployee!.name.isNotEmpty &&
        assignedEmployee!.employeeNo.isNotEmpty;

    final hasSpecs = (specs['is_configured'] == true) ||
        (capacity > 0 &&
            specs['panel_brand'] != null &&
            specs['panel_brand'].toString().isNotEmpty &&
            specs['panel_brand'] != 'Pending Survey');

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      color: AppColors.gold500,
      backgroundColor: AppColors.navy800,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (homeData?['needs_phone_verification'] == true)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.gold100,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.gold300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phonelink_lock_outlined, color: AppColors.ink900),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'To see your project, sign out and sign in once with Mobile OTP. '
                          'This confirms the mobile number on your account is yours.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.ink900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Hero: "Your Solar System"
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SpEntrance(
                child: SpSolarSystemCard(
                  capacityKw: capacity,
                  stageLabel: currentStage == 'REGISTRATION_SUBMITTED'
                      ? 'Registration Submitted'
                      : _formatStageName(currentStage),
                  completed: completedCount,
                  total: totalCount,
                  percentage: progressPercentage,
                  active: completedCount > 0,
                ),
              ),
            ),
          ),

          // REQUIREMENT 1: "Status with Employee No." Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: hasAssignedOfficer
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.navy800,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.gold500.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold500.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.badge_rounded, color: AppColors.gold500, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Assigned Project Officer',
                                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.fg),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // PROMINENT EMPLOYEE NO BADGE
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: assignedEmployee!.employeeNo));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Employee No. ${assignedEmployee!.employeeNo} copied!'),
                                      backgroundColor: AppColors.navy700,
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold500.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                    border: Border.all(color: AppColors.gold500, width: 1.2),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.copy_rounded, color: AppColors.gold400, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        assignedEmployee!.employeeNo,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.gold400,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: AppColors.navy600, height: 20),
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.gold500.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.gold500.withValues(alpha: 0.3)),
                                ),
                                child: Center(
                                  child: Text(
                                    assignedEmployee!.name.isNotEmpty ? assignedEmployee!.name[0] : 'P',
                                    style: const TextStyle(
                                      color: AppColors.gold500,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(assignedEmployee!.name, style: AppTextStyles.headlineSmall),
                                    Text(assignedEmployee!.roleTitle,
                                        style: AppTextStyles.caption.copyWith(color: AppColors.teal400)),
                                    Text('Emp ID: ${assignedEmployee!.employeeNo}',
                                        style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
                                  ],
                                ),
                              ),
                              // Quick Contact Actions
                              if (assignedEmployee!.phone.isNotEmpty) ...[
                                IconButton(
                                  icon: const Icon(Icons.phone_rounded, color: AppColors.success, size: 22),
                                  tooltip: 'Call Representative',
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Calling ${assignedEmployee!.name} at ${assignedEmployee!.phone}...'),
                                        backgroundColor: AppColors.navy700,
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat_bubble_rounded, color: AppColors.teal400, size: 20),
                                  tooltip: 'WhatsApp Representative',
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Opening WhatsApp with ${assignedEmployee!.name} (${assignedEmployee!.employeeNo})...'),
                                        backgroundColor: AppColors.navy700,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.08, end: 0)
                  : Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.navy800,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.navy600, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.orange500.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.orange500.withValues(alpha: 0.3)),
                            ),
                            child: const Center(
                              child: Icon(Icons.engineering_outlined, color: AppColors.orange400, size: 24),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Assigned Project Officer',
                                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.fg),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.orange500.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(AppRadius.pill),
                                        border: Border.all(color: AppColors.orange500.withValues(alpha: 0.4)),
                                      ),
                                      child: const Text(
                                        'PENDING',
                                        style: TextStyle(color: AppColors.orange400, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Admin is reviewing your registration and will assign a dedicated project engineer shortly.',
                                  style: TextStyle(color: AppColors.grey400, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 450.ms),
            ),
          ),

          // Quick Action Shortcut Buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onOpenPayment,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.navy800,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.gold500.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.payment_rounded, color: AppColors.gold500, size: 18),
                            const SizedBox(width: 8),
                            Text('Submit Payment',
                                style: AppTextStyles.labelMedium.copyWith(color: AppColors.gold400, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: onOpenTicket,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.navy800,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.orange500.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.support_agent_rounded, color: AppColors.orange400, size: 18),
                            const SizedBox(width: 8),
                            Text('Raise Ticket',
                                style: AppTextStyles.labelMedium.copyWith(color: AppColors.orange400, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // SECTION TITLE: 10-Stage Project Milestones
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Text('10-Stage Project Milestones', style: AppTextStyles.headlineSmall),
                  const Spacer(),
                  Text('Real-time sync',
                      style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
                ],
              ),
            ),
          ),

          // Milestones Timeline
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final item = (timelineRaw.length > i && timelineRaw[i] is Map)
                      ? Map<String, dynamic>.from(timelineRaw[i] as Map)
                      : <String, dynamic>{};

                  final title = item['title']?.toString() ?? 'Milestone ${i + 1}';
                  final status = item['status']?.toString() ?? 'upcoming';
                  final note = item['note'];

                  final isDone = status == 'done';
                  final isCurrent = status == 'current';
                  

                  return TimelineTile(
                    alignment: TimelineAlign.manual,
                    lineXY: 0.08,
                    isFirst: i == 0,
                    isLast: i == (timelineRaw.isNotEmpty ? timelineRaw.length - 1 : 9),
                    indicatorStyle: IndicatorStyle(
                      width: 28,
                      height: 28,
                      indicator: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppColors.success.withValues(alpha: 0.2)
                              : (isCurrent ? AppColors.gold500.withValues(alpha: 0.25) : AppColors.navy900),
                          border: Border.all(
                            color: isDone
                                ? AppColors.success
                                : (isCurrent ? AppColors.gold500 : AppColors.navy600),
                            width: 2,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: AppColors.gold500.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check_rounded, color: AppColors.success, size: 16)
                              : (isCurrent
                                  ? const Icon(Icons.autorenew_rounded, color: AppColors.gold500, size: 16)
                                      .animate(onPlay: (c) => c.repeat())
                                      .rotate(duration: const Duration(seconds: 4))
                                  : Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.navy600,
                                      ),
                                    )),
                        ),
                      ),
                    ),
                    beforeLineStyle: LineStyle(
                      color: isDone ? AppColors.success : AppColors.navy700,
                      thickness: 2,
                    ),
                    afterLineStyle: LineStyle(
                      color: isDone ? AppColors.success : AppColors.navy700,
                      thickness: 2,
                    ),
                    endChild: Padding(
                      padding: const EdgeInsets.only(left: 14, bottom: 14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.gold500.withValues(alpha: 0.08)
                              : (isDone ? AppColors.navy800 : AppColors.navy900),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: isCurrent
                                ? AppColors.gold500.withValues(alpha: 0.4)
                                : (isDone ? AppColors.success.withValues(alpha: 0.2) : AppColors.navy700),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('${i + 1}. ',
                                    style: TextStyle(
                                      color: isCurrent ? AppColors.gold500 : AppColors.grey500,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    )),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: isDone || isCurrent ? AppColors.fg : AppColors.grey400,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isDone)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text((item['completed_by'] != null && item['completed_by'].toString().isNotEmpty) ? 'DONE by ${item["completed_by"]} ✓' : 'DONE ✓',
                                        style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold)),
                                  )
                                else if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold500.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('IN PROGRESS',
                                        style: TextStyle(fontSize: 10, color: AppColors.gold400, fontWeight: FontWeight.bold)),
                                  ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.7, end: 1.0),
                              ],
                            ),
                            if (note != null && note.toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                note.toString(),
                                style: AppTextStyles.caption.copyWith(color: AppColors.grey300),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ).animate(delay: Duration(milliseconds: i * 50)).fadeIn(duration: 350.ms).slideX(begin: 0.04, end: 0),
                  );
                },
                childCount: timelineRaw.isNotEmpty ? timelineRaw.length : 10,
              ),
            ),
          ),

          // Technical Specs
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.navy800,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.navy600),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.settings_suggest_rounded, color: AppColors.teal400, size: 20),
                        const SizedBox(width: 8),
                        Text('System Technical Specifications', style: AppTextStyles.labelLarge),
                      ],
                    ),
                    const Divider(color: AppColors.navy600, height: 16),
                    if (hasSpecs) ...[
                      _specRow('System Capacity', '$capacity kW'),
                      _specRow('Grid Phase', specs['phase']?.toString() ?? 'Single Phase'),
                      _specRow('Solar Panels', '${specs['panel_count'] ?? 0}x ${specs['panel_watt'] ?? 0}W (${specs['panel_brand'] ?? 'Tata / Waaree'})'),
                      _specRow('Inverter', specs['inverter_brand']?.toString() ?? 'N/A'),
                      _specRow('Mounting Structure', specs['structure_type']?.toString() ?? 'N/A'),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline_rounded, color: AppColors.teal400, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Solar system capacity, panel models, and inverter specifications will be finalized after the on-site feasibility survey by our engineers.',
                                style: TextStyle(color: AppColors.grey400, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey200, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatStageName(String stage) {
    return stage
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join(' ');
  }
}
