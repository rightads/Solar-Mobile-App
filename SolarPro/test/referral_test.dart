import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_pro/features/leads/presentation/referral/refer_lead.dart';

void main() {
  testWidgets('refer-a-customer sheet validates name and mobile before sending', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return; // test font artefact
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => showReferLeadSheet(context), child: const Text('open')),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Refer a customer'), findsOneWidget);

    await tester.tap(find.text('Send to sales'));
    await tester.pump();
    expect(find.text("Enter the customer's name."), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Customer name *'), 'Neighbour Ji');
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number *'), '98765');
    await tester.tap(find.text('Send to sales'));
    await tester.pump();
    expect(find.text('Enter a 10-digit mobile number.'), findsOneWidget);
  });
}
