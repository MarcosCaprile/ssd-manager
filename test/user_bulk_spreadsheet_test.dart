import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/core/files/bulk_user_spreadsheet_service.dart';
import 'package:ssd_manager/models/user_bulk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled Excel template maps one valid example per role', () async {
    final data = await rootBundle.load(
      BulkUserSpreadsheetService.templateAsset,
    );
    final rows = BulkUserSpreadsheetService().parse(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );

    expect(rows, hasLength(4));
    expect(rows.every((row) => row.action == UserBulkAction.create), isTrue);
    expect(rows.map((row) => row.role).toSet(), {
      'sanitaeter',
      'sani_leitung',
      'teacher',
      'sekretariat',
    });
    expect(rows.every((row) => row.localErrors.isEmpty), isTrue);
    expect(rows.first.sanitaeterSince, matches(r'^\d{4}-\d{2}-\d{2}$'));
  });

  test(
    'German role labels and DD/MM/YYYY are normalized for the API',
    () async {
      final data = await rootBundle.load(
        BulkUserSpreadsheetService.templateAsset,
      );
      final rows = BulkUserSpreadsheetService().parse(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );

      expect(rows.first.role, 'sanitaeter');
      expect(rows.first.sanitaeterSince, '2025-09-01');
      expect(rows[2].role, 'teacher');
      expect(rows[2].sanitaeterSince, isEmpty);
    },
  );

  test('demo school workbook contains 37 valid funny-name accounts', () async {
    final bytes = await File(
      'outputs/ssd-manager-demo-school/SSD_Manager_Demo_Schule_Bulk_Import.xlsx',
    ).readAsBytes();
    final rows = BulkUserSpreadsheetService().parse(bytes);

    expect(rows, hasLength(37));
    expect(rows.where((row) => row.role == 'sanitaeter'), hasLength(30));
    expect(rows.where((row) => row.role == 'sani_leitung'), hasLength(3));
    expect(rows.where((row) => row.role == 'teacher'), hasLength(2));
    expect(rows.where((row) => row.role == 'sekretariat'), hasLength(2));
    expect(rows.every((row) => row.localErrors.isEmpty), isTrue);
    expect(rows.first.displayName, 'Tomas Tomate');
  });
}
