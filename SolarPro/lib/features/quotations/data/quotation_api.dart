import 'package:solar_pro/core/network/api_client.dart';

/// One equipment line of a quotation and the fields it asks for.
/// Mirrors the backend (app/api/v1/quotations.py ITEM_LABELS).
class QuoteItemDef {
  final String key;
  final String label;

  /// Field keys shown for this line: make, capacity, size, quantity, technology, other.
  final List<String> fields;

  /// Hint for the capacity / size field (e.g. "540 W").
  final String? capacityHint;
  const QuoteItemDef(this.key, this.label, this.fields, {this.capacityHint});
}

const kQuoteItems = [
  QuoteItemDef('solar_module', 'Solar Module', ['make', 'capacity', 'quantity', 'technology', 'other'],
      capacityHint: 'Module capacity (W)'),
  QuoteItemDef('solar_inverter', 'Solar Inverter', ['make', 'capacity', 'quantity', 'technology', 'other'],
      capacityHint: 'Capacity (kW)'),
  QuoteItemDef('solar_structure', 'Solar Structure', ['make', 'quantity', 'technology', 'other']),
  QuoteItemDef('acdb', 'ACDB', ['make', 'capacity', 'quantity', 'technology', 'other']),
  QuoteItemDef('dcdb', 'DCDB', ['make', 'capacity', 'quantity', 'technology', 'other']),
  QuoteItemDef('ac_wire', 'AC Wire', ['make', 'size', 'quantity', 'technology', 'other']),
  QuoteItemDef('dc_wire', 'DC Wire', ['make', 'size', 'quantity', 'technology', 'other']),
  QuoteItemDef('earthing_wire', 'Earthing Wire', ['make', 'size', 'quantity', 'technology', 'other']),
  QuoteItemDef('lightning_arrester', 'Lightning Arrester', ['make', 'size', 'quantity', 'other']),
  QuoteItemDef('earthing_kit', 'Earthing Kit', ['make', 'size', 'quantity', 'other']),
  QuoteItemDef('solar_meter', 'Solar Meter', ['make', 'size', 'quantity', 'other']),
  QuoteItemDef('civil_work', 'Civil Work', ['size', 'other']),
];

const kQuoteFieldLabels = {
  'make': 'Make (Brand)',
  'capacity': 'Capacity',
  'size': 'Size',
  'quantity': 'Quantity',
  'technology': 'Technology',
  'other': 'Other',
};

/// Read-only view over a quotation returned by the API.
class Quotation {
  final Map<String, dynamic> raw;
  const Quotation(this.raw);

  String get id => (raw['id'] ?? raw['_id'] ?? '').toString();
  String get quoteNo => (raw['quote_no'] ?? '').toString();
  int get version => (raw['version'] as num?)?.toInt() ?? 1;
  String get status => (raw['status'] ?? 'sent').toString();
  bool get isPending => status == 'sent';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  String get customerId => (raw['customer_id'] ?? '').toString();
  String get customerName => (raw['customer_name'] ?? '').toString();
  double get capacityKw => _num(raw['capacity_kw']);
  double get loadKw => _num(raw['load_kw']);
  double get projectCost => _num(raw['project_cost']);
  double get discomCharges => _num(raw['discom_charges']);
  double get fileCharges => _num(raw['file_charges']);
  double get total => _num(raw['total_amount']);
  String get remark => (raw['remark'] ?? '').toString();
  String? get clientRemark => raw['client_remark']?.toString();
  String get createdBy => (raw['created_by_name'] ?? '').toString();
  DateTime? get sentAt => DateTime.tryParse((raw['sent_at'] ?? raw['created_at'] ?? '').toString())?.toLocal();
  DateTime? get decidedAt => DateTime.tryParse((raw['decided_at'] ?? '').toString())?.toLocal();

  Map<String, dynamic> item(String key) {
    final items = raw['items'];
    if (items is Map && items[key] is Map) return Map<String, dynamic>.from(items[key] as Map);
    return const {};
  }

  List<Map<String, dynamic>> get otherItems => [
        for (final o in (raw['other_items'] as List? ?? const []))
          if (o is Map) Map<String, dynamic>.from(o),
      ];

  static double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
}

class QuotationApi {
  QuotationApi._();
  static final _api = ApiClient();

  static List<Quotation> _list(dynamic data) => [
        for (final q in (data as List? ?? const []))
          if (q is Map) Quotation(Map<String, dynamic>.from(q))
      ];

  /// Staff: every version for one customer, newest first.
  static Future<List<Quotation>> forCustomer(String customerId) async {
    final res = await _api.get('/quotations', queryParameters: {'customer_id': customerId});
    return _list(res.data);
  }

  /// Client: quotations sent to me (pending, approved and rejected).
  static Future<List<Quotation>> mine() async {
    final res = await _api.get('/quotations/mine');
    return _list(res.data);
  }

  static Future<Quotation> create(Map<String, dynamic> payload) async {
    final res = await _api.post('/quotations', data: payload);
    return Quotation(Map<String, dynamic>.from(res.data as Map));
  }

  static Future<Quotation> approve(String id) async {
    final res = await _api.post('/quotations/$id/approve');
    return Quotation(Map<String, dynamic>.from(res.data as Map));
  }

  static Future<Quotation> reject(String id, String remark) async {
    final res = await _api.post('/quotations/$id/reject', data: {'remark': remark});
    return Quotation(Map<String, dynamic>.from(res.data as Map));
  }
}
