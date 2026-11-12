import 'package:flutter/material.dart';
import 'package:solar_pro/core/services/media_picker.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/client/data/models/client_dashboard_model.dart';
import 'package:solar_pro/features/client/data/repositories/client_repository.dart';

class RaiseTicketModal extends StatefulWidget {
  final Function(ClientTicketRecord) onTicketCreated;

  const RaiseTicketModal({
    super.key,
    required this.onTicketCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(ClientTicketRecord) onTicketCreated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: RaiseTicketModal(onTicketCreated: onTicketCreated),
      ),
    );
  }

  @override
  State<RaiseTicketModal> createState() => _RaiseTicketModalState();
}

class _RaiseTicketModalState extends State<RaiseTicketModal> {
  ClientTicketType _selectedType = ClientTicketType.structure;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _errorCodeCtrl = TextEditingController();

  final String _priority = 'high';
  final List<PickedMedia> _attachedImages = [];
  bool _isSubmitting = false;

  final _clientRepo = ClientRepository();

  final List<String> _inverterPresetCodes = [
    'E04 - Grid Overvoltage',
    'E08 - Frequency Out of Range',
    'F12 - Insulation Failure',
    'Zero Generation (Standby)',
    'LED Fault Blink',
  ];

  @override
  void initState() {
    super.initState();
    _applyDefaultTitleForType(_selectedType);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _errorCodeCtrl.dispose();
    super.dispose();
  }

  void _applyDefaultTitleForType(ClientTicketType type) {
    switch (type) {
      case ClientTicketType.structure:
        _titleCtrl.text = 'Structure Vibration / Mounting Loose';
        break;
      case ClientTicketType.wiring:
        _titleCtrl.text = 'DC Cabling / Earthing Conduit Issue';
        break;
      case ClientTicketType.inverter:
        _titleCtrl.text = 'Inverter Fault / Generation Tripped';
        break;
    }
  }

  Future<void> _addSampleImage() async {
    final remaining = 10 - _attachedImages.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 images allowed per ticket.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    try {
      final picked = await MediaPicker.pickPhotos(context, max: remaining);
      if (picked.isEmpty || !mounted) return;
      setState(() => _attachedImages.addAll(picked.take(remaining)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _attachedImages.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter ticket title'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the issue in detail'), backgroundColor: AppColors.error),
      );
      return;
    }

