import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// Downloads a file the signed-in user may access (reports, receipts, proofs)
/// and lets them choose where to save it.
class FileDownloader {
  FileDownloader._();

  static const xlsx = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// [path] is an API path (`/reports/export/payments`) or a stored file URL
  /// (`/api/v1/files/...`). Shows the outcome as a snackbar.
  static Future<void> save(
    BuildContext context, {
    required String path,
    required String fileName,
    String? mimeType,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Downloading $fileName…'), duration: const Duration(seconds: 2)));
    try {
      final dio = ApiClient().dio;
      final base = dio.options.baseUrl;
      // Stored file URLs may already carry the /api/v1 prefix.
      final apiPath = path.startsWith('/api/') && base.endsWith('/api/v1') ? path.substring('/api/v1'.length) : path;
      final res = await dio.get<List<int>>(apiPath, options: Options(responseType: ResponseType.bytes));
      final bytes = Uint8List.fromList(res.data ?? const []);
      if (bytes.isEmpty) throw Exception('The file is empty.');
      final type = (mimeType ?? res.headers.value('content-type') ?? 'application/octet-stream').split(';').first.trim();
      // Names passed without an extension get one from the server's content type.
      const exts = {'application/pdf': 'pdf', 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp',
                    'image/heic': 'heic', xlsx: 'xlsx'};
      final name = fileName.contains('.') ? fileName : '$fileName.${exts[type] ?? 'bin'}';
      final saved = await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: type);
      messenger.hideCurrentSnackBar();
      if (saved != null) {
        messenger.showSnackBar(SnackBar(content: Text('Saved $name'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(ApiClient.toFriendly(e, fallback: 'Download failed.').toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  /// Excel export from `/reports/export/{kind}` (customers, payments, inventory).
  static Future<void> exportReport(BuildContext context, String kind) {
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    return save(context, path: '/reports/export/$kind', fileName: 'solarpro_${kind}_$stamp.xlsx', mimeType: xlsx);
  }
}
