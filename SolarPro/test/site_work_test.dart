import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/features/work_assignment/data/models/site_customer_scope.dart';
import 'package:solar_pro/features/work_assignment/data/models/work_assignment_model.dart';
import 'package:solar_pro/features/work_assignment/data/repositories/work_assignment_repository.dart';
import 'package:solar_pro/features/work_assignment/data/services/site_offline_queue_service.dart';
import 'helpers/fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend.install();
    final queue = SiteOfflineQueueService();
    await queue.init();
    await queue.clearAll();
  });

  group('WorkAssignment & Scope Models Test', () {
    test('WorkType and WorkStatus enums serialize and deserialize accurately', () {
      expect(WorkType.fromString('structure'), WorkType.structure);
      expect(WorkType.fromString('electrical'), WorkType.electrical);
      expect(WorkType.fromString('electrician'), WorkType.electrical);
      expect(WorkType.fromString('civil'), WorkType.civil);

      expect(WorkStatus.fromString('pending'), WorkStatus.pending);
      expect(WorkStatus.fromString('in_progress'), WorkStatus.inProgress);
      expect(WorkStatus.fromString('completed'), WorkStatus.completed);
      expect(WorkStatus.fromString('cancelled'), WorkStatus.cancelled);
    });

    test('CustomerShortForLabourModel strictly lacks financial, pricing, and document fields', () {
      final json = {
        'id': 'cust_001',
        'name': 'Ramesh Kumar',
        'mobile': '9876543210',
        'address': 'Jaipur, Rajasthan',
        'latitude': 26.9124,
        'longitude': 75.7873,
        // Any extraneous data from backend is not stored in labour model
        'final_price': 25000000,
        'documents': ['doc1', 'doc2'],
      };

      final model = CustomerShortForLabourModel.fromJson(json);
      expect(model.name, 'Ramesh Kumar');
      expect(model.mobile, '9876543210');
      expect(model.address, 'Jaipur, Rajasthan');
      expect(model.latitude, 26.9124);

      final exported = model.toJson();
      expect(exported.containsKey('final_price'), isFalse);
      expect(exported.containsKey('documents'), isFalse);
      expect(exported.containsKey('payment_summary'), isFalse);
    });

    test('SiteCustomerScope extracts technical equipment specs by discipline safely', () {
      const scope = SiteCustomerScope(
        structureBrand: 'Tata Solar Heavy GI',
        panelBrand: 'Adani Solar DCR Bifacial',
        panelCount: 12,
        panelWatt: 540,
        structureHeight: '8 ft Elevated Rooftop',
        inverterBrand: 'Growatt Grid-Tie',
        inverterCapacityKw: 6.0,
        phase: 'Three Phase (415V)',
      );

      final structEntries = scope.getEntriesForRole(WorkType.structure);
      expect(structEntries.any((e) => e.value.contains('Tata Solar Heavy GI')), isTrue);
      expect(structEntries.any((e) => e.value.contains('12 x Adani Solar DCR Bifacial (540 W)')), isTrue);

      final elecEntries = scope.getEntriesForRole(WorkType.electrical);
      expect(elecEntries.any((e) => e.value.contains('Growatt Grid-Tie')), isTrue);
      expect(elecEntries.any((e) => e.value.contains('Three Phase')), isTrue);

      final civilEntries = scope.getEntriesForRole(WorkType.civil);
      expect(civilEntries.any((e) => e.key == 'Civil Work Scope'), isTrue);
      expect(civilEntries.any((e) => e.key == 'Earthing Setup'), isTrue);
    });
  });

  group('WorkAssignmentRepository Role Scoping Tests', () {
    test('Electrician only retrieves electrical jobs, never structure or civil', () async {
      final repo = WorkAssignmentRepository();
      final jobs = await repo.listWorkAssignments(workType: WorkType.electrical);

      expect(jobs.isNotEmpty, isTrue);
      for (final job in jobs) {
        expect(job.workType, WorkType.electrical);
        expect(job.workType, isNot(WorkType.structure));
        expect(job.workType, isNot(WorkType.civil));
      }
    });

    test('Structure team only retrieves structure jobs, never electrical or civil', () async {
      final repo = WorkAssignmentRepository();
      final jobs = await repo.listWorkAssignments(workType: WorkType.structure);

      expect(jobs.isNotEmpty, isTrue);
      for (final job in jobs) {
        expect(job.workType, WorkType.structure);
        expect(job.workType, isNot(WorkType.electrical));
        expect(job.workType, isNot(WorkType.civil));
      }
    });

    test('Civil team only retrieves civil jobs, never electrical or structure', () async {
      final repo = WorkAssignmentRepository();
      final jobs = await repo.listWorkAssignments(workType: WorkType.civil);

      expect(jobs.isNotEmpty, isTrue);
      for (final job in jobs) {
        expect(job.workType, WorkType.civil);
        expect(job.workType, isNot(WorkType.electrical));
        expect(job.workType, isNot(WorkType.structure));
      }
    });
  });

  group('Work Actions & Photo Rules Test', () {
    test('Starting a job updates status to inProgress and records actualStart', () async {
      final repo = WorkAssignmentRepository();
      final electricalJobs = await repo.listWorkAssignments(workType: WorkType.electrical);
      final pendingJob = electricalJobs.firstWhere((j) => j.status == WorkStatus.pending);

      final started = await repo.startWork(pendingJob.id);
      expect(started.status, WorkStatus.inProgress);
      expect(started.actualStart, isNotNull);
    });

    test('Completing a job without photos is blocked and throws StateError', () async {
      final repo = WorkAssignmentRepository();
      final electricalJobs = await repo.listWorkAssignments(workType: WorkType.electrical);
      final job = electricalJobs.first;

      expect(
        () => repo.completeWork(job.id, existingPhotos: []),
        throwsA(isA<StateError>()),
      );
    });

    test('Completing a job with at least 1 photo succeeds and updates status to completed', () async {
      final repo = WorkAssignmentRepository();
      const jobId = 'job_electrical_1';
      backend.addJobPhoto(jobId); // photo proof already on the server
      final photo = WorkPhotoModel(
        id: 'photo_test_01',
        workAssignmentId: jobId,
        fileKey: 'proof.jpg',
        createdAt: DateTime.now(),
      );

      final completed = await repo.completeWork(jobId, existingPhotos: [photo]);
      expect(completed.status, WorkStatus.completed);
      expect(completed.isPendingSync, isFalse);
    });
  });

  group('Offline Queue & Sync Tests', () {
    test('Offline queue queues actions and reflects pending count', () async {
      final queue = SiteOfflineQueueService();
      await queue.init();

      expect(queue.pendingCount, 0);
      expect(queue.hasPending, isFalse);

      await queue.queueStartWork('assignment_123');
      await queue.queuePhotoUpload('assignment_123', ['local/path/pic.jpg']);

      expect(queue.pendingCount, 2);
      expect(queue.hasPending, isTrue);
      expect(queue.hasPendingForAssignment('assignment_123'), isTrue);
      expect(queue.hasPendingForAssignment('other_id'), isFalse);

      await queue.removeAction(queue.actions.first.id);
      expect(queue.pendingCount, 1);

      await queue.clearAll();
      expect(queue.pendingCount, 0);
    });
  });
}