    // MANDATORY HANDWRITTEN REQUIREMENTS VALIDATION
    if (_selectedType == ClientTicketType.structure) {
      if (_attachedImages.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Structure Issue requires between 2 and 10 photos. Please attach at least 2 photos.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    } else if (_selectedType == ClientTicketType.wiring) {
      if (_attachedImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wiring Issue requires photo upload. Please attach at least 1 photo.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final ticket = await _clientRepo.createTicket(
        type: _selectedType,
        title: title,
        description: desc,
        errorCode: _selectedType == ClientTicketType.inverter && _errorCodeCtrl.text.trim().isNotEmpty
            ? _errorCodeCtrl.text.trim()
            : null,
        priority: _priority,
        images: List.from(_attachedImages),
      );

      if (mounted) {
        widget.onTicketCreated(ticket);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Service Ticket "${ticket.ticketNo}" raised successfully! Field technician assigned.'),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to raise ticket: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.orange500.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.build_rounded, color: AppColors.orange500, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Raise Service Ticket', style: AppTextStyles.headlineMedium),
                    Text('Direct support from SolarPro maintenance crew',
                        style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3 Specific Issue Types from user handwritten note
          Text('Select Issue Type *',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTypeCard(
                type: ClientTicketType.structure,
                label: 'Structure Issue',
                sublabel: '2-10 Photos',
                icon: Icons.foundation_rounded,
                color: AppColors.orange500,
              ),
              const SizedBox(width: 8),
              _buildTypeCard(
                type: ClientTicketType.wiring,
                label: 'Wiring Issue',
                sublabel: 'Photos upload',
                icon: Icons.electrical_services_rounded,
                color: AppColors.purple500,
              ),
              const SizedBox(width: 8),
              _buildTypeCard(
                type: ClientTicketType.inverter,
                label: 'Inverter Fault',
                sublabel: 'Error Code',
                icon: Icons.power_rounded,
                color: AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Requirement hint banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.navy700,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: _getTypeColor().withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(_selectedType.icon, color: _getTypeColor(), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedType.imageHint,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.grey200,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Conditional Inverter Error Code field
          if (_selectedType == ClientTicketType.inverter) ...[
            Text('Inverter Error / Fault Code',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.gold400, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _errorCodeCtrl,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
              decoration: InputDecoration(
                hintText: 'e.g. E04, F12, Inverter Tripping',
                hintStyle: const TextStyle(color: AppColors.grey500),
                prefixIcon: const Icon(Icons.warning_amber_rounded, color: AppColors.gold500, size: 20),
                filled: true,
                fillColor: AppColors.navy900,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _inverterPresetCodes.map((code) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      backgroundColor: AppColors.navy900,
                      side: BorderSide(color: AppColors.gold500.withValues(alpha: 0.3)),
                      label: Text(code, style: const TextStyle(fontSize: 11, color: AppColors.gold400)),
                      onPressed: () => setState(() => _errorCodeCtrl.text = code),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Title
          Text('Issue Title', style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
            decoration: InputDecoration(
              hintText: 'Brief summary of issue',
              hintStyle: const TextStyle(color: AppColors.grey500),
              prefixIcon: const Icon(Icons.title_rounded, color: AppColors.grey400, size: 20),
              filled: true,
              fillColor: AppColors.navy900,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: 14),

          // Description
          Text('Issue Details', style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300)),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
            decoration: InputDecoration(
              hintText: 'Describe exact site observations, when it started, affected panels...',
              hintStyle: const TextStyle(color: AppColors.grey500),
              filled: true,
              fillColor: AppColors.navy900,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: 16),

          // Mandatory Images Upload Section with counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upload Photos (${_selectedType == ClientTicketType.structure ? '2-10 Required' : 'Photos'})',
                style: AppTextStyles.labelMedium.copyWith(
                  color: _selectedType == ClientTicketType.structure && _attachedImages.length < 2
                      ? AppColors.error
                      : AppColors.gold400,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _selectedType == ClientTicketType.structure && _attachedImages.length < 2
                      ? AppColors.error.withValues(alpha: 0.15)
                      : AppColors.teal500.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: _selectedType == ClientTicketType.structure && _attachedImages.length < 2
                        ? AppColors.error
                        : AppColors.teal500,
                  ),
                ),
                child: Text(
                  '${_attachedImages.length} / 10 photos ${_selectedType == ClientTicketType.structure ? '(Min 2)' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _selectedType == ClientTicketType.structure && _attachedImages.length < 2
                        ? AppColors.error
                        : AppColors.teal400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Image gallery / add photo button
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._attachedImages.asMap().entries.map((entry) {
                final idx = entry.key;
                return Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.navy900,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.gold500.withValues(alpha: 0.4)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(entry.value.bytes, fit: BoxFit.cover, width: 72, height: 72),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _removeImage(idx),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 12, color: AppColors.fg),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (_attachedImages.length < 10)
                GestureDetector(
                  onTap: _addSampleImage,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.navy700,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.gold500, style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_rounded, color: AppColors.gold500, size: 22),
                        const SizedBox(height: 4),
                        Text(
                          '+ Add Photo',
                          style: AppTextStyles.caption.copyWith(color: AppColors.gold400, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),

          // Submit Ticket button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange500,
                foregroundColor: AppColors.fg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: AppColors.fg, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.support_agent_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Submit Service Ticket',
                            style: AppTextStyles.labelLarge.copyWith(color: AppColors.fg, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor() {
    switch (_selectedType) {
      case ClientTicketType.structure:
        return AppColors.orange500;
      case ClientTicketType.wiring:
        return AppColors.purple500;
      case ClientTicketType.inverter:
        return AppColors.error;
    }
  }

  Widget _buildTypeCard({
    required ClientTicketType type,
    required String label,
    required String sublabel,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _applyDefaultTitleForType(type);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : AppColors.navy900,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? color : AppColors.navy700,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? color : AppColors.grey500, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.fg : AppColors.grey400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? color : AppColors.grey600,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
