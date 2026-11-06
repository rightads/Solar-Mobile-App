import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/shared/widgets/sp_stat_card.dart';

class DesktopOverviewPane extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;

  const DesktopOverviewPane({
    super.key,
    required this.onNavigateTab,
  });

  @override
  State<DesktopOverviewPane> createState() => _DesktopOverviewPaneState();
}

class _DesktopOverviewPaneState extends State<DesktopOverviewPane> {
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    try {
      final list = await ApiClient().getPendingApprovals(status: 'pending');
      if (mounted) {
        setState(() => _pendingCount = list.length);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Pending Staff Registration Alert Banner ─────────────────────────
          if (_pendingCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.orange500.withValues(alpha: 0.22),
                    const Color(0xFF0C192E),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.orange500.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.orange500.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_rounded, color: AppColors.orange400, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_pendingCount Employee Registration Request${_pendingCount > 1 ? "s" : ""} Pending Review',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Newly registered employees cannot be assigned installation or sales tasks until approved by Admin.',
                          style: TextStyle(color: AppColors.grey400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      await context.push(AppRoutes.adminApprovals);
                      _loadPendingCount();
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Review Applications'),
                  ),
                ],
              ),
            ),

          // ── Top 4-Column KPI Metrics ───────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: SpStatCard(
                  label: 'Total Revenue',
                  value: '₹0',
                  icon: Icons.currency_rupee_rounded,
                  iconColor: AppColors.gold500,
                  change: 'Live pipeline',
                  delay: 0,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: SpStatCard(
                  label: 'Active Customers',
                  value: '0 Systems',
                  icon: Icons.solar_power_rounded,
                  iconColor: AppColors.teal500,
                  change: '0 active',
                  delay: 80,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: SpStatCard(
                  label: 'KEDL In Progress',
                  value: '0 Files',
                  icon: Icons.description_rounded,
                  iconColor: AppColors.purple500,
                  change: '0 in progress',
                  delay: 160,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await context.push(AppRoutes.adminApprovals);
                    _loadPendingCount();
                  },
                  child: SpStatCard(
                    label: 'Pending Approvals',
                    value: '$_pendingCount Requests',
                    icon: Icons.how_to_reg_rounded,
                    iconColor: _pendingCount > 0 ? AppColors.orange500 : AppColors.warning,
                    change: _pendingCount > 0 ? '$_pendingCount awaiting action' : 'All staff reviewed',
                    delay: 240,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Quick Action Command Bar ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1E33),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.gold400, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Quick Management Actions:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(width: 20),
                _buildQuickBtn(
                  label: 'Leads Pipeline',
                  icon: Icons.person_add_rounded,
                  color: AppColors.teal500,
                  onTap: () => widget.onNavigateTab(1),
                ),
                const SizedBox(width: 12),
                _buildQuickBtn(
                  label: 'Customer Accounts',
                  icon: Icons.group_rounded,
                  color: AppColors.gold500,
                  onTap: () => widget.onNavigateTab(2),
                ),
                const SizedBox(width: 12),
                _buildQuickBtn(
                  label: 'Staff Approvals${_pendingCount > 0 ? " ($_pendingCount)" : ""}',
                  icon: Icons.how_to_reg_rounded,
                  color: _pendingCount > 0 ? AppColors.orange400 : AppColors.gold500,
                  onTap: () async {
                    await context.push(AppRoutes.adminApprovals);
                    _loadPendingCount();
                  },
                ),
                const SizedBox(width: 12),
                _buildQuickBtn(
                  label: 'Verify Payments',
                  icon: Icons.verified_rounded,
                  color: AppColors.success,
                  onTap: () => widget.onNavigateTab(3),
                ),
                const SizedBox(width: 12),
                _buildQuickBtn(
                  label: 'Assign Installation',
                  icon: Icons.construction_rounded,
                  color: AppColors.orange500,
                  onTap: () => widget.onNavigateTab(4),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Live Swagger Docs', style: TextStyle(fontSize: 12)),
                  onPressed: () {},
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 24),

          // ── Two-Column Operational Layout ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left Column: Operations & Active Pipelines ─────────────────
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildSectionCard(
                      title: 'Current Solar Project Pipelines',
                      subtitle: 'Active residential and commercial rooftop phases',
                      actionLabel: 'View All Customers →',
                      onAction: () => widget.onNavigateTab(2),
                      child: _buildEmptyState(
                        'No active installation pipelines. Enroll customers to track solar progress.',
                        Icons.solar_power_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Installation Team Work Status',
                      subtitle: 'Live field updates from Structure & Electrical crews',
                      actionLabel: 'Manage Teams →',
                      onAction: () => widget.onNavigateTab(4),
                      child: _buildEmptyState(
                        'No field installation teams currently dispatched.',
                        Icons.construction_outlined,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // ── Right Column: Financial Approvals & KEDL Tracker ───────────
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildSectionCard(
                      title: 'Pending Financial Approvals',
                      subtitle: 'Customer milestone submissions requiring verification',
                      actionLabel: 'Payments Queue →',
                      onAction: () => widget.onNavigateTab(3),
                      child: _buildEmptyState(
                        'No pending milestone receipts requiring review.',
                        Icons.verified_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'KEDL & Net Metering Watchlist',
                      subtitle: 'DISCOM applications and demand notes',
                      actionLabel: 'Tracker →',
                      onAction: () => widget.onNavigateTab(5),
                      child: _buildEmptyState(
                        'No DISCOM or net metering applications pending.',
                        Icons.description_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  }

  Widget _buildQuickBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        elevation: 0,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      onPressed: onTap,
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0C192E),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.headlineSmall.copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
                ],
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel,
                    style: const TextStyle(color: AppColors.gold400, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.grey600),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500),
            ),
          ],
        ),
      ),
    );
  }
}
