import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tells installed Android and Windows apps when CI has published a newer build.
///
/// CI stamps every build with `--dart-define=APP_BUILD=<run number>` and
/// uploads `version.json` next to the download on the platform's GitHub
/// release ("Android" / "Windows"):
///   {"build": 57, "version": "1.0.57", "download_url": "...", "notes": "...", "min_build": 0}
/// A build older than `min_build` gets a dialog that cannot be dismissed.
///
/// Android opens the APK download in the browser (the user taps Install).
/// Windows downloads the zip, closes, swaps the files in place and relaunches.
class UpdateService {
  UpdateService._();

  /// 0 for local/debug builds, which never prompt.
  static const int currentBuild = int.fromEnvironment('APP_BUILD');

  static const String _releases = 'https://github.com/rightads/Solar-Mobile-App/releases/download/';
  static const String _kSkippedBuild = 'update_skipped_build';

  static bool _checkedThisSession = false;

  static String? get _platformTag {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    return null;
  }

  static Future<void> checkForUpdate(BuildContext? Function() contextOf) async {
    final tag = _platformTag;
    if (tag == null || currentBuild == 0 || _checkedThisSession) return;
    _checkedThisSession = true;

    final _Release? latest = await _fetchLatest(tag);
    if (latest == null || latest.build <= currentBuild) return;

    final mandatory = currentBuild < latest.minBuild;
    final prefs = await SharedPreferences.getInstance();
    if (!mandatory && prefs.getInt(_kSkippedBuild) == latest.build) return;

    final context = contextOf();
    if (context == null || !context.mounted) return;
    final isWindows = tag == 'Windows';
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
                isWindows
                    ? 'SolarPro will download the update, close, and reopen on the new version. You stay signed in.'
                    : 'After the download finishes, open the file and tap Install. You stay signed in.',
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
                if (isWindows) {
                  Navigator.of(ctx).pop();
                  final outer = contextOf();
                  if (outer != null && outer.mounted) await _installOnWindows(outer, latest);
                  return;
                }
                await _openInBrowser(latest.downloadUrl);
                if (!mandatory && ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(isWindows ? 'Update now' : 'Download update'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openInBrowser(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  // ── Windows self-update ────────────────────────────────────────────────────

  static Future<void> _installOnWindows(BuildContext context, _Release latest) async {
    final exe = Platform.resolvedExecutable;
    final installDir = File(exe).parent.path;
    if (!await _isWritable(installDir)) {
      // e.g. installed under Program Files: let the user replace it manually.
      await _openInBrowser(latest.downloadUrl);
      return;
    }
    if (!context.mounted) return;

    final progress = ValueNotifier<double?>(null);
    final cancel = CancelToken();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Downloading update'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, value, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value),
                const SizedBox(height: 8),
                Text(value == null ? 'Starting…' : '${(value * 100).round()}%'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => cancel.cancel(), child: const Text('Cancel')),
          ],
        ),
      ),
    );

    final work = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}solarpro_update_${latest.build}',
    );
    final zip = '${work.path}${Platform.pathSeparator}SolarPro-Windows.zip';
    final script = '${work.path}${Platform.pathSeparator}apply_update.ps1';
    try {
      await work.create(recursive: true);
      await Dio().download(
        latest.downloadUrl,
        zip,
        cancelToken: cancel,
        onReceiveProgress: (got, total) {
          if (total > 0) progress.value = got / total;
        },
      );
      await File(script).writeAsString(_applyScript);
      await Process.start(
        'powershell.exe',
        [
          '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
          '-File', script,
          '-AppPid', '$pid',
          '-Zip', zip,
          '-Dest', installDir,
          '-Exe', exe,
        ],
        mode: ProcessStartMode.detached,
      );
      exit(0); // the script waits for this process to end, then swaps files
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (e is DioException && CancelToken.isCancel(e)) return;
      // Download or launch failed: fall back to a manual download.
      await _openInBrowser(latest.downloadUrl);
    }
  }

  static Future<bool> _isWritable(String dir) async {
    try {
      final probe = File('$dir${Platform.pathSeparator}.update_probe');
      await probe.writeAsString('ok');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Waits for the app to exit, unpacks the new build over the install folder
  /// and starts it again. If anything fails the old build is kept and relaunched
  /// (files are only copied after a complete, valid extraction).
  static const String _applyScript = r'''
param([int]$AppPid, [string]$Zip, [string]$Dest, [string]$Exe)
$ErrorActionPreference = 'Stop'
try { Wait-Process -Id $AppPid -Timeout 60 -ErrorAction SilentlyContinue } catch {}
Start-Sleep -Milliseconds 800
$staging = Join-Path (Split-Path $Zip) 'staging'
try {
  if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
  Expand-Archive -Path $Zip -DestinationPath $staging -Force
  if (-not (Test-Path (Join-Path $staging (Split-Path $Exe -Leaf)))) { throw 'Update package is missing the app.' }
  for ($i = 0; $i -lt 10; $i++) {
    try { Copy-Item -Path (Join-Path $staging '*') -Destination $Dest -Recurse -Force; break }
    catch { if ($i -eq 9) { throw }; Start-Sleep -Seconds 1 }
  }
} finally {
  Start-Process -FilePath $Exe
  Remove-Item (Split-Path $Zip) -Recurse -Force -ErrorAction SilentlyContinue
}
''';

  // ── Manifest ───────────────────────────────────────────────────────────────

  static Future<_Release?> _fetchLatest(String tag) async {
    try {
      final res = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        // GitHub serves release assets as application/octet-stream.
        responseType: ResponseType.plain,
      )).get<String>('$_releases$tag/version.json',
          queryParameters: {'t': DateTime.now().millisecondsSinceEpoch});
      final data = jsonDecode(res.data ?? '');
      if (data is! Map) return null;
      final build = int.tryParse('${data['build']}') ?? 0;
      final url = '${data['download_url'] ?? data['apk_url'] ?? ''}';
      // Only ever download from this repository's own release for this platform.
      if (build <= 0 || !url.startsWith('$_releases$tag/')) return null;
      return _Release(
        build: build,
        version: '${data['version'] ?? build}',
        downloadUrl: url,
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
    required this.downloadUrl,
    required this.notes,
    required this.minBuild,
  });

  final int build;
  final String version;
  final String downloadUrl;
  final String notes;
  final int minBuild;
}
