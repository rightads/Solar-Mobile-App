import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/auth/presentation/widgets/forgot_password_sheet.dart';
import 'package:solar_pro/shared/animations/motion.dart';
import 'package:solar_pro/shared/animations/pixel_art.dart';

enum _Portal { client, employee, admin }

enum _Stage { portal, signIn, otp, register }

enum _Method { password, otp }

extension on _Portal {
  String get title => switch (this) {
        _Portal.client => 'Client',
        _Portal.employee => 'Employee',
        _Portal.admin => 'Admin',
      };
  String get blurb => switch (this) {
        _Portal.client => 'Get solar for your home\nor business',
        _Portal.employee => 'Sales, site, KEDL &\nservice teams',
        _Portal.admin => 'Oversee operations,\nusers and performance',
      };
  IconData get icon => switch (this) {
        _Portal.client => Icons.groups_2_outlined,
        _Portal.employee => Icons.engineering_outlined,
        _Portal.admin => Icons.settings_outlined,
      };
  Color get tint => switch (this) {
        _Portal.client => AppColors.violet500,
        _Portal.employee => AppColors.gold500,
        _Portal.admin => AppColors.teal500,
      };
  String get fallbackRole => switch (this) {
        _Portal.client => 'client',
        _Portal.employee => 'sales',
        _Portal.admin => 'admin',
      };
}

