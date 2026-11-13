import 'package:flutter/material.dart';
import 'package:solar_pro/shared/widgets/sp_greeting_header.dart';
import 'package:solar_pro/shared/animations/motion.dart';
import 'package:solar_pro/shared/widgets/sp_bottom_nav.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/leads/presentation/screens/leads_screen.dart';
import 'package:solar_pro/features/customers/presentation/screens/customers_screen.dart';
import 'package:solar_pro/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:solar_pro/features/payments/presentation/screens/payments_screen.dart';
import 'package:solar_pro/features/work_assignment/presentation/screens/work_assignment_screen.dart';
import 'package:solar_pro/features/kedl/presentation/screens/kedl_screen.dart';
import 'package:solar_pro/features/tickets/presentation/screens/tickets_screen.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/features/admin/employees/models/admin_employee_model.dart';
import 'package:solar_pro/features/admin/employees/widgets/employee_task_sheet.dart';
import 'package:solar_pro/features/dashboard/presentation/widgets/desktop_sidebar.dart';
import 'package:solar_pro/features/dashboard/presentation/widgets/desktop_header.dart';
import 'package:solar_pro/features/dashboard/presentation/screens/desktop_overview_pane.dart';
import 'package:solar_pro/shared/widgets/sp_stat_card.dart';
import 'package:solar_pro/shared/widgets/sp_section_header.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  int _selectedIndex = 0;
  int _selectedDesktopIndex = 0;
  bool _isSidebarCollapsed = false;

  String get _currentDesktopTitle => switch (_selectedDesktopIndex) {
        0 => 'Operations Dashboard',
        1 => 'Leads & Enquiries Pipeline',
        2 => 'Customer Directory & Accounts',
        3 => 'Financial Management & Billing',
        4 => 'Work Assignments & Teams',
        5 => 'KEDL Net Metering Tracker',
        6 => 'Stock Inventory & Warehouses',
        7 => 'Service Tickets & Support',
        _ => 'Operations Console',
      };

  String get _currentDesktopSubtitle => switch (_selectedDesktopIndex) {
        0 => 'SolarPro Enterprise Command Center • Live Telemetry',
        1 => 'Manage prospects, conversions, and quotation follow-ups',
        2 => 'Client installation portfolio, documents and status tracking',
        3 => 'Payment milestones, cashier verification and receipts',
        4 => 'Field installation teams, schedule dispatch & civil progress',
        5 => 'Government liaison, DISCOM file submissions & net metering',
        6 => 'Panels, inverters, structure rails, meters & BOS components',
        7 => 'Customer grievance management, maintenance & site issues',
        _ => 'Solar Management Console',
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;
        if (isDesktop) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildDesktopLayout() {
    final desktopPages = [
      DesktopOverviewPane(
        onNavigateTab: (index) => setState(() => _selectedDesktopIndex = index),
      ),
      const LeadsScreen(),
      const CustomersScreen(),
      const PaymentsScreen(),
      const WorkAssignmentScreen(),
      const KedlScreen(),
      const InventoryScreen(),
      const TicketsScreen(showAppBar: false),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4FD),
      body: Row(
        children: [
          DesktopSidebar(
            selectedIndex: _selectedDesktopIndex,
            onSelect: (index) => setState(() => _selectedDesktopIndex = index),
            isCollapsed: _isSidebarCollapsed,
            onToggleCollapse: () =>
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
          ),
          Expanded(
            child: Column(
              children: [
                DesktopHeader(
                  title: _currentDesktopTitle,
                  subtitle: _currentDesktopSubtitle,
                  onAddLead: () => setState(() => _selectedDesktopIndex = 1),
                  onRecordPayment: () => setState(() => _selectedDesktopIndex = 3),
                ),
                Expanded(
                  child: Container(
                    color: AppColors.navy900,
                    child: SpAnimatedIndexedStack(
                      index: _selectedDesktopIndex,
                      children: desktopPages,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    final mobilePages = [
      _DashboardHome(
        onNavigateTab: (index) => setState(() => _selectedIndex = index),
      ),
      const LeadsScreen(),
      const CustomersScreen(),
      const InventoryScreen(),
      _MoreMenu(
        onNavigateTab: (index) => setState(() => _selectedIndex = index),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SpAnimatedIndexedStack(
        index: _selectedIndex,
        children: mobilePages,
      ),
      bottomNavigationBar: SpBottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}


void _showAdminLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.navy800,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.gold500.withValues(alpha: 0.2)),
      ),
      title: const Text(
        'Log Out',
        style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold),
      ),
      content: const Text(
        'Are you sure you want to log out of your admin account?',
        style: TextStyle(color: AppColors.grey300),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.grey400)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.fg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          onPressed: () async {
            Navigator.of(ctx).pop();
            await ApiClient().logout();
            if (!context.mounted) return;
            context.go(AppRoutes.login);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Logged out successfully'),
                backgroundColor: AppColors.navy700,
              ),
            );
          },
          child: const Text('Log Out'),
        ),
      ],
    ),
  );
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topInset;
  final SpGreetingHeader header;
  _HeaderDelegate(this.topInset, this.header);

  @override
  double get minExtent => header.preferredSize.height + topInset;
  @override
  double get maxExtent => header.preferredSize.height + topInset;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => header;

  @override
  bool shouldRebuild(covariant _HeaderDelegate old) => true;
}

// ── Home Tab ─────────────────────────────────────────────────────────────────
class _DashboardHome extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;
  const _DashboardHome({required this.onNavigateTab});

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  static const _recent = <_RA>[];
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingApprovals();
  }

  Future<void> _loadPendingApprovals() async {
    try {
      final list = await ApiClient().getPendingApprovals(status: 'pending');
      if (mounted) {
        setState(() {
          _pendingCount = list.length;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── App Bar ─────────────────────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _HeaderDelegate(
            MediaQuery.paddingOf(context).top,
            SpGreetingHeader(
              name: 'Admin',
              role: 'Administrator',
              badge: _pendingCount > 0 ? '$_pendingCount pending' : null,
              unread: _pendingCount,
              onBell: () => context.push(AppRoutes.notifications),
              onLogout: () => _showAdminLogoutDialog(context),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Pending Staff Registration Alert Banner ───────────────────────
              if (_pendingCount > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.orange500.withValues(alpha: 0.22),
                        AppColors.navy800,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.orange500.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.orange500.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_add_rounded, color: AppColors.orange400, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_pendingCount New Employee Registration${_pendingCount > 1 ? "s" : ""} Pending',
                              style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'New staff require your approval to access the app and work tasks.',
                              style: TextStyle(color: AppColors.grey400, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange500,
                          foregroundColor: AppColors.fg,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          await context.push(AppRoutes.adminApprovals);
                          _loadPendingApprovals();
                        },
                        child: const Text('Review'),
                      ),
                    ],
                  ),
                ),

              // ── Stats Grid ─────────────────────────────────────────────
              GridView.count(
                crossAxisCount: 2,
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.38,
                children: [
                  GestureDetector(
                    onTap: () => widget.onNavigateTab(1), // Leads tab
                    child: const SpStatCard(
                        label: 'Active Leads',
                        value: '0',
                        icon: Icons.trending_up_rounded,
                        iconColor: AppColors.teal500,
                        change: 'Pipeline clean',
                        delay: 0),
                  ),
                  GestureDetector(
                    onTap: () => widget.onNavigateTab(2), // Customers tab
                    child: const SpStatCard(
                        label: 'Customers',
                        value: '0',
                        icon: Icons.groups_rounded,
                        iconColor: AppColors.gold500,
                        change: 'Ready for enroll',
                        delay: 100),
                  ),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.payments),
                    child: const SpStatCard(
                        label: 'Pending Payments',
                        value: '₹0',
                        icon: Icons.payments_rounded,
                        iconColor: AppColors.orange500,
                        change: '0 awaiting',
                        delay: 200),
                  ),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.workAssign),
                    child: const SpStatCard(
                        label: 'Active Works',
                        value: '0',
                        icon: Icons.construction_rounded,
                        iconColor: AppColors.purple500,
                        change: '0 teams',
                        delay: 300),
                  ),
                ],
              ),

              // ── Quick Actions ───────────────────────────────────────────
              const SizedBox(height: 28),
              const SpSectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 14),
              SizedBox(
                height: 94,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _QuickActionCard(
                      label: 'Leads\nPortal',
                      icon: Icons.person_add_rounded,
                      color: AppColors.teal500,
                      onTap: () => widget.onNavigateTab(1),
                      delay: 0,
                    ),
                    const SizedBox(width: 12),
                    _QuickActionCard(
                      label: 'Customer\nDirectory',
                      icon: Icons.assignment_ind_rounded,
                      color: AppColors.gold500,
                      onTap: () => widget.onNavigateTab(2),
                      delay: 80,
                    ),
                    const SizedBox(width: 12),
                    _QuickActionCard(
                      label: 'Staff &\nEmployees',
                      icon: Icons.badge_rounded,
                      color: AppColors.gold500,
                      onTap: () async {
                        await context.push(AppRoutes.adminEmployees);
                        _loadPendingApprovals();
                      },
                      delay: 120,
                    ),
                    const SizedBox(width: 12),
                    _QuickActionCard(
                      label: 'Staff\nApprovals',
                      icon: Icons.how_to_reg_rounded,
                      color: AppColors.orange500,
                      badgeText: _pendingCount > 0 ? '$_pendingCount' : null,
                      onTap: () async {
                        await context.push(AppRoutes.adminApprovals);
                        _loadPendingApprovals();
                      },
                      delay: 140,
                    ),
                    const SizedBox(width: 12),
                    _QuickActionCard(
                      label: 'Work\nAssign',
                      icon: Icons.construction_rounded,
                      color: AppColors.orange500,
                      onTap: () => context.push(AppRoutes.workAssign),
                      delay: 160,
                    ),
                    const SizedBox(width: 12),
                    _QuickActionCard(
                      label: 'KEDL\nFiles',
                      icon: Icons.description_rounded,
                      color: AppColors.purple500,
                      onTap: () => context.push(AppRoutes.kedl),
                      delay: 240,
                    ),
                    const SizedBox(width: 12),
                    _QuickActionCard(
                      label: 'Payments\nManager',
                      icon: Icons.payments_rounded,
                      color: AppColors.green500,
                      onTap: () => context.push(AppRoutes.payments),
                      delay: 320,
                    ),
                    const SizedBox(width: 12),
                    _QuickActionCard(
                      label: 'Stock\nInventory',
                      icon: Icons.inventory_2_rounded,
                      color: AppColors.info,
                      onTap: () => widget.onNavigateTab(3),
                      delay: 400,
                    ),
                  ],
                ),
              ),

              // ── Today's Pipeline ────────────────────────────────────────
              const SizedBox(height: 28),
              const SpSectionHeader(title: "Today's Pipeline"),
              const SizedBox(height: 14),
              _PipeRow(
                label: 'Payments to verify',
                count: 0,
                color: AppColors.orange500,
                icon: Icons.verified_rounded,
                route: AppRoutes.payments,
                delay: 100,
              ),
              const SizedBox(height: 10),
              _PipeRow(
                label: 'Work assignments due',
                count: 0,
                color: AppColors.teal500,
                icon: Icons.calendar_today_rounded,
                route: AppRoutes.workAssign,
                delay: 200,
              ),
              const SizedBox(height: 10),
              _PipeRow(
                label: 'KEDL files pending',
                count: 0,
                color: AppColors.purple500,
                icon: Icons.description_rounded,
                route: AppRoutes.kedl,
                delay: 300,
              ),
              const SizedBox(height: 10),
              _PipeRow(
                label: 'Open service tickets',
                count: 0,
                color: AppColors.error,
                icon: Icons.support_agent_rounded,
                route: AppRoutes.serviceTickets,
                delay: 400,
              ),

              // ── Staff & Employees Column ───────────────────────────────────
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SpSectionHeader(title: 'Staff & Team Directory'),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.adminEmployees),
                    child: Text('View all staff',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.gold400)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _DashboardEmployeesColumn(),

              // ── Recent Activity ─────────────────────────────────────────
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SpSectionHeader(title: 'Recent Activity'),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.notifications),
                    child: Text('See all',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.gold400)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_recent.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.navy800,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.navy700),
                  ),
                  child: Center(
                    child: Text(
                      'No recent activity recorded yet',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey500),
                    ),
                  ),
                )
              else
                ..._recent.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActivityTile(ra: e.value, delay: e.key * 70),
                    )),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── More Menu Tab ────────────────────────────────────────────────────────────
