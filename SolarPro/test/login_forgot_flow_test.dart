import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/features/auth/presentation/screens/login_screen.dart';

// Regression: Forgot Password → leave the sheet → Sign in used to crash with
// "'_dependents.isEmpty': is not true".
/// The login screen animates forever, so advance time instead of settling.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openLogin(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
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
  await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
  await _settle(tester);
  await tester.tap(find.text('Client').first); // portal choice comes first
  await _settle(tester);
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Forgot Password?'));
  await tester.tap(find.text('Forgot Password?'));
  await _settle(tester);
  expect(find.text('Sign in with SMS OTP instead'), findsOneWidget);
}

/// Fails on real errors. Layout overflow warnings are skipped: widget tests
/// draw text in a wide block font, so they overflow where real phones don't.
void _expectNoError(WidgetTester tester) {
  for (Object? e = tester.takeException(); e != null; e = tester.takeException()) {
    if (e is FlutterError && e.toString().contains('overflowed')) continue;
    fail('Unexpected error: $e');
  }
}

void main() {
  testWidgets('Forgot password → "Sign in with SMS OTP instead" → sign in', (tester) async {
    await _openLogin(tester);
    await _openSheet(tester);
    await tester.tap(find.text('Sign in with SMS OTP instead'));
    await _settle(tester);
    _expectNoError(tester);
    // Now on the OTP form: try to sign in without a number.
    final send = find.textContaining(RegExp('OTP', caseSensitive: false)).last;
    await tester.ensureVisible(send);
    await tester.tap(send, warnIfMissed: false);
    await _settle(tester);
    _expectNoError(tester);
  });

  testWidgets('Forgot password → dismiss sheet → Login', (tester) async {
    await _openLogin(tester);
    await _openSheet(tester);
    await tester.tapAt(const Offset(20, 20)); // tap outside: dismiss
    await _settle(tester);
    _expectNoError(tester);
    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    await _settle(tester);
    _expectNoError(tester);
  });

  testWidgets('typed + focused fields, every way out of the sheet, then sign in', (tester) async {
    for (final exit in ['otp', 'outside', 'code-then-outside']) {
      await _openLogin(tester);
      // Type into the sign-in fields so they hold focus, like on a phone.
      await tester.enterText(find.byType(TextField).first, 'me@x.in');
      await tester.enterText(find.byType(TextField).at(1), 'secret123');
      await _settle(tester);
      await _openSheet(tester);
      final sheetEmail = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)).first;
      await tester.enterText(sheetEmail, 'me@x.in');
      await _settle(tester);
      if (exit == 'otp') {
        await tester.tap(find.text('Sign in with SMS OTP instead'));
      } else {
        if (exit == 'code-then-outside') {
          await tester.tap(find.text('I already have a code'));
          await _settle(tester);
          await tester.enterText(find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)).at(1), '123456');
        }
        await tester.tapAt(const Offset(20, 20));
      }
      await _settle(tester);
      _expectNoError(tester);
      final signIn = find.text(exit == 'otp' ? 'Send OTP' : 'Login');
      await tester.ensureVisible(signIn);
      await tester.tap(signIn, warnIfMissed: false);
      await _settle(tester);
      _expectNoError(tester);
      // Leave the screen entirely (e.g. after a successful sign-in navigates away).
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await _settle(tester);
      _expectNoError(tester);
    }
  });
}
