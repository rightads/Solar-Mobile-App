import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/service/presentation/screens/service_ticket_detail_screen.dart';
import 'package:solar_pro/features/employee/service/presentation/widgets/service_ticket_card.dart';
import 'package:solar_pro/features/tickets/data/models/ticket_model.dart';
import 'package:solar_pro/features/tickets/data/repositories/ticket_repository.dart';

class ServiceTicketsTab extends StatefulWidget {
  final TicketRepository? repository;

  const ServiceTicketsTab({
    super.key,
    this.repository,
  });

  @override
  State<ServiceTicketsTab> createState() => _ServiceTicketsTabState();
}

class _ServiceTicketsTabState extends State<ServiceTicketsTab>
    with SingleTickerProviderStateMixin {
  late TicketRepository _repo;
  late TabController _tabController;
  bool _isLoading = true;
  List<TicketModel> _tickets = [];

  // Filters
  TicketType? _selectedType;
  TicketPriority? _selectedPriority;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? TicketRepository();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.listTickets(
        type: _selectedType,
        priority: _selectedPriority,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _tickets = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openDetail(TicketModel ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceTicketDetailScreen(
          initialTicket: ticket,
          repository: _repo,
        ),
      ),
    ).then((_) => _loadTickets());
  }

  List<TicketModel> _getFilteredTicketsForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: // Assigned to me
        return _tickets.where((t) => t.status == TicketStatus.assigned || t.status == TicketStatus.open).toList();
      case 1: // In progress
        return _tickets.where((t) => t.status == TicketStatus.inProgress).toList();
      case 2: // Resolved
        return _tickets.where((t) => t.status == TicketStatus.resolved || t.status == TicketStatus.closed).toList();
      default:
        return _tickets;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentList = _getFilteredTicketsForTab(_tabController.index);

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: AppColors.navy800,
            child: Column(
              children: [
                // Search Field
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _loadTickets(),
                  style: const TextStyle(color: AppColors.fg, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by ticket #, customer, error code...',
                    hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey400, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppColors.grey400, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadTickets();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.navy900,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.navy600),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.navy600),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.gold500),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Type Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All Types',
                        isSelected: _selectedType == null,
                        onSelected: () {
                          setState(() => _selectedType = null);
                          _loadTickets();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Inverter',
                        isSelected: _selectedType == TicketType.inverter,
                        onSelected: () {
                          setState(() => _selectedType = TicketType.inverter);
                          _loadTickets();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Wiring',
                        isSelected: _selectedType == TicketType.wiring,
                        onSelected: () {
                          setState(() => _selectedType = TicketType.wiring);
                          _loadTickets();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Structure',
                        isSelected: _selectedType == TicketType.structure,
                        onSelected: () {
                          setState(() => _selectedType = TicketType.structure);
                          _loadTickets();
                        },
                      ),
                      const SizedBox(width: 12),
                      Container(height: 16, width: 1, color: AppColors.navy600),
                      const SizedBox(width: 12),
                      // Priority Chips
                      _buildFilterChip(
                        label: 'All Priorities',
                        isSelected: _selectedPriority == null,
                        onSelected: () {
                          setState(() => _selectedPriority = null);
                          _loadTickets();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Urgent',
                        isSelected: _selectedPriority == TicketPriority.urgent,
                        activeColor: AppColors.error,
                        onSelected: () {
                          setState(() => _selectedPriority = TicketPriority.urgent);
                          _loadTickets();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'High',
                        isSelected: _selectedPriority == TicketPriority.high,
                        activeColor: Colors.orangeAccent,
                        onSelected: () {
                          setState(() => _selectedPriority = TicketPriority.high);
                          _loadTickets();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Normal',
                        isSelected: _selectedPriority == TicketPriority.normal,
                        activeColor: AppColors.gold500,
                        onSelected: () {
                          setState(() => _selectedPriority = TicketPriority.normal);
                          _loadTickets();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar: Assigned, In Progress, Resolved
          Container(
            color: AppColors.navy800,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.gold500,
              indicatorWeight: 3,
              labelColor: AppColors.gold500,
              unselectedLabelColor: AppColors.grey400,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Assigned'),
                        const SizedBox(width: 6),
                        _buildCountBadge(
                          _tickets.where((t) => t.status == TicketStatus.assigned || t.status == TicketStatus.open).length,
                        ),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('In Progress'),
                        const SizedBox(width: 6),
                        _buildCountBadge(
                          _tickets.where((t) => t.status == TicketStatus.inProgress).length,
                          badgeColor: AppColors.info,
                        ),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Resolved'),
                        const SizedBox(width: 6),
                        _buildCountBadge(
                          _tickets.where((t) => t.status == TicketStatus.resolved || t.status == TicketStatus.closed).length,
                          badgeColor: AppColors.success,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Ticket List Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTickets,
              color: AppColors.gold500,
              backgroundColor: AppColors.navy800,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold500))
                  : currentList.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _tabController.index == 2
                                        ? Icons.task_alt_rounded
                                        : Icons.inbox_rounded,
                                    size: 56,
                                    color: AppColors.grey600,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _tabController.index == 0
                                        ? 'No assigned tickets found'
                                        : _tabController.index == 1
                                            ? 'No tickets currently in progress'
                                            : 'No resolved tickets yet',
                                    style: const TextStyle(
                                      color: AppColors.fg,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Pull down to refresh tickets queue',
                                    style: TextStyle(color: AppColors.grey500, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: currentList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final ticket = currentList[index];
                            return ServiceTicketCard(
                              ticket: ticket,
                              onTap: () => _openDetail(ticket),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(int count, {Color badgeColor = AppColors.gold500}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: count > 0 ? badgeColor.withValues(alpha: 0.2) : AppColors.navy900,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: count > 0 ? badgeColor.withValues(alpha: 0.5) : AppColors.navy600,
        ),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: count > 0 ? badgeColor : AppColors.grey500,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? activeColor,
  }) {
    final effectiveColor = activeColor ?? AppColors.gold500;
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? effectiveColor.withValues(alpha: 0.2) : AppColors.navy900,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? effectiveColor : AppColors.navy600,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.fg : AppColors.grey400,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
