import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/core/utils/geo_input.dart';

/// Interactive Location and GPS preview card for customer site mapping.
class LocationPickerCard extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String address;
  final void Function(double lat, double lng) onLocationChanged;

  const LocationPickerCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.onLocationChanged,
  });

  @override
  State<LocationPickerCard> createState() => _LocationPickerCardState();
}

class _LocationPickerCardState extends State<LocationPickerCard> {
  bool _isAcquiring = false;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(text: widget.latitude?.toStringAsFixed(6) ?? '');
    _lngController = TextEditingController(text: widget.longitude?.toStringAsFixed(6) ?? '');
  }

  @override
  void didUpdateWidget(covariant LocationPickerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.latitude != oldWidget.latitude) {
      _latController.text = widget.latitude?.toStringAsFixed(6) ?? '';
    }
    if (widget.longitude != oldWidget.longitude) {
      _lngController.text = widget.longitude?.toStringAsFixed(6) ?? '';
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  /// The phone's real GPS position.
  Future<void> _useCurrentLocation() async {
    setState(() => _isAcquiring = true);
    try {
      final fix = await GeoInput.currentLocation();
      if (!mounted) return;
      _latController.text = fix.point.lat.toStringAsFixed(6);
      _lngController.text = fix.point.lng.toStringAsFixed(6);
      widget.onLocationChanged(fix.point.lat, fix.point.lng);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Site location captured (±${fix.accuracyM.round()} m)'),
        backgroundColor: AppColors.success,
      ));
    } on GeoError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 6),
        action: e.canOpenSettings ? SnackBarAction(label: 'Settings', onPressed: GeoInput.openAppSettings) : null,
      ));
    } finally {
      if (mounted) setState(() => _isAcquiring = false);
    }
  }

  /// Paste the pin copied from Google Maps (never a guessed location).
  Future<void> _pasteFromMaps() async {
    setState(() => _isAcquiring = true);
    final point = await GeoInput.fromClipboard();
    if (!mounted) return;
    setState(() => _isAcquiring = false);
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No coordinates on the clipboard. ${GeoInput.pasteHelp}'),
            backgroundColor: AppColors.warning, duration: Duration(seconds: 6)),
      );
      return;
    }
    _latController.text = point.lat.toStringAsFixed(6);
    _lngController.text = point.lng.toStringAsFixed(6);
    widget.onLocationChanged(point.lat, point.lng);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Site location set to ${point.display}'), backgroundColor: AppColors.success),
    );
  }

  void _onManualCoordinateChanged() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
      widget.onLocationChanged(lat, lng);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = widget.latitude != null && widget.longitude != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: hasCoords ? AppColors.teal500.withValues(alpha: 0.4) : AppColors.navy700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.teal500, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Installation Site Location (GPS)',
                style: TextStyle(
                  color: AppColors.fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (hasCoords)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Captured',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (GeoInput.gpsSupported) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isAcquiring ? null : _useCurrentLocation,
                icon: _isAcquiring
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal500))
                    : const Icon(Icons.my_location_rounded, color: AppColors.teal500, size: 18),
                label: Text(_isAcquiring ? 'Getting GPS fix…' : 'Use current location (at the site)',
                    style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.teal500),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Not at the site: pin it in Google Maps, then paste it here.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => GeoInput.openMaps(widget.address),
                  icon: const Icon(Icons.map_outlined, color: AppColors.teal500, size: 18),
                  label: const Text('Open Maps', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.teal500),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAcquiring ? null : _pasteFromMaps,
                  icon: const Icon(Icons.content_paste_rounded, color: AppColors.teal500, size: 18),
                  label: const Text('Paste location', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.teal500),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Not at the site? ${GeoInput.pasteHelp}', style: TextStyle(color: AppColors.grey500, fontSize: 11)),
          const SizedBox(height: 12),

          // Latitude and Longitude fields
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Latitude', style: TextStyle(color: AppColors.grey400, fontSize: 11)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      style: const TextStyle(color: AppColors.fg, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. 28.6139',
                        hintStyle: const TextStyle(color: AppColors.grey600, fontSize: 12),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: AppColors.navy900,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: const BorderSide(color: AppColors.navy700),
                        ),
                      ),
                      onChanged: (_) => _onManualCoordinateChanged(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Longitude', style: TextStyle(color: AppColors.grey400, fontSize: 11)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      style: const TextStyle(color: AppColors.fg, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. 77.2090',
                        hintStyle: const TextStyle(color: AppColors.grey600, fontSize: 12),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: AppColors.navy900,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: const BorderSide(color: AppColors.navy700),
                        ),
                      ),
                      onChanged: (_) => _onManualCoordinateChanged(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Map preview container
          if (hasCoords) ...[
            const SizedBox(height: 12),
            Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.navy900,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.navy700),
                image: const DecorationAnimationMapPlaceholder(),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_pin, color: AppColors.error, size: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.shadow.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${widget.latitude!.toStringAsFixed(4)}°, ${widget.longitude!.toStringAsFixed(4)}°',
                            style: const TextStyle(color: AppColors.fg, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.navy800.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: const Text('Map Preview', style: TextStyle(color: AppColors.grey400, fontSize: 9)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DecorationAnimationMapPlaceholder extends DecorationImage {
  const DecorationAnimationMapPlaceholder()
      : super(
          image: const AssetImage('assets/images/map_grid_pattern.png'),
          fit: BoxFit.cover,
          onError: _emptyImageError,
        );

  static void _emptyImageError(Object exception, StackTrace? stackTrace) {}
}
