import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/features/employee/common/employee_shell.dart';
import 'helpers/fake_backend.dart';

void main() {
  testWidgets('Service portal shell shows the signed-in employee', (WidgetTester tester) async {
    FakeBackend.install();
    SharedPreferences.setMockInitialValues({
      AppConstants.kAccessToken: 'mock_jwt_token',
      AppConstants.kUserId: 'emp-srv-104',
      AppConstants.kUserName: 'Vikram Singh',
      AppConstants.kUserPhone: '9829054321',
      'user_email': 'vikram.singh@solarpro.in',
      AppConstants.kUserRole: 'technician',
      'user_team': 'Service & Maintenance Team A',
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: EmployeeShell(portalType: EmployeePortalType.service),
      ),
    );

    // Let the saved profile load from SharedPreferences.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Header greets the employee by first name and names the portal.
    expect(find.text('Hi, Vikram'), findsOneWidget);
    expect(find.textContaining('Service Desk'), findsOneWidget);

    // Unmount and let pending work (API calls, animations) finish.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
