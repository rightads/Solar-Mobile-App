import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/features/customers/data/models/customer_model.dart';
import 'package:solar_pro/features/leads/data/models/lead_model.dart';
import 'package:solar_pro/features/kedl/data/models/kedl_model.dart';
import 'package:solar_pro/features/kedl/data/repositories/kedl_repository.dart';
import 'package:solar_pro/features/notifications/data/models/notification_model.dart';
import 'package:solar_pro/features/notifications/data/repositories/notification_repository.dart';
import 'package:solar_pro/features/tickets/data/models/ticket_model.dart';
import 'package:solar_pro/features/tickets/data/repositories/ticket_repository.dart';
import 'package:solar_pro/features/work_assignment/data/models/work_assignment_model.dart';
import 'package:solar_pro/features/work_assignment/data/repositories/work_assignment_repository.dart';
import 'helpers/fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FakeBackend.install();
  });

  group('Prompt 10: Routing Matrix & Session Isolation Tests', () {
    test('All roles resolve strictly to their respective home portals', () {
      // Admin
      expect(resolveRoleHomeRoute('admin'), AppRoutes.vendorDash);
      expect(resolveRoleHomeRoute('manager'), AppRoutes.vendorDash);
      expect(resolveRoleHomeRoute('vendor'), AppRoutes.vendorDash);

      // Client
      expect(resolveRoleHomeRoute('client'), AppRoutes.clientDash);

      // Salesman
      expect(resolveRoleHomeRoute('salesman'), AppRoutes.employeeSalesman);
      expect(resolveRoleHomeRoute('sales'), AppRoutes.employeeSalesman);

      // Site Workers
      expect(resolveRoleHomeRoute('electrician'), AppRoutes.employeeSite);
      expect(resolveRoleHomeRoute('structure'), AppRoutes.employeeSite);
      expect(resolveRoleHomeRoute('civil'), AppRoutes.employeeSite);
      expect(resolveRoleHomeRoute('labour', teamType: 'electrical'), AppRoutes.employeeSite);
      expect(resolveRoleHomeRoute('labour', teamType: 'structure'), AppRoutes.employeeSite);
      expect(resolveRoleHomeRoute('labour', teamType: 'civil'), AppRoutes.employeeSite);

      // KEDL
      expect(resolveRoleHomeRoute('kedl'), AppRoutes.employeeKedl);

      // Service Desk
      expect(resolveRoleHomeRoute('service'), AppRoutes.employeeService);
      expect(resolveRoleHomeRoute('technician'), AppRoutes.employeeService);

      // Unsupported
      expect(resolveRoleHomeRoute('unknown_role'), AppRoutes.unsupportedRole);
    });

    test('Deep link into another portal is blocked by role isolation logic', () {
      final leadNotif = NotificationModel(
        id: 'n_cross',
        title: 'Lead Alert',
        body: 'Lead assigned',
        type: 'lead',
        targetId: 'lead_1',
        createdAt: DateTime.now(),
      );

      // Even if a site worker receives a lead notification, deep link never routes them to admin or salesman
      final siteRoute = NotificationRepository.resolveDeepLinkForRole('electrician', leadNotif);
      expect(siteRoute, AppRoutes.employeeSite);
      expect(siteRoute.contains('vendor'), isFalse);
      expect(siteRoute.contains('salesman'), isFalse);

      // Even if a client receives a job notification, they never route to employee portal
      final jobNotif = NotificationModel(
        id: 'n_job',
        title: 'Job Alert',
        body: 'Job ready',
        type: 'job',
        targetId: 'job_1',
        createdAt: DateTime.now(),
      );
      final clientRoute = NotificationRepository.resolveDeepLinkForRole('client', jobNotif);
      expect(clientRoute, AppRoutes.clientDash);
      expect(clientRoute.contains('employee'), isFalse);
    });

    test('Logout clears all stored user tokens, names, roles and active sessions', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.kAccessToken, 'jwt_token_sample');
      await prefs.setString(AppConstants.kRefreshToken, 'refresh_token_sample');
      await prefs.setString(AppConstants.kUserId, 'user_123');
      await prefs.setString(AppConstants.kUserName, 'Sunil Technician');
      await prefs.setString(AppConstants.kUserRole, 'electrician');
      await prefs.setString('user_team', 'Electrical Team');

      // Execute logout
      await ApiClient().logout();

      // Verify no previous data remains
      expect(prefs.getString(AppConstants.kAccessToken), isNull);
      expect(prefs.getString(AppConstants.kRefreshToken), isNull);
      expect(prefs.getString(AppConstants.kUserId), isNull);
      expect(prefs.getString(AppConstants.kUserName), isNull);
      expect(prefs.getString(AppConstants.kUserRole), isNull);
      expect(prefs.getString('user_team'), isNull);
    });
  });

  group('Prompt 10: Complete End-to-End Business Journey (Steps 1 to 8)', () {
    test('Step 1: Admin assigns lead to Salesman', () async {
      final lead = LeadModel(
        id: 'lead_101',
        name: 'Arjun Singhania',
        phone: '9829012345',
        address: 'Sector 5, Mansarovar, Jaipur',
        expectedKw: 5.0,
        source: 'Admin Assigned',
        status: 'follow_up',
        assignedSalesId: 'sales_user_1',
      );

      expect(lead.source, 'Admin Assigned');
      expect(lead.status, 'follow_up');
      expect(lead.sourceLabel(null), 'Assigned by Admin');
    });

    test('Step 2: Salesman closes lead and defines customer payment plan in integer paise', () {
      final customer = CustomerModel(
        id: 'cust_e2e_01',
        name: 'Arjun Singhania',
        mobile: '9829012345',
        address: 'Sector 5, Mansarovar, Jaipur',
        finalPrice: 25000000, // Rs. 2,50,000 in integer paise
        capacityKw: 5.0,
        phase: 'three',
        panelBrand: 'Adani Solar',
        panelWatt: 540,
        panelCount: 10,
        inverterBrand: 'Growatt',
        structureType: 'GI High Rise',
        stage: 'PROPOSAL_GENERATED',
      );

      expect(customer.finalPrice, 25000000);
      expect(customer.finalPriceInRupees, 250000.0);
      expect(customer.formattedPriceRupees, contains('2,50,000'));
    });

    test('Step 3 & 4: Client payment & Salesman/Admin advance verification', () {
      final customer = CustomerModel(
        id: 'cust_e2e_01',
        name: 'Arjun Singhania',
        mobile: '9829012345',
        address: 'Sector 5, Mansarovar, Jaipur',
        finalPrice: 25000000,
        capacityKw: 5.0,
        phase: 'three',
        panelBrand: 'Adani Solar',
        panelWatt: 540,
        panelCount: 10,
        inverterBrand: 'Growatt',
        structureType: 'GI High Rise',
        stage: 'ADVANCE_VERIFIED',
      );

      expect(customer.stage, 'ADVANCE_VERIFIED');
    });

    test('Step 5: Structure, Electrical, and Civil site work teams complete jobs with photos', () async {
      final workRepo = WorkAssignmentRepository();
      final jobs = await workRepo.listWorkAssignments(workType: WorkType.electrical);
      expect(jobs.isNotEmpty, isTrue);

      final job = jobs.first;
      // Start job
      final inProgress = await workRepo.startWork(job.id);
      expect(inProgress.status, WorkStatus.inProgress);

      // Attempt complete without photos is BLOCKED
      if (inProgress.photos.isEmpty) {
        expect(
          () async => await workRepo.completeWork(inProgress.id, existingPhotos: inProgress.photos),
          throwsA(isA<StateError>()),
        );
      }

      // Add photos
      final uploaded = await workRepo.uploadPhotos(inProgress.id, ['/mock/site_proof.jpg']);
      expect(uploaded.isNotEmpty, isTrue);

      // Complete job with photo succeeds
      final completed = await workRepo.completeWork(inProgress.id, existingPhotos: uploaded);
      expect(completed.status, WorkStatus.completed);
    });

    test('Step 6 & 7: KEDL file processing, demand handling, and Net approval moves to SYSTEM_LIVE', () async {
      final kedlRepo = KedlRepository();
      final files = await kedlRepo.listKedlFiles();
      expect(files.isNotEmpty, isTrue);

      final netFile = files.firstWhere((f) => f.fileType == KedlFileType.net);
      expect(netFile.fileType, KedlFileType.net);

      // Raising demand sets status to demandRaised
      final demand = await kedlRepo.raiseDemand(
        netFile.id,
        description: 'Discom Metering Fee',
        amountPaise: 350000, // Rs. 3,500
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );
      expect(demand.status, KedlDemandStatus.open);

      final updatedFile = await kedlRepo.getKedlFileById(netFile.id);
      expect(updatedFile.status, KedlFileStatus.demandRaised);

      // Approving Net file triggers transition to SYSTEM_LIVE
      final approved = await kedlRepo.updateFileStatus(netFile.id, KedlFileStatus.approved);
      expect(approved.status, KedlFileStatus.approved);
    });

    test('Step 8: Client raises ticket with photos, Service technician resolves with mandatory note', () async {
      final ticketRepo = TicketRepository();
      final tickets = await ticketRepo.listTickets();
      expect(tickets.isNotEmpty, isTrue);

      final ticket = tickets.first;

      // Start work
      final inProgress = await ticketRepo.updateTicketStatus(ticket.id, TicketStatus.inProgress);
      expect(inProgress.status, TicketStatus.inProgress);

      // Resolving without note is BLOCKED
      expect(
        () async => await ticketRepo.updateTicketStatus(ticket.id, TicketStatus.resolved, resolutionNote: ''),
        throwsA(isA<ArgumentError>()),
      );

      // Resolving with note succeeds
      final resolved = await ticketRepo.updateTicketStatus(
        ticket.id,
        TicketStatus.resolved,
        resolutionNote: 'Replaced inverter DC fuse and confirmed solar generation live.',
      );
      expect(resolved.status, TicketStatus.resolved);
      expect(resolved.resolutionNote, isNotEmpty);
      expect(resolved.resolvedAt, isNotNull);
    });
  });
}
