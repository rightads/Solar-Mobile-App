import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_pro/core/constants/project_stages.dart';
import 'package:solar_pro/core/constants/staff_departments.dart';
import 'package:solar_pro/features/quotations/data/quotation_api.dart';
import 'package:solar_pro/features/quotations/presentation/quotation_form_screen.dart';
import 'package:solar_pro/features/quotations/presentation/widgets/quotation_card.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('overflowed')) return; // test font artefact
    original?.call(d);
  };
  addTearDown(() => FlutterError.onError = original);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('7 employee departments in project order, legacy roles mapped', () {
    expect(kStaffDepartments.map((d) => d.key),
        ['sales', 'discom', 'structure', 'wiring', 'civil', 'subsidy', 'account']);
    expect(departmentOf('kedl'), 'discom');
    expect(departmentOf('site'), 'structure');
    expect(departmentOf('electrician'), 'wiring');
    expect(departmentOf('service'), isNull);
    expect(staffDepartment('discom')!.nameField, 'discom_employee_name');
  });

  test('8 project stages, each owned by a department', () {
    expect(kProjectStages.length, 8);
    expect(kProjectStages.first.key, 'DOCUMENTS_COLLECTION');
    expect(kProjectStages.last.key, 'ACCOUNT_BILL');
    for (final s in kProjectStages) {
      expect(kStaffDepartments.any((d) => d.key == s.department), isTrue, reason: s.key);
    }
    expect(projectStageLabel('COMPLETED'), 'Completed ✓');
    expect(projectStageIndex('WIRING_WORK'), 4);
  });

  testWidgets('approved quotation shows as locked with its total', (tester) async {
    await _pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: QuotationCard(
            quotation: const Quotation({
              'id': 'q1', 'quote_no': 'QT-AB12-01', 'version': 1, 'status': 'approved',
              'capacity_kw': 5, 'project_cost': 250000, 'discom_charges': 3000, 'file_charges': 625,
              'total_amount': 253625, 'remark': 'Includes AMC',
              'items': {'solar_module': {'make': 'Waaree', 'capacity': '540 W', 'quantity': 10}},
            }),
          ),
        ),
      ),
    );
    expect(find.textContaining('Approved'), findsWidgets);
    expect(find.textContaining('can no longer be changed'), findsOneWidget);
    expect(find.textContaining('2,53,625'), findsWidgets);
    expect(find.text('Solar Module'), findsOneWidget);
  });

  testWidgets('rejected quotation shows the client\'s reason', (tester) async {
    await _pump(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          child: QuotationCard(
            quotation: Quotation({
              'id': 'q1', 'version': 1, 'status': 'rejected', 'capacity_kw': 5, 'project_cost': 1,
              'total_amount': 1, 'remark': 'r', 'client_remark': 'Too costly',
            }),
          ),
        ),
      ),
    );
    expect(find.text('Too costly'), findsOneWidget);
  });

  testWidgets('quotation form requires capacity, cost and a remark; total adds up', (tester) async {
    await _pump(tester, const QuotationFormScreen(customerId: 'c1', customerName: 'Ravi'));
    await tester.tap(find.textContaining('Submit & send'));
    await tester.pump();
    expect(find.text('A remark is required'), findsOneWidget);
    expect(find.text('Required'), findsNWidgets(2)); // capacity + project cost

    await tester.enterText(find.widgetWithText(TextFormField, 'Project cost *'), '250000');
    await tester.enterText(find.widgetWithText(TextFormField, 'File charges'), '625');
    await tester.pump();
    expect(find.textContaining('2,50,625'), findsWidgets);
  });

  testWidgets('regenerating starts from the rejected version and shows the reason', (tester) async {
    const prev = Quotation({
      'id': 'q1', 'quote_no': 'QT-AB12-01', 'version': 1, 'status': 'rejected', 'capacity_kw': 5,
      'project_cost': 250000, 'total_amount': 250000, 'remark': 'Old remark', 'client_remark': 'Want Tata panels',
      'items': {'solar_module': {'make': 'Waaree'}},
    });
    await _pump(tester, const QuotationFormScreen(customerId: 'c1', customerName: 'Ravi', previous: prev));
    expect(find.text('Regenerate Quotation'), findsOneWidget);
    expect(find.text('"Want Tata panels"'), findsOneWidget);
    expect(find.text('Old remark'), findsOneWidget);
    expect(find.text('Waaree'), findsOneWidget);
  });
}
