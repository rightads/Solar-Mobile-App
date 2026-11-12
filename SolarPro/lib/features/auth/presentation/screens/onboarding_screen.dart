import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/auth/presentation/screens/splash_screen.dart';
import 'package:solar_pro/shared/animations/motion.dart';
import 'package:solar_pro/shared/animations/pixel_art.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  double _page = 0;

  static final _pages = [
    _OnboardData(
      art: (h) => PixelScenes.house(height: h),
      lead: 'Clean Energy\nfor a ',
      highlight: 'Brighter',
      tail: '\nTomorrow',
      subtitle: 'Install · Monitor · Manage\nyour solar ecosystem',
    ),
    _OnboardData(
      art: (h) => PixelScenes.monitor(height: h),
      lead: 'Track, Save\nand ',
      highlight: 'Grow',
      tail: '',
      subtitle: 'Follow every project stage, payment\nand service ticket in real time',
    ),
    _OnboardData(
      art: (h) => PixelScenes.earth(height: h),
      lead: 'Be a Part of\nthe ',
      highlight: 'Green',
      tail: ' Shift',
      subtitle: 'Reduce emissions and build a\nsustainable future together',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _page = _controller.page ?? 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingSeen, true);
    if (mounted) context.go(AppRoutes.login);
  }

  void _next() {
    if (_page.round() < _pages.length - 1) {
      _controller.nextPage(duration: AppMotion.slow, curve: AppMotion.emphasized);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final current = _page.round();
    return Scaffold(
      body: PixelBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                    child: Row(
                      children: [
                        const SolarProLogo(size: 20),
                        const Spacer(),
                        AnimatedOpacity(
                          duration: AppMotion.medium,
                          opacity: current < _pages.length - 1 ? 1 : 0,
                          child: TextButton(onPressed: _finish, child: const Text('Skip')),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      itemBuilder: (context, i) {
                        // Parallax: art drifts slower than the text as you swipe.
                        final delta = (i - _page).clamp(-1.0, 1.0);
                        return _OnboardPage(data: _pages[i], delta: delta, artHeight: h * 0.32);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    child: Row(
                      children: [
                        ...List.generate(_pages.length, (i) {
                          final active = (1 - (_page - i).abs()).clamp(0.0, 1.0);
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: 8 + 18 * active,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Color.lerp(AppColors.navy500, AppColors.ink900, active),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                        const Spacer(),
                        SizedBox(
                          width: current == _pages.length - 1 ? 150 : 64,
                          child: AnimatedSize(
                            duration: AppMotion.medium,
                            curve: AppMotion.emphasized,
                            child: SpPixelButton(
                              label: current == _pages.length - 1 ? 'Get Started' : '',
                              trailingIcon: Icons.arrow_forward_rounded,
                              height: 48,
                              onPressed: _next,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final _OnboardData data;
  final double delta;
  final double artHeight;
  const _OnboardPage({required this.data, required this.delta, required this.artHeight});

  @override
  Widget build(BuildContext context) {
    final title = AppTextStyles.displayMedium.copyWith(fontSize: 32, height: 1.18);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Transform.translate(
            offset: Offset(delta * 140, 0),
            child: Center(child: data.art(artHeight)),
          ),
          const Spacer(),
          Opacity(
            opacity: (1 - delta.abs() * 1.4).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(delta * 40, 0),
              child: Text.rich(
                TextSpan(
                  style: title,
                  children: [
                    TextSpan(text: data.lead),
                    TextSpan(text: data.highlight, style: title.copyWith(color: AppColors.gold500)),
                    TextSpan(text: data.tail),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: (1 - delta.abs() * 1.8).clamp(0.0, 1.0),
            child: Text(
              data.subtitle,
              style: AppTextStyles.bodyLarge.copyWith(fontSize: 15, color: AppColors.grey300),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _OnboardData {
  final Widget Function(double height) art;
  final String lead;
  final String highlight;
  final String tail;
  final String subtitle;

  const _OnboardData({
    required this.art,
    required this.lead,
    required this.highlight,
    required this.tail,
    required this.subtitle,
  });
}