/// Employee departments selectable at sign-up (pending admin approval).
const _departments = [
  ('sales', 'Sales', Icons.handshake_outlined),
  ('site', 'Site Ops', Icons.construction_outlined),
  ('kedl', 'KEDL', Icons.description_outlined),
  ('service', 'Service', Icons.build_circle_outlined),
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  _Stage _stage = _Stage.portal;
  _Portal _portal = _Portal.client;
  _Method _method = _Method.password;
  bool _forward = true;

  // Sign in
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _obscure = true;

  // Register
  final _regNameCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();
  bool _regObscure = true;
  String _regDepartment = 'sales';

  bool _isLoading = false;
  String? _error;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _success =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _identifierCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [
      _identifierCtrl, _passwordCtrl, _phoneCtrl, _otpCtrl,
      _regNameCtrl, _regPhoneCtrl, _regEmailCtrl, _regPasswordCtrl, _regConfirmCtrl,
    ]) {
      c.dispose();
    }
    _cooldownTimer?.cancel();
    _shake.dispose();
    _success.dispose();
    super.dispose();
  }

  // ── Navigation between stages ─────────────────────────────────────────────

  void _go(_Stage stage, {bool forward = true}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = forward;
      _stage = stage;
      _error = null;
    });
  }

  void _back() {
    switch (_stage) {
      case _Stage.signIn:
        _go(_Stage.portal, forward: false);
      case _Stage.otp:
      case _Stage.register:
        _go(_Stage.signIn, forward: false);
      case _Stage.portal:
        break;
    }
  }

  void _choosePortal(_Portal p) {
    _portal = p;
    _method = _Method.password;
    _go(_Stage.signIn);
  }

  void _fail(String message) {
    setState(() {
      _isLoading = false;
      _error = message.replaceFirst('Exception: ', '');
    });
    HapticFeedback.mediumImpact();
    _shake.forward(from: 0);
  }

  // ── Auth handlers ─────────────────────────────────────────────────────────

  Future<void> _handlePasswordLogin() async {
    final id = _identifierCtrl.text.trim();
    final pw = _passwordCtrl.text;
    if (id.isEmpty || pw.isEmpty) return _fail('Please enter your email/mobile and password');

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().loginWithPassword(id, pw);
      if (!mounted) return;
      setState(() => _isLoading = false);
      await _playSuccessAndNavigate(res);
    } on EmailVerificationRequiredException catch (ev) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showEmailVerificationSheet(ev.email ?? id);
    } catch (e) {
      if (mounted) _fail(e.toString());
    }
  }

  Future<void> _handleSendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) return _fail('Please enter a valid 10-digit mobile number');

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().requestOtp(phone);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _otpCtrl.clear();
      _startCooldown();
      if (_stage != _Stage.otp) _go(_Stage.otp);
      _snack(res?['message']?.toString() ?? 'If this number is registered, a code is on its way.');
    } catch (e) {
      if (mounted) _fail(e.toString());
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) return _fail('Please enter the complete 6-digit code');

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().verifyOtp(_phoneCtrl.text.trim(), otp);
      if (!mounted) return;
      setState(() => _isLoading = false);
      await _playSuccessAndNavigate(res);
    } on EmailVerificationRequiredException catch (ev) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showEmailVerificationSheet(ev.email ?? '');
    } catch (e) {
      if (mounted) _fail(e.toString());
    }
  }

  Future<void> _handleRegister() async {
    final name = _regNameCtrl.text.trim();
    final phone = _regPhoneCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final password = _regPasswordCtrl.text;

    if (name.isEmpty) return _fail('Please enter your full name');
    if (phone.length < 10) return _fail('Please enter a valid 10-digit mobile number');
    if (!email.contains('@')) return _fail('A valid email address is required');
    if (password.length < 8 || !RegExp(r'[A-Za-z]').hasMatch(password) || !RegExp(r'\d').hasMatch(password)) {
      return _fail('Password must be at least 8 characters with letters and numbers');
    }
    if (password != _regConfirmCtrl.text) return _fail('Passwords do not match');

    if (_portal == _Portal.admin) return _fail('Admin accounts are created by the Super Admin.');
    final role = _portal == _Portal.client ? 'client' : _regDepartment;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().registerUser(name: name, phone: phone, email: email, password: password, role: role);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSignupVerificationSheet(
        res?['email']?.toString() ?? email,
        res?['phone']?.toString() ?? phone,
      );
    } catch (e) {
      if (mounted) _fail(e.toString());
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  /// Video-A style hand-off: an amber disc swells over the screen, then the
  /// dashboard route fades in underneath via the global page transition.
  Future<void> _playSuccessAndNavigate(Map<String, dynamic>? authData) async {
    HapticFeedback.heavyImpact();
    await _success.forward(from: 0);
    if (mounted) await _navigateUser(authData);
  }

  Future<void> _navigateUser(Map<String, dynamic>? authData) async {
    final prefs = await SharedPreferences.getInstance();
    final user = authData?['user'] as Map<String, dynamic>?;
    final role = (user?['role'] ?? prefs.getString(AppConstants.kUserRole) ?? _portal.fallbackRole)
        .toString()
        .toLowerCase();
    final team = (user?['team'] ?? user?['team_type'] ?? prefs.getString('user_team'))?.toString();
    if (!mounted) return;

    final target = resolveRoleHomeRoute(role, teamType: team);
    if (target != AppRoutes.unsupportedRole) {
      context.go(target);
    } else {
      context.go(switch (_portal) {
        _Portal.client => AppRoutes.clientDash,
        _Portal.employee => AppRoutes.employeeSalesman,
        _Portal.admin => AppRoutes.vendorDash,
      });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _maskPhone(String p) =>
      p.length < 4 ? p : '${p.substring(0, 2)}${'*' * (p.length - 4)}${p.substring(p.length - 2)}';

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.gold300, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: AppColors.white))),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return PopScope(
      canPop: _stage == _Stage.portal,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: Stack(
          children: [
            PixelBackdrop(child: wide ? _buildWide() : _buildNarrow()),
            _SuccessOverlay(animation: _success),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrow() {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildStageSwitcher(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Split layout: illustration panel + form. The panel glides to the other
  /// side for sign-up, like the Qubstudio reference.
  Widget _buildWide() {
    final panelRight = _stage == _Stage.register;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: LayoutBuilder(
          builder: (context, c) {
            final half = c.maxWidth / 2;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 700),
                  curve: AppMotion.emphasized,
                  left: panelRight ? half : 0,
                  top: 0,
                  bottom: 0,
                  width: half,
                  child: _IllustrationPanel(stage: _stage),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 700),
                  curve: AppMotion.emphasized,
                  left: panelRight ? 0 : half,
                  top: 0,
                  bottom: 0,
                  width: half,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _buildStageSwitcher(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStageSwitcher() {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value), 0),
        child: child,
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.slow,
        switchInCurve: AppMotion.emphasized,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        transitionBuilder: (child, anim) {
          final isIncoming = child.key == ValueKey(_stage);
          final dir = (_forward ? 1.0 : -1.0) * (isIncoming ? 1 : -1);
          return FadeTransition(
            opacity: anim,
            child: AnimatedBuilder(
              animation: anim,
              child: child,
              builder: (context, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..translateByDouble(dir * 70 * (1 - anim.value), 0, 0, 1)
                  ..rotateY(dir * 0.35 * (1 - anim.value)),
                child: child,
              ),
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_stage),
          child: switch (_stage) {
            _Stage.portal => _buildPortalStage(),
            _Stage.signIn => _buildSignInStage(),
            _Stage.otp => _buildOtpStage(),
            _Stage.register => _buildRegisterStage(),
          },
        ),
      ),
    );
  }

  // ── Stage: choose portal ──────────────────────────────────────────────────

  Widget _buildPortalStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        const SpEntrance(child: Center(child: SolarProLogo(size: 26))),
        const SizedBox(height: 26),
        SpEntrance(
          index: 1,
          child: Text('Choose Your Portal',
              textAlign: TextAlign.center, style: AppTextStyles.displaySmall.copyWith(fontSize: 28)),
        ),
        const SizedBox(height: 6),
        SpEntrance(
          index: 2,
          child: Text('One app. Three experiences.',
              textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
        ),
        const SizedBox(height: 28),
        for (final (i, p) in _Portal.values.indexed) ...[
          SpEntrance(
            index: 3 + i,
            step: const Duration(milliseconds: 90),
            from: const Offset(40, 0),
            child: _PortalCard(portal: p, onTap: () => _choosePortal(p)),
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 18),
        SpEntrance(
          index: 7,
          child: Text('Secured with end-to-end encryption',
              textAlign: TextAlign.center, style: AppTextStyles.caption),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  // ── Stage: sign in ────────────────────────────────────────────────────────

  Widget _buildSignInStage() {
    final usesPassword = _method == _Method.password;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(onBack: _back, trailing: _PortalBadge(portal: _portal)),
        const SizedBox(height: 18),
        const SpEntrance(child: Center(child: SolarProLogo(size: 24))),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SpEntrance(
                    index: 1,
                    child: Row(
                      children: [
                        Text('Welcome Back', style: AppTextStyles.displaySmall.copyWith(fontSize: 27)),
                        const SizedBox(width: 6),
                        const _WavingHand(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SpEntrance(
                    index: 2,
                    child: Text('Sign in to your ${_portal.title.toLowerCase()} portal',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
                  ),
                ],
              ),
            ),
            _MorphAvatar(text: usesPassword ? _identifierCtrl.text : '', portal: _portal),
          ],
        ),
        const SizedBox(height: 22),
        if (_portal != _Portal.admin) ...[
          SpEntrance(
            index: 3,
            child: _MethodToggle(
              value: _method,
              onChanged: (m) => setState(() {
                _method = m;
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _ErrorBanner(message: _error),
        AnimatedSize(
          duration: AppMotion.medium,
          curve: AppMotion.emphasized,
          alignment: Alignment.topCenter,
          child: usesPassword
              ? Column(
                  key: const ValueKey('pw'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SpEntrance(
                      index: 4,
                      child: _PixelField(
                        controller: _identifierCtrl,
                        hint: 'Email or Mobile',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SpEntrance(
                      index: 5,
                      child: _PixelField(
                        controller: _passwordCtrl,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _handlePasswordLogin(),
                        suffix: _eyeToggle(_obscure, () => setState(() => _obscure = !_obscure)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _openForgotPassword,
                        child: Text(
                          'Forgot Password?',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.ink900,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SpEntrance(
                      index: 6,
                      child: SpPixelButton(label: 'Login', isLoading: _isLoading, onPressed: _handlePasswordLogin),
                    ),
                  ],
                )
              : Column(
                  key: const ValueKey('otp'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PixelField(
                      controller: _phoneCtrl,
                      hint: 'Mobile number',
                      icon: Icons.phone_iphone_rounded,
                      prefixText: '+91  ',
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      digitsOnly: true,
                      onSubmitted: (_) => _handleSendOtp(),
                    ),
                    const SizedBox(height: 10),
                    Text("We'll text you a 6-digit code to sign in securely.", style: AppTextStyles.bodySmall),
                    const SizedBox(height: 20),
                    SpPixelButton(
                      label: 'Send OTP',
                      trailingIcon: Icons.arrow_forward_rounded,
                      isLoading: _isLoading,
                      onPressed: _handleSendOtp,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 26),
        if (_portal != _Portal.admin)
        SpEntrance(
          index: 7,
          child: Center(
            child: Text.rich(
              TextSpan(
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
                children: [
                  const TextSpan(text: "Don't have an account? "),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: SpPressable(
                      onTap: () => _go(_Stage.register),
                      child: Text('Register',
                          style: AppTextStyles.labelLarge.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  // ── Stage: OTP ────────────────────────────────────────────────────────────

  Widget _buildOtpStage() {
    final mm = (_cooldown ~/ 60).toString().padLeft(2, '0');
    final ss = (_cooldown % 60).toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(onBack: _back),
        const SizedBox(height: 12),
        Center(child: SpEntrance(from: const Offset(0, -20), child: PixelScenes.sunCloud(size: 76))),
        const SizedBox(height: 14),
        SpEntrance(index: 1, child: Text('Verify OTP', style: AppTextStyles.displaySmall.copyWith(fontSize: 28))),
        const SizedBox(height: 6),
        SpEntrance(
          index: 2,
          child: Text.rich(
            TextSpan(
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
              children: [
                const TextSpan(text: 'Enter the 6-digit code sent to\n'),
                TextSpan(
                  text: '+91 ${_maskPhone(_phoneCtrl.text.trim())}',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.ink900),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _ErrorBanner(message: _error),
        SpEntrance(
          index: 3,
          child: _PixelOtpField(
            controller: _otpCtrl,
            onCompleted: (_) => _handleVerifyOtp(),
          ),
        ),
        const SizedBox(height: 18),
        SpEntrance(
          index: 4,
          child: Center(
            child: AnimatedSwitcher(
              duration: AppMotion.medium,
              child: _cooldown > 0
                  ? Row(
                      key: const ValueKey('wait'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: AppColors.grey400),
                        const SizedBox(width: 6),
                        Text('Resend OTP in ', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
                        Text('$mm:$ss', style: AppTextStyles.labelLarge.copyWith(color: AppColors.ink900)),
                      ],
                    )
                  : TextButton.icon(
                      key: const ValueKey('resend'),
                      onPressed: _isLoading ? null : _handleSendOtp,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Resend OTP'),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        SpEntrance(
          index: 5,
          child: SpPixelButton(label: 'Verify', isLoading: _isLoading, onPressed: _handleVerifyOtp),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  // ── Stage: register ───────────────────────────────────────────────────────

  Widget _buildRegisterStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(onBack: _back, trailing: _PortalBadge(portal: _portal)),
        const SizedBox(height: 14),
        SpEntrance(child: Text('Create Account', style: AppTextStyles.displaySmall.copyWith(fontSize: 28))),
        const SizedBox(height: 4),
        SpEntrance(
          index: 1,
          child: Text(
            switch (_portal) {
              _Portal.client => 'Join SolarPro and track your solar journey',
              _Portal.employee => 'Your account is activated once an admin approves it',
              _Portal.admin => 'Admin accounts are created by the Super Admin',
            },
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
          ),
        ),
        const SizedBox(height: 20),
        if (_portal == _Portal.employee) ...[
          SpEntrance(index: 2, child: Text('Department', style: AppTextStyles.labelLarge)),
          const SizedBox(height: 10),
          SpEntrance(
            index: 2,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (key, label, icon) in _departments)
                  _DepartmentChip(
                    label: label,
                    icon: icon,
                    selected: _regDepartment == key,
                    onTap: () => setState(() => _regDepartment = key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        _ErrorBanner(message: _error),
        SpEntrance(
          index: 3,
          child: _PixelField(controller: _regNameCtrl, hint: 'Full name', icon: Icons.person_outline_rounded,
              autofillHints: const [AutofillHints.name]),
        ),
        const SizedBox(height: 12),
        SpEntrance(
          index: 4,
          child: _PixelField(
            controller: _regPhoneCtrl,
            hint: 'Mobile number',
            icon: Icons.phone_iphone_rounded,
            prefixText: '+91  ',
            keyboardType: TextInputType.phone,
            maxLength: 10,
            digitsOnly: true,
          ),
        ),
        const SizedBox(height: 12),
        SpEntrance(
          index: 5,
          child: _PixelField(
            controller: _regEmailCtrl,
            hint: 'Email address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
        ),
        const SizedBox(height: 12),
        SpEntrance(
          index: 6,
          child: _PixelField(
            controller: _regPasswordCtrl,
            hint: 'Password (8+ letters & numbers)',
            icon: Icons.lock_outline_rounded,
            obscure: _regObscure,
            autofillHints: const [AutofillHints.newPassword],
            suffix: _eyeToggle(_regObscure, () => setState(() => _regObscure = !_regObscure)),
          ),
        ),
        const SizedBox(height: 12),
        SpEntrance(
          index: 6,
          child: _PixelField(
            controller: _regConfirmCtrl,
            hint: 'Confirm password',
            icon: Icons.lock_reset_rounded,
            obscure: _regObscure,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _handleRegister(),
            suffix: _eyeToggle(_regObscure, () => setState(() => _regObscure = !_regObscure)),
          ),
        ),
        const SizedBox(height: 22),
        SpEntrance(
          index: 7,
          child: SpPixelButton(label: 'Create Account', isLoading: _isLoading, onPressed: _handleRegister),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: () => _go(_Stage.signIn, forward: false),
            child: Text('Already have an account? Sign in',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.ink900)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Reset link + code by email; client and staff portals can also switch to
  /// signing in with an SMS OTP instead.
  Future<void> _openForgotPassword() async {
    final email = await showForgotPasswordSheet(
      context,
      initialEmail: _identifierCtrl.text,
      onUseOtp: _portal == _Portal.admin ? null : () => setState(() => _method = _Method.otp),
    );
    if (email != null && mounted) {
      setState(() {
        _identifierCtrl.text = email;
        _passwordCtrl.clear();
      });
    }
  }

  Widget _eyeToggle(bool obscured, VoidCallback onPressed) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: AppMotion.fast,
        transitionBuilder: (c, a) => RotationTransition(turns: a, child: FadeTransition(opacity: a, child: c)),
        child: Icon(
          obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          key: ValueKey(obscured),
          color: AppColors.ink700,
          size: 20,
        ),
      ),
    );
  }

  // ── Sheets & dialogs ──────────────────────────────────────────────────────

  /// New accounts verify both the email (code by email) and the mobile
  /// (separate code by SMS) before they can be used.
  void _showSignupVerificationSheet(String email, String phone) {
    final emailCodeCtrl = TextEditingController();
    final phoneCodeCtrl = TextEditingController();
    bool verifying = false;
    bool resendingEmail = false;
    bool resendingSms = false;
    String? sheetError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> verify() async {
            if (emailCodeCtrl.text.trim().length != 6 || phoneCodeCtrl.text.trim().length != 6) {
              setSheet(() => sheetError = 'Please enter both 6-digit codes');
              return;
            }
            setSheet(() {
              verifying = true;
              sheetError = null;
            });
            try {
              final res = await ApiClient().verifySignup(
                email: email,
                emailCode: emailCodeCtrl.text,
                phone: phone,
                phoneCode: phoneCodeCtrl.text,
              );
              if (!sheetCtx.mounted) return;
              Navigator.pop(sheetCtx);
              if (res?['access_token'] is String) {
                await _playSuccessAndNavigate(res);
              } else {
                _showPendingApprovalDialog();
              }
            } catch (e) {
              if (!sheetCtx.mounted) return;
              setSheet(() {
                verifying = false;
                sheetError = e.toString().replaceFirst('Exception: ', '');
              });
            }
          }

          Widget resendButton({required bool busy, required String label, required Future<void> Function() onTap}) {
            return Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: busy
                    ? const SizedBox(width: 30, height: 12, child: SpPixelLoader(size: 5))
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(busy ? 'Sending…' : label),
                onPressed: busy ? null : onTap,
              ),
            );
          }

          return Container(
            padding: EdgeInsets.fromLTRB(24, 14, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
            decoration: const BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
              border: Border(top: BorderSide(color: AppColors.navy500, width: 1.4)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: AppColors.navy500, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Verify your account', textAlign: TextAlign.center,
                      style: AppTextStyles.displaySmall.copyWith(fontSize: 22)),
                  const SizedBox(height: 6),
                  Text(
                    'We sent one code to your email and another by SMS to your mobile.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
                  ),
                  const SizedBox(height: 16),
                  _ErrorBanner(message: sheetError),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'Email code  ', style: AppTextStyles.labelLarge),
                      TextSpan(text: email, style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  _PixelOtpField(controller: emailCodeCtrl, onCompleted: (_) {}),
                  resendButton(
                    busy: resendingEmail,
                    label: 'Resend email code',
                    onTap: () async {
                      setSheet(() => resendingEmail = true);
                      final ok = await ApiClient().sendEmailVerification(email);
                      if (!sheetCtx.mounted) return;
                      setSheet(() {
                        resendingEmail = false;
                        sheetError = ok ? null : 'Could not resend the email code. Please try again.';
                      });
                      if (ok) _snack('New code sent to $email');
                    },
                  ),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'Mobile (SMS) code  ', style: AppTextStyles.labelLarge),
                      TextSpan(text: '+91 ${_maskPhone(phone)}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  _PixelOtpField(controller: phoneCodeCtrl, autofocus: false, onCompleted: (_) => verify()),
                  resendButton(
                    busy: resendingSms,
                    label: 'Resend SMS code',
                    onTap: () async {
                      setSheet(() => resendingSms = true);
                      String? err;
                      try {
                        await ApiClient().sendPhoneVerification(phone);
                      } catch (e) {
                        err = e.toString().replaceFirst('Exception: ', '');
                      }
                      if (!sheetCtx.mounted) return;
                      setSheet(() {
                        resendingSms = false;
                        sheetError = err;
                      });
                      if (err == null) _snack('New SMS code sent');
                    },
                  ),
                  const SizedBox(height: 8),
                  SpPixelButton(label: 'Verify & Continue', isLoading: verifying, onPressed: verify),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _go(_Stage.signIn, forward: false);
                      },
                      child: const Text('Verify later'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      emailCodeCtrl.dispose();
      phoneCodeCtrl.dispose();
    });
  }

  void _showPendingApprovalDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: AppColors.ink900.withValues(alpha: 0.35),
      transitionDuration: AppMotion.slow,
      transitionBuilder: (ctx, a, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: a, child: child),
      ),
      pageBuilder: (ctx, _, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              color: Colors.transparent,
              child: SpCard(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PixelScenes.sunCloud(size: 64),
                    const SizedBox(height: 12),
                    Text('Request Submitted', style: AppTextStyles.displaySmall.copyWith(fontSize: 22)),
                    const SizedBox(height: 8),
                    Text(
                      'Your ${_portal == _Portal.employee ? 'employee' : 'admin'} account is awaiting approval. '
                      "You'll be able to sign in once an administrator activates it.",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    SpPixelButton(
                      label: 'Got it',
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _go(_Stage.signIn, forward: false);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEmailVerificationSheet(String email) {
    final codeCtrl = TextEditingController();
    bool verifying = false;
    bool resending = false;
    String? sheetError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> verify() async {
            final code = codeCtrl.text.trim();
            if (code.length != 6) {
              setSheet(() => sheetError = 'Please enter the complete 6-digit code');
              return;
            }
            setSheet(() {
              verifying = true;
              sheetError = null;
            });
            try {
              final res = await ApiClient().verifyEmail(email, code);
              if (!sheetCtx.mounted) return;
              Navigator.pop(sheetCtx);
              await _playSuccessAndNavigate(res);
            } catch (e) {
              if (!sheetCtx.mounted) return;
              setSheet(() {
                verifying = false;
                sheetError = e.toString().replaceFirst('Exception: ', '');
              });
            }
          }

          return Container(
            padding: EdgeInsets.fromLTRB(24, 14, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
            decoration: const BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
              border: Border(top: BorderSide(color: AppColors.navy500, width: 1.4)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: AppColors.navy500, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(child: PixelScenes.sunCloud(size: 60)),
                  const SizedBox(height: 10),
                  Text('Verify your email', textAlign: TextAlign.center,
                      style: AppTextStyles.displaySmall.copyWith(fontSize: 22)),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
                      children: [
                        const TextSpan(text: 'We sent a 6-digit code to\n'),
                        TextSpan(text: email, style: AppTextStyles.labelLarge.copyWith(color: AppColors.ink900)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _ErrorBanner(message: sheetError),
                  _PixelOtpField(controller: codeCtrl, onCompleted: (_) => verify()),
                  const SizedBox(height: 20),
                  SpPixelButton(label: 'Verify & Continue', isLoading: verifying, onPressed: verify),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      icon: resending
                          ? const SizedBox(width: 30, height: 12, child: SpPixelLoader(size: 5))
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(resending ? 'Sending…' : 'Resend code'),
                      onPressed: resending
                          ? null
                          : () async {
                              setSheet(() => resending = true);
                              final ok = await ApiClient().sendEmailVerification(email);
                              if (!sheetCtx.mounted) return;
                              setSheet(() {
                                resending = false;
                                sheetError = ok ? null : 'Could not resend the code. Please try again.';
                              });
                              if (ok) _snack('New code sent to $email');
                            },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(codeCtrl.dispose);
  }
}

// ═══ Pieces ═══════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final Widget? trailing;
  const _TopBar({required this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          SpPressable(
            onTap: onBack,
            child: Container(
              width: 42,
              height: 42,
              decoration: AppDecor.card(radius: AppRadius.md, shadowOffset: 2),
              child: const Icon(Icons.arrow_back_rounded, color: AppColors.ink900, size: 20),
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _PortalBadge extends StatelessWidget {
  final _Portal portal;
  const _PortalBadge({required this.portal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: portal.tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: portal.tint.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(portal.icon, size: 15, color: AppColors.ink900),
          const SizedBox(width: 6),
          Text('${portal.title} portal', style: AppTextStyles.labelMedium.copyWith(color: AppColors.ink900)),
        ],
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  final _Portal portal;
  final VoidCallback onTap;
  const _PortalCard({required this.portal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SpCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: portal.tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: portal.tint.withValues(alpha: 0.45), width: 1.2),
            ),
            child: Icon(portal.icon, color: AppColors.ink900, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(portal.title, style: AppTextStyles.headlineSmall.copyWith(fontSize: 17)),
                const SizedBox(height: 2),
                Text(portal.blurb, style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey300)),
              ],
            ),
          ),
          const _NudgeArrow(),
        ],
      ),
    );
  }
}

/// Chevron that nudges right on a loop, hinting the card is tappable.
class _NudgeArrow extends StatefulWidget {
  const _NudgeArrow();
  @override
  State<_NudgeArrow> createState() => _NudgeArrowState();
}

class _NudgeArrowState extends State<_NudgeArrow> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value < 0.3 ? math.sin(_c.value / 0.3 * math.pi) * 4 : 0.0;
        return Transform.translate(offset: Offset(v, 0), child: child);
      },
      child: const Icon(Icons.chevron_right_rounded, color: AppColors.ink900, size: 26),
    );
  }
}

class _WavingHand extends StatefulWidget {
  const _WavingHand();
  @override
  State<_WavingHand> createState() => _WavingHandState();
}

class _WavingHandState extends State<_WavingHand> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final angle = t < 0.5 ? math.sin(t / 0.5 * math.pi * 4) * 0.35 : 0.0;
        return Transform.rotate(angle: angle, alignment: Alignment.bottomRight, child: child);
      },
      child: const Text('👋', style: TextStyle(fontSize: 24)),
    );
  }
}

/// Avatar that morphs as the user types (Cleveroad reference): empty outline
/// ring → filled gradient disc showing their initial.
class _MorphAvatar extends StatelessWidget {
  final String text;
  final _Portal portal;
  const _MorphAvatar({required this.text, required this.portal});

  @override
  Widget build(BuildContext context) {
    final filled = text.trim().length >= 3;
    final initial = filled ? text.trim()[0].toUpperCase() : '';
    return TweenAnimationBuilder<double>(
      tween: Tween(end: filled ? 1 : 0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, v, _) {
        final f = v.clamp(0.0, 1.0);
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(AppColors.white, AppColors.gold500, f),
            border: Border.all(color: AppColors.ink900, width: 1.6),
            boxShadow: [
              BoxShadow(color: AppColors.navy500.withValues(alpha: 0.6), offset: const Offset(0, 3)),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 1 - f,
                child: Transform.scale(scale: 1 - 0.4 * f, child: Icon(portal.icon, color: AppColors.ink700, size: 28)),
              ),
              Opacity(
                opacity: f,
                child: Transform.scale(
                  scale: 0.4 + 0.6 * v,
                  child: Text(initial, style: AppTextStyles.displaySmall.copyWith(fontSize: 28)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MethodToggle extends StatelessWidget {
  final _Method value;
  final ValueChanged<_Method> onChanged;
  const _MethodToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.navy700,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.navy600, width: 1.2),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppMotion.medium,
                curve: Curves.easeOutBack,
                left: value == _Method.password ? 0 : w,
                width: w,
                top: 0,
                bottom: 0,
                child: Container(decoration: AppDecor.card(radius: AppRadius.md, shadowOffset: 2)),
              ),
              Row(
                children: [
                  for (final (m, label, icon) in [
                    (_Method.password, 'Password', Icons.key_rounded),
                    (_Method.otp, 'Mobile OTP', Icons.sms_outlined),
                  ])
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(m),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 16, color: value == m ? AppColors.ink900 : AppColors.grey500),
                            const SizedBox(width: 6),
                            AnimatedDefaultTextStyle(
                              duration: AppMotion.fast,
                              style: AppTextStyles.labelLarge.copyWith(
                                fontSize: 13,
                                color: value == m ? AppColors.ink900 : AppColors.grey500,
                              ),
                              child: Text(label),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PixelField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final String? prefixText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool digitsOnly;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  const _PixelField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.prefixText,
    this.keyboardType,
    this.maxLength,
    this.digitsOnly = false,
    this.autofillHints,
    this.onSubmitted,
  });

  @override
  State<_PixelField> createState() => _PixelFieldState();
}

class _PixelFieldState extends State<_PixelField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.emphasized,
      transform: Matrix4.translationValues(0, focused ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: focused ? AppColors.violet500 : AppColors.navy500, width: focused ? 1.8 : 1.4),
        boxShadow: [
          BoxShadow(
            color: (focused ? AppColors.violet500 : AppColors.navy500).withValues(alpha: focused ? 0.35 : 0.5),
            offset: Offset(0, focused ? 4 : 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          AnimatedScale(
            duration: AppMotion.medium,
            curve: Curves.easeOutBack,
            scale: focused ? 1.15 : 1,
            child: Icon(widget.icon, size: 20, color: focused ? AppColors.violet500 : AppColors.ink700),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              obscureText: widget.obscure,
              keyboardType: widget.keyboardType,
              autofillHints: widget.autofillHints,
              maxLength: widget.maxLength,
              onSubmitted: widget.onSubmitted,
              cursorColor: AppColors.violet500,
              inputFormatters: widget.digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w600, fontSize: 15),
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixText: widget.prefixText,
                prefixStyle: AppTextStyles.bodyLarge.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w700, fontSize: 15),
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),
          ),
          if (widget.suffix != null) widget.suffix!,
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Six chunky boxes over a hidden field; the active box glows and filled boxes pop.
class _PixelOtpField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final bool autofocus;
  const _PixelOtpField({required this.controller, required this.onCompleted, this.autofocus = true});

  @override
  State<_PixelOtpField> createState() => _PixelOtpFieldState();
}

class _PixelOtpFieldState extends State<_PixelOtpField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    _focus.addListener(() => setState(() {}));
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  void _onChange() {
    setState(() {});
    if (widget.controller.text.length == 6) widget.onCompleted(widget.controller.text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: '', border: InputBorder.none),
            ),
          ),
          Row(
            children: List.generate(6, (i) {
              final filled = i < code.length;
              final active = _focus.hasFocus && i == code.length.clamp(0, 5) && code.length < 6;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 5 ? 0 : 8),
                  child: AspectRatio(
                    aspectRatio: 0.86,
                    child: AnimatedContainer(
                      duration: AppMotion.medium,
                      curve: Curves.easeOutBack,
                      transform: Matrix4.translationValues(0, active ? -4 : 0, 0),
                      decoration: BoxDecoration(
                        color: filled ? AppColors.gold100 : AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: active ? AppColors.violet500 : (filled ? AppColors.goldDeep : AppColors.navy500),
                          width: active ? 2 : 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (active ? AppColors.violet500 : AppColors.navy500).withValues(alpha: 0.45),
                            offset: Offset(0, active ? 5 : 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: AppMotion.medium,
                        transitionBuilder: (c, a) => ScaleTransition(
                          scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                          child: c,
                        ),
                        child: filled
                            ? Text(code[i],
                                key: ValueKey('d$i${code[i]}'),
                                style: AppTextStyles.displaySmall.copyWith(fontSize: 24))
                            : active
                                ? const _BlinkCursor()
                                : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _BlinkCursor extends StatefulWidget {
  const _BlinkCursor();
  @override
  State<_BlinkCursor> createState() => _BlinkCursorState();
}

class _BlinkCursorState extends State<_BlinkCursor> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _c, child: Container(width: 12, height: 3, color: AppColors.ink900));
}

class _DepartmentChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _DepartmentChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SpPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold100 : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? AppColors.goldDeep : AppColors.navy500, width: selected ? 1.6 : 1.2),
          boxShadow: [
            BoxShadow(
              color: (selected ? AppColors.gold500 : AppColors.navy500).withValues(alpha: 0.5),
              offset: Offset(0, selected ? 3 : 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: AppColors.ink900),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
            AnimatedSize(
              duration: AppMotion.medium,
              child: selected
                  ? const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.check_circle_rounded, size: 16, color: AppColors.goldDeep),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String? message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.medium,
      curve: AppMotion.emphasized,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.5), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(message!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.ink900)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Left/right panel on wide screens.
class _IllustrationPanel extends StatelessWidget {
  final _Stage stage;
  const _IllustrationPanel({required this.stage});

  @override
  Widget build(BuildContext context) {
    final register = stage == _Stage.register;
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.skyGradient,
        borderRadius: BorderRadius.circular(AppRadius.xxl + 8),
        border: Border.all(color: AppColors.navy500, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 40),
          AnimatedSwitcher(
            duration: AppMotion.slow,
            child: Text(
              register ? 'Join the\nGreen Shift' : 'Clean Energy\nfor a Brighter\nTomorrow',
              key: ValueKey(register),
              textAlign: TextAlign.center,
              style: AppTextStyles.displayMedium.copyWith(fontSize: 34),
            ),
          ),
          const SizedBox(height: 12),
          Text('Install · Monitor · Manage', style: AppTextStyles.bodyLarge),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              child: AnimatedSwitcher(
                duration: AppMotion.slow,
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
                  child: FadeTransition(opacity: a, child: c),
                ),
                child: register
                    ? KeyedSubtree(key: const ValueKey('earth'), child: PixelScenes.earth())
                    : KeyedSubtree(key: const ValueKey('house'), child: PixelScenes.house()),
              ),
            ),
          ),
          PixelScenes.landscape(height: 120),
        ],
      ),
    );
  }
}

/// Amber disc that swells from the centre to cover the screen on success.
class _SuccessOverlay extends StatelessWidget {
  final Animation<double> animation;
  const _SuccessOverlay({required this.animation});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final v = animation.value;
          if (v == 0) return const SizedBox.shrink();
          final size = MediaQuery.of(context).size;
          final maxR = math.sqrt(size.width * size.width + size.height * size.height);
          final r = Curves.easeInOutCubic.transform((v / 0.75).clamp(0.0, 1.0)) * maxR;
          final logo = Curves.easeOutBack.transform(((v - 0.45) / 0.55).clamp(0.0, 1.0));
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _DiscPainter(r)),
              ),
              Center(
                child: Opacity(
                  opacity: logo.clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.6 + 0.4 * logo, child: const SolarProLogo(size: 34)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DiscPainter extends CustomPainter {
  final double r;
  _DiscPainter(this.r);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, r, Paint()..color = AppColors.gold500);
    canvas.drawCircle(c, r * 0.82, Paint()..color = AppColors.navy900);
  }

  @override
  bool shouldRepaint(covariant _DiscPainter old) => old.r != r;
}
