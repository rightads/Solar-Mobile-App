import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:solar_pro/shared/widgets/sp_greeting_header.dart';
import 'package:solar_pro/shared/animations/motion.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/common/employee_empty_placeholder.dart';
import 'package:solar_pro/features/employee/salesman/customers/salesman_customers_tab.dart';
import 'package:solar_pro/features/employee/salesman/home/salesman_home_tab.dart';
import 'package:solar_pro/features/employee/salesman/leads/salesman_leads_tab.dart';
import 'package:solar_pro/features/employee/salesman/payments/salesman_payments_tab.dart';
import 'package:solar_pro/features/employee/kedl/presentation/tabs/kedl_demands_tab.dart';
import 'package:solar_pro/features/employee/kedl/presentation/tabs/kedl_files_tab.dart';
import 'package:solar_pro/features/employee/kedl/presentation/tabs/kedl_home_tab.dart';
import 'package:solar_pro/features/employee/service/presentation/tabs/service_home_tab.dart';
import 'package:solar_pro/features/employee/service/presentation/tabs/service_serial_lookup_tab.dart';
import 'package:solar_pro/features/employee/service/presentation/tabs/service_tickets_tab.dart';
import 'package:solar_pro/core/services/shared_upload_service.dart';
import 'package:solar_pro/core/utils/permission_helper.dart';
import 'package:solar_pro/features/employee/common/pending_sync_screen.dart';
import 'package:solar_pro/features/employee/site_work/presentation/tabs/site_calendar_tab.dart';
import 'package:solar_pro/features/employee/site_work/presentation/tabs/site_home_tab.dart';
import 'package:solar_pro/features/employee/site_work/presentation/tabs/site_my_jobs_tab.dart';
import 'package:solar_pro/shared/widgets/sp_bottom_nav.dart';


enum EmployeePortalType {
  salesman,
  site,
  kedl,
  service,
}

class EmployeeShell extends StatefulWidget {
  final EmployeePortalType portalType;

