import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/features/auth/presentation/screens/splash_screen.dart';
import 'package:solar_pro/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:solar_pro/features/auth/presentation/screens/login_screen.dart';
import 'package:solar_pro/features/auth/presentation/screens/otp_screen.dart';
import 'package:solar_pro/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:solar_pro/features/dashboard/presentation/screens/vendor_dashboard_screen.dart';
import 'package:solar_pro/features/leads/presentation/screens/leads_screen.dart';
import 'package:solar_pro/features/customers/presentation/screens/customers_screen.dart';
import 'package:solar_pro/features/customers/presentation/screens/customer_detail_screen.dart';
import 'package:solar_pro/features/payments/presentation/screens/payments_screen.dart';
import 'package:solar_pro/features/work_assignment/presentation/screens/work_assignment_screen.dart';
import 'package:solar_pro/features/kedl/presentation/screens/kedl_screen.dart';
import 'package:solar_pro/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:solar_pro/features/tickets/presentation/screens/tickets_screen.dart';
import 'package:solar_pro/features/client/presentation/screens/client_dashboard_screen.dart';
import 'package:solar_pro/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:solar_pro/features/admin/presentation/screens/admin_approvals_screen.dart';
import 'package:solar_pro/features/admin/employees/screens/admin_employees_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/services/session_store.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/features/employee/common/employee_shell.dart';
import 'package:solar_pro/features/employee/common/unsupported_role_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  late final GoRouter router;
  // When a session can no longer be refreshed, send the user back to sign in.
  ApiClient.onSessionExpired = () => router.go(AppRoutes.login);
  router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) async {
      final path = state.uri.path;

      // Public auth routes
      if (path == AppRoutes.login ||
          path == AppRoutes.otp ||
          path == AppRoutes.resetPassword ||
          path == AppRoutes.splash ||
          path == AppRoutes.onboarding) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final hasSession = await SessionStore.hasSession();
      final role = prefs.getString(AppConstants.kUserRole)?.toLowerCase();
      final team = prefs.getString('user_team_type') ?? prefs.getString('user_team');

      // If not authenticated, force login
      if (!hasSession) {
        return AppRoutes.login;
      }

      final isVendorRoute = path.startsWith('/vendor') || path.startsWith('/admin');
      final isClientRoute = path.startsWith('/client');
      final isEmployeeRoute = path.startsWith('/employee');

      final isAdminRole = (role == 'admin' || role == 'manager' || role == 'vendor');
      final isClientRole = (role == 'client');
      final isEmployeeRole = (role == 'sales' ||
          role == 'salesman' ||
          role == 'employee' ||
          role == 'office_staff' ||
          role == 'kedl' ||
          role == 'service' ||
          role == 'technician' ||
          role == 'site' ||
          role == 'labour' ||
          role == 'electrician' ||
          role == 'structure' ||
          role == 'civil');

      // Unauthorized vendor access
      if (isVendorRoute && !isAdminRole) {
        return resolveRoleHomeRoute(role, teamType: team);
      }

      // Unauthorized client access
      if (isClientRoute && !isClientRole) {
        return resolveRoleHomeRoute(role, teamType: team);
      }

      // Unauthorized employee access or wrong employee sub-portal
      if (isEmployeeRoute) {
        if (!isEmployeeRole) {
          return resolveRoleHomeRoute(role, teamType: team);
        }
        final targetHome = resolveRoleHomeRoute(role, teamType: team);
        if (!path.startsWith(targetHome) && targetHome.startsWith('/employee/')) {
          return targetHome;
        }
      }

      return null;
    },
    routes: [
      // ── Auth ─────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => ResetPasswordScreen(token: state.uri.queryParameters['token'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpScreen(phone: phone);
        },
      ),

      // ── Vendor / Admin Shell ───────────────────────────────────────────
      GoRoute(
        path: AppRoutes.vendorDash,
        builder: (context, state) => const VendorDashboardScreen(),
      ),

      // ── Dedicated Leads & Customers Screens ────────────────────────────
      GoRoute(
        path: AppRoutes.leads,
        builder: (context, state) => const LeadsScreen(),
      ),
      GoRoute(
        path: AppRoutes.customers,
        builder: (context, state) => const CustomersScreen(),
      ),

      // ── Customer detail ───────────────────────────────────────────────
      GoRoute(
        path: '/vendor/customers/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CustomerDetailScreen(customerId: id);
        },
      ),

      // ── Feature screens ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.payments,
        builder: (context, state) => const PaymentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.workAssign,
        builder: (context, state) => const WorkAssignmentScreen(),
      ),
      GoRoute(
        path: AppRoutes.kedl,
        builder: (context, state) => const KedlScreen(),
      ),
      GoRoute(
        path: AppRoutes.inventory,
        builder: (context, state) => const InventoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.serviceTickets,
        builder: (context, state) => const TicketsScreen(),
      ),

      // ── Client portal ─────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.clientDash,
        builder: (context, state) => const ClientDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.clientTickets,
        builder: (context, state) => const TicketsScreen(),
      ),

      // ── Employee Portal ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.employeeSalesman,
        builder: (context, state) => const EmployeeShell(
          portalType: EmployeePortalType.salesman,
        ),
      ),
      GoRoute(
        path: AppRoutes.employeeSite,
        builder: (context, state) => const EmployeeShell(
          portalType: EmployeePortalType.site,
        ),
      ),
      GoRoute(
        path: AppRoutes.employeeKedl,
        builder: (context, state) => const EmployeeShell(
          portalType: EmployeePortalType.kedl,
        ),
      ),
      GoRoute(
        path: AppRoutes.employeeService,
        builder: (context, state) => const EmployeeShell(
          portalType: EmployeePortalType.service,
        ),
      ),
      GoRoute(
        path: AppRoutes.unsupportedRole,
        builder: (context, state) {
          final role = state.extra as String?;
          return UnsupportedRoleScreen(role: role);
        },
      ),

      // ── Shared & Admin ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminApprovals,
        builder: (context, state) => const AdminApprovalsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminEmployees,
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          return AdminEmployeesScreen(initialTrade: tab);
        },
      ),
    ],


    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFFF6F4FD),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFF7A21B), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Page not found',
              style: TextStyle(
                  color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.message ?? '',
              style: const TextStyle(color: Color(0xFF8A84AE), fontSize: 12),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go(AppRoutes.vendorDash),
              child: const Text('Go to Dashboard',
                  style: TextStyle(color: Color(0xFFF7A21B))),
            ),
          ],
        ),
      ),
    ),
  );
  return router;
});
