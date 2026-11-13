import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/service/presentation/tabs/service_tickets_tab.dart';

/// Admin page for every service ticket raised by customers: search, filter by
/// status, open a ticket to assign a service engineer, follow progress and
/// reply. Service engineers use the same list inside their own portal.
class TicketsScreen extends StatelessWidget {
  /// False when embedded in the desktop shell, which draws its own header.
  final bool showAppBar;

  const TicketsScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: showAppBar
          ? AppBar(
              title: const Text('Service Tickets', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: const ServiceTicketsTab(),
    );
  }
}