class _MoreMenu extends StatelessWidget {
  final ValueChanged<int> onNavigateTab;
  const _MoreMenu({required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(title: const Text('More Options & Modules')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // SolarPro Brand banner
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2838), Color(0xFF131C28)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.gold500.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold500.withValues(alpha: 0.3),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(AppAssets.logo, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SolarPro Enterprise', style: AppTextStyles.headlineSmall),
                      const SizedBox(height: 2),
                      Text('v1.0.0 • Solar Energy & Client Suite',
                          style: AppTextStyles.caption.copyWith(color: AppColors.gold400)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 250.ms),

          // Menu items
          _MenuItemCard(
            label: 'Staff & Employees Directory',
            icon: Icons.badge_rounded,
            color: AppColors.gold500,
            onTap: () => context.push(AppRoutes.adminEmployees),
          ),
          const SizedBox(height: 10),
          _MenuItemCard(
            label: 'User & Staff Registration Approvals',
            icon: Icons.how_to_reg_rounded,
            color: AppColors.orange500,
            onTap: () => context.push(AppRoutes.adminApprovals),
          ),
          const SizedBox(height: 10),
          _MenuItemCard(
            label: 'Payment Manager & Receipts',
            icon: Icons.payments_rounded,
            color: AppColors.gold500,
            onTap: () => context.push(AppRoutes.payments),
          ),
          const SizedBox(height: 10),
          _MenuItemCard(
            label: 'Work Assignments & Teams',
            icon: Icons.construction_rounded,
            color: AppColors.orange500,
            onTap: () => context.push(AppRoutes.workAssign),
          ),
          const SizedBox(height: 10),
          _MenuItemCard(
            label: 'KEDL & Net Metering Tracker',
            icon: Icons.description_rounded,
            color: AppColors.purple500,
            onTap: () => context.push(AppRoutes.kedl),
          ),
          const SizedBox(height: 10),
          _MenuItemCard(
            label: 'Stock Inventory & Items',
            icon: Icons.inventory_2_rounded,
            color: AppColors.info,
            onTap: () => onNavigateTab(3),
          ),
          const SizedBox(height: 10),
          _MenuItemCard(
            label: 'Customer Support Tickets',
            icon: Icons.support_agent_rounded,
            color: AppColors.error,
            onTap: () => context.push(AppRoutes.serviceTickets),
          ),
          const SizedBox(height: 10),
          _MenuItemCard(
            label: 'Notifications & Alerts',
            icon: Icons.notifications_rounded,
            color: AppColors.warning,
            onTap: () => context.push(AppRoutes.notifications),
          ),
          const SizedBox(height: 24),

          // Logout Button
          GestureDetector(
            onTap: () => _showAdminLogoutDialog(context),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Text('Log Out',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.error)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuItemCard({
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.navy800,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.grey100)),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey600),
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
  final int delay;
  final String? badgeText;

  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.delay,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
                  style: AppTextStyles.caption
                      .copyWith(fontSize: 10, color: AppColors.grey200),
                ),
              ],
            ),
          ),
          if (badgeText != null)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.orange500,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.navy900, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange500.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  badgeText!,
                  style: const TextStyle(
                    color: AppColors.fg,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }
}

