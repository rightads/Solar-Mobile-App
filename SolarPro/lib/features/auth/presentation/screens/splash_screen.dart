import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/services/session_store.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/shared/animations/motion.dart';
import 'package:solar_pro/shared/animations/pixel_art.dart';

const kOnboardingSeen = 'onboarding_seen';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    _progress.forward().whenComplete(_route);
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (await SessionStore.hasSession()) {
      if (!mounted) return;
      final role = prefs.getString(AppConstants.kUserRole);
      final team = prefs.getString('user_team_type') ?? prefs.getString('user_team');
      final home = resolveRoleHomeRoute(role, teamType: team);
      context.go(home == AppRoutes.unsupportedRole ? AppRoutes.login : home);
      return;
    }
    final seen = prefs.getBool(kOnboardingSeen) ?? false;
    context.go(seen ? AppRoutes.login : AppRoutes.onboarding);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      body: PixelBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  SizedBox(height: h * 0.06),
                  SpEntrance(
                    from: const Offset(0, -30),
                    child: PixelScenes.sunPanel(width: 200, height: 150),
                  ),
                  const SizedBox(height: 18),
                  SpEntrance(
                    index: 3,
                    child: Text('SolarPro', style: AppTextStyles.displayLarge.copyWith(fontSize: 46)),
                  ),
                  const SizedBox(height: 10),
                  SpEntrance(
                    index: 5,
                    child: Text(
                      'Powering a\nCleaner Tomorrow',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.ink700,
                        fontSize: 17,
                        letterSpacing: 0.6,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: _LoadingBar(progress: _progress),
                  ),
                  const SizedBox(height: 18),
                  PixelScenes.landscape(height: h * 0.22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  final Animation<double> progress;
  const _LoadingBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final v = Curves.easeInOutCubic.transform(progress.value);
        final dots = '.' * (1 + (progress.value * 9).floor() % 3);
        return Column(
          children: [
            Text('Loading$dots', style: AppTextStyles.labelLarge.copyWith(color: AppColors.ink700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 16,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.ink900, width: 1.6),
                    ),
                    child: LayoutBuilder(
                      builder: (context, c) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: c.maxWidth * v,
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${(v * 100).round()}%',
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.ink900),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
