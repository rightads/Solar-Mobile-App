import 'package:flutter/material.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/shared/widgets/sp_greeting_header.dart';
import 'package:solar_pro/shared/animations/motion.dart';
import 'package:solar_pro/shared/widgets/sp_bottom_nav.dart';
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
        _userName = prefs.getString('user_name') ?? 'Client';
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
          style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold),
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
              foregroundColor: AppColors.fg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: () async {
              final router = GoRouter.of(context);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              await ApiClient().logout();
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
      appBar: SpGreetingHeader(
        name: _userName,
        role: 'Client',
        badge: hasOfficer ? empNo : 'Awaiting officer',
        onBell: () => context.push(AppRoutes.notifications),
        onLogout: () => _logout(context),
      ),
      bottomNavigationBar: SpBottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          SpNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'My Project'),
          SpNavItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Payments'),
          SpNavItem(icon: Icons.support_agent_outlined, activeIcon: Icons.support_agent_rounded, label: 'Support'),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold500),
            )
          : SpAnimatedIndexedStack(
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


