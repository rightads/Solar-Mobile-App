import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:solar_pro/core/constants/app_constants.dart';

/// Trusts the API server's own certificate, and nothing else, for the API.
///
/// The API is reached by IP with a self-signed certificate, so no public CA
/// can vouch for it. Connections to the API host and port are opened with an
/// empty trust store, so *every* certificate goes to the pin check, which
/// accepts only the one whose SHA-256 fingerprint equals
/// [AppConstants.apiCertSha256]. A certificate a public CA issued for the
/// server's IP (or one from a CA installed on the device) is rejected as well.
/// The API is always reached directly, never through a proxy tunnel. Every
/// other host (GitHub updates, fonts) keeps normal CA validation.
///
/// Installed globally so Dio and Image.network (uploaded photos, which carry
/// the bearer token) both use it.
class PinnedHttpOverrides extends HttpOverrides {
  PinnedHttpOverrides({Uri? api, String? pin})
      : _api = api ?? Uri.parse(AppConstants.baseUrl),
        _pin = (pin ?? AppConstants.apiCertSha256).trim().toLowerCase();

  final Uri _api;
  final String _pin;

  bool _isApi(String host, int port) => host == _api.host && port == _api.port;

  bool _matchesPin(X509Certificate cert) =>
      _pin.isNotEmpty && sha256.convert(cert.der).toString() == _pin;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) => _isApi(host, port) && _matchesPin(cert);
    if (_pin.isEmpty || _api.scheme != 'https') return client; // no pin: plain CA validation

    client.findProxy = (uri) =>
        _isApi(uri.host, uri.port) ? 'DIRECT' : HttpClient.findProxyFromEnvironment(uri);
    client.connectionFactory = (uri, proxyHost, proxyPort) {
      if (proxyHost != null && proxyPort != null) {
        // Never the API (see findProxy). HttpClient builds the TLS tunnel itself.
        return Socket.startConnect(proxyHost, proxyPort);
      }
      if (uri.scheme != 'https') return Socket.startConnect(uri.host, uri.port);
      if (_isApi(uri.host, uri.port)) {
        return SecureSocket.startConnect(
          uri.host,
          uri.port,
          context: SecurityContext(withTrustedRoots: false),
          onBadCertificate: _matchesPin,
        );
      }
      return SecureSocket.startConnect(uri.host, uri.port, context: context);
    };
    return client;
  }
}
