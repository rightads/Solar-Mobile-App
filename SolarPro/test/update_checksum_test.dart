import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_pro/core/services/update_service.dart';

void main() {
  late File zip;
  late String good;

  setUpAll(() async {
    zip = File('${(await Directory.systemTemp.createTemp('upd_test')).path}/SolarPro-Windows.zip');
    await zip.writeAsBytes(List<int>.generate(200000, (i) => i % 251));
    good = sha256.convert(await zip.readAsBytes()).toString();
  });

  tearDownAll(() => zip.parent.delete(recursive: true));

  test('update zip matching the published SHA-256 is accepted', () async {
    expect(await UpdateService.fileMatchesSha256(zip.path, good), isTrue);
    expect(await UpdateService.fileMatchesSha256(zip.path, good.toUpperCase()), isTrue);
  });

  test('tampered, truncated or unhashed updates are refused', () async {
    expect(await UpdateService.fileMatchesSha256(zip.path, 'ab' * 32), isFalse);
    expect(await UpdateService.fileMatchesSha256(zip.path, ''), isFalse, reason: 'no hash published');
    expect(await UpdateService.fileMatchesSha256(zip.path, 'not-a-hash'), isFalse);
    final truncated = File('${zip.parent.path}/truncated.zip');
    await truncated.writeAsBytes((await zip.readAsBytes()).sublist(0, 1000));
    expect(await UpdateService.fileMatchesSha256(truncated.path, good), isFalse);
  });
}
