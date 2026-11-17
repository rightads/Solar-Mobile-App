import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart';

/// A latitude/longitude pair entered or pasted by the user.
class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);

  String get display => '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
}

/// Site coordinates come from what the user actually provides: typed
/// numbers, or a location copied from Google Maps. Nothing is ever guessed.
class GeoInput {
  GeoInput._();

  static bool _valid(double lat, double lng) => lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 && !(lat == 0 && lng == 0);

  /// Parses "28.4595, 77.0266", Google Maps URLs (`@lat,lng`, `q=lat,lng`,
  /// `ll=`, `!3dlat!4dlng`) and "28.4595° N, 77.0266° E".
  static GeoPoint? parse(String? raw) {
    var text = (raw ?? '').trim();
    try {
      text = Uri.decodeFull(text); // %2C etc. in shared links
    } catch (_) {} // not URL-encoded: use as typed
    if (text.isEmpty) return null;
    const num = r'(-?\d{1,3}(?:\.\d+)?)';
    final patterns = [
      RegExp('!3d$num!4d$num'),
      RegExp('@$num,$num'),
      RegExp('[?&](?:q|ll|query|destination|center)=$num,\\s*$num'),
      RegExp('^$num\\s*,\\s*$num\$'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final lat = double.parse(m.group(1)!), lng = double.parse(m.group(2)!);
        if (_valid(lat, lng)) return GeoPoint(lat, lng);
      }
    }
    // Degrees with hemispheres: 28.6139° N, 77.2090° E
    final dm = RegExp(r'(\d{1,3}(?:\.\d+)?)\s*°?\s*([NS])[\s,]+(\d{1,3}(?:\.\d+)?)\s*°?\s*([EW])', caseSensitive: false)
        .firstMatch(text);
    if (dm != null) {
      var lat = double.parse(dm.group(1)!), lng = double.parse(dm.group(3)!);
      if (dm.group(2)!.toUpperCase() == 'S') lat = -lat;
      if (dm.group(4)!.toUpperCase() == 'W') lng = -lng;
      if (_valid(lat, lng)) return GeoPoint(lat, lng);
    }
    return null;
  }

  /// Reads coordinates from the clipboard (after "Share → Copy" or long-press
  /// "copy coordinates" in Google Maps). Returns null if none are found.
  static Future<GeoPoint?> fromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return parse(data?.text);
  }

  /// Opens Google Maps at the site address so the user can drop a pin and copy it.
  static Future<bool> openMaps(String address) {
    final q = address.trim().isEmpty ? 'India' : address.trim();
    return launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Device GPS is used on phones; desktop builds use the paste flow.
  static bool get gpsSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// The phone's real current position. Throws [GeoError] with a message
  /// the user can act on (location off, permission denied, no fix).
  static Future<({GeoPoint point, double accuracyM})> currentLocation() async {
    if (!gpsSupported) throw const GeoError('GPS is available in the mobile app. Paste the location from Google Maps instead.');
    final geo = GeolocatorPlatform.instance;
    if (!await geo.isLocationServiceEnabled()) {
      throw const GeoError('Location is turned off. Turn on Location (GPS) in your phone settings and try again.');
    }
    var permission = await geo.checkPermission();
    if (permission == LocationPermission.denied) permission = await geo.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      throw const GeoError('Location permission is blocked for SolarPro. Allow it in App settings, or paste the location from Google Maps.',
          canOpenSettings: true);
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
      throw const GeoError('Location permission was not granted. Paste the location from Google Maps instead.');
    }
    try {
      final pos = await geo.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      return (point: GeoPoint(pos.latitude, pos.longitude), accuracyM: pos.accuracy);
    } catch (_) {
      throw const GeoError('Could not get a GPS fix. Move to an open area and retry, or paste the location from Google Maps.');
    }
  }

  static Future<void> openAppSettings() => GeolocatorPlatform.instance.openAppSettings();

  static const pasteHelp =
      'In Google Maps, long-press the site to drop a pin, tap the coordinates to copy them, then tap Paste here.';
}

/// A location problem with a message meant for the user.
class GeoError implements Exception {
  final String message;
  final bool canOpenSettings;
  const GeoError(this.message, {this.canOpenSettings = false});
  @override
  String toString() => message;
}
