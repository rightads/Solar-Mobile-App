import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/customers/data/customer_repository.dart';
import 'package:solar_pro/features/customers/data/models/customer_model.dart';
import 'package:solar_pro/features/employee/salesman/customers/lead_convert_draft_manager.dart';
import 'package:solar_pro/features/employee/salesman/customers/widgets/brand_selector_field.dart';
import 'package:solar_pro/features/employee/salesman/customers/widgets/document_upload_tile.dart';
import 'package:solar_pro/features/employee/salesman/customers/widgets/location_picker_card.dart';
import 'package:solar_pro/features/leads/data/models/lead_model.dart';

class ConvertLeadScreen extends StatefulWidget {
  final LeadModel lead;
  final VoidCallback? onConverted;

  const ConvertLeadScreen({
    super.key,
    required this.lead,
    this.onConverted,
  });

  @override
  State<ConvertLeadScreen> createState() => _ConvertLeadScreenState();
}

class _ConvertLeadScreenState extends State<ConvertLeadScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1 Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _priceController;
  double? _latitude;
  double? _longitude;

  // Step 2 Subsidy & Panels
  bool _isSubsidy = true;
  String _panelBrand = 'Tata Power Solar';
  late TextEditingController _panelWattController;
  late TextEditingController _panelCountController;

  // Step 3 Inverter & Structure
  // TODO(backend-gap): Inverter quantity and capacity are stored in draft/client until backend adds schema columns
  String _inverterBrand = 'Growatt';
  late TextEditingController _inverterCountController;
  late TextEditingController _inverterCapacityController;
  String _phase = 'single'; // "single" or "three"
  // TODO(backend-gap): Structure quantity and height are stored in draft/client until backend adds schema columns
  String _structureBrand = 'Galvanised Iron (GI)';
  late TextEditingController _structureCountController;
  String _structureHeight = 'High Rise (8-10 ft)';

  // Step 4 Wiring & Protection
  // TODO(backend-gap): AC/DC/Earthing wire, SPDs and solar meter details stored in draft until backend adds columns
  String _acWireBrand = 'Polycab';
  String _acWireSize = '4 sq mm';
  String _dcWireBrand = 'Siechem';
  String _dcWireSize = '4 sq mm';
  String _earthingWireBrand = 'Copper';
  String _earthingWireSize = '10 sq mm';
  String _spdAcBrand = 'Schneider Electric';
  String _spdAcDetails = 'Type 2 AC SPD 40kA';
  String _spdDcBrand = 'Havells';
  String _spdDcDetails = '1000V DC SPD 40kA';
  String _solarMeterBrand = 'Secure Meters';
  late TextEditingController _solarMeterCountController;

  // Step 5 Extra Work
  // TODO(backend-gap): Civil work and Earthing notes are stored in draft until backend adds columns
  late TextEditingController _civilWorkController;
  late TextEditingController _earthingNotesController;

  // Step 6 Documents attachment state
  final Map<String, String> _attachedDocs = {}; // docType -> fileName
  final Map<String, bool> _uploadingDocs = {};
  final Map<String, double> _uploadProgress = {};
  final Map<String, bool> _uploadErrors = {};
  final Map<String, bool> _uploadedSuccess = {};

  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  // Presets for searchable brand dropdowns
  static const _panelPresets = [
    'Tata Power Solar',
    'Adani Solar',
    'Vikram Solar',
    'Waaree Energies',
    'Goldi Solar',
    'Loom Solar',
    'Canadian Solar',
    'LONGi Solar',
    'RenewSys',
  ];

  static const _inverterPresets = [
    'Growatt',
    'Sungrow',
    'Solis',
    'Polycab',
    'Microtek',
    'Luminous',
    'Havells',
    'Fronius',
    'Delta',
    'SolarEdge',
  ];

  static const _structurePresets = [
    'Galvanised Iron (GI)',
    'Heavy Duty Aluminum',
    'Tata Structura',
    'Jindal Steel',
    'Elevated Rooftop',
    'Tin Shed Clamps',
  ];

  static const _wirePresets = ['Polycab', 'Siechem', 'Havells', 'KEI', 'Finolex', 'RR Kabel'];
  static const _spdPresets = ['Schneider Electric', 'Havells', 'Phoenix Contact', 'Hensel', 'Elmex'];
  static const _meterPresets = ['Secure Meters', 'L&T Electrical', 'Genus Power', 'Schneider', 'HPL Electric'];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadDraft();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.lead.name);
    _phoneController = TextEditingController(text: widget.lead.phone);
    _addressController = TextEditingController(text: widget.lead.address ?? '');
    _priceController = TextEditingController(text: '225000'); // ₹2,25,000 default

    const defaultWatt = 540;
    final defaultCount = widget.lead.expectedKw != null && widget.lead.expectedKw! > 0
        ? ((widget.lead.expectedKw! * 1000) / defaultWatt).round().clamp(1, 100)
        : 6;

    _panelWattController = TextEditingController(text: defaultWatt.toString());
    _panelCountController = TextEditingController(text: defaultCount.toString());

    _inverterCountController = TextEditingController(text: '1');
    _inverterCapacityController = TextEditingController(
      text: widget.lead.expectedKw != null && widget.lead.expectedKw! > 0
          ? widget.lead.expectedKw!.toStringAsFixed(1)
          : '3.3',
    );
    _structureCountController = TextEditingController(text: '1');
    _solarMeterCountController = TextEditingController(text: '1');

    _civilWorkController = TextEditingController();
    _earthingNotesController = TextEditingController();
  }

  Future<void> _loadDraft() async {
    final draft = await LeadConvertDraftManager.loadDraft(widget.lead.id);
    if (draft != null && mounted) {
      setState(() {
        _currentStep = draft.currentStep.clamp(0, 6);
        _nameController.text = draft.name.isNotEmpty ? draft.name : widget.lead.name;
        _phoneController.text = draft.phone.isNotEmpty ? draft.phone : widget.lead.phone;
        _addressController.text = draft.address.isNotEmpty ? draft.address : (widget.lead.address ?? '');
        if (draft.finalPriceRupees > 0) {
          _priceController.text = draft.finalPriceRupees.toString();
        }
        _latitude = draft.latitude;
        _longitude = draft.longitude;

        _isSubsidy = draft.isSubsidy;
        if (draft.panelBrand.isNotEmpty) _panelBrand = draft.panelBrand;
        _panelWattController.text = draft.panelWatt.toString();
        _panelCountController.text = draft.panelCount.toString();

        if (draft.inverterBrand.isNotEmpty) _inverterBrand = draft.inverterBrand;
        _inverterCountController.text = draft.inverterCount.toString();
        _inverterCapacityController.text = draft.inverterCapacity.toString();
        _phase = draft.phase;

        if (draft.structureBrand.isNotEmpty) _structureBrand = draft.structureBrand;
        _structureCountController.text = draft.structureCount.toString();
        _structureHeight = draft.structureHeight;

        _acWireBrand = draft.acWireBrand;
        _acWireSize = draft.acWireSize;
        _dcWireBrand = draft.dcWireBrand;
        _dcWireSize = draft.dcWireSize;
        _earthingWireBrand = draft.earthingWireBrand;
        _earthingWireSize = draft.earthingWireSize;

        _spdAcBrand = draft.spdAcBrand;
        _spdAcDetails = draft.spdAcDetails;
        _spdDcBrand = draft.spdDcBrand;
        _spdDcDetails = draft.spdDcDetails;

        _solarMeterBrand = draft.solarMeterBrand;
        _solarMeterCountController.text = draft.solarMeterCount.toString();

        _civilWorkController.text = draft.civilWork;
        _earthingNotesController.text = draft.earthingNotes;

        _attachedDocs.addAll(draft.attachedDocs);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resumed conversion draft from your last session'),
          backgroundColor: AppColors.teal500,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _autosaveDraft() async {
    final rupees = int.tryParse(_priceController.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    final watt = int.tryParse(_panelWattController.text.trim()) ?? 540;
    final count = int.tryParse(_panelCountController.text.trim()) ?? 6;
    final invQty = int.tryParse(_inverterCountController.text.trim()) ?? 1;
    final invCap = double.tryParse(_inverterCapacityController.text.trim()) ?? 3.3;
    final structQty = int.tryParse(_structureCountController.text.trim()) ?? 1;
    final meterQty = int.tryParse(_solarMeterCountController.text.trim()) ?? 1;

    final draft = LeadConvertDraft(
      leadId: widget.lead.id,
      currentStep: _currentStep,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      finalPriceRupees: rupees,
      isSubsidy: _isSubsidy,
      panelBrand: _panelBrand,
      panelWatt: watt,
      panelCount: count,
      inverterBrand: _inverterBrand,
      inverterCount: invQty,
      inverterCapacity: invCap,
      phase: _phase,
      structureBrand: _structureBrand,
      structureCount: structQty,
      structureHeight: _structureHeight,
      acWireBrand: _acWireBrand,
      acWireSize: _acWireSize,
      dcWireBrand: _dcWireBrand,
      dcWireSize: _dcWireSize,
      earthingWireBrand: _earthingWireBrand,
      earthingWireSize: _earthingWireSize,
      spdAcBrand: _spdAcBrand,
      spdAcDetails: _spdAcDetails,
      spdDcBrand: _spdDcBrand,
      spdDcDetails: _spdDcDetails,
      solarMeterBrand: _solarMeterBrand,
      solarMeterCount: meterQty,
      civilWork: _civilWorkController.text.trim(),
      earthingNotes: _earthingNotesController.text.trim(),
      attachedDocs: _attachedDocs,
    );

    await LeadConvertDraftManager.saveDraft(draft);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _panelWattController.dispose();
    _panelCountController.dispose();
    _inverterCountController.dispose();
    _inverterCapacityController.dispose();
    _structureCountController.dispose();
    _solarMeterCountController.dispose();
    _civilWorkController.dispose();
    _earthingNotesController.dispose();
    super.dispose();
  }

  double get _calculatedCapacityKw {
    final watt = double.tryParse(_panelWattController.text.trim()) ?? 540;
    final count = double.tryParse(_panelCountController.text.trim()) ?? 6;
    return (watt * count) / 1000.0;
  }

  int get _finalPricePaise {
    final cleanDigits = _priceController.text.replaceAll(RegExp(r'\D'), '');
    final rupees = int.tryParse(cleanDigits) ?? 0;
    return rupees * 100;
  }

  void _onNext() {
    if (_currentStep == 0) {
      if (!_formKeyStep1.currentState!.validate()) return;
      if (_addressController.text.trim().length < 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address must be at least 5 characters long'), backgroundColor: AppColors.error),
        );
        return;
      }
    } else if (_currentStep == 1) {
      if (!_formKeyStep2.currentState!.validate()) return;
      if (_panelBrand.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a panel brand'), backgroundColor: AppColors.error),
        );
        return;
      }
    }

    if (_currentStep < 6) {
      setState(() => _currentStep++);
      _autosaveDraft();
    }
  }

  void _onPrevious() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _autosaveDraft();
    }
  }

  // Document attachment handler (simulated native camera/gallery compression)
  void _attachDocument(String docType, String source) {
    final timestamp = DateTime.now().millisecondsSinceEpoch % 10000;
    final ext = source == 'camera' ? 'jpg' : 'pdf';
    final simulatedName = '${docType}_doc_$timestamp.$ext';

    setState(() {
      _attachedDocs[docType] = simulatedName;
      _uploadErrors[docType] = false;
    });
    _autosaveDraft();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Attached $simulatedName (auto-compressed 80%)'),
        backgroundColor: AppColors.teal500,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeDocument(String docType) {
    setState(() {
      _attachedDocs.remove(docType);
      _uploadingDocs.remove(docType);
      _uploadProgress.remove(docType);
      _uploadErrors.remove(docType);
      _uploadedSuccess.remove(docType);
    });
    _autosaveDraft();
  }

  Future<void> _submitConversion() async {
    setState(() => _isLoading = true);

    try {
      final repo = CustomerRepository();

      // Step 1: Execute atomic lead conversion
      final convertedCustomer = await repo.convertLead(
        leadId: widget.lead.id,
        address: _addressController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        finalPricePaise: _finalPricePaise,
        capacityKw: _calculatedCapacityKw,
        phase: _phase,
        panelBrand: _panelBrand,
        panelWatt: int.tryParse(_panelWattController.text.trim()) ?? 540,
        panelCount: int.tryParse(_panelCountController.text.trim()) ?? 6,
        inverterBrand: _inverterBrand,
        structureType: _structureBrand,
      );

      // Step 2: Upload all attached documents
      for (final entry in _attachedDocs.entries) {
        final docType = entry.key;
        final fileName = entry.value;

        setState(() {
          _uploadingDocs[docType] = true;
          _uploadProgress[docType] = 0.3;
        });

        try {
          await repo.uploadCustomerDocument(
            customerId: convertedCustomer.id,
            docType: docType,
            fileName: fileName,
            onProgress: (sent, total) {
              if (mounted && total > 0) {
                setState(() {
                  _uploadProgress[docType] = sent / total;
                });
              }
            },
          );

          if (mounted) {
            setState(() {
              _uploadingDocs[docType] = false;
              _uploadedSuccess[docType] = true;
              _uploadProgress[docType] = 1.0;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _uploadingDocs[docType] = false;
              _uploadErrors[docType] = true;
            });
          }
        }
      }

      // Step 3: Clear local draft
      await LeadConvertDraftManager.clearDraft(widget.lead.id);

      setState(() => _isLoading = false);
      widget.onConverted?.call();

      if (mounted) {
        _showSuccessDialog(convertedCustomer);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(CustomerModel customer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            SizedBox(width: 10),
            Text('Lead Converted!', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lead "${widget.lead.name}" has been successfully converted into an active Customer.',
              style: const TextStyle(color: AppColors.grey300, fontSize: 14),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.navy900,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.navy700),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(label: 'Customer ID', value: customer.id.substring(0, 8).toUpperCase()),
                  _SummaryRow(label: 'Name', value: customer.name),
                  _SummaryRow(label: 'Capacity', value: '${customer.capacityKw} kW (${customer.phase} phase)'),
                  _SummaryRow(label: 'Sale Value', value: customer.formattedPriceRupees),
                  _SummaryRow(label: 'Stage', value: customer.stageDisplayLabel),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text('Back to Leads', style: TextStyle(color: AppColors.grey400)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal500,
              foregroundColor: AppColors.fg,
            ),
            child: const Text('Proceed to Payments'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        backgroundColor: AppColors.navy800,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Convert Lead to Customer',
              style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              '${widget.lead.name} • ${_calculatedCapacityKw.toStringAsFixed(1)} kW',
              style: const TextStyle(color: AppColors.teal500, fontSize: 12),
            ),
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.navy900,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.navy700),
                ),
                child: Text(
                  'Step ${_currentStep + 1} of 7',
                  style: const TextStyle(color: AppColors.grey400, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator bar
            LinearProgressIndicator(
              value: (_currentStep + 1) / 7.0,
              minHeight: 3,
              backgroundColor: AppColors.navy800,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal500),
            ),

            // Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildCurrentStepContent(),
              ),
            ),

            // Navigation Bottom Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.navy800,
                border: Border(top: BorderSide(color: AppColors.navy700)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    OutlinedButton(
                      onPressed: _isLoading ? null : _onPrevious,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.grey600),
                        foregroundColor: AppColors.grey300,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_currentStep == 6 ? _submitConversion : _onNext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentStep == 6 ? AppColors.success : AppColors.teal500,
                        foregroundColor: AppColors.fg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.fg),
                            )
                          : Text(
                              _currentStep == 6 ? 'Confirm & Convert Lead' : 'Next Step',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1CustomerInfo();
      case 1:
        return _buildStep2SubsidyAndPanels();
      case 2:
        return _buildStep3InverterAndStructure();
      case 3:
        return _buildStep4WiringAndProtection();
      case 4:
        return _buildStep5ExtraWork();
      case 5:
        return _buildStep6Documents();
      case 6:
        return _buildStep7ReviewAndSubmit();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 1: Customer Information ───────────────────────────────────────────
  Widget _buildStep1CustomerInfo() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            stepNumber: 1,
            title: 'Customer & Site Details',
            subtitle: 'Verify personal details, site GPS, and contract price.',
          ),
          const SizedBox(height: 16),

          // Name
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.fg),
            decoration: _inputDecoration('Customer Full Name *', Icons.person_rounded),
            validator: (v) => (v == null || v.trim().length < 2) ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),

          // Phone
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppColors.fg),
            decoration: _inputDecoration('10-Digit Mobile *', Icons.phone_rounded),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
              return digits.length == 10 ? null : 'Valid 10-digit mobile number required';
            },
          ),
          const SizedBox(height: 12),

          // Address
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            style: const TextStyle(color: AppColors.fg),
            decoration: _inputDecoration('Site Installation Address *', Icons.home_rounded),
            validator: (v) => (v == null || v.trim().length < 5) ? 'Min 5 characters required' : null,
          ),
          const SizedBox(height: 16),

          // GPS Location Card
          LocationPickerCard(
            latitude: _latitude,
            longitude: _longitude,
            address: _addressController.text.trim(),
            onLocationChanged: (lat, lng) {
              setState(() {
                _latitude = lat;
                _longitude = lng;
              });
              _autosaveDraft();
            },
          ),
          const SizedBox(height: 16),

          // Final Contract Price
          const Text(
            'Final Work Price (Rupees)',
            style: TextStyle(color: AppColors.grey300, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppColors.gold500),
              hintText: 'e.g. 250000',
              hintStyle: const TextStyle(color: AppColors.grey500),
              helperText: 'Will be stored precisely as integer paise on backend',
              helperStyle: const TextStyle(color: AppColors.grey500, fontSize: 11),
              filled: true,
              fillColor: AppColors.navy800,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.navy700),
              ),
            ),
            validator: (v) {
              final clean = (v ?? '').replaceAll(RegExp(r'\D'), '');
              return (int.tryParse(clean) ?? 0) > 0 ? null : 'Valid price is required';
            },
          ),
        ],
      ),
    );
  }

  // ── Step 2: Subsidy Type & Panels ──────────────────────────────────────────
  Widget _buildStep2SubsidyAndPanels() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            stepNumber: 2,
            title: 'Subsidy & Solar Panels',
            subtitle: 'Choose subsidy scheme and configure panel capacity and quantity.',
          ),
          const SizedBox(height: 16),

          // Subsidy Toggle (DCR vs NDCR)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.navy700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Subsidy Scheme Selection',
                  style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Govt subsidy requires DCR certified domestic cells. Non-subsidy allows NDCR modules.',
                  style: TextStyle(color: AppColors.grey400, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => _isSubsidy = true);
                          _autosaveDraft();
                        },
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isSubsidy ? AppColors.teal500 : AppColors.navy900,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: _isSubsidy ? AppColors.teal500 : AppColors.navy700),
                          ),
                          child: Center(
                            child: Text(
                              'SUBSIDY',
                              style: TextStyle(
                                color: _isSubsidy ? AppColors.fg : AppColors.grey400,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => _isSubsidy = false);
                          _autosaveDraft();
                        },
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isSubsidy ? AppColors.gold500 : AppColors.navy900,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: !_isSubsidy ? AppColors.gold500 : AppColors.navy700),
                          ),
                          child: Center(
                            child: Text(
                              'NON-SUBSIDY',
                              style: TextStyle(
                                color: !_isSubsidy ? AppColors.shadow : AppColors.grey400,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Dynamic Panel Type Label Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isSubsidy ? AppColors.teal500.withValues(alpha: 0.12) : AppColors.gold500.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: _isSubsidy ? AppColors.teal500.withValues(alpha: 0.4) : AppColors.gold500.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSubsidy ? Icons.verified_rounded : Icons.info_outline_rounded,
                        color: _isSubsidy ? AppColors.teal500 : AppColors.gold500,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isSubsidy
                              ? 'Panel Type: DCR Panels (Domestic Content Requirement)'
                              : 'Panel Type: NDCR Panels (Non-DCR / Commercial)',
                          style: TextStyle(
                            color: _isSubsidy ? AppColors.teal500 : AppColors.gold500,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Panel Brand Searchable Dropdown
          BrandSelectorField(
            label: 'Panel Brand',
            value: _panelBrand,
            presetBrands: _panelPresets,
            isRequired: true,
            onSelected: (val) {
              setState(() => _panelBrand = val);
              _autosaveDraft();
            },
          ),
          const SizedBox(height: 14),

          // Panel Watt & Quantity
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Panel Rating (Watt) *', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _panelWattController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.fg),
                      decoration: _inputDecoration('e.g. 540', Icons.bolt_rounded),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Watt required',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quantity (Modules) *', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _panelCountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.fg),
                      decoration: _inputDecoration('e.g. 10', Icons.solar_power_rounded),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Quantity required',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Live Total System Capacity Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.teal500.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.teal500.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate_rounded, color: AppColors.teal500, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Solar System Capacity',
                        style: TextStyle(color: AppColors.grey300, fontSize: 12),
                      ),
                      Text(
                        '${_calculatedCapacityKw.toStringAsFixed(2)} kW',
                        style: const TextStyle(
                          color: AppColors.teal500,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Formula: ${_panelWattController.text}W × ${_panelCountController.text} modules ÷ 1000',
                        style: const TextStyle(color: AppColors.grey500, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Inverter & Structure ───────────────────────────────────────────
  Widget _buildStep3InverterAndStructure() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          stepNumber: 3,
          title: 'Inverter & Mounting Structure',
          subtitle: 'Inverter brand, capacity, electrical phase, and mounting structure.',
        ),
        const SizedBox(height: 16),

        // Inverter Brand
        BrandSelectorField(
          label: 'Inverter Brand',
          value: _inverterBrand,
          presetBrands: _inverterPresets,
          isRequired: true,
          onSelected: (val) {
            setState(() => _inverterBrand = val);
            _autosaveDraft();
          },
        ),
        const SizedBox(height: 12),

        // Inverter Quantity and Capacity (kW)
        // TODO(backend-gap): Inverter quantity and capacity stored in client draft
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Inverter Count', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _inverterCountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.fg),
                    decoration: _inputDecoration('1', Icons.numbers_rounded),
                    onChanged: (_) => _autosaveDraft(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Capacity (kW)', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _inverterCapacityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.fg),
                    decoration: _inputDecoration('e.g. 5.0', Icons.speed_rounded),
                    onChanged: (_) => _autosaveDraft(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Inverter Phase (single vs three)
        const Text(
          'Electrical Phase *',
          style: TextStyle(color: AppColors.grey300, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => _phase = 'single');
                  _autosaveDraft();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _phase == 'single' ? AppColors.teal500 : AppColors.navy800,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: _phase == 'single' ? AppColors.teal500 : AppColors.navy700),
                  ),
                  child: Center(
                    child: Text(
                      '1-Phase (Single)',
                      style: TextStyle(
                        color: _phase == 'single' ? AppColors.fg : AppColors.grey400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => _phase = 'three');
                  _autosaveDraft();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _phase == 'three' ? AppColors.teal500 : AppColors.navy800,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: _phase == 'three' ? AppColors.teal500 : AppColors.navy700),
                  ),
                  child: Center(
                    child: Text(
                      '3-Phase (Three)',
                      style: TextStyle(
                        color: _phase == 'three' ? AppColors.fg : AppColors.grey400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Structure Brand / Type
        BrandSelectorField(
          label: 'Mounting Structure Type / Brand',
          value: _structureBrand,
          presetBrands: _structurePresets,
          isRequired: true,
          onSelected: (val) {
            setState(() => _structureBrand = val);
            _autosaveDraft();
          },
        ),
        const SizedBox(height: 12),

        // Structure Quantity & Height
        // TODO(backend-gap): Structure quantity and height stored in client draft
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Structure Count', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _structureCountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.fg),
                    decoration: _inputDecoration('1', Icons.layers_rounded),
                    onChanged: (_) => _autosaveDraft(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Structure Height', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.navy800,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.navy700),
                    ),
                    child: DropdownButton<String>(
                      value: _structureHeight,
                      isExpanded: true,
                      dropdownColor: AppColors.navy800,
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(color: AppColors.fg, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'Standard (4-6 ft)', child: Text('Standard (4-6 ft)')),
                        DropdownMenuItem(value: 'High Rise (8-10 ft)', child: Text('High Rise (8-10 ft)')),
                        DropdownMenuItem(value: 'Flush Rooftop', child: Text('Flush Rooftop')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _structureHeight = val);
                          _autosaveDraft();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 4: Wiring & Protection ────────────────────────────────────────────
  // TODO(backend-gap): Wiring, SPD and meter details will be forwarded when backend adds schema columns
  Widget _buildStep4WiringAndProtection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          stepNumber: 4,
          title: 'Wiring & Protection Systems',
          subtitle: 'AC/DC wiring sizes, SPD combiner boxes, and net meter specifications.',
        ),
        const SizedBox(height: 16),

        // AC Wiring
        _buildWireSection(
          title: 'AC Wiring',
          brand: _acWireBrand,
          size: _acWireSize,
          onBrandChanged: (b) => setState(() => _acWireBrand = b),
          onSizeChanged: (s) => setState(() => _acWireSize = s),
        ),
        const SizedBox(height: 12),

        // DC Wiring
        _buildWireSection(
          title: 'DC Wiring (Solar Grade)',
          brand: _dcWireBrand,
          size: _dcWireSize,
          onBrandChanged: (b) => setState(() => _dcWireBrand = b),
          onSizeChanged: (s) => setState(() => _dcWireSize = s),
        ),
        const SizedBox(height: 12),

        // Earthing Wire
        _buildWireSection(
          title: 'Earthing Wire',
          brand: _earthingWireBrand,
          size: _earthingWireSize,
          onBrandChanged: (b) => setState(() => _earthingWireBrand = b),
          onSizeChanged: (s) => setState(() => _earthingWireSize = s),
        ),
        const SizedBox(height: 16),

        // SPD Boxes
        BrandSelectorField(
          label: 'SPD ACDB Brand',
          value: _spdAcBrand,
          presetBrands: _spdPresets,
          onSelected: (val) {
            setState(() => _spdAcBrand = val);
            _autosaveDraft();
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: _spdAcDetails),
          style: const TextStyle(color: AppColors.fg, fontSize: 13),
          decoration: _inputDecoration('SPD ACDB Details (e.g. Type 2 40kA)', Icons.security_rounded),
          onChanged: (v) {
            _spdAcDetails = v;
            _autosaveDraft();
          },
        ),
        const SizedBox(height: 12),

        BrandSelectorField(
          label: 'SPD DCDB Brand',
          value: _spdDcBrand,
          presetBrands: _spdPresets,
          onSelected: (val) {
            setState(() => _spdDcBrand = val);
            _autosaveDraft();
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: _spdDcDetails),
          style: const TextStyle(color: AppColors.fg, fontSize: 13),
          decoration: _inputDecoration('SPD DCDB Details (e.g. 1000V 40kA)', Icons.shield_rounded),
          onChanged: (v) {
            _spdDcDetails = v;
            _autosaveDraft();
          },
        ),
        const SizedBox(height: 16),

        // Solar Meter
        Row(
          children: [
            Expanded(
              flex: 2,
              child: BrandSelectorField(
                label: 'Solar Meter Brand',
                value: _solarMeterBrand,
                presetBrands: _meterPresets,
                onSelected: (val) {
                  setState(() => _solarMeterBrand = val);
                  _autosaveDraft();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Meter Qty', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _solarMeterCountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.fg),
                    decoration: _inputDecoration('1', Icons.speed_rounded),
                    onChanged: (_) => _autosaveDraft(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWireSection({
    required String title,
    required String brand,
    required String size,
    required ValueChanged<String> onBrandChanged,
    required ValueChanged<String> onSizeChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.navy700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: BrandSelectorField(
                  label: 'Brand',
                  value: brand,
                  presetBrands: _wirePresets,
                  onSelected: (b) {
                    onBrandChanged(b);
                    _autosaveDraft();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Size / Gauge', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: size),
                      style: const TextStyle(color: AppColors.fg, fontSize: 13),
                      decoration: _inputDecoration('e.g. 4 sq mm', Icons.straighten_rounded),
                      onChanged: (s) {
                        onSizeChanged(s);
                        _autosaveDraft();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 5: Extra Work ─────────────────────────────────────────────────────
  // TODO(backend-gap): Civil work and Earthing notes stored in draft until backend adds columns
  Widget _buildStep5ExtraWork() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          stepNumber: 5,
          title: 'Extra Site Work Notes',
          subtitle: 'Optional free-text instructions for civil foundation or earthing pits (blank by default).',
        ),
        const SizedBox(height: 16),

        // Civil Work
        const Text(
          'Civil Work Notes (Optional)',
          style: TextStyle(color: AppColors.grey300, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _civilWorkController,
          maxLines: 3,
          style: const TextStyle(color: AppColors.fg),
          decoration: _inputDecoration('Enter civil work notes, concrete foundation, column grouting...', Icons.foundation_rounded),
          onChanged: (_) => _autosaveDraft(),
        ),
        const SizedBox(height: 16),

        // Earthing Notes
        const Text(
          'Earthing Notes (Optional)',
          style: TextStyle(color: AppColors.grey300, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _earthingNotesController,
          maxLines: 3,
          style: const TextStyle(color: AppColors.fg),
          decoration: _inputDecoration('Enter chemical earthing pits, copper strip bonding notes...', Icons.bolt_rounded),
          onChanged: (_) => _autosaveDraft(),
        ),
      ],
    );
  }

  // ── Step 6: Documents ──────────────────────────────────────────────────────
  Widget _buildStep6Documents() {
    final docTypes = [
      {'key': 'e_bill', 'name': 'Electricity Bill (E-Bill)', 'desc': 'Latest consumer power bill with CA number', 'icon': Icons.receipt_long_rounded},
      {'key': 'aadhaar', 'name': 'Aadhaar Card', 'desc': 'Applicant identity proof (front & back)', 'icon': Icons.badge_rounded},
      {'key': 'pan', 'name': 'PAN Card', 'desc': 'Income Tax PAN identification card', 'icon': Icons.credit_card_rounded},
      {'key': 'cancelled_cheque', 'name': 'Cancelled Cheque', 'desc': 'Bank account proof for subsidy DBT disbursement', 'icon': Icons.account_balance_rounded},
      {'key': 'registry', 'name': 'Registry (Property Paper)', 'desc': 'Property ownership deed or tax receipt', 'icon': Icons.home_work_rounded},
    ];

    final attachedCount = docTypes.where((d) => _attachedDocs.containsKey(d['key'])).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          stepNumber: 6,
          title: 'Mandatory KYC & Site Documents',
          subtitle: 'Upload the 5 mandatory documents. Files are auto-compressed and staged for upload.',
        ),
        const SizedBox(height: 16),

        // Missing checklist summary banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: attachedCount == 5 ? AppColors.success.withValues(alpha: 0.12) : AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: attachedCount == 5 ? AppColors.success.withValues(alpha: 0.4) : AppColors.warning.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                attachedCount == 5 ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                color: attachedCount == 5 ? AppColors.success : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  attachedCount == 5
                      ? 'All 5 mandatory documents attached! Backend will advance customer to DOCUMENTS_RECEIVED.'
                      : '$attachedCount of 5 mandatory documents attached. You can attach remaining docs now or later.',
                  style: TextStyle(
                    color: attachedCount == 5 ? AppColors.success : AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Document Tiles
        ...docTypes.map((doc) {
          final key = doc['key'] as String;
          final title = doc['name'] as String;
          final desc = doc['desc'] as String;
          final icon = doc['icon'] as IconData;

          return DocumentUploadTile(
            title: title,
            description: desc,
            docType: key,
            icon: icon,
            attachedFileName: _attachedDocs[key],
            isUploading: _uploadingDocs[key] ?? false,
            uploadProgress: _uploadProgress[key] ?? 0.0,
            hasError: _uploadErrors[key] ?? false,
            isUploaded: _uploadedSuccess[key] ?? false,
            onPickCamera: () => _attachDocument(key, 'camera'),
            onPickGallery: () => _attachDocument(key, 'gallery'),
            onRemove: () => _removeDocument(key),
            onRetry: () => _attachDocument(key, 'gallery'),
          );
        }),
      ],
    );
  }

  // ── Step 7: Review & Submit ────────────────────────────────────────────────
  Widget _buildStep7ReviewAndSubmit() {
    final finalRupees = _finalPricePaise ~/ 100;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          stepNumber: 7,
          title: 'Review Sale & Confirm Conversion',
          subtitle: 'Verify the complete system configuration before submitting atomic customer conversion.',
        ),
        const SizedBox(height: 16),

        // Review card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.navy800,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.teal500.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment_turned_in_rounded, color: AppColors.teal500, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Order & System Summary',
                    style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const Divider(color: AppColors.navy700, height: 24),

              _SummaryRow(label: 'Customer', value: _nameController.text.trim()),
              _SummaryRow(label: 'Mobile', value: _phoneController.text.trim()),
              _SummaryRow(label: 'Site Address', value: _addressController.text.trim()),
              if (_latitude != null && _longitude != null)
                _SummaryRow(label: 'GPS Coordinates', value: '${_latitude!.toStringAsFixed(4)}°, ${_longitude!.toStringAsFixed(4)}°'),

              const Divider(color: AppColors.navy700, height: 20),

              _SummaryRow(
                label: 'Scheme',
                value: _isSubsidy ? 'SUBSIDY (DCR Panels)' : 'NON-SUBSIDY (NDCR Panels)',
                valueColor: _isSubsidy ? AppColors.teal500 : AppColors.gold500,
              ),
              _SummaryRow(label: 'Solar Capacity', value: '${_calculatedCapacityKw.toStringAsFixed(2)} kW'),
              _SummaryRow(label: 'Panel Specs', value: '$_panelBrand (${_panelWattController.text}W × ${_panelCountController.text} pcs)'),
              _SummaryRow(label: 'Inverter', value: '$_inverterBrand (${_inverterCapacityController.text} kW, $_phase phase)'),
              _SummaryRow(label: 'Structure', value: '$_structureBrand ($_structureHeight)'),

              const Divider(color: AppColors.navy700, height: 20),

              _SummaryRow(label: 'Wiring', value: 'AC: $_acWireBrand • DC: $_dcWireBrand'),
              _SummaryRow(label: 'SPD & Meter', value: 'ACDB: $_spdAcBrand • Solar Meter: $_solarMeterBrand'),
              _SummaryRow(label: 'Documents Attached', value: '${_attachedDocs.length} / 5 files staged'),

              const Divider(color: AppColors.navy700, height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Final Sale Price:', style: TextStyle(color: AppColors.grey300, fontSize: 14)),
                  Text(
                    formatter.format(finalRupees),
                    style: const TextStyle(color: AppColors.gold500, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.grey400, size: 20),
      filled: true,
      fillColor: AppColors.navy800,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.navy700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.navy700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.teal500),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String subtitle;

  const _StepHeader({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STEP $stepNumber OF 7',
          style: const TextStyle(color: AppColors.teal500, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.grey400, fontSize: 13),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.fg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
