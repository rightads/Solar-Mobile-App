import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/features/employee/common/employee_shell.dart';

void main() {
  testWidgets('Test rendering Vikram Singh portal shell', (WidgetTester tester) async {
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

    await tester.pumpWidget(
      const MaterialApp(
        home: EmployeeShell(portalType: EmployeePortalType.service),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify top bar
    expect(find.text('Vikram Singh'), findsOneWidget);
    expect(find.textContaining('Service Desk'), findsOneWidget);

    // Check if ServiceHomeTab widgets are present
    print('Checking for Service & Maintenance banner: ${find.text('Service & Maintenance').evaluate().length}');
    print('Checking for Assigned metric card: ${find.text('Assigned').evaluate().length}');

    // Let any async tasks complete
    await tester.pumpAndSettle();

    print('After pumpAndSettle:');
    print('Checking for Service & Maintenance banner: ${find.text('Service & Maintenance').evaluate().length}');
    print('Checking for Assigned metric card: ${find.text('Assigned').evaluate().length}');
  });
}
