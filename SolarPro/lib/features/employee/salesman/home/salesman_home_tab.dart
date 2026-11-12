import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/salesman/leads/add_lead_bottom_sheet.dart';
import 'package:solar_pro/features/employee/salesman/leads/salesman_lead_detail_screen.dart';
import 'package:solar_pro/features/leads/data/lead_repository.dart';
import 'package:solar_pro/features/leads/data/models/lead_model.dart';
import 'package:solar_pro/shared/widgets/sp_stat_card.dart';

class SalesmanHomeTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const SalesmanHomeTab({super.key, this.onNavigateTab});

  @override
  State<SalesmanHomeTab> createState() => _SalesmanHomeTabState();
}

class _SalesmanHomeTabState extends State<SalesmanHomeTab> {
  final LeadRepository _repository = LeadRepository();
  List<LeadModel> _leads = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchDashboardData();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getString(AppConstants.kUserId);
      });
    }
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final leads = await _repository.getLeads();
      if (mounted) {
        setState(() {
          _leads = leads;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _callNumber(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phone +91 $phone copied to dialer'),
        backgroundColor: AppColors.teal500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayFollowUps = _leads.where((l) => l.isFollowUpToday || l.isFollowUpOverdue).toList();
    final closedCount = _leads.where((l) => l.status == 'converted').length;
    final totalLeads = _leads.length;

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      color: AppColors.gold500,
      backgroundColor: AppColors.navy800,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KPI Stats Grid ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SpStatCard(
                    label: 'Total Pipeline',
                    value: totalLeads.toString(),
                    change: 'Assigned',
                    icon: Icons.trending_up_rounded,
                    iconColor: AppColors.teal500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SpStatCard(
                    label: 'Due Follow-ups',
                    value: todayFollowUps.length.toString(),
                    change: todayFollowUps.any((l) => l.isFollowUpOverdue) ? 'Overdue' : 'Today',
                    icon: Icons.alarm_rounded,
                    iconColor: todayFollowUps.isNotEmpty ? AppColors.gold500 : AppColors.teal500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SpStatCard(
                    label: 'Converted Sales',
                    value: closedCount.toString(),
                    change: 'Closed',
                    icon: Icons.check_circle_rounded,
                    iconColor: AppColors.green500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SpStatCard(
                    label: 'Customer Accounts',
                    value: closedCount.toString(),
                    change: 'Directory',
                    icon: Icons.groups_rounded,
                    iconColor: AppColors.orange500,
                  ),
                ),
              ],
            ),

            // ── Quick Actions ───────────────────────────────────────────
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quick Actions', style: AppTextStyles.headlineSmall),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 94,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _QuickActionCard(
                    label: 'Add\nLead',
                    icon: Icons.person_add_rounded,
                    color: AppColors.teal500,
                    onTap: () async {
                      final newLead = await AddLeadBottomSheet.show(context);
                      if (newLead != null) _fetchDashboardData();
                    },
                  ),
                  const SizedBox(width: 12),
                  _QuickActionCard(
                    label: 'Leads\nPortal',
                    icon: Icons.groups_rounded,
                    color: AppColors.gold500,
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                  const SizedBox(width: 12),
                  _QuickActionCard(
                    label: 'Customer\nDirectory',
                    icon: Icons.assignment_ind_rounded,
                    color: AppColors.orange500,
                    onTap: () => widget.onNavigateTab?.call(2),
                  ),
                  const SizedBox(width: 12),
                  _QuickActionCard(
                    label: 'Payments\nPortal',
                    icon: Icons.payments_rounded,
                    color: AppColors.green500,
                    onTap: () => widget.onNavigateTab?.call(3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Today's Follow-ups Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alarm_on_rounded, color: AppColors.gold500, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Today's Follow-ups",
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (todayFollowUps.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold500,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${todayFollowUps.length} DUE',
                      style: const TextStyle(color: AppColors.ink900, fontWeight: FontWeight.w800, fontSize: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.gold500),
                ),
              )
            else if (todayFollowUps.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.navy800,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.navy600),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.celebration_rounded, color: AppColors.teal500, size: 36),
                    SizedBox(height: 10),
                    Text(
                      'All caught up for today!',
                      style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No prospect calls or visits are pending right now.',
                      style: TextStyle(color: AppColors.grey500, fontSize: 12),
                    ),
                  ],
                ),
              )

            else
              Column(
                children: todayFollowUps.map((lead) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.navy800,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: lead.isFollowUpOverdue ? AppColors.error : AppColors.gold500.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.gold500.withValues(alpha: 0.15),
                          child: Text(
                            lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'L',
                            style: const TextStyle(color: AppColors.gold500, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lead.name,
                                style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lead.followUpDate != null
                                    ? DateFormat('hh:mm a').format(lead.followUpDate!)
                                    : 'Today',
                                style: TextStyle(
                                  color: lead.isFollowUpOverdue ? AppColors.error : AppColors.gold400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (lead.notes != null && lead.notes!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  lead.notes!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.grey400, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone_rounded, color: AppColors.teal500),
                          onPressed: () => _callNumber(lead.phone),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.grey400),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => SalesmanLeadDetailScreen(
                                  lead: lead,
                                  currentUserId: _currentUserId,
                                  onLeadUpdated: _fetchDashboardData,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),
            // Bottom Action to View Pipeline
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => widget.onNavigateTab?.call(1),
                icon: const Icon(Icons.view_list_rounded, size: 18),
                label: const Text('View Full Leads Pipeline'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.fg,
                  side: const BorderSide(color: AppColors.navy600),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.grey200,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
