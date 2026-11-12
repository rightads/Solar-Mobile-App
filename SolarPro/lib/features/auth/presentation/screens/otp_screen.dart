import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _pinController = TextEditingController();
  String _otp = '';
  bool _isLoading = false;
  bool _isVerified = false;
  int _timer = AppConstants.otpTimerSecs;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _timer = AppConstants.otpTimerSecs;
      _canResend = false;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_timer > 0) {
          _timer--;
        } else {
          _canResend = true;
        }
      });
      return _timer > 0;
    });
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) return;
    setState(() => _isLoading = true);

    try {
      final res = await ApiClient().verifyOtp(widget.phone, _otp);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isVerified = true;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        final role = res?['user']?['role']?.toString().toLowerCase();
        if (role == 'client') {
          context.go(AppRoutes.clientDash);
        } else {
          context.go(AppRoutes.vendorDash);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.phone.isNotEmpty ? widget.phone : '9876543210';
    final maskedPhone =
        phone.length >= 7 ? phone.replaceRange(3, 7, '****') : phone;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                IconButton(
                  onPressed: () => context.go(AppRoutes.login),
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: AppColors.fg),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 30),

                // Header
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.gold500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: AppColors.gold500.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: AppColors.gold500,
                    size: 30,
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 300.ms),

                const SizedBox(height: 24),

                Text(
                  'Verify OTP',
                  style: AppTextStyles.displaySmall,
                )
                    .animate(delay: 150.ms)
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 8),

                RichText(
                  text: TextSpan(
                    text: 'OTP sent to ',
                    style: AppTextStyles.bodyMedium,
                    children: [
                      TextSpan(
                        text: '+91 $maskedPhone',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.gold400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate(delay: 250.ms)
                    .fadeIn(duration: 500.ms),

                const SizedBox(height: 40),

                // OTP Pin field
                PinCodeTextField(
                  appContext: context,
                  controller: _pinController,
                  length: 6,
                  onChanged: (v) => setState(() => _otp = v),
                  onCompleted: (_) => _verifyOtp(),
                  animationType: AnimationType.scale,
                  animationDuration: const Duration(milliseconds: 200),
                  keyboardType: TextInputType.number,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    fieldHeight: 52,
                    fieldWidth: 44,
                    activeFillColor: AppColors.navy700,
                    inactiveFillColor: AppColors.navy800,
                    selectedFillColor: AppColors.navy700,
                    activeColor: AppColors.gold500,
                    inactiveColor: AppColors.navy600,
                    selectedColor: AppColors.gold500,
                    borderWidth: 1.5,
                  ),
                  enableActiveFill: true,
                  textStyle: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.fg,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    .animate(delay: 350.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 32),

                // Verify Button
                if (_isVerified)
                  Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.fg, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Verified! Entering Portal...',
                          style: TextStyle(
                            color: AppColors.fg,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(
                        begin: const Offset(0.8, 0.8),
                        duration: 400.ms,
                        curve: Curves.elasticOut,
                      )
                else
                  GestureDetector(
                    onTap: _otp.length == 6 ? _verifyOtp : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: _otp.length == 6
                            ? AppColors.goldGradient
                            : null,
                        color: _otp.length < 6 ? AppColors.navy700 : null,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: _otp.length == 6
                            ? [
                                BoxShadow(
                                  color: AppColors.gold500.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Color(0xFFF6F4FD),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'Verify & Continue',
                                style: AppTextStyles.labelLarge.copyWith(
                                  fontSize: 17,
                                  color: _otp.length == 6
                                      ? AppColors.navy900
                                      : AppColors.grey500,
                                ),
                              ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Resend OTP
                Center(
                  child: _canResend
                      ? TextButton(
                          onPressed: () async {
                            _startTimer();
                            await ApiClient().requestOtp(widget.phone);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('A new 6-digit OTP code has been dispatched.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                          child: Text(
                            'Resend OTP',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.gold400,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.gold400,
                            ),
                          ),
                        )
                      : RichText(
                          text: TextSpan(
                            text: 'Resend OTP in ',
                            style: AppTextStyles.bodyMedium,
                            children: [
                              TextSpan(
                                text: '${_timer}s',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.gold400,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),

                const Spacer(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
