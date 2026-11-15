import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show HttpOverrides, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:solar_pro/core/network/pinned_http_overrides.dart';
import 'package:solar_pro/core/router/app_router.dart';
import 'package:solar_pro/core/services/update_service.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) HttpOverrides.global = PinnedHttpOverrides();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  runApp(const ProviderScope(child: SolarProApp()));
}

class SolarProApp extends ConsumerStatefulWidget {
  const SolarProApp({super.key});

  @override
  ConsumerState<SolarProApp> createState() => _SolarProAppState();
}

class _SolarProAppState extends ConsumerState<SolarProApp> {
  Timer? _updateCheckTimer;

  @override
  void initState() {
    super.initState();
    // Let the splash screen route first, then look for a newer APK.
    _updateCheckTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      final router = ref.read(routerProvider);
      UpdateService.checkForUpdate(() => router.routerDelegate.navigatorKey.currentContext);
    });
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SolarPro',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );
      },
    );
  }
}
