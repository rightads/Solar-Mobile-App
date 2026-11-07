import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Page Controller for sliding between portals (0: Client, 1: Vendor, 2: Admin)
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPortal = 0; // 0: Client, 1: Vendor, 2: Admin

  // Client Controllers
  final _clientPhoneController = TextEditingController();
  final _clientOtpController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _clientPasswordController = TextEditingController();
  int _clientAuthMethod = 0; // 0: Phone & OTP, 1: Email & Password
  bool _clientOtpSent = false;
  int _clientOtpCooldown = 0;

  // Vendor Controllers
  final _vendorEmailController = TextEditingController();
  final _vendorPasswordController = TextEditingController();
  final _vendorPhoneController = TextEditingController();
  final _vendorOtpController = TextEditingController();
  int _vendorAuthMethod = 1; // Default to Email & Password for vendors
  bool _vendorOtpSent = false;
  int _vendorOtpCooldown = 0;

  // Admin Controllers
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  // Common UI State
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _pageController.dispose();
    _clientPhoneController.dispose();
    _clientOtpController.dispose();
    _clientEmailController.dispose();
    _clientPasswordController.dispose();
    _vendorEmailController.dispose();
    _vendorPasswordController.dispose();
    _vendorPhoneController.dispose();
    _vendorOtpController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  void _onPortalSelected(int index) {
    setState(() {
      _currentPortal = index;
      _errorMessage = null;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  // ── Authentication Handlers ──────────────────────────────────────────────────

  Future<void> _handlePasswordLogin({
    required String email,
    required String password,
    required String expectedRole,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().loginWithPassword(cleanEmail, password);
      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessSnack('Welcome back, ${res?['user']?['name'] ?? 'User'}!');
        _navigateUser(res, expectedRole);
      }
    } on EmailVerificationRequiredException catch (ev) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showEmailVerificationModal(ev.email ?? cleanEmail, pendingPassword: password);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleSendOtp({
    required String phone,
    required VoidCallback onSentSuccess,
  }) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty || cleanPhone.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().requestOtp(cleanPhone);
      if (mounted) {
        setState(() => _isLoading = false);
        final email = res?['email'] as String?;
        _clientOtpController.clear();
        _vendorOtpController.clear();
        onSentSuccess();
        final emailNotice = email != null ? ' and $email' : '';
        _showSuccessSnack('Verification OTP sent to +91 $cleanPhone$emailNotice. Please enter it below.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleVerifyOtp({
    required String phone,
    required String otp,
    required String expectedRole,
  }) async {
    final cleanPhone = phone.trim();
    final cleanOtp = otp.trim();
    if (cleanOtp.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().verifyOtp(cleanPhone, cleanOtp);
      if (mounted) {
        setState(() => _isLoading = false);
        _navigateUser(res, expectedRole);
      }
    } on EmailVerificationRequiredException catch (ev) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showEmailVerificationModal(ev.email ?? '');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _startCooldownTimer(Function(int) onTick, VoidCallback onFinished) {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      int next = 0;
      setState(() {
        if (_clientOtpCooldown > 0) {
          _clientOtpCooldown--;
          next = _clientOtpCooldown;
        } else if (_vendorOtpCooldown > 0) {
          _vendorOtpCooldown--;
          next = _vendorOtpCooldown;
        }
      });
      return next > 0;
    });
  }

  void _navigateUser(Map<String, dynamic>? authData, String fallbackRole) async {
    final prefs = await SharedPreferences.getInstance();
    final userMap = authData?['user'] as Map<String, dynamic>?;
    final role = (userMap?['role'] ??
            prefs.getString(AppConstants.kUserRole) ??
            fallbackRole)
        .toString()
        .toLowerCase();
    final team = (userMap?['team'] ??
            userMap?['team_type'] ??
            prefs.getString('user_team'))
        ?.toString();

    if (mounted) {
      final target = resolveRoleHomeRoute(role, teamType: team);
      if (target != AppRoutes.unsupportedRole) {
        context.go(target);
      } else {
        if (_currentPortal == 0 || role == 'client') {
          context.go(AppRoutes.clientDash);
        } else if (_currentPortal == 1) {
          context.go(AppRoutes.employeeSalesman);
        } else {
          context.go(AppRoutes.vendorDash);
        }
      }
    }
  }

  void _showSuccessSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.green400, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: AppColors.navy700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Bypass login for rapid testing without credentials
  Future<void> _bypassEmployeeLogin({
    String role = 'salesman',
    String? team,
    String? customName,
    String? route,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final name = customName ?? (role == 'vendor' ? 'Operations Manager' : 'Test Employee');
    final email = '${role.replaceAll(' ', '_').toLowerCase()}@solarpro.com';

    await prefs.setString(AppConstants.kAccessToken, 'test_mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}');
    await prefs.setString(AppConstants.kRefreshToken, 'test_mock_refresh_token');
    await prefs.setString(AppConstants.kUserId, 'test-emp-999');
    await prefs.setString(AppConstants.kUserName, name);
    await prefs.setString(AppConstants.kUserPhone, '9876543210');
    await prefs.setString('user_email', email);
    await prefs.setString(AppConstants.kUserRole, role);
    if (team != null) {
      await prefs.setString('user_team', team);
    } else {
      await prefs.remove('user_team');
    }

    if (!mounted) return;

    _showSuccessSnack('Opened $name without credentials (Test Mode)');

    final targetRoute = route ?? resolveRoleHomeRoute(role, teamType: team);
    context.go(targetRoute);
  }

  // ── Build UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 700;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: Stack(
        children: [
          // Ambient Radial Aura Gradients
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.gold500.withValues(alpha: 0.18),
                    AppColors.gold400.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.teal500.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? (size.width - 540) / 2 : 20,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Header
                    _buildBrandHeader(),
                    const SizedBox(height: 18),

                    // Portal Navigation Slider Bar (Client ➔ Employee ➔ Admin)
                    _buildPortalSlider(),
                    const SizedBox(height: 10),

                    // Swipe Hint Helper
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.swipe_rounded, color: AppColors.grey500, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Swipe horizontally or tap above to switch portals',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.grey500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Error Banner if present
                    if (_errorMessage != null) ...[
                      _buildErrorBanner(),
                      const SizedBox(height: 12),
                    ],

                    // PageView Card containing the 3 portals
                    SizedBox(
                      height: 570,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (idx) {
                          setState(() {
                            _currentPortal = idx;
                            _errorMessage = null;
                          });
                        },
                        children: [
                          _buildClientPortalPage(),
                          _buildVendorPortalPage(),
                          _buildAdminPortalPage(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Account Creation Option (for clients)
                    _buildRegisterFooter(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Brand Header ─────────────────────────────────────────────────────────────

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFF5A623), Color(0xFFFF8C00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold500.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.wb_sunny_rounded,
              color: AppColors.navy900,
              size: 36,
            ),
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 10),
        Text(
          'SolarPro',
          style: AppTextStyles.displaySmall.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Clean Energy Command Platform',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.gold300,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Portal Slider Tabs ───────────────────────────────────────────────────────

  Widget _buildPortalSlider() {
    final portals = [
      {'title': 'Client', 'icon': Icons.solar_power_rounded, 'color': AppColors.gold500},
      {'title': 'Employee', 'icon': Icons.badge_rounded, 'color': AppColors.teal500},
      {'title': 'Admin', 'icon': Icons.admin_panel_settings_rounded, 'color': AppColors.orange500},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navy600),
      ),
      child: Row(
        children: List.generate(portals.length, (i) {
          final isSelected = _currentPortal == i;
          final p = portals[i];
          final color = p['color'] as Color;

          return Expanded(
            child: GestureDetector(
              onTap: () => _onPortalSelected(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.3),
                            color.withValues(alpha: 0.15),
                          ],
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: color.withValues(alpha: 0.8), width: 1.5)
                      : Border.all(color: Colors.transparent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      p['icon'] as IconData,
                      size: 16,
                      color: isSelected ? color : AppColors.grey500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p['title'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.grey400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Error Banner ─────────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Portal 0: Client Login (Main Landing Page) ───────────────────────────────

  Widget _buildClientPortalPage() {
    return _buildPortalCard(
      badgeLabel: 'CLIENT PORTAL',
      badgeColor: AppColors.gold500,
      headline: 'Welcome, Solar Owner',
      subtitle: 'Monitor rooftop generation, net metering & service tickets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-tabs: Phone OTP vs Email Password
          _buildMethodSwitch(
            selectedIndex: _clientAuthMethod,
            tab1: 'Mobile & OTP',
            tab2: 'Email & Password',
            onChanged: (idx) => setState(() {
              _clientAuthMethod = idx;
              _errorMessage = null;
            }),
          ),
          const SizedBox(height: 18),

          if (_clientAuthMethod == 0) ...[
            // Phone & OTP Flow
            _buildFieldLabel('Mobile Number'),
            const SizedBox(height: 6),
            TextField(
              controller: _clientPhoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              decoration: _inputDecoration(
                hintText: 'Enter 10-digit mobile number',
                prefixWidget: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.phone_iphone_rounded, color: AppColors.gold400, size: 18),
                      SizedBox(width: 6),
                      Text('+91', style: TextStyle(color: AppColors.gold400, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (!_clientOtpSent) ...[
              _buildPrimaryButton(
                text: 'Send Login OTP',
                icon: Icons.send_rounded,
                onPressed: () {
                  _handleSendOtp(
                    phone: _clientPhoneController.text,
                    onSentSuccess: () {
                      setState(() {
                        _clientOtpSent = true;
                        _clientOtpCooldown = 60;
                      });
                      _startCooldownTimer((t) {}, () {});
                    },
                  );
                },
              ),
            ] else ...[
              _buildFieldLabel('Enter 6-Digit OTP'),
              const SizedBox(height: 6),
              TextField(
                controller: _clientOtpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  color: AppColors.gold400,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                ),
                decoration: _inputDecoration(
                  hintText: '• • • • • •',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _clientOtpCooldown > 0 ? 'Resend in ${_clientOtpCooldown}s' : 'Didn\'t get OTP?',
                    style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
                  ),
                  GestureDetector(
                    onTap: _clientOtpCooldown == 0
                        ? () {
                            _handleSendOtp(
                              phone: _clientPhoneController.text,
                              onSentSuccess: () {
                                setState(() => _clientOtpCooldown = 60);
                                _startCooldownTimer((t) {}, () {});
                              },
                            );
                          }
                        : null,
                    child: Text(
                      'Resend Code',
                      style: AppTextStyles.caption.copyWith(
                        color: _clientOtpCooldown == 0 ? AppColors.gold400 : AppColors.grey600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildPrimaryButton(
                text: 'Verify & Enter Dashboard',
                icon: Icons.verified_user_rounded,
                onPressed: () {
                  _handleVerifyOtp(
                    phone: _clientPhoneController.text,
                    otp: _clientOtpController.text,
                    expectedRole: 'client',
                  );
                },
              ),
            ],
          ] else ...[
            // Email & Password Flow
            _buildFieldLabel('Client Email Address'),
            const SizedBox(height: 6),
            TextField(
              controller: _clientEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                hintText: 'name@example.com',
                prefixIcon: Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 12),

            _buildFieldLabel('Password'),
            const SizedBox(height: 6),
            TextField(
              controller: _clientPasswordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                hintText: 'Enter your account password',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.grey500,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 18),

            _buildPrimaryButton(
              text: 'Sign In to Client Portal',
              icon: Icons.login_rounded,
              onPressed: () {
                _handlePasswordLogin(
                  email: _clientEmailController.text,
                  password: _clientPasswordController.text,
                  expectedRole: 'client',
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: AppColors.navy600)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'OR',
                  style: TextStyle(color: AppColors.grey500, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(child: Container(height: 1, color: AppColors.navy600)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold400,
                side: BorderSide(color: AppColors.gold500.withValues(alpha: 0.6), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: AppColors.gold500.withValues(alpha: 0.08),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text(
                'Register Client Account',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _showRegisterModal,
            ),
          ),
        ],
      ),
    );
  }

  // ── Portal 1: Employee Portal Page ──────────────────────────────────────────

  Widget _buildVendorPortalPage() {
    return _buildPortalCard(
      badgeLabel: 'EMPLOYEES',
      badgeColor: AppColors.teal500,
      headline: 'Operations Console',
      subtitle: 'Manage site installations, technician teams & inventory items',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMethodSwitch(
            selectedIndex: _vendorAuthMethod,
            tab1: 'Mobile & OTP',
            tab2: 'Email & Password',
            onChanged: (idx) => setState(() {
              _vendorAuthMethod = idx;
              _errorMessage = null;
            }),
          ),
          const SizedBox(height: 18),

          if (_vendorAuthMethod == 1) ...[
            _buildFieldLabel('Employee Email'),
            const SizedBox(height: 6),
            TextField(
              controller: _vendorEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                hintText: 'employee@solarpro.com',
                prefixIcon: Icons.badge_outlined,
              ),
            ),
            const SizedBox(height: 12),

            _buildFieldLabel('Password'),
            const SizedBox(height: 6),
            TextField(
              controller: _vendorPasswordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                hintText: 'Enter account password',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.grey500,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 18),

            _buildPrimaryButton(
              text: 'Access Employee Portal',
              icon: Icons.badge_outlined,
              onPressed: () {
                _handlePasswordLogin(
                  email: _vendorEmailController.text,
                  password: _vendorPasswordController.text,
                  expectedRole: 'salesman',
                );
              },
            ),
          ] else ...[
            _buildFieldLabel('Registered Mobile Number'),
            const SizedBox(height: 6),
            TextField(
              controller: _vendorPhoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              decoration: _inputDecoration(
                hintText: '10-digit mobile number',
                prefixWidget: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.phone_android_rounded, color: AppColors.teal400, size: 18),
                      SizedBox(width: 6),
                      Text('+91', style: TextStyle(color: AppColors.teal400, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (!_vendorOtpSent) ...[
              _buildPrimaryButton(
                text: 'Send Employee OTP',
                icon: Icons.send_rounded,
                onPressed: () {
                  _handleSendOtp(
                    phone: _vendorPhoneController.text,
                    onSentSuccess: () {
                      setState(() {
                        _vendorOtpSent = true;
                        _vendorOtpCooldown = 60;
                      });
                      _startCooldownTimer((t) {}, () {});
                    },
                  );
                },
              ),
            ] else ...[
              _buildFieldLabel('Enter 6-Digit OTP'),
              const SizedBox(height: 6),
              TextField(
                controller: _vendorOtpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  color: AppColors.teal400,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                ),
                decoration: _inputDecoration(
                  hintText: '• • • • • •',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _vendorOtpCooldown > 0 ? 'Resend in ${_vendorOtpCooldown}s' : 'Didn\'t get OTP?',
                    style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
                  ),
                  GestureDetector(
                    onTap: _vendorOtpCooldown == 0
                        ? () {
                            _handleSendOtp(
                              phone: _vendorPhoneController.text,
                              onSentSuccess: () {
                                setState(() => _vendorOtpCooldown = 60);
                                _startCooldownTimer((t) {}, () {});
                              },
                            );
                          }
                        : null,
                    child: Text(
                      'Resend Code',
                      style: AppTextStyles.caption.copyWith(
                        color: _vendorOtpCooldown == 0 ? AppColors.teal400 : AppColors.grey600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildPrimaryButton(
                text: 'Verify & Enter Console',
                icon: Icons.verified_user_rounded,
                onPressed: () {
                  _handleVerifyOtp(
                    phone: _vendorPhoneController.text,
                    otp: _vendorOtpController.text,
                    expectedRole: 'salesman',
                  );
                },
              ),
            ],
          ],

          const SizedBox(height: 14),

          // Testing Bypass: Open Employee without credentials
          _buildEmployeeTestBypassSection(),

          const SizedBox(height: 14),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'New employee or staff? ',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400),
                ),
                GestureDetector(
                  onTap: () => _showStaffRegisterModal(isEmployee: true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Text(
                      'Apply for Access',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.teal400,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Testing Bypass Widget ──────────────────────────────────────────────────

  Widget _buildEmployeeTestBypassSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.teal500.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.teal400.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.teal400.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.science_outlined, color: AppColors.teal400, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'TEST MODE',
                      style: TextStyle(
                        color: AppColors.teal400,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Bypass Credentials (Testing)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal400,
                foregroundColor: AppColors.navy900,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.bolt_rounded, size: 20),
              label: const Text(
                'Open Employee (No Credentials)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              onPressed: () => _bypassEmployeeLogin(
                role: 'salesman',
                customName: 'Sales Executive (Test)',
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Quick switch test portal:',
            style: TextStyle(
              color: AppColors.grey400,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildRoleChip(
                label: 'Sales',
                icon: Icons.person_pin_rounded,
                onTap: () => _bypassEmployeeLogin(
                  role: 'salesman',
                  customName: 'Sales Executive (Test)',
                ),
              ),
              _buildRoleChip(
                label: 'Site Team',
                icon: Icons.build_rounded,
                onTap: () => _bypassEmployeeLogin(
                  role: 'electrician',
                  team: 'electrical',
                  customName: 'Site Technician (Test)',
                ),
              ),
              _buildRoleChip(
                label: 'KEDL Discom',
                icon: Icons.electric_bolt_rounded,
                onTap: () => _bypassEmployeeLogin(
                  role: 'kedl',
                  customName: 'KEDL Officer (Test)',
                ),
              ),
              _buildRoleChip(
                label: 'Service Desk',
                icon: Icons.handyman_rounded,
                onTap: () => _bypassEmployeeLogin(
                  role: 'service',
                  customName: 'Service Tech (Test)',
                ),
              ),
              _buildRoleChip(
                label: 'Operations',
                icon: Icons.dashboard_customize_rounded,
                onTap: () => _bypassEmployeeLogin(
                  role: 'vendor',
                  customName: 'Operations Lead (Test)',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.navy800,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.teal400.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.teal400),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Portal 2: Admin Console Page ─────────────────────────────────────────────

  Widget _buildAdminPortalPage() {
    return _buildPortalCard(
      badgeLabel: 'ADMIN CONSOLE',
      badgeColor: AppColors.orange500,
      headline: 'Executive Command',
      subtitle: 'System administration, DISCOM liaison approvals & user directory',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.orange500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.orange500.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.security_rounded, color: AppColors.orange500, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Administrative sign-in requires authorized SolarPro credentials.',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          _buildFieldLabel('Administrator Email'),
          const SizedBox(height: 6),
          TextField(
            controller: _adminEmailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              hintText: 'admin@solarpro.com',
              prefixIcon: Icons.admin_panel_settings_outlined,
            ),
          ),
          const SizedBox(height: 14),

          _buildFieldLabel('Password'),
          const SizedBox(height: 6),
          TextField(
            controller: _adminPasswordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              hintText: 'Enter admin password',
              prefixIcon: Icons.key_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.grey500,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildPrimaryButton(
            text: 'Sign In as Administrator',
            icon: Icons.vpn_key_rounded,
            onPressed: () {
              _handlePasswordLogin(
                email: _adminEmailController.text,
                password: _adminPasswordController.text,
                expectedRole: 'admin',
              );
            },
          ),

          const SizedBox(height: 18),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Need administrative access? ',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400),
                ),
                GestureDetector(
                  onTap: () => _showStaffRegisterModal(isEmployee: false),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Text(
                      'Request Admin Access',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.orange400,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Portal Card Wrapper ──────────────────────────────────────────────────────

  Widget _buildPortalCard({
    required String badgeLabel,
    required Color badgeColor,
    required String headline,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.navy800.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(headline, style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(color: AppColors.grey400, height: 1.3),
          ),
          const SizedBox(height: 18),
          Expanded(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }

  // ── Sub-Method Switcher (e.g. Phone vs Email) ────────────────────────────────

  Widget _buildMethodSwitch({
    required int selectedIndex,
    required String tab1,
    required String tab2,
    required Function(int) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.navy900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navy700),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(0),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selectedIndex == 0 ? AppColors.navy700 : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    tab1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selectedIndex == 0 ? FontWeight.bold : FontWeight.w500,
                      color: selectedIndex == 0 ? AppColors.gold400 : AppColors.grey400,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(1),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selectedIndex == 1 ? AppColors.navy700 : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    tab2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selectedIndex == 1 ? FontWeight.bold : FontWeight.w500,
                      color: selectedIndex == 1 ? AppColors.gold400 : AppColors.grey400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Inputs & Buttons ──────────────────────────────────────────────────

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.labelMedium.copyWith(
        color: AppColors.grey300,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildRoleSelectorTile({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : AppColors.navy800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.navy600,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.25) : AppColors.navy700,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? color : AppColors.grey400, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.grey300,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected ? color : AppColors.grey500,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? counterText,
    IconData? prefixIcon,
    Widget? prefixWidget,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      counterText: counterText,
      hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
      filled: true,
      fillColor: AppColors.navy900,
      prefixIcon: prefixWidget ?? (prefixIcon != null ? Icon(prefixIcon, color: AppColors.gold400, size: 18) : null),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.navy700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.navy700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.gold500, width: 1.5),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    if (_isLoading) {
      return Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.navy700,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: AppColors.gold500, strokeWidth: 2.2),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold500.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.navy900, size: 18),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: AppColors.navy900,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Register / Account Creation Modal ────────────────────────────────────────

  Widget _buildRegisterFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'New Solar Customer?',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showRegisterModal,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              'Create Client Account',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.gold400,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showRegisterModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isRegLoading = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: AppColors.navy900,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: AppColors.gold500.withValues(alpha: 0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold500.withValues(alpha: 0.15),
                            border: Border.all(color: AppColors.gold500.withValues(alpha: 0.5), width: 1.5),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: AppColors.gold500,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Client Account',
                                style: AppTextStyles.headlineMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Register to monitor generation & solar assets.',
                                style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    if (modalError != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                modalError!,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    _buildFieldLabel('Full Name'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        hintText: 'e.g. Aryan Singh',
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildFieldLabel('Mobile Number'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      decoration: _inputDecoration(
                        hintText: '10-digit mobile number',
                        prefixWidget: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.phone_iphone_rounded, color: AppColors.gold400, size: 18),
                              SizedBox(width: 6),
                              Text('+91', style: TextStyle(color: AppColors.gold400, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildFieldLabel('Email Address (for 6-digit verification code)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        hintText: 'e.g. aryan@gmail.com',
                        prefixIcon: Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildFieldLabel('Set Password'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        hintText: 'Min 6 characters',
                        prefixIcon: Icons.lock_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold500,
                          foregroundColor: AppColors.navy900,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        onPressed: isRegLoading
                            ? null
                            : () async {
                                final phone = phoneCtrl.text.trim();
                                final email = emailCtrl.text.trim();
                                final password = passCtrl.text;
                                final name = nameCtrl.text.trim();

                                if (name.isEmpty) {
                                  setModalState(() => modalError = 'Please enter your full name');
                                  return;
                                }

                                if (phone.length < 10) {
                                  setModalState(() => modalError = 'Please enter a valid 10-digit mobile number');
                                  return;
                                }

                                if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
                                  setModalState(() => modalError = 'A valid email address is required for verification');
                                  return;
                                }

                                if (password.length < 6) {
                                  setModalState(() => modalError = 'Password must be at least 6 characters');
                                  return;
                                }

                                setModalState(() {
                                  isRegLoading = true;
                                  modalError = null;
                                });

                                try {
                                  await ApiClient().registerUser(
                                    name: name,
                                    phone: phone,
                                    email: email,
                                    password: password,
                                    role: 'client',
                                  );

                                  if (!bottomSheetCtx.mounted) return;
                                  Navigator.pop(bottomSheetCtx);
                                  _showEmailVerificationModal(email, pendingPassword: password);
                                  _showSuccessSnack('Account created! Verification code sent to $email');
                                } catch (e) {
                                  if (!modalCtx.mounted) return;
                                  setModalState(() {
                                    isRegLoading = false;
                                    modalError = e.toString().replaceFirst("Exception: ", "");
                                  });
                                }
                              },
                        child: isRegLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.navy900),
                              )
                            : const Text(
                                'Register Client Account',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Employee & Admin Registration Modal (Super Admin Authorization) ─────────

  void _showStaffRegisterModal({required bool isEmployee}) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'sales';
    bool isSubmitting = false;
    String? modalError;

    final title = isEmployee ? 'Register as Employee' : 'Apply for Admin Access';
    final subtitle = isEmployee
        ? 'Submit registration request to Super Admin for authorization.'
        : 'Request executive credentials verified by the Super Admin.';
    final themeColor = isEmployee ? AppColors.teal400 : AppColors.orange400;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: AppColors.navy900,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: themeColor.withValues(alpha: 0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: themeColor.withValues(alpha: 0.15),
                            border: Border.all(color: themeColor.withValues(alpha: 0.5), width: 1.5),
                          ),
                          child: Icon(
                            isEmployee ? Icons.badge_rounded : Icons.admin_panel_settings_rounded,
                            color: themeColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppTextStyles.headlineMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    if (modalError != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                modalError!,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (isEmployee) ...[
                      _buildFieldLabel('Select Role / Department'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRoleSelectorTile(
                              label: 'Sales',
                              subtitle: 'Leads & Deals',
                              icon: Icons.trending_up_rounded,
                              color: AppColors.gold500,
                              isSelected: selectedRole == 'sales',
                              onTap: () => setModalState(() => selectedRole = 'sales'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildRoleSelectorTile(
                              label: 'KEDL',
                              subtitle: 'Net Metering',
                              icon: Icons.description_rounded,
                              color: AppColors.purple500,
                              isSelected: selectedRole == 'kedl',
                              onTap: () => setModalState(() => selectedRole = 'kedl'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRoleSelectorTile(
                              label: 'Service',
                              subtitle: 'Maintenance',
                              icon: Icons.build_rounded,
                              color: AppColors.teal400,
                              isSelected: selectedRole == 'service',
                              onTap: () => setModalState(() => selectedRole = 'service'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildRoleSelectorTile(
                              label: 'Site Work',
                              subtitle: 'Installation',
                              icon: Icons.construction_rounded,
                              color: AppColors.orange400,
                              isSelected: selectedRole == 'site',
                              onTap: () => setModalState(() => selectedRole = 'site'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    _buildFieldLabel('Full Name'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        hintText: isEmployee ? 'e.g. Ramesh Sharma' : 'e.g. Administrative Lead',
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildFieldLabel('Mobile Number'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      decoration: _inputDecoration(
                        hintText: '10-digit mobile number',
                        prefixWidget: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_iphone_rounded, color: themeColor, size: 18),
                              const SizedBox(width: 6),
                              Text('+91', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildFieldLabel('Official Email Address'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        hintText: isEmployee ? 'employee@solarpro.com' : 'admin@solarpro.com',
                        prefixIcon: Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildFieldLabel('Set Password'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        hintText: 'Min 6 characters',
                        prefixIcon: Icons.lock_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: AppColors.navy900,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final phone = phoneCtrl.text.trim();
                                final email = emailCtrl.text.trim();
                                final password = passCtrl.text;
                                final name = nameCtrl.text.trim();

                                if (name.isEmpty) {
                                  setModalState(() => modalError = 'Please enter your full name');
                                  return;
                                }

                                if (phone.length < 10) {
                                  setModalState(() => modalError = 'Please enter a valid 10-digit mobile number');
                                  return;
                                }

                                if (email.isEmpty || !email.contains('@')) {
                                  setModalState(() => modalError = 'A valid official email is required');
                                  return;
                                }

                                if (password.length < 6) {
                                  setModalState(() => modalError = 'Password must be at least 6 characters');
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  modalError = null;
                                });

                                try {
                                  await ApiClient().registerUser(
                                    name: name,
                                    phone: phone,
                                    email: email,
                                    password: password,
                                    role: isEmployee ? selectedRole : 'admin',
                                  );

                                  if (!bottomSheetCtx.mounted) return;
                                  Navigator.pop(bottomSheetCtx);
                                  _showApprovalSubmittedDialog(isEmployee: isEmployee);
                                } catch (e) {
                                  if (!modalCtx.mounted) return;
                                  setModalState(() {
                                    isSubmitting = false;
                                    modalError = e.toString().replaceFirst("Exception: ", "");
                                  });
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.navy900),
                              )
                            : Text(
                                isEmployee ? 'Submit Employee Application' : 'Submit Admin Application',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showApprovalSubmittedDialog({required bool isEmployee}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: isEmployee ? AppColors.teal400 : AppColors.orange400),
            const SizedBox(width: 10),
            const Text('Request Submitted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Your registration request has been submitted to the Super Admin for authorization.\n\nYou will be able to log in once your application is approved.',
          style: TextStyle(color: AppColors.grey300, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isEmployee ? AppColors.teal500 : AppColors.orange500,
              foregroundColor: AppColors.navy900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Client Email Verification Modal ──────────────────────────────────────────

  void _showEmailVerificationModal(String email, {String? pendingPassword}) {
    final codeCtrl = TextEditingController();
    bool isVerifying = false;
    bool isResending = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
              decoration: BoxDecoration(
                color: AppColors.navy900,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: AppColors.gold500.withValues(alpha: 0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold500.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.gold500.withValues(alpha: 0.5), width: 2),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_rounded,
                        color: AppColors.gold500,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Verify Client Email',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),

                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: AppColors.grey300, height: 1.4),
                        children: [
                          const TextSpan(text: 'A 6-digit verification code has been dispatched to\n'),
                          TextSpan(
                            text: email,
                            style: const TextStyle(
                              color: AppColors.gold400,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (modalError != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                modalError!,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _buildFieldLabel('Enter 6-Digit Verification Code'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: codeCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        color: AppColors.gold400,
                        fontFamily: 'monospace',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.navy800,
                        hintText: '• • • • • •',
                        hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8, fontSize: 20),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.gold500, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold500,
                          foregroundColor: AppColors.navy900,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isVerifying
                            ? null
                            : () async {
                                final code = codeCtrl.text.trim();
                                if (code.length != 6) {
                                  setModalState(() => modalError = 'Please enter the complete 6-digit code');
                                  return;
                                }
                                setModalState(() {
                                  isVerifying = true;
                                  modalError = null;
                                });
                                try {
                                  final res = await ApiClient().verifyEmail(email, code);
                                  if (!modalCtx.mounted) return;
                                  Navigator.pop(modalCtx);
                                  _showSuccessSnack('Email verified successfully! Welcome to SolarPro.');
                                  _navigateUser(res, 'client');
                                } catch (e) {
                                  if (!modalCtx.mounted) return;
                                  setModalState(() {
                                    isVerifying = false;
                                    modalError = e.toString().replaceFirst('Exception: ', '');
                                  });
                                }
                              },
                        child: isVerifying
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy900),
                              )
                            : const Text('Verify & Open Dashboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextButton.icon(
                      icon: isResending
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.gold400))
                          : const Icon(Icons.refresh_rounded, size: 18, color: AppColors.gold400),
                      label: Text(
                        isResending ? 'Sending...' : 'Resend Verification Code',
                        style: const TextStyle(color: AppColors.gold400, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      onPressed: isResending
                          ? null
                          : () async {
                              setModalState(() => isResending = true);
                              try {
                                await ApiClient().sendEmailVerification(email);
                                if (!modalCtx.mounted) return;
                                setModalState(() {
                                  isResending = false;
                                  modalError = null;
                                });
                                _showSuccessSnack('New verification code sent to $email');
                              } catch (e) {
                                if (!modalCtx.mounted) return;
                                setModalState(() {
                                  isResending = false;
                                  modalError = e.toString().replaceFirst('Exception: ', '');
                                });
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
