import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_pro/core/network/pinned_http_overrides.dart';

/// Real TLS handshakes against local servers. Certificates are generated with
/// openssl at test time (skipped when openssl is not installed).
void main() {
  late Directory dir;
  late String pinnedFp;
  HttpServer? pinnedServer;
  HttpServer? caServer;
  late SecurityContext trustsTestCa;
  var haveOpenssl = true;

  Future<void> ssl(List<String> args) async {
    final r = await Process.run('openssl', args, workingDirectory: dir.path);
    if (r.exitCode != 0) throw StateError('openssl ${args.first} failed: ${r.stderr}');
  }

  Future<HttpServer> serve(String cert, String key) async {
    final ctx = SecurityContext()
      ..useCertificateChain('${dir.path}/$cert')
      ..usePrivateKey('${dir.path}/$key');
    final server = await HttpServer.bindSecure('127.0.0.1', 0, ctx);
    server.listen((req) => req.response
      ..write('ok')
      ..close());
    return server;
  }

  setUpAll(() async {
    try {
      await Process.run('openssl', ['version']);
    } catch (_) {
      haveOpenssl = false;
      return;
    }
    dir = await Directory.systemTemp.createTemp('pin_test');
    // The API's own self-signed certificate (what the app pins).
    await ssl(['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', 'pinned.key', '-out', 'pinned.crt',
      '-days', '2', '-subj', '/CN=api', '-addext', 'subjectAltName=IP:127.0.0.1']);
    // An attacker's certificate for the same IP, issued by a CA the device trusts.
    await ssl(['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', 'ca.key', '-out', 'ca.crt',
      '-days', '2', '-subj', '/CN=Test CA', '-addext', 'basicConstraints=critical,CA:TRUE',
      '-addext', 'keyUsage=critical,keyCertSign,cRLSign']);
    await ssl(['req', '-newkey', 'rsa:2048', '-nodes', '-keyout', 'leaf.key', '-out', 'leaf.csr', '-subj', '/CN=127.0.0.1']);
    await File('${dir.path}/ext.cnf').writeAsString('subjectAltName=IP:127.0.0.1\n');
    await ssl(['x509', '-req', '-in', 'leaf.csr', '-CA', 'ca.crt', '-CAkey', 'ca.key', '-CAcreateserial',
      '-out', 'leaf.crt', '-days', '2', '-extfile', 'ext.cnf']);
    await ssl(['x509', '-in', 'pinned.crt', '-outform', 'der', '-out', 'pinned.der']);

    pinnedFp = sha256.convert(await File('${dir.path}/pinned.der').readAsBytes()).toString();
    trustsTestCa = SecurityContext(withTrustedRoots: true)..setTrustedCertificates('${dir.path}/ca.crt');
    pinnedServer = await serve('pinned.crt', 'pinned.key');
    caServer = await serve('leaf.crt', 'leaf.key');
  });

  tearDownAll(() async {
    await pinnedServer?.close(force: true);
    await caServer?.close(force: true);
    if (haveOpenssl) await dir.delete(recursive: true);
  });

  Future<String> get(HttpClient client, int port) async {
    try {
      final req = await client.getUrl(Uri.parse('https://127.0.0.1:$port/'));
      final res = await req.close();
      return await res.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  HttpClient clientFor(int apiPort, {String? pin}) =>
      PinnedHttpOverrides(api: Uri.parse('https://127.0.0.1:$apiPort/api/v1'), pin: pin ?? pinnedFp)
          .createHttpClient(trustsTestCa);

  test('API with the pinned self-signed certificate is accepted', () async {
    if (!haveOpenssl) return markTestSkipped('openssl not installed');
    expect(await get(clientFor(pinnedServer!.port), pinnedServer!.port), 'ok');
  });

  test('API presenting a CA-trusted certificate that is not the pin is rejected (MITM)', () async {
    if (!haveOpenssl) return markTestSkipped('openssl not installed');
    await expectLater(get(clientFor(caServer!.port), caServer!.port), throwsA(isA<HandshakeException>()));
  });

  test('API with a different self-signed certificate is rejected', () async {
    if (!haveOpenssl) return markTestSkipped('openssl not installed');
    await expectLater(get(clientFor(pinnedServer!.port, pin: 'ab' * 32), pinnedServer!.port),
        throwsA(isA<HandshakeException>()));
  });

  test('other hosts keep normal CA validation', () async {
    if (!haveOpenssl) return markTestSkipped('openssl not installed');
    // The API is on pinnedServer's port; caServer is "some other site" with a valid CA chain.
    expect(await get(clientFor(pinnedServer!.port), caServer!.port), 'ok');
    // ...and an untrusted self-signed certificate on a non-API host is still refused.
    await expectLater(get(clientFor(caServer!.port), pinnedServer!.port), throwsA(isA<HandshakeException>()));
  });
}
