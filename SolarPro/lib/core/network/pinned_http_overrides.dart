import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:solar_pro/core/constants/app_constants.dart';

/// Trusts the API server's self-signed certificate, and nothing else.
///
/// The API is reached by IP, so no public CA can vouch for it. Normal CA
/// validation still runs for every connection; only when it fails does this
/// callback decide, and it accepts the certificate solely for the API's own
/// host and port and only when its SHA-256 fingerprint equals
/// [AppConstants.apiCertSha256]. Installed globally so Dio and
/// Image.network (uploaded photos) both use it.
class PinnedHttpOverrides extends HttpOverrides {
  PinnedHttpOverrides() : _api = Uri.parse(AppConstants.baseUrl);

  final Uri _api;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) {
      final pin = AppConstants.apiCertSha256.trim().toLowerCase();
      if (pin.isEmpty) return false;
      if (host != _api.host || port != _api.port) return false;
      return sha256.convert(cert.der).toString() == pin;
    };
    return client;
  }
}