class _RA {
  final String title, subtitle, time, route;
  final IconData icon;
  final Color iconColor;
  const _RA(this.title, this.subtitle, this.time, this.icon, this.iconColor, this.route);
}

class _ActivityTile extends StatelessWidget {
  final _RA ra;
  final int delay;
  const _ActivityTile({required this.ra, required this.delay});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(ra.route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.navy800,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.navy600),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: ra.iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Icon(ra.icon, color: ra.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ra.title, style: AppTextStyles.labelLarge),
                  const SizedBox(height: 2),
                  Text(ra.subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Text(ra.time, style: AppTextStyles.caption),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.1, end: 0);
  }
}

class _PipeRow extends StatelessWidget {
  final String label, route;
  final int count, delay;
  final Color color;
  final IconData icon;
  const _PipeRow({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.route,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.navy800,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.grey200)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text('$count',
                  style: AppTextStyles.labelMedium.copyWith(color: color)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.grey600, size: 18),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.06, end: 0);
  }
}


class _DashboardEmployeesColumn extends StatefulWidget {
  const _DashboardEmployeesColumn();

  @override
  State<_DashboardEmployeesColumn> createState() => _DashboardEmployeesColumnState();
}

class _DashboardEmployeesColumnState extends State<_DashboardEmployeesColumn> {
  bool _isLoading = true;
  List<AdminEmployee> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final list = await ApiClient().getEmployees();
      if (mounted) {
        setState(() {
          _employees = list.map((e) => AdminEmployee.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppColors.gold500, strokeWidth: 2),
      );
    }

    if (_employees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.navy800,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.navy700),
        ),
        child: Center(
          child: Text(
            'No staff members found in database',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey500),
          ),
        ),
      );
    }

    return Column(
      children: _employees.take(4).map((emp) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.navy800,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.navy700),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () {
                EmployeeTaskDetailSheet.show(
                  context,
                  employee: emp,
                  onTasksChanged: _loadEmployees,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: emp.roleColor.withValues(alpha: 0.15),
                      child: Text(
                        emp.name.isNotEmpty ? emp.name.substring(0, 1).toUpperCase() : 'E',
                        style: TextStyle(
                          color: emp.roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  emp.name,
                                  style: const TextStyle(
                                    color: AppColors.fg,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.navy700,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  emp.employeeNo,
                                  style: const TextStyle(
                                    color: AppColors.gold400,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${emp.roleDisplayName} • ${emp.team}',
                            style: TextStyle(
                              color: emp.roleColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: emp.taskCount > 0
                            ? AppColors.gold500.withValues(alpha: 0.15)
                            : AppColors.navy700,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: emp.taskCount > 0
                              ? AppColors.gold500.withValues(alpha: 0.4)
                              : AppColors.navy600,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.task_alt_rounded,
                            size: 11,
                            color: emp.taskCount > 0 ? AppColors.gold400 : AppColors.grey400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            emp.taskCount > 0 ? '${emp.taskCount} tasks' : 'No tasks',
                            style: TextStyle(
                              color: emp.taskCount > 0 ? AppColors.gold400 : AppColors.grey400,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.grey500),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
