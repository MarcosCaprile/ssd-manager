import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/core/files/bulk_user_spreadsheet_service.dart';
import 'package:ssd_manager/models/user.dart';
import 'package:ssd_manager/models/user_bulk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled Excel template maps its example row', () async {
    final data = await rootBundle.load(
      BulkUserSpreadsheetService.templateAsset,
    );
    final rows = BulkUserSpreadsheetService().parse(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );

    expect(rows, isNotEmpty);
    expect(rows.first.action, UserBulkAction.create);
    expect(rows.first.role, 'sanitaeter');
    expect(rows.first.sanitaeterSince, isNotEmpty);
    expect(rows.first.localErrors, isEmpty);
  });

  test('spreadsheet action aliases map to explicit API actions', () {
    expect(UserBulkAction.fromSpreadsheet('hinzufügen'), UserBulkAction.create);
    expect(
      UserBulkAction.fromSpreadsheet('entfernen'),
      UserBulkAction.deactivate,
    );
    expect(
      UserBulkAction.fromSpreadsheet('löschung_vormerken'),
      UserBulkAction.markDeletion,
    );
  });

  test('selected Sanis export in the same importable format', () async {
    const user = User(
      id: 17,
      firstName: 'Tina',
      lastName: 'Test',
      username: 'tina.t',
      email: 'tina@example.test',
      role: UserRole.saniLeitung,
      status: 'active',
      mustChangePassword: false,
    );
    final service = BulkUserSpreadsheetService();
    final exportedRows = service.parse(await service.exportBytes([user]));

    expect(exportedRows, hasLength(1));
    expect(exportedRows.single.action, UserBulkAction.update);
    expect(exportedRows.single.id, 17);
    expect(exportedRows.single.username, 'tina.t');
    expect(exportedRows.single.role, 'sani_leitung');
    expect(exportedRows.single.temporaryPassword, isEmpty);
    expect(exportedRows.single.localErrors, isEmpty);
  });
}
