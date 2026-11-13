import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/features/customers/data/models/customer_model.dart';
import 'package:solar_pro/features/employee/salesman/customers/lead_convert_draft_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prompt 4: Salesman Lead Conversion Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Draft persistence: save, load, and clear draft per leadId', () async {
      const leadId = 'lead-uuid-101';
      final draft = LeadConvertDraft(
        leadId: leadId,
        currentStep: 3,
        name: 'Ramesh Kumar',
        phone: '9876543210',
        address: 'Plot 45, Sector 14, Gurugram',
        latitude: 28.4595,
        longitude: 77.0266,
        finalPriceRupees: 280000,
        isSubsidy: true,
        panelBrand: 'Tata Power Solar',
        panelWatt: 540,
        panelCount: 10,
        inverterBrand: 'Growatt',
        inverterCount: 1,
        inverterCapacity: 5.0,
        phase: 'three',
        structureBrand: 'Galvanised Iron (GI)',
        structureCount: 1,
        structureHeight: 'High Rise (8-10 ft)',
        attachedDocs: const {
          'e_bill': 'e_bill_101.pdf',
          'aadhaar': 'aadhaar_101.jpg',
        },
      );

      // Save draft
      await LeadConvertDraftManager.saveDraft(draft);

      final hasDraft = await LeadConvertDraftManager.hasDraft(leadId);
      expect(hasDraft, isTrue);

      // Load draft
      final loaded = await LeadConvertDraftManager.loadDraft(leadId);
      expect(loaded, isNotNull);
      expect(loaded!.leadId, equals(leadId));
      expect(loaded.currentStep, equals(3));
      expect(loaded.name, equals('Ramesh Kumar'));
      expect(loaded.finalPriceRupees, equals(280000));
      expect(loaded.finalPricePaise, equals(28000000)); // Exactly 2.8 lakh rupees in paise
      expect(loaded.panelBrand, equals('Tata Power Solar'));
      expect(loaded.isSubsidy, isTrue);
      expect(loaded.panelTypeLabel, equals('DCR Panels'));
      expect(loaded.totalCapacityKw, equals(5.4));
      expect(loaded.attachedDocs['e_bill'], equals('e_bill_101.pdf'));

      // Clear draft
      await LeadConvertDraftManager.clearDraft(leadId);
      final hasDraftAfterClear = await LeadConvertDraftManager.hasDraft(leadId);
      expect(hasDraftAfterClear, isFalse);

      final loadedAfterClear = await LeadConvertDraftManager.loadDraft(leadId);
      expect(loadedAfterClear, isNull);
    });

    test('Subsidy toggle changes panel type label between DCR and NDCR', () {
      const subsidyDraft = LeadConvertDraft(
        leadId: 'lead-1',
        isSubsidy: true,
      );
      expect(subsidyDraft.panelTypeLabel, equals('DCR Panels'));

      const nonSubsidyDraft = LeadConvertDraft(
        leadId: 'lead-2',
        isSubsidy: false,
      );
      expect(nonSubsidyDraft.panelTypeLabel, equals('NDCR Panels'));
    });

    test('Solar capacity formula: Watt * Count / 1000 = kW', () {
      const draft1 = LeadConvertDraft(
        leadId: 'lead-1',
        panelWatt: 540,
        panelCount: 10,
      );
      expect(draft1.totalCapacityKw, equals(5.4));

      const draft2 = LeadConvertDraft(
        leadId: 'lead-2',
        panelWatt: 550,
        panelCount: 6,
      );
      expect(draft2.totalCapacityKw, equals(3.3));

      const draft3 = LeadConvertDraft(
        leadId: 'lead-3',
        panelWatt: 450,
        panelCount: 20,
      );
      expect(draft3.totalCapacityKw, equals(9.0));
    });

    test('Money calculation strictly follows integer paise rules', () {
      const draft = LeadConvertDraft(
        leadId: 'lead-1',
        finalPriceRupees: 350000,
      );
      // Paise should be rupees * 100 in strict integer
      expect(draft.finalPricePaise, equals(35000000));
      expect(draft.finalPricePaise, isA<int>());

      final customer = CustomerModel(
        id: 'cust-uuid-1',
        name: 'Sunil Verma',
        mobile: '9812345678',
        address: 'Civil Lines, Jaipur',
        finalPrice: 35000000, // 35,000,000 paise
        capacityKw: 5.4,
        phase: 'three',
        panelBrand: 'Tata Power',
        panelWatt: 540,
        panelCount: 10,
        inverterBrand: 'Growatt',
        structureType: 'GI High Rise',
        stage: 'SALE_CONFIRMED',
      );

      expect(customer.finalPriceInRupees, equals(350000));
      expect(customer.formattedPriceRupees, contains('3,50,000'));
    });

    test('CustomerModel.fromJson handles backend CustomerRead payload accurately', () {
      final json = {
        'id': 'cust-uuid-8899',
        'name': 'Pooja Sharma',
        'mobile': '9988776655',
        'address': 'B-12, Sector 62, Noida, UP',
        'latitude': 28.6280,
        'longitude': 77.3649,
        'final_price': 22500000, // 2,25,000 rupees
        'capacity_kw': 3.3,
        'phase': 'single',
        'panel_brand': 'Waaree Energies',
        'panel_watt': 550,
        'panel_count': 6,
        'inverter_brand': 'Sungrow',
        'structure_type': 'Aluminum Elevated',
        'stage': 'DOCUMENTS_RECEIVED',
        'documents_count': 5,
        'payment_summary': {
          'total_amount_paise': 22500000,
          'received_amount_paise': 5000000,
          'pending_amount_paise': 17500000,
          'status': 'partially_paid',
        },
      };

      final customer = CustomerModel.fromJson(json);

      expect(customer.id, equals('cust-uuid-8899'));
      expect(customer.name, equals('Pooja Sharma'));
      expect(customer.mobile, equals('9988776655'));
      expect(customer.finalPrice, equals(22500000));
      expect(customer.finalPriceInRupees, equals(225000));
      expect(customer.formattedPriceRupees, contains('2,25,000'));
      expect(customer.capacityKw, equals(3.3));
      expect(customer.phase, equals('single'));
      expect(customer.stage, equals('DOCUMENTS_RECEIVED'));
      // Pre-installation stages from the old 10-step flow fold into Site Installation.
      expect(customer.stageDisplayLabel, equals('Site Installation'));
      expect(customer.documentsCount, equals(5));
      expect(customer.paymentSummary?['status'], equals('partially_paid'));
    });
  });
}
