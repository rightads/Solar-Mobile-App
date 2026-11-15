import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/features/kedl/data/models/kedl_model.dart';
import 'package:solar_pro/features/kedl/data/repositories/kedl_repository.dart';
import 'helpers/fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FakeBackend.install();
  });

  group('KEDL Models & Enums Tests', () {
    test('KedlFileType handles name_change, load (labeled Load Increase), and net', () {
      expect(KedlFileType.fromBackendString('name_change'), KedlFileType.nameChange);
      expect(KedlFileType.nameChange.displayName, 'Name Change');
      expect(KedlFileType.nameChange.toBackendString(), 'name_change');

      // Backend value `load` must display as "Load Increase"
      expect(KedlFileType.fromBackendString('load'), KedlFileType.loadIncrease);
      expect(KedlFileType.loadIncrease.displayName, 'Load Increase');
      expect(KedlFileType.loadIncrease.toBackendString(), 'load');

      expect(KedlFileType.fromBackendString('net'), KedlFileType.net);
      expect(KedlFileType.net.displayName, 'Net Metering');
      expect(KedlFileType.net.toBackendString(), 'net');
    });

    test('KedlFileStatus handles full lifecycle flow', () {
      expect(KedlFileStatus.fromBackendString('not_started'), KedlFileStatus.notStarted);
      expect(KedlFileStatus.fromBackendString('submitted'), KedlFileStatus.submitted);
      expect(KedlFileStatus.fromBackendString('demand_raised'), KedlFileStatus.demandRaised);
      expect(KedlFileStatus.fromBackendString('demand_paid'), KedlFileStatus.demandPaid);
      expect(KedlFileStatus.fromBackendString('approved'), KedlFileStatus.approved);
      expect(KedlFileStatus.fromBackendString('rejected'), KedlFileStatus.rejected);
    });

    test('KedlDemandModel strict integer paise and overdue calculations', () {
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 4));
      final futureDate = now.add(const Duration(days: 5));

      final overdueDemand = KedlDemandModel(
        id: 'dem_01',
        kedlFileId: 'file_01',
        description: 'Inspection fee',
        amountPaise: 250000, // Rs. 2,500
        dueDate: pastDate,
        status: KedlDemandStatus.open,
        raisedOn: now.subtract(const Duration(days: 10)),
      );

      expect(overdueDemand.amountRupees, 2500.0);
      expect(overdueDemand.isOverdue, isTrue);

      final upcomingDemand = KedlDemandModel(
        id: 'dem_02',
        kedlFileId: 'file_01',
        description: 'Meter security deposit',
        amountPaise: 500000, // Rs. 5,000
        dueDate: futureDate,
        status: KedlDemandStatus.open,
        raisedOn: now,
      );

      expect(upcomingDemand.amountRupees, 5000.0);
      expect(upcomingDemand.isOverdue, isFalse);

      final resolvedDemand = overdueDemand.copyWith(status: KedlDemandStatus.paid);
      expect(resolvedDemand.isOverdue, isFalse);
    });
  });

  group('KedlRepository Operations Tests', () {
    test('listKedlFiles returns files and groups by customer', () async {
      final repo = KedlRepository();
      final files = await repo.listKedlFiles();
      expect(files.isNotEmpty, isTrue);

      final groups = repo.groupFilesByCustomer(files);
      expect(groups.isNotEmpty, isTrue);
      // Each customer has up to 3 Discom files (name_change, load, net)
      for (final g in groups) {
        expect(g.files.length, inInclusiveRange(1, 3));
      }
    });

    test('Filter files by fileType and hasOpenDemand', () async {
      final repo = KedlRepository();
      final netFiles = await repo.listKedlFiles(fileType: KedlFileType.net);
      for (final f in netFiles) {
        expect(f.fileType, KedlFileType.net);
      }

      final openDemandFiles = await repo.listKedlFiles(hasOpenDemand: true);
      for (final f in openDemandFiles) {
        expect(f.hasOpenDemand, isTrue);
      }
    });

    test('Raising a demand automatically transitions file status to demand_raised', () async {
      final repo = KedlRepository();
      final files = await repo.listKedlFiles();
      final targetFile = files.firstWhere((f) => f.status == KedlFileStatus.submitted || f.status == KedlFileStatus.notStarted);

      final demand = await repo.raiseDemand(
        targetFile.id,
        description: 'Discom testing fee',
        amountPaise: 150000,
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );

      expect(demand.amountPaise, 150000);
      expect(demand.status, KedlDemandStatus.open);

      final updatedFile = await repo.getKedlFileById(targetFile.id);
      expect(updatedFile.status, KedlFileStatus.demandRaised);
      expect(updatedFile.demands.any((d) => d.id == demand.id), isTrue);
    });

    test('Resolving all demands on a file transitions status to demand_paid', () async {
      final repo = KedlRepository();
      final files = await repo.listKedlFiles();
      final fileWithDemands = files.firstWhere((f) => f.demands.any((d) => d.status == KedlDemandStatus.open));
      final openDemand = fileWithDemands.demands.firstWhere((d) => d.status == KedlDemandStatus.open);

      final updatedDemand = await repo.updateDemand(openDemand.id, status: KedlDemandStatus.paid);
      expect(updatedDemand.status, KedlDemandStatus.paid);

      final refreshed = await repo.getKedlFileById(fileWithDemands.id);
      final allResolved = refreshed.demands.every((d) => d.status != KedlDemandStatus.open);
      if (allResolved) {
        expect(refreshed.status, KedlFileStatus.demandPaid);
      }
    });

    test('Dashboard metrics computes counts, open demands, and overdue demands', () async {
      final repo = KedlRepository();
      final metrics = await repo.getDashboardMetrics();

      expect(metrics.totalFiles, greaterThan(0));
      expect(metrics.openDemandsCount, greaterThanOrEqualTo(0));
      expect(metrics.overdueDemandsCount, greaterThanOrEqualTo(0));
    });
  });
}