  const EmployeeShell({
    super.key,
    required this.portalType,
  });

  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  int _currentIndex = 0;
  String _userName = 'Employee';
  String _userPhone = '';
  String _userRole = '';
  String _userTeam = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void didUpdateWidget(covariant EmployeeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.portalType != widget.portalType) {
      _loadUserInfo();
    }
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final role = prefs.getString(AppConstants.kUserRole) ?? widget.portalType.name;
      String? name = prefs.getString(AppConstants.kUserName);
      if (name == null || name.trim().isEmpty || name.trim().toLowerCase() == 'employee') {
        name = prefs.getString('user_name') ??
               prefs.getString('name') ??
               prefs.getString('userName');
      }
      if (name == null || name.trim().isEmpty || name.trim().toLowerCase() == 'employee') {
        final rawUser = prefs.getString('user_data') ?? prefs.getString('user');
        if (rawUser != null && rawUser.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawUser);
            if (decoded is Map<String, dynamic>) {
              name = decoded['name'] ?? decoded['full_name'] ?? decoded['fullName'] ?? decoded['username'];
            }
          } catch (_) {}
        }
      }

      final resolvedName = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Employee';
      if (resolvedName != 'Employee') {
        await prefs.setString(AppConstants.kUserName, resolvedName);
      }

      setState(() {
        _userName = resolvedName;
        _userPhone = prefs.getString(AppConstants.kUserPhone) ?? '';
        _userRole = role;
        _userTeam = prefs.getString('user_team') ?? _getDefaultTeam(widget.portalType, role);
      });
    }
  }

  String _getDefaultTeam(EmployeePortalType portal, String role) {
    final r = role.toLowerCase();
    switch (portal) {
      case EmployeePortalType.salesman:
        return 'Solar Sales Executive Division';
      case EmployeePortalType.site:
        if (r.contains('elec')) return 'Electrical Installation Team';
        if (r.contains('struc')) return 'Structure & Mounts Team';
        if (r.contains('civil')) return 'Civil Foundation Team';
        return 'Field Operations Team';
      case EmployeePortalType.kedl:
        return 'KEDL Discom Liason Division';
      case EmployeePortalType.service:
        return 'Field Service & Warranty Desk';
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Confirm Logout',
          style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to log out of your employee account?',
          style: TextStyle(color: AppColors.grey400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.grey400)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.fg,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ApiClient().logout();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon 👋';
    return 'Good Evening 👋';
  }

  List<SpNavItem> _buildNavItems() {
    switch (widget.portalType) {
      case EmployeePortalType.salesman:
        return const [
          SpNavItem(icon: Icons.dashboard_rounded, label: 'Home'),
          SpNavItem(icon: Icons.people_rounded, label: 'Leads'),
          SpNavItem(icon: Icons.person_rounded, label: 'Customers'),
          SpNavItem(icon: Icons.payments_rounded, label: 'Payments'),
          SpNavItem(icon: Icons.menu_rounded, label: 'More'),
        ];
      case EmployeePortalType.site:
        return const [
          SpNavItem(icon: Icons.dashboard_rounded, label: 'Home'),
          SpNavItem(icon: Icons.assignment_rounded, label: 'My Jobs'),
          SpNavItem(icon: Icons.calendar_month_rounded, label: 'Calendar'),
          SpNavItem(icon: Icons.menu_rounded, label: 'More'),
        ];
      case EmployeePortalType.kedl:
        return const [
          SpNavItem(icon: Icons.dashboard_rounded, label: 'Home'),
          SpNavItem(icon: Icons.folder_shared_rounded, label: 'Files'),
          SpNavItem(icon: Icons.receipt_long_rounded, label: 'Demands'),
          SpNavItem(icon: Icons.menu_rounded, label: 'More'),
        ];
      case EmployeePortalType.service:
        return const [
          SpNavItem(icon: Icons.dashboard_rounded, label: 'Home'),
          SpNavItem(icon: Icons.confirmation_number_rounded, label: 'Tickets'),
          SpNavItem(icon: Icons.qr_code_scanner_rounded, label: 'Serials'),
          SpNavItem(icon: Icons.menu_rounded, label: 'More'),
        ];
    }
  }

  String _getPortalTitle() {
    switch (widget.portalType) {
      case EmployeePortalType.salesman:
        return 'Sales Executive';
      case EmployeePortalType.site:
        return 'Site Operations';
      case EmployeePortalType.kedl:
        return 'KEDL Discom';
      case EmployeePortalType.service:
        return 'Service Desk';
    }
  }

  Widget _buildBody(int tabIndex) {
    // If last tab is profile
    final navItems = _buildNavItems();
    if (tabIndex == navItems.length - 1) {
      return _buildProfileTab();
    }

    switch (widget.portalType) {
      case EmployeePortalType.salesman:
        switch (tabIndex) {
          case 0:
            return SalesmanHomeTab(
              onNavigateTab: (index) => setState(() => _currentIndex = index),
            );
          case 1:
            return const SalesmanLeadsTab();

          case 2:
            return SalesmanCustomersTab(
              onNavigateTab: (index) => setState(() => _currentIndex = index),
            );
          case 3:
            return const SalesmanPaymentsTab();
        }
        break;

      case EmployeePortalType.site:
        switch (tabIndex) {
          case 0:
            return SiteHomeTab(
              onNavigateTab: (index) => setState(() => _currentIndex = index),
            );
          case 1:
            return const SiteMyJobsTab();
          case 2:
            return const SiteCalendarTab();
        }
        break;

      case EmployeePortalType.kedl:
        switch (tabIndex) {
          case 0:
            return KedlHomeTab(
              onNavigateTab: (index) => setState(() => _currentIndex = index),
            );
          case 1:
            return const KedlFilesTab();
          case 2:
            return const KedlDemandsTab();
        }
        break;

      case EmployeePortalType.service:
        switch (tabIndex) {
          case 0:
            return ServiceHomeTab(
              onNavigateTab: (index) => setState(() => _currentIndex = index),
            );
          case 1:
            return const ServiceTicketsTab();
          case 2:
            return const ServiceSerialLookupTab();
        }
        break;
    }

    return const EmployeeEmptyPlaceholder(
      title: 'Section Coming Soon',
      description: 'This feature will be enabled in the upcoming release.',
    );
  }

  void _showPermissionsSheet(BuildContext sheetContext) {
    showModalBottomSheet(
      context: sheetContext,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Field Device Permissions',
              style: TextStyle(color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Permissions required for site operations, documentation and instant alerts.',
              style: TextStyle(color: AppColors.grey400, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...PermissionType.values.map((p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(p.icon, color: AppColors.gold500),
                  title: Text(p.title, style: const TextStyle(color: AppColors.fg, fontSize: 14)),
                  subtitle: Text(
                    p.rationale,
                    style: const TextStyle(color: AppColors.grey500, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final granted = await PermissionHelper.requestPermission(sheetContext, p);
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(
                            content: Text(granted ? '${p.title} granted!' : '${p.title} access required for field features.'),
                            backgroundColor: granted ? AppColors.teal500 : AppColors.error,
                          ),
                        );
                      }
                    },
                    child: const Text('Configure', style: TextStyle(color: AppColors.gold400, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final uploadService = SharedUploadService();
    final pendingCount = uploadService.pendingCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.navy600),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.gold500.withValues(alpha: 0.2),
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : 'E',
                    style: const TextStyle(
                      color: AppColors.gold500,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: AppColors.fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userPhone.isNotEmpty ? _userPhone : 'Employee Profile',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.grey400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.gold500.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              _userRole.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.gold400,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.teal500.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              _userTeam,
                              style: const TextStyle(
                                color: AppColors.teal400,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.navy600),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_sync_rounded, color: AppColors.gold500),
                  title: const Text('Offline Sync & Pending Uploads', style: TextStyle(color: AppColors.fg)),
                  subtitle: Text(
                    pendingCount > 0 ? '$pendingCount upload(s) pending sync' : 'All items synced to cloud',
                    style: TextStyle(
                      color: pendingCount > 0 ? AppColors.gold400 : AppColors.grey500,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.grey500),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PendingSyncScreen()),
                  ),
                ),
                const Divider(height: 1, color: AppColors.navy600),
                ListTile(
                  leading: const Icon(Icons.tune_rounded, color: AppColors.gold500),
                  title: const Text('Field Device Permissions', style: TextStyle(color: AppColors.fg)),
                  subtitle: const Text('Camera, Gallery, Location & Alerts', style: TextStyle(color: AppColors.grey500, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.grey500),
                  onTap: () => _showPermissionsSheet(context),
                ),
                const Divider(height: 1, color: AppColors.navy600),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined, color: AppColors.gold500),
                  title: const Text('Notifications', style: TextStyle(color: AppColors.fg)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.grey500),
                  onTap: () => context.push(AppRoutes.notifications),
                ),
                const Divider(height: 1, color: AppColors.navy600),
                ListTile(
                  leading: const Icon(Icons.security_rounded, color: AppColors.gold500),
                  title: const Text('Security & Session', style: TextStyle(color: AppColors.fg)),
                  subtitle: const Text('JWT authenticated tokens stored securely', style: TextStyle(color: AppColors.grey500, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error.withValues(alpha: 0.15),
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar(BuildContext context) {
    return SpGreetingHeader(
      name: _userName == 'Employee' ? '' : _userName,
      role: '${_getTimeGreeting().replaceAll('👋', '').trim()} · ${_getPortalTitle()}',
      onBell: () => context.push(AppRoutes.notifications),
      onLogout: _logout,
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _buildNavItems();
    final safeIndex = _currentIndex.clamp(0, navItems.length - 1);

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: _buildTopAppBar(context),
      body: SpEntrance(
        key: ValueKey(safeIndex),
        from: const Offset(0, 18),
        child: _buildBody(safeIndex),
      ),
      bottomNavigationBar: SpBottomNav(
        selectedIndex: safeIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: navItems,
      ),
    );
  }
}
