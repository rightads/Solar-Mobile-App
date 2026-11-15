import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tells sideloaded Android installs when CI has published a newer APK.
///
/// CI stamps every build with `--dart-define=APP_BUILD=<run number>` and
/// uploads `version.json` next to the APK on the "Android" GitHub release:
///   {"build": 57, "version": "1.0.57", "apk_url": "...", "notes": "...", "min_build": 0}
/// A build older than `min_build` gets a dialog that cannot be dismissed.
class UpdateService {
  UpdateService._();

  /// 0 for local/debug builds, which never prompt.
  static const int currentBuild = int.fromEnvironment('APP_BUILD');

  static const String manifestUrl =
      'https://github.com/rightads/Solar-Mobile-App/releases/download/Android/version.json';
  static const String _kSkippedBuild = 'update_skipped_build';

  static bool _checkedThisSession = false;

  static Future<void> checkForUpdate(BuildContext? Function() contextOf) async {
    if (kIsWeb || !Platform.isAndroid || currentBuild == 0 || _checkedThisSession) return;
    _checkedThisSession = true;

    final _Release? latest = await _fetchLatest();
    if (latest == null || latest.build <= currentBuild) return;

    final mandatory = currentBuild < latest.minBuild;
    final prefs = await SharedPreferences.getInstance();
    if (!mandatory && prefs.getInt(_kSkippedBuild) == latest.build) return;

    final context = contextOf();
    if (context == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: !mandatory,
      builder: (ctx) => PopScope(
        canPop: !mandatory,
        child: AlertDialog(
          title: Text(mandatory ? 'Update required' : 'Update available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mandatory
                  ? 'This version of SolarPro is no longer supported. Please install version ${latest.version} to continue.'
                  : 'SolarPro ${latest.version} is available.'),
              if (latest.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text("What's new:", style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(latest.notes),
              ],
              const SizedBox(height: 12),
              Text(
                'After the download finishes, open the file and tap Install. Your data stays signed in.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            if (!mandatory)
              TextButton(
                onPressed: () {
                  prefs.setInt(_kSkippedBuild, latest.build);
                  Navigator.of(ctx).pop();
                },
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () async {
                await launchUrl(Uri.parse(latest.apkUrl), mode: LaunchMode.externalApplication);
                if (!mandatory && ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Download update'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<_Release?> _fetchLatest() async {
    try {
      final res = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        // GitHub serves release assets as application/octet-stream.
        responseType: ResponseType.plain,
      )).get<String>(manifestUrl, queryParameters: {'t': DateTime.now().millisecondsSinceEpoch});
      final data = jsonDecode(res.data ?? '');
      if (data is! Map) return null;
      final build = int.tryParse('${data['build']}') ?? 0;
      final url = '${data['apk_url'] ?? ''}';
      // Only ever send users to this repository's own release downloads.
      if (build <= 0 || !url.startsWith('https://github.com/rightads/Solar-Mobile-App/releases/download/')) {
        return null;
      }
      return _Release(
        build: build,
        version: '${data['version'] ?? build}',
        apkUrl: url,
        notes: '${data['notes'] ?? ''}'.trim(),
        minBuild: int.tryParse('${data['min_build']}') ?? 0,
      );
    } catch (_) {
      return null; // offline or GitHub unreachable: try again next launch
    }
  }
}

class _Release {
  const _Release({
    required this.build,
    required this.version,
    required this.apkUrl,
    required this.notes,
    required this.minBuild,
  });

  final int build;
  final String version;
  final String apkUrl;
  final String notes;
  final int minBuild;
}
