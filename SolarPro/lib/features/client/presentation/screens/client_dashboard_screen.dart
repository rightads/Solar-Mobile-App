import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/client/data/models/client_dashboard_model.dart';
import 'package:solar_pro/features/client/data/repositories/client_repository.dart';
import 'package:solar_pro/features/client/presentation/widgets/client_payments_tab.dart';
import 'package:solar_pro/features/client/presentation/widgets/client_status_tab.dart';
import 'package:solar_pro/features/client/presentation/widgets/client_tickets_tab.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  int _selectedIndex = 0;
  String _userName = 'Solar Client';

  final _clientRepo = ClientRepository();
  bool _isLoading = true;

  Map<String, dynamic>? _homeData;
  List<ClientPaymentRecord> _payments = [];
  List<ClientTicketRecord> _tickets = [];
  AssignedEmployeeInfo? _assignedEmployee;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadDashboardData();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Aryan Jadaun';
      });
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final home = await _clientRepo.getClientHomeData();
      final payList = await _clientRepo.getPayments();
      final ticList = await _clientRepo.getTickets();

      AssignedEmployeeInfo? emp;
      if (home['responsible_contact'] is Map) {
        emp = AssignedEmployeeInfo.fromJson(
            Map<String, dynamic>.from(home['responsible_contact'] as Map));
      } else if (home['sales_contact'] is Map) {
        emp = AssignedEmployeeInfo.fromJson(
            Map<String, dynamic>.from(home['sales_contact'] as Map));
      }

      if (mounted) {
        setState(() {
          _homeData = home;
          _payments = payList;
          _tickets = ticList;
          _assignedEmployee = emp;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onPaymentSubmitted(ClientPaymentRecord record) {
    setState(() {
      _payments.insert(0, record);
    });
  }

  void _onTicketCreated(ClientTicketRecord record) {
    setState(() {
      _tickets.insert(0, record);
    });
  }

  void _logout(BuildContext context) {
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
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to log out of your client solar portal?',
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
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: () async {
              final router = GoRouter.of(context);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                router.go(AppRoutes.login);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Logged out successfully'),
                    backgroundColor: AppColors.navy700,
                  ),
                );
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasOfficer = _assignedEmployee != null && _assignedEmployee!.employeeNo.isNotEmpty;
    final empNo = hasOfficer ? _assignedEmployee!.employeeNo : '';

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        backgroundColor: AppColors.navy900,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold500.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(AppAssets.logo, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Client Portal',
                    style: AppTextStyles.caption.copyWith(color: AppColors.gold400, fontWeight: FontWeight.bold)),
                Text(_userName,
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.white)),
              ],
            ),
          ],
        ),
        actions: [
          // Assigned Employee indicator pill in app bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: hasOfficer ? AppColors.gold500.withValues(alpha: 0.4) : AppColors.grey700,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasOfficer ? Icons.badge_outlined : Icons.person_outline_rounded,
                  color: hasOfficer ? AppColors.gold500 : AppColors.grey400,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  hasOfficer ? empNo : 'Awaiting Officer',
                  style: TextStyle(
                    color: hasOfficer ? AppColors.gold400 : AppColors.grey400,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
            tooltip: 'Log Out',
            onPressed: () => _logout(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: _ClientBottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold500),
            )
          : IndexedStack(
              index: _selectedIndex,
              children: [
                // 1) Status with Employee No.
                ClientStatusTab(
                  homeData: _homeData,
                  assignedEmployee: _assignedEmployee,
                  onRefresh: _loadDashboardData,
                  onOpenPayment: () => setState(() => _selectedIndex = 1),
                  onOpenTicket: () => setState(() => _selectedIndex = 2),
                ),

                // 2) Payment Submit with Photo approved by Salesman
                ClientPaymentsTab(
                  paymentSummary: _homeData?['payment_summary'] as Map<String, dynamic>?,
                  payments: _payments,
                  salesRep: _assignedEmployee,
                  onPaymentSubmitted: _onPaymentSubmitted,
                ),

                // 3) Raise service ticket (Structure 2-10 photos, Wiring, Inverter)
                ClientTicketsTab(
                  tickets: _tickets,
                  onTicketCreated: _onTicketCreated,
                ),
              ],
            ),
    );
  }
}

class _ClientBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _ClientBottomNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navy800,
        border: Border(top: BorderSide(color: AppColors.navy700, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                label: 'Status & Emp ID',
                icon: Icons.assignment_turned_in_rounded,
                activeColor: AppColors.gold500,
              ),
              _buildNavItem(
                index: 1,
                label: 'Pay & Salesman',
                icon: Icons.payments_rounded,
                activeColor: AppColors.teal400,
              ),
              _buildNavItem(
                index: 2,
                label: 'Service Tickets',
                icon: Icons.support_agent_rounded,
                activeColor: AppColors.orange500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : AppColors.grey500,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? activeColor : AppColors.grey500,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
