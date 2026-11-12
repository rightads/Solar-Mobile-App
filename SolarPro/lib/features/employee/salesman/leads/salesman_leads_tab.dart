import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/employee/salesman/leads/add_lead_bottom_sheet.dart';
import 'package:solar_pro/features/employee/salesman/leads/salesman_lead_detail_screen.dart';
import 'package:solar_pro/features/leads/data/lead_repository.dart';
import 'package:solar_pro/features/leads/data/models/lead_model.dart';

class SalesmanLeadsTab extends StatefulWidget {
  const SalesmanLeadsTab({super.key});

  @override
  State<SalesmanLeadsTab> createState() => _SalesmanLeadsTabState();
}

class _SalesmanLeadsTabState extends State<SalesmanLeadsTab> {
  final LeadRepository _repository = LeadRepository();
  final TextEditingController _searchController = TextEditingController();

  List<LeadModel> _allLeads = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  String? _currentUserId;

  final List<String> _filters = ['All', 'New', 'Follow-up', 'Closed', 'Returned'];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _fetchLeads();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getString(AppConstants.kUserId);
      });
    }
  }

  Future<void> _fetchLeads() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final leads = await _repository.getLeads();
      if (mounted) {
        setState(() {
          _allLeads = leads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  List<LeadModel> get _filteredLeads {
    return _allLeads.where((lead) {
      // Status filter
      if (_selectedFilter != 'All') {
        if (lead.uiStatusLabel.toLowerCase() != _selectedFilter.toLowerCase()) {
          return false;
        }
      }
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final nameMatch = lead.name.toLowerCase().contains(_searchQuery);
        final phoneMatch = lead.phone.contains(_searchQuery);
        final addressMatch = (lead.address ?? '').toLowerCase().contains(_searchQuery);
        return nameMatch || phoneMatch || addressMatch;
      }
      return true;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return AppColors.info;
      case 'follow_up':
        return AppColors.gold500;

      case 'converted':
        return AppColors.teal500;
      case 'lost':
        return AppColors.error;
      default:
        return AppColors.grey500;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppColors.navy800,
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.fg, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by prospect name or phone...',
                    hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey400, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.grey400, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    filled: true,
                    fillColor: AppColors.navy900,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.navy600),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.navy600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedFilter = filter);
                            }
                          },
                          backgroundColor: AppColors.navy900,
                          selectedColor: AppColors.gold500.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.gold500,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.gold400 : AppColors.grey400,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected ? AppColors.gold500 : AppColors.navy600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Main List View
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchLeads,
              color: AppColors.gold500,
              backgroundColor: AppColors.navy800,
              child: _buildListContent(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newLead = await AddLeadBottomSheet.show(context);
          if (newLead != null) {
            _fetchLeads();
          }
        },
        backgroundColor: AppColors.gold500,
        foregroundColor: AppColors.ink900,
        icon: const Icon(Icons.person_add_alt_1_rounded),

        label: const Text('New Lead', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildListContent() {
    if (_isLoading) {
      return _buildShimmerList();
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.fg, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchLeads,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy700,
                  foregroundColor: AppColors.fg,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final leads = _filteredLeads;
    if (leads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline_rounded, size: 52, color: AppColors.grey600),
              const SizedBox(height: 14),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No leads matching "$_searchQuery"'
                    : (_selectedFilter == 'All' ? 'No leads found' : 'No $_selectedFilter leads'),
                style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add prospects directly or wait for admin lead assignments.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grey500, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: leads.length,
      itemBuilder: (context, index) {
        final lead = leads[index];
        return _buildLeadCard(lead);
      },
    );
  }

  Widget _buildLeadCard(LeadModel lead) {
    final statusColor = _getStatusColor(lead.status);
    final sourceTag = lead.sourceLabel(_currentUserId);
    final isSelfAdded = sourceTag == 'Added by me';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.navy800,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.navy600),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => SalesmanLeadDetailScreen(
                lead: lead,
                currentUserId: _currentUserId,
                onLeadUpdated: _fetchLeads,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.gold500.withValues(alpha: 0.15),
                    child: Text(
                      lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'L',
                      style: const TextStyle(
                        color: AppColors.gold500,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.name,
                          style: const TextStyle(
                            color: AppColors.fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+91 ${lead.phone}',
                          style: const TextStyle(color: AppColors.grey400, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: statusColor.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      lead.uiStatusLabel.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tags row
              Row(
                children: [
                  // Source Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelfAdded
                          ? AppColors.teal500.withValues(alpha: 0.12)
                          : AppColors.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelfAdded ? Icons.person_rounded : Icons.admin_panel_settings_rounded,
                          size: 12,
                          color: isSelfAdded ? AppColors.teal500 : AppColors.info,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          sourceTag,
                          style: TextStyle(
                            color: isSelfAdded ? AppColors.teal500 : AppColors.info,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                  ),
                  const SizedBox(width: 8),
                  if (lead.expectedKw != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.navy700,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        '${lead.expectedKw} kW',
                        style: const TextStyle(color: AppColors.fg, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const Spacer(),
                  if (lead.address != null && lead.address!.isNotEmpty)
                    Flexible(
                      child: Text(
                        lead.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.grey500, fontSize: 11),
                      ),
                    ),
                ],
              ),
              // Follow-up chip if present
              if (lead.followUpDate != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: lead.isFollowUpOverdue
                        ? AppColors.error.withValues(alpha: 0.15)
                        : (lead.isFollowUpToday
                            ? AppColors.gold500.withValues(alpha: 0.15)
                            : AppColors.navy700),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: lead.isFollowUpOverdue
                          ? AppColors.error
                          : (lead.isFollowUpToday ? AppColors.gold500 : AppColors.navy600),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.alarm_rounded,
                        size: 13,
                        color: lead.isFollowUpOverdue
                            ? AppColors.error
                            : (lead.isFollowUpToday ? AppColors.gold500 : AppColors.grey400),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        lead.isFollowUpOverdue
                            ? 'Overdue: ${DateFormat('dd MMM').format(lead.followUpDate!)}'
                            : (lead.isFollowUpToday
                                ? "Follow-up Today (${DateFormat('hh:mm a').format(lead.followUpDate!)})"
                                : 'Follow-up: ${DateFormat('EEE, dd MMM').format(lead.followUpDate!)}'),
                        style: TextStyle(
                          color: lead.isFollowUpOverdue
                              ? AppColors.error
                              : (lead.isFollowUpToday ? AppColors.gold400 : AppColors.grey300),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (ctx, i) => Shimmer.fromColors(
        baseColor: AppColors.navy800,
        highlightColor: AppColors.navy700,
        child: Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.navy800,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}
