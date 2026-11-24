import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_pro/core/dev/server_status_sheet.dart';

Widget _host(Future<ServerStatus> Function() check) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: DevTapTrigger(check: check, child: const SizedBox(width: 80, height: 80, child: Text('logo'))),
        ),
      ),
    );

Future<void> _tapTimes(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.tap(find.text('logo'));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('logo stays a logo until tapped 7 times quickly', (tester) async {
    await tester.pumpWidget(_host(() async => const ServerStatus(reachable: true, databaseOk: true)));
    await _tapTimes(tester, 6);
    await tester.pumpAndSettle();
    expect(find.text('Developer · Server status'), findsNothing);

    // A pause longer than the tap window resets the count.
    await tester.pump(const Duration(seconds: 2));
    await _tapTimes(tester, 1);
    await tester.pumpAndSettle();
    expect(find.text('Developer · Server status'), findsNothing);
  });

  testWidgets('7 quick taps open the panel and show a healthy server', (tester) async {
    await tester.pumpWidget(_host(
        () async => const ServerStatus(reachable: true, databaseOk: true, httpStatus: 200, latencyMs: 42)));
    await _tapTimes(tester, 7);
    await tester.pumpAndSettle();
    expect(find.text('Developer · Server status'), findsOneWidget);
    expect(find.text('Connected to server'), findsOneWidget);
    expect(find.text('42 ms'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
  });

  testWidgets('panel distinguishes database down from server unreachable', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_host(() async {
      calls++;
      return calls == 1
          ? const ServerStatus(reachable: true, databaseOk: false, httpStatus: 503, detail: 'Database unavailable.')
          : const ServerStatus(reachable: false, databaseOk: false, detail: 'Connection timed out.');
    }));
    await _tapTimes(tester, 7);
    await tester.pumpAndSettle();
    expect(find.text('Server up, database unavailable'), findsOneWidget);
    expect(find.text('Database unavailable.'), findsOneWidget);

    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Connection timed out.'), findsOneWidget);
  });
}
