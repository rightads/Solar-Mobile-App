import 'package:solar_pro/core/network/api_client.dart';

/// Live counts for the admin dashboards (phone and desktop).
///
/// Each source is fetched independently, so one failing endpoint only
/// leaves its own numbers at zero.
class AdminStats {
  final int activeLeads;
  final int customers;
  final int liveSystems;
  final int pendingPayments;
  final int pendingPaymentsPaise;
  final int contractValuePaise;
  final int activeWorks;
  final int activeTeams;
  final int worksDue;
  final int kedlPending;
  final int openTickets;

  const AdminStats({
    this.activeLeads = 0,
    this.customers = 0,
    this.liveSystems = 0,
    this.pendingPayments = 0,
    this.pendingPaymentsPaise = 0,
    this.contractValuePaise = 0,
    this.activeWorks = 0,
    this.activeTeams = 0,
    this.worksDue = 0,
    this.kedlPending = 0,
    this.openTickets = 0,
  });

  static const _closedLeads = {'converted', 'won', 'closed', 'lost'};
  static const _doneWorks = {'completed', 'cancelled'};
  static const _doneKedl = {'approved', 'rejected'};
  static const _doneTickets = {'resolved', 'closed'};
  static const _liveStages = {'SYSTEM_LIVE', 'HANDED_OVER'};

  static Future<AdminStats> load() async {
    final api = ApiClient();
    final results = await Future.wait<List<Map<String, dynamic>>>([
      api.getLeads(),
      api.getCustomers(),
      _list(api, '/payments/pending'),
      api.getWorkAssignments(),
      api.getKedlFiles(),
      _list(api, '/tickets'),
    ]);
    final leads = results[0];
    final customers = results[1];
    final payments = results[2];
    final works = results[3];
    final kedl = results[4];
    final tickets = results[5];

    String status(Map<String, dynamic> m) =>
        (m['status'] ?? '').toString().toLowerCase();
    int paise(dynamic v) => v is num ? v.toInt() : 0;

    final activeWorks = works.where((w) => !_doneWorks.contains(status(w))).toList();
    final today = DateTime.now();
    final endOfToday = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return AdminStats(
      activeLeads: leads.where((l) => !_closedLeads.contains(status(l))).length,
      customers: customers.length,
      liveSystems: customers
          .where((c) => _liveStages.contains((c['stage'] ?? '').toString()))
          .length,
      pendingPayments: payments.length,
      pendingPaymentsPaise: payments.fold(0, (sum, p) => sum + paise(p['amount'])),
      contractValuePaise: customers.fold(
          0, (sum, c) => sum + paise(c['final_price'] ?? c['total_amount'])),
      activeWorks: activeWorks.length,
      activeTeams: activeWorks
          .map((w) => (w['team_name'] ?? w['team_id'] ?? '').toString())
          .where((t) => t.isNotEmpty)
          .toSet()
          .length,
      worksDue: activeWorks.where((w) {
        final end = DateTime.tryParse((w['end_date'] ?? '').toString());
        return end != null && !end.isAfter(endOfToday);
      }).length,
      kedlPending: kedl.where((k) => !_doneKedl.contains(status(k))).length,
      openTickets: tickets.where((t) => !_doneTickets.contains(status(t))).length,
    );
  }

  static Future<List<Map<String, dynamic>>> _list(ApiClient api, String path) async {
    try {
      final res = await api.get<dynamic>(path);
      final data = res.data;
      final items = data is Map ? data['items'] : data;
      if (items is List) {
        return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Formats paise as a short rupee figure: ₹950, ₹45.2K, ₹3.4L, ₹1.2Cr.
  static String rupees(int paise) {
    final r = paise / 100;
    if (r >= 10000000) return '₹${(r / 10000000).toStringAsFixed(1)}Cr';
    if (r >= 100000) return '₹${(r / 100000).toStringAsFixed(1)}L';
    if (r >= 1000) return '₹${(r / 1000).toStringAsFixed(1)}K';
    return '₹${r.toStringAsFixed(0)}';
  }
}
