import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_pro/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:solar_pro/features/auth/presentation/widgets/forgot_password_sheet.dart';

Widget _host({VoidCallback? onUseOtp}) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showForgotPasswordSheet(context, initialEmail: 'me@x.in', onUseOtp: onUseOtp),
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('forgot password sheet offers email link, code entry and OTP alternative', (tester) async {
    var usedOtp = false;
    await tester.pumpWidget(_host(onUseOtp: () => usedOtp = true));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Email Me a Reset Link'), findsOneWidget);
    expect(find.text('me@x.in'), findsOneWidget, reason: 'email from the login field is prefilled');

    await tester.tap(find.text('I already have a code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter Reset Code'), findsOneWidget);
    await tester.tap(find.text('Reset Password'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the 6-digit code from the email'), findsOneWidget);

    Navigator.of(tester.element(find.text('Enter Reset Code'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with SMS OTP instead'));
    await tester.pumpAndSettle();
    expect(usedOtp, isTrue);
  });

  testWidgets('admin portal sheet has no SMS OTP option', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with SMS OTP instead'), findsNothing);
  });

  testWidgets('reset screen from the email link checks the passwords match', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ResetPasswordScreen(token: 'a' * 64)));
    await tester.enterText(find.byType(TextField).at(0), 'Good1Pass');
    await tester.enterText(find.byType(TextField).at(1), 'Other1Pass');
    await tester.tap(find.text('Save New Password'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('reset screen without a token explains the link is incomplete', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ResetPasswordScreen(token: '')));
    expect(find.text('This reset link is incomplete'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
