import 'package:flutter_test/flutter_test.dart';
import 'package:solar_pro/core/utils/geo_input.dart';

void main() {
  test('parses plain coordinates', () {
    final p = GeoInput.parse('28.4595, 77.0266')!;
    expect(p.lat, 28.4595);
    expect(p.lng, 77.0266);
  });

  test('parses Google Maps URLs', () {
    expect(GeoInput.parse('https://www.google.com/maps/@28.4595,77.0266,17z')!.lng, 77.0266);
    expect(GeoInput.parse('https://maps.google.com/?q=28.5,77.1')!.lat, 28.5);
    expect(GeoInput.parse('https://www.google.com/maps/place/X/data=!3d28.61!4d77.20')!.lat, 28.61);
  });

  test('parses hemisphere notation', () {
    final p = GeoInput.parse('28.6139° N, 77.2090° E')!;
    expect(p.lat, 28.6139);
    expect(p.lng, 77.209);
    expect(GeoInput.parse('33.86° S, 151.21° E')!.lat, -33.86);
  });

  test('rejects text without coordinates and out-of-range values', () {
    expect(GeoInput.parse('Sector 9, Gurugram'), isNull);
    expect(GeoInput.parse('95.0, 77.0'), isNull);
    expect(GeoInput.parse('0, 0'), isNull);
    expect(GeoInput.parse(''), isNull);
  });
}
