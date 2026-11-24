import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/services/update_service.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// Result of one probe of `GET /health` on the API server.
class ServerStatus {
  const ServerStatus({
    required this.reachable,
    required this.databaseOk,
    this.httpStatus,
    this.latencyMs,
    this.detail,
  });

  /// The server answered over the pinned TLS connection (any HTTP status).
  final bool reachable;

  /// `/health` returned 200, which the backend only does after a MongoDB ping.
  final bool databaseOk;
  final int? httpStatus;
  final int? latencyMs;

  /// Human-readable reason when something is wrong.
  final String? detail;

  bool get connected => reachable && databaseOk;
}

/// Calls the public health endpoint with a throwaway client (no auth header,
/// no session refresh), so it works signed in or out. TLS goes through the
/// globally installed [PinnedHttpOverrides], so a wrong certificate shows up
/// here as a pin failure rather than being silently accepted.
Future<ServerStatus> checkServerStatus() async {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    validateStatus: (_) => true,
  ));
  final watch = Stopwatch()..start();
  try {
    final res = await dio.get<dynamic>('/health');
    watch.stop();
    final code = res.statusCode ?? 0;
    final body = res.data;
    final ok = code == 200 && body is Map && body['status'] == 'ok';
    String? detail;
    if (!ok) {
      final err = body is Map ? body['error'] : null;
      detail = err is Map && err['message'] is String
          ? err['message'] as String
          : 'Unexpected response (HTTP $code).';
    }
    return ServerStatus(
      reachable: true,
      databaseOk: ok,
      httpStatus: code,
      latencyMs: watch.elapsedMilliseconds,
      detail: detail,
    );
  } on DioException catch (e) {
    watch.stop();
    return ServerStatus(reachable: false, databaseOk: false, detail: _describe(e));
  } catch (e) {
    return ServerStatus(reachable: false, databaseOk: false, detail: e.runtimeType.toString());
  } finally {
    dio.close(force: true);
  }
}

String _describe(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
      return 'Connection timed out. Server down, wrong port, or firewall dropping traffic.';
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return 'Server accepted the connection but did not answer in time.';
    case DioExceptionType.badCertificate:
      return 'TLS certificate does not match the pinned fingerprint.';
    case DioExceptionType.connectionError:
      final msg = '${e.error ?? e.message ?? ''}';
      if (msg.contains('CERTIFICATE') || msg.contains('Handshake')) {
        return 'TLS handshake failed: certificate does not match the pinned fingerprint.';
      }
      return 'No connection. Check the device network, or the server is refusing connections.';
    case DioExceptionType.cancel:
      return 'Request cancelled.';
    default:
      return 'Network error: ${e.message ?? e.type.name}';
  }
}

/// Hidden developer entry: wraps [child] and opens the server status sheet
/// after [taps] quick taps (each within [window] of the previous one).
class DevTapTrigger extends StatefulWidget {
  const DevTapTrigger({
    super.key,
    required this.child,
    this.taps = 7,
    this.window = const Duration(milliseconds: 600),
    this.check = checkServerStatus,
  });

  final Widget child;
  final int taps;
  final Duration window;
  final Future<ServerStatus> Function() check;

  @override
  State<DevTapTrigger> createState() => _DevTapTriggerState();
}

class _DevTapTriggerState extends State<DevTapTrigger> {
  int _count = 0;
  Timer? _reset;

  void _onTap() {
    _reset?.cancel();
    _count++;
    if (_count >= widget.taps) {
      _count = 0;
      HapticFeedback.mediumImpact();
      ServerStatusSheet.show(context, check: widget.check);
      return;
    }
    // A pause longer than [window] between taps starts the count over.
    _reset = Timer(widget.window, () => _count = 0);
  }

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: widget.child,
      );
}

class ServerStatusSheet extends StatefulWidget {
  const ServerStatusSheet({super.key, this.check = checkServerStatus});

  final Future<ServerStatus> Function() check;

  static Future<void> show(BuildContext context, {Future<ServerStatus> Function() check = checkServerStatus}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ServerStatusSheet(check: check),
    );
  }

  @override
  State<ServerStatusSheet> createState() => _ServerStatusSheetState();
}

class _ServerStatusSheetState extends State<ServerStatusSheet> {
  ServerStatus? _status;
  bool _loading = false;
  DateTime? _checkedAt;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    final s = await widget.check();
    if (!mounted) return;
    setState(() {
      _status = s;
      _loading = false;
      _checkedAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final (Color color, IconData icon, String label) = _loading || s == null
        ? (AppColors.grey400, Icons.sync_rounded, 'Checking…')
        : s.connected
            ? (AppColors.green500, Icons.check_circle_rounded, 'Connected to server')
            : s.reachable
                ? (AppColors.orange500, Icons.warning_amber_rounded, 'Server up, database unavailable')
                : (AppColors.red500, Icons.cloud_off_rounded, 'Not connected');
    final pin = AppConstants.apiCertSha256.trim();
    const build = UpdateService.currentBuild;
    final t = _checkedAt;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.navy600, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Developer · Server status', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 16),
            Container(
              key: const ValueKey('server-status-pill'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  _loading
                      ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: color))
                      : Icon(icon, color: color, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label, style: AppTextStyles.labelLarge.copyWith(color: AppColors.fg)),
                  ),
                ],
              ),
            ),
            if (!_loading && s?.detail != null) ...[
              const SizedBox(height: 10),
              Text(s!.detail!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.fg70)),
            ],
            const SizedBox(height: 14),
            _row('Endpoint', '${AppConstants.baseUrl}/health'),
            _row('HTTP status', s?.httpStatus?.toString() ?? '—'),
            _row('Latency', s?.latencyMs != null ? '${s!.latencyMs} ms' : '—'),
            _row('Database', s == null ? '—' : (s.databaseOk ? 'OK' : (s.reachable ? 'Unavailable' : 'Unknown'))),
            _row('TLS pin', pin.isEmpty ? 'none (CA only)' : '${pin.substring(0, pin.length.clamp(0, 16))}…'),
            _row('App build', build == 0 ? 'dev' : '$build'),
            _row('Checked at', t == null ? '—' : '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _run,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check again'),
            ),
          ],
        ),
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: Text(k, style: AppTextStyles.bodySmall.copyWith(color: AppColors.fg70)),
            ),
            Expanded(
              child: SelectableText(v, style: AppTextStyles.bodySmall.copyWith(color: AppColors.fg)),
            ),
          ],
        ),
      );
}
