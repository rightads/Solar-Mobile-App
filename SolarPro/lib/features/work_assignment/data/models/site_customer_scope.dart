import 'package:solar_pro/features/work_assignment/data/models/work_assignment_model.dart';

/// Scope of work for a site job, from `GET /work-assignments/{id}/scope`.
///
/// Only equipment and site details: the endpoint never returns prices,
/// payments or documents. Anything sales did not record is shown as
/// "Not specified" — never a made-up default the crew might act on.
class SiteCustomerScope {
  static const notSpecified = 'Not specified';

  final bool loaded;
  final String address;
  final String gps;

  // Structure
  final String structureType;
  final String structureHeight;
  final int? structureCount;
  final String panelBrand;
  final int? panelCount;
  final int? panelWatt;

  // Electrical
  final String inverterBrand;
  final int? inverterCount;
  final double? inverterCapacityKw;
  final double? systemCapacityKw;
  final String phase;
  final String acWire;
  final String dcWire;
  final String earthingWire;
  final String acSpd;
  final String dcSpd;
  final String solarMeter;

  // Civil
  final String civilWork;
  final String earthingNotes;

  const SiteCustomerScope({
    this.loaded = false,
    this.address = '',
    this.gps = '',
    this.structureType = notSpecified,
    this.structureHeight = notSpecified,
    this.structureCount,
    this.panelBrand = notSpecified,
    this.panelCount,
    this.panelWatt,
    this.inverterBrand = notSpecified,
    this.inverterCount,
    this.inverterCapacityKw,
    this.systemCapacityKw,
    this.phase = notSpecified,
    this.acWire = notSpecified,
    this.dcWire = notSpecified,
    this.earthingWire = notSpecified,
    this.acSpd = notSpecified,
    this.dcSpd = notSpecified,
    this.solarMeter = notSpecified,
    this.civilWork = notSpecified,
    this.earthingNotes = notSpecified,
  });

  static String _s(dynamic v) {
    final t = v?.toString().trim() ?? '';
    return t.isEmpty ? notSpecified : t;
  }

  static String _join(dynamic a, dynamic b) {
    final parts = [a, b].map((v) => v?.toString().trim() ?? '').where((t) => t.isNotEmpty).toList();
    return parts.isEmpty ? notSpecified : parts.join(' — ');
  }

  static int? _i(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
  static double? _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  factory SiteCustomerScope.fromScopeJson(Map<String, dynamic> json) {
    final bom = json['bom'] is Map ? Map<String, dynamic>.from(json['bom'] as Map) : const <String, dynamic>{};
    final phase = json['phase']?.toString().toLowerCase() ?? '';
    final meterCount = _i(bom['solar_meter_count']);
    return SiteCustomerScope(
      loaded: true,
      address: json['address']?.toString() ?? '',
      gps: json['location_gps']?.toString() ?? '',
      structureType: _s(json['structure_type']),
      structureHeight: _s(bom['structure_height']),
      structureCount: _i(bom['structure_count']),
      panelBrand: _s(json['panel_brand']),
      panelCount: _i(json['panel_count']),
      panelWatt: _i(json['panel_watt']),
      inverterBrand: _s(json['inverter_brand']),
      inverterCount: _i(bom['inverter_count']),
      inverterCapacityKw: _d(bom['inverter_capacity_kw']),
      systemCapacityKw: _d(json['capacity_kw']),
      phase: phase.contains('three') ? 'Three phase' : (phase.contains('single') ? 'Single phase' : notSpecified),
      acWire: _join(bom['ac_wire_brand'], bom['ac_wire_size']),
      dcWire: _join(bom['dc_wire_brand'], bom['dc_wire_size']),
      earthingWire: _join(bom['earthing_wire_brand'], bom['earthing_wire_size']),
      acSpd: _join(bom['spd_ac_brand'], bom['spd_ac_details']),
      dcSpd: _join(bom['spd_dc_brand'], bom['spd_dc_details']),
      solarMeter: bom['solar_meter_brand'] == null
          ? notSpecified
          : '${bom['solar_meter_brand']}${meterCount != null ? ' (qty $meterCount)' : ''}',
      civilWork: _s(bom['civil_work']),
      earthingNotes: _s(bom['earthing_notes']),
    );
  }

  String get _panels {
    if (panelBrand == notSpecified && panelCount == null) return notSpecified;
    final count = panelCount != null ? '$panelCount × ' : '';
    final watt = panelWatt != null && panelWatt! > 0 ? ' (${panelWatt}W)' : '';
    return '$count$panelBrand$watt';
  }

  String get _inverter {
    final cap = inverterCapacityKw ?? systemCapacityKw;
    final parts = [
      if (inverterCount != null) '$inverterCount ×',
      inverterBrand,
      if (cap != null && cap > 0) '${cap.toStringAsFixed(cap % 1 == 0 ? 0 : 1)} kW',
      if (phase != notSpecified) phase,
    ];
    return inverterBrand == notSpecified && cap == null ? notSpecified : parts.join(' ');
  }

  /// Role-specific scope lines for the job card.
  List<MapEntry<String, String>> getEntriesForRole(WorkType workType) {
    final site = [
      if (address.isNotEmpty) MapEntry('Site Address', address),
      if (gps.isNotEmpty) MapEntry('GPS', gps),
    ];
    switch (workType) {
      case WorkType.structure:
        return [
          ...site,
          MapEntry('Structure Type', structureType),
          MapEntry('Structure Height', structureHeight),
          if (structureCount != null) MapEntry('Structure Sets', '$structureCount'),
          MapEntry('Panels', _panels),
        ];
      case WorkType.electrical:
        return [
          ...site,
          MapEntry('Inverter', _inverter),
          MapEntry('AC Wiring', acWire),
          MapEntry('DC Solar Wiring', dcWire),
          MapEntry('Earthing Wire', earthingWire),
          MapEntry('AC Surge Protection', acSpd),
          MapEntry('DC Surge Protection', dcSpd),
          MapEntry('Solar Meter', solarMeter),
        ];
      case WorkType.civil:
        return [
          ...site,
          MapEntry('Civil Work', civilWork),
          MapEntry('Earthing', earthingNotes),
        ];
    }
  }
}
