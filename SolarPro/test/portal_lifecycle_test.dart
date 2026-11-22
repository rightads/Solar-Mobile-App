import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/features/client/presentation/screens/client_dashboard_screen.dart';
import 'package:solar_pro/features/customers/presentation/screens/customers_screen.dart';
import 'package:solar_pro/features/employee/common/employee_shell.dart';
import 'package:solar_pro/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:solar_pro/features/kedl/presentation/screens/kedl_screen.dart';
import 'package:solar_pro/features/leads/presentation/screens/leads_screen.dart';
import 'package:solar_pro/features/payments/presentation/screens/payments_screen.dart';
import 'package:solar_pro/features/work_assignment/presentation/screens/work_assignment_screen.dart';
import 'helpers/fake_backend.dart';

/// Every post-login home screen: load, visit each bottom tab, then leave.
/// Guards against "'_dependents.isEmpty': is not true" style crashes.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _expectNoError(WidgetTester tester, String where) {
  for (Object? e = tester.takeException(); e != null; e = tester.takeException()) {
    if (e is FlutterError && e.toString().contains('overflowed')) continue; // test font artefact
    fail('$where: $e');
  }
}

Future<void> _exercise(WidgetTester tester, Widget home, String name, String role) async {
  FakeBackend.install();
  SharedPreferences.setMockInitialValues({
    AppConstants.kAccessToken: 'mock_jwt_token',
    AppConstants.kUserId: 'u-1',
    AppConstants.kUserName: 'Test User',
    AppConstants.kUserRole: role,
  });
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  // Widget tests draw text in a wide block font, so rows "overflow" that fit
  // on real phones. Drop only those reports; every other error still fails.
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
  await tester.pumpWidget(MaterialApp(home: home));
  await _settle(tester);
  _expectNoError(tester, '$name load');
  for (final label in ['Leads', 'Customers', 'Payments', 'My Jobs', 'Calendar', 'Files', 'Demands', 'Tickets',
      'Serials', 'Projects', 'More', 'Status', 'Home']) {
    final f = find.text(label);
    if (f.evaluate().isEmpty) continue;
    await tester.tap(f.last, warnIfMissed: false);
    await _settle(tester);
    _expectNoError(tester, '$name → $label');
  }
  await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  await _settle(tester);
  _expectNoError(tester, '$name leave');
}

void main() {
  for (final p in EmployeePortalType.values) {
    testWidgets('employee portal ${p.name}', (tester) async {
      await _exercise(tester, EmployeeShell(portalType: p), p.name,
          {'salesman': 'sales', 'site': 'site', 'kedl': 'kedl', 'service': 'service', 'desk': 'subsidy'}[p.name]!);
    });
  }
  testWidgets('employee portal desk (account / bill)', (tester) async {
    await _exercise(tester, const EmployeeShell(portalType: EmployeePortalType.desk), 'desk-account', 'account');
  });
  final vendorScreens = <String, Widget>{
    'vendor leads': const LeadsScreen(),
    'vendor customers': const CustomersScreen(),
    'vendor payments': const PaymentsScreen(),
    'vendor site work': const WorkAssignmentScreen(),
    'vendor kedl': const KedlScreen(),
    'vendor inventory': const InventoryScreen(),
  };
  vendorScreens.forEach((name, screen) {
    testWidgets(name, (tester) async {
      await _exercise(tester, screen, name, 'vendor');
    });
  });
  testWidgets('client dashboard', (tester) async {
    await _exercise(tester, const ClientDashboardScreen(), 'client', 'client');
  });
}
