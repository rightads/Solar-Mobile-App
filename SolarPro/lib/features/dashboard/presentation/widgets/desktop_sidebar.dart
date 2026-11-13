import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_pro/shared/widgets/change_password_sheet.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class DesktopSidebarItem {
  final IconData icon;
  final String label;
  final String? badge;
  final Color? badgeColor;

  const DesktopSidebarItem({
    required this.icon,
    required this.label,
    this.badge,
    this.badgeColor,
  });
}

class DesktopSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  String _adminName = 'Administrator';

  String get _initials {
    final parts = _adminName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'A';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }


  int _pendingApprovalsCount = 0;

  bool get isCollapsed => widget.isCollapsed;
  int get selectedIndex => widget.selectedIndex;
  ValueChanged<int> get onSelect => widget.onSelect;
  VoidCallback? get onToggleCollapse => widget.onToggleCollapse;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final name = prefs.getString(AppConstants.kUserName);
      if (mounted && name != null && name.isNotEmpty) setState(() => _adminName = name);
    });
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    try {
      final list = await ApiClient().getPendingApprovals(status: 'pending');
      if (mounted) setState(() => _pendingApprovalsCount = list.length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final double width = widget.isCollapsed ? 76.0 : 250.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4FD),
        border: Border(
          right: BorderSide(
            color: AppColors.fg.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // ── App Brand Header ───────────────────────────────────────────────
          Container(
            height: 72,
            padding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 12 : 18),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.fg.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold500.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(AppAssets.logo, fit: BoxFit.cover),
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'SolarPro',
                          style: AppTextStyles.headlineSmall.copyWith(
                            color: AppColors.fg,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Local Server Active',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.gold400,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onToggleCollapse != null)
                    IconButton(
                      icon: const Icon(Icons.menu_open_rounded, size: 20, color: AppColors.grey500),
                      onPressed: onToggleCollapse,
                      tooltip: 'Collapse sidebar',
                    ),
                ],
              ],
            ),
          ),

          // ── Navigation List ────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              children: [
                _buildSectionHeader('CORE OVERVIEW'),
                _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard', null),
                _buildNavItem(1, Icons.people_rounded, 'Leads Pipeline', '12', AppColors.teal500),
                _buildNavItem(2, Icons.person_rounded, 'Customers', '48', AppColors.gold500),

                const SizedBox(height: 16),
                _buildSectionHeader('OPERATIONS'),
                _buildNavItem(3, Icons.payments_rounded, 'Payments & Accounts', '3 Pending', AppColors.warning),
                _buildNavItem(4, Icons.construction_rounded, 'Work Assignments', null),
                _buildNavItem(5, Icons.description_rounded, 'KEDL Net Metering', '4 Files', AppColors.purple500),
                _buildNavItem(6, Icons.inventory_2_rounded, 'Inventory & Stock', null),
                _buildNavItem(7, Icons.support_agent_rounded, 'Service Tickets', '7 Open', AppColors.error),

                const SizedBox(height: 16),
                _buildActionItem(
                  icon: Icons.badge_rounded,
                  label: 'Staff Directory',
                  color: AppColors.teal500,
                  onTap: () => context.push(AppRoutes.adminEmployees),
                ),
                const SizedBox(height: 8),
                _buildActionItem(
                  icon: Icons.verified_user_rounded,
                  label: 'User Approvals',
                  color: AppColors.orange500,
                  badge: _pendingApprovalsCount > 0 ? '$_pendingApprovalsCount New' : null,
                  badgeColor: AppColors.orange500,
                  onTap: () async {
                    await context.push(AppRoutes.adminApprovals);
                    _loadPendingCount();
                  },
                ),
                const SizedBox(height: 8),
                _buildActionItem(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  color: AppColors.warning,
                  onTap: () => context.push(AppRoutes.notifications),
                ),
              ],
            ),
          ),

          // ── Bottom User Profile Card ───────────────────────────────────────
          Container(
            padding: EdgeInsets.all(isCollapsed ? 10 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1728),
              border: Border(
                top: BorderSide(
                  color: AppColors.fg.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: isCollapsed ? 18 : 20,
                  backgroundColor: AppColors.gold500.withValues(alpha: 0.2),
                  child: Text(_initials,
                      style: TextStyle(color: AppColors.gold400, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _adminName,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.fg,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'SolarPro Administrator',
                          style: AppTextStyles.caption.copyWith(color: AppColors.grey500, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.key_rounded, size: 18, color: AppColors.grey500),
                    tooltip: 'Change Password',
                    onPressed: () => showChangePasswordSheet(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                    tooltip: 'Log Out',
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final router = GoRouter.of(context);
                      await ApiClient().logout();
                      router.go(AppRoutes.login);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Logged out successfully'),
                          backgroundColor: AppColors.navy700,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    if (isCollapsed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(color: AppColors.fg10),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.grey600,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    String? badge, [
    Color? badgeColor,
  ]) {
    final bool isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelect(index),
          hoverColor: AppColors.gold500.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 12 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.gold500.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.gold500.withValues(alpha: 0.4)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppColors.gold400 : AppColors.grey500,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? AppColors.fg : AppColors.grey400,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontFamily: 'Outfit',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? AppColors.grey600).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: (badgeColor ?? AppColors.grey600).withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: badgeColor ?? AppColors.grey400,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          hoverColor: color.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 19, color: color),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? color).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: (badgeColor ?? color).withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: badgeColor ?? color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.grey600),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
