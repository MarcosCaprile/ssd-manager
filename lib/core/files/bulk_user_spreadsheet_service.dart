import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/user.dart';
import '../../models/user_bulk.dart';

class BulkUserSpreadsheetService {
  static const templateAsset =
      'assets/templates/ssd_manager_sani_bulk_template.xlsx';
  static const _headers = [
    'Aktion',
    'ID',
    'Vorname',
    'Nachname',
    'Benutzername',
    'E-Mail',
    'Temporäres Passwort',
    'Rolle',
    'Sanitäter seit',
    'Hinweis',
  ];

  Future<File> saveTemplate() async {
    final data = await rootBundle.load(templateAsset);
    return _writeFile(
      'SSD-Manager-Sani-Bulk-Template.xlsx',
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  List<UserBulkRow> parse(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables['Sanis'] ?? excel.tables.values.firstOrNull;
    if (sheet == null) {
      throw const FormatException(
        'Die Excel-Datei enthält kein Tabellenblatt.',
      );
    }
    final headerRowIndex = _findHeaderRow(sheet);
    if (headerRowIndex == null) {
      throw const FormatException(
        'Die erwarteten Spaltenüberschriften wurden nicht gefunden.',
      );
    }
    final headerMap = <String, int>{};
    final headerRow = sheet.rows[headerRowIndex];
    for (var index = 0; index < headerRow.length; index++) {
      final name = _cellText(headerRow[index]?.value).trim().toLowerCase();
      if (name.isNotEmpty) headerMap[name] = index;
    }
    for (final header in _headers.take(9)) {
      if (!headerMap.containsKey(header.toLowerCase())) {
        throw FormatException('Die Spalte „$header“ fehlt.');
      }
    }

    final rows = <UserBulkRow>[];
    for (
      var rowIndex = headerRowIndex + 1;
      rowIndex < sheet.rows.length && rows.length < 250;
      rowIndex++
    ) {
      final values = sheet.rows[rowIndex];
      String value(String header) {
        final column = headerMap[header.toLowerCase()]!;
        return column < values.length
            ? _cellText(values[column]?.value).trim()
            : '';
      }

      final rawAction = value('Aktion');
      final allEmpty = _headers
          .take(9)
          .every((header) => value(header).isEmpty);
      if (allEmpty) continue;

      final action = UserBulkAction.fromSpreadsheet(rawAction);
      final rawId = value('ID');
      final id = int.tryParse(rawId);
      final firstName = value('Vorname');
      final lastName = value('Nachname');
      final username = value('Benutzername');
      final email = value('E-Mail').toLowerCase();
      final temporaryPassword = value('Temporäres Passwort');
      final role = value('Rolle').toLowerCase();
      final sanitaeterSince = value('Sanitäter seit');
      final errors = _localErrors(
        action: action,
        rawAction: rawAction,
        rawId: rawId,
        id: id,
        firstName: firstName,
        lastName: lastName,
        username: username,
        email: email,
        temporaryPassword: temporaryPassword,
        role: role,
        sanitaeterSince: sanitaeterSince,
      );
      rows.add(
        UserBulkRow(
          rowNumber: rowIndex + 1,
          action: action,
          rawAction: rawAction,
          id: id,
          firstName: firstName,
          lastName: lastName,
          username: username,
          email: email,
          temporaryPassword: temporaryPassword,
          role: role,
          sanitaeterSince: sanitaeterSince,
          localErrors: errors,
        ),
      );
    }
    if (rows.isEmpty) {
      throw const FormatException('Die Excel-Datei enthält keine Aktionen.');
    }
    return _appendDuplicateErrors(rows);
  }

  Future<File> exportUsers(List<User> users) async {
    final bytes = await exportBytes(users);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    return _writeFile('SSD-Manager-Sani-Export-$stamp.xlsx', bytes);
  }

  Future<Uint8List> exportBytes(List<User> users) async {
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, 'Sanis');
    final sheet = excel['Sanis'];
    final notes = excel['Hinweise'];
    final navy = '#123B73'.excelColor;
    final blue = '#2563EB'.excelColor;
    final paleBlue = '#E8F1FB'.excelColor;
    final white = '#FFFFFF'.excelColor;
    final darkText = '#374151'.excelColor;
    final titleStyle = CellStyle(
      backgroundColorHex: navy,
      fontColorHex: white,
      bold: true,
      fontSize: 18,
      verticalAlign: VerticalAlign.Center,
    );
    final subtitleStyle = CellStyle(
      backgroundColorHex: paleBlue,
      fontColorHex: navy,
      italic: true,
      textWrapping: TextWrapping.WrapText,
    );
    final infoStyle = CellStyle(
      fontColorHex: darkText,
      textWrapping: TextWrapping.WrapText,
    );
    final headerStyle = CellStyle(
      backgroundColorHex: blue,
      fontColorHex: white,
      bold: true,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final dataStyle = CellStyle(verticalAlign: VerticalAlign.Top);
    final noteStyle = CellStyle(
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );
    final dateStyle = CellStyle(
      verticalAlign: VerticalAlign.Top,
      numberFormat: NumFormat.custom(formatCode: 'yyyy-mm-dd'),
    );

    _mergeWithValue(
      sheet,
      startColumn: 0,
      endColumn: 9,
      row: 0,
      value: 'SSD Manager – Sani Bulk-Export',
      style: titleStyle,
    );
    sheet.setRowHeight(0, 34);
    _mergeWithValue(
      sheet,
      startColumn: 0,
      endColumn: 9,
      row: 1,
      value:
          'Ausgewählte Accounts im Format der Importvorlage. '
          'Passwörter werden niemals exportiert.',
      style: subtitleStyle,
    );
    sheet.setRowHeight(1, 30);
    _mergeWithValue(
      sheet,
      startColumn: 0,
      endColumn: 9,
      row: 3,
      value:
          'Aktion bei Bedarf ändern: bearbeiten, deaktivieren, reaktivieren '
          'oder löschung_vormerken.',
      style: infoStyle,
    );
    _mergeWithValue(
      sheet,
      startColumn: 0,
      endColumn: 9,
      row: 4,
      value:
          'Die exportierte ID nicht verändern. „Sanitäter seit“ bleibt bei '
          'bestehenden Accounts unveränderlich.',
      style: infoStyle,
    );
    for (var column = 0; column < _headers.length; column++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 7),
      );
      cell.value = TextCellValue(_headers[column]);
      cell.cellStyle = headerStyle;
    }
    sheet.setRowHeight(7, 34);

    const widths = <double>[22, 10, 17, 19, 20, 31, 29, 20, 20, 43];
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }

    for (var index = 0; index < users.length; index++) {
      final user = users[index];
      final row = 8 + index;
      final values = <CellValue?>[
        TextCellValue(UserBulkAction.update.spreadsheetValue),
        IntCellValue(user.id),
        TextCellValue(user.firstName),
        TextCellValue(user.lastName),
        TextCellValue(user.username),
        TextCellValue(user.email),
        null,
        TextCellValue(user.role.toJson()),
        user.sanitaeterSince == null
            ? null
            : DateCellValue(
                year: user.sanitaeterSince!.year,
                month: user.sanitaeterSince!.month,
                day: user.sanitaeterSince!.day,
              ),
        TextCellValue(
          'Rolle, Name, Benutzername oder E-Mail bearbeiten; '
          '„Sanitäter seit“ bleibt unverändert.',
        ),
      ];
      for (var column = 0; column < values.length; column++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
        );
        cell.value = values[column];
        cell.cellStyle = column == 8
            ? dateStyle
            : column == 9
            ? noteStyle
            : dataStyle;
      }
    }

    _mergeWithValue(
      notes,
      startColumn: 0,
      endColumn: 3,
      row: 0,
      value: 'SSD Manager – Hinweise zum Bulk-Export',
      style: titleStyle,
    );
    const noteRows = <List<String>>[
      ['Aktion', 'Bedeutung', 'ID', 'Passwort'],
      [
        'bearbeiten',
        'Name, Benutzername, E-Mail oder Sani-Rolle aktualisieren',
        'Unverändert lassen',
        'Bleibt leer',
      ],
      [
        'deaktivieren',
        'Account deaktivieren und alle Sitzungen widerrufen',
        'Erforderlich',
        'Bleibt leer',
      ],
      [
        'reaktivieren',
        'Einen deaktivierten Account wieder aktivieren',
        'Erforderlich',
        'Bleibt leer',
      ],
      [
        'löschung_vormerken',
        'Account zur späteren Löschung vormerken',
        'Erforderlich',
        'Bleibt leer',
      ],
    ];
    for (var row = 0; row < noteRows.length; row++) {
      for (var column = 0; column < noteRows[row].length; column++) {
        final cell = notes.cell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row + 2),
        );
        cell.value = TextCellValue(noteRows[row][column]);
        cell.cellStyle = row == 0 ? headerStyle : noteStyle;
      }
    }
    for (var column = 0; column < 4; column++) {
      notes.setColumnWidth(column, const [24.0, 52.0, 22.0, 20.0][column]);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw const FileSystemException(
        'Die Excel-Datei konnte nicht erstellt werden.',
      );
    }
    return Uint8List.fromList(bytes);
  }

  void _mergeWithValue(
    Sheet sheet, {
    required int startColumn,
    required int endColumn,
    required int row,
    required String value,
    required CellStyle style,
  }) {
    final start = CellIndex.indexByColumnRow(
      columnIndex: startColumn,
      rowIndex: row,
    );
    sheet.merge(
      start,
      CellIndex.indexByColumnRow(columnIndex: endColumn, rowIndex: row),
      customValue: TextCellValue(value),
    );
    sheet.setMergedCellStyle(start, style);
  }

  Future<File> _writeFile(String name, Uint8List bytes) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/SSD Manager Exporte');
    await directory.create(recursive: true);
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  int? _findHeaderRow(Sheet sheet) {
    final scanRows = sheet.rows.take(20).toList();
    for (var index = 0; index < scanRows.length; index++) {
      final values = scanRows[index]
          .map((cell) => _cellText(cell?.value).trim().toLowerCase())
          .toSet();
      if (values.contains('aktion') &&
          values.contains('benutzername') &&
          values.contains('e-mail')) {
        return index;
      }
    }
    return null;
  }

  String _cellText(CellValue? value) {
    return switch (value) {
      null => '',
      TextCellValue() => value.value.toString(),
      FormulaCellValue() => value.formula,
      IntCellValue() => value.value.toString(),
      DoubleCellValue() =>
        value.value == value.value.roundToDouble()
            ? value.value.round().toString()
            : value.value.toString(),
      BoolCellValue() => value.value ? 'true' : 'false',
      DateCellValue() =>
        '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}',
      DateTimeCellValue() =>
        '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}',
      TimeCellValue() => value.asDuration().toString(),
    };
  }

  List<String> _localErrors({
    required UserBulkAction? action,
    required String rawAction,
    required String rawId,
    required int? id,
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String temporaryPassword,
    required String role,
    required String sanitaeterSince,
  }) {
    final errors = <String>[];
    if (action == null) {
      errors.add('Aktion „$rawAction“ ist unbekannt.');
      return errors;
    }
    if (action == UserBulkAction.create) {
      if (rawId.isNotEmpty) {
        errors.add('Beim Hinzufügen muss die ID leer bleiben.');
      }
      if (temporaryPassword.length < 10) {
        errors.add('Das temporäre Passwort benötigt mindestens 10 Zeichen.');
      }
      if (_isSanitaryRole(role) && !_isValidDate(sanitaeterSince)) {
        errors.add('„Sanitäter seit“ muss als YYYY-MM-DD angegeben werden.');
      }
      if (!_isSanitaryRole(role) && sanitaeterSince.isNotEmpty) {
        errors.add('„Sanitäter seit“ muss bei Lehreraufsicht und Sekretariat leer bleiben.');
      }
    } else if (id == null || id < 1) {
      errors.add('Für diese Aktion ist eine gültige exportierte ID nötig.');
    }
    if (action == UserBulkAction.create || action == UserBulkAction.update) {
      if (firstName.isEmpty ||
          lastName.isEmpty ||
          username.isEmpty ||
          email.isEmpty) {
        errors.add(
          'Vorname, Nachname, Benutzername und E-Mail sind erforderlich.',
        );
      }
      if (!email.contains('@') ||
          email.startsWith('@') ||
          email.endsWith('@')) {
        errors.add('Die E-Mail-Adresse ist nicht plausibel.');
      }
      if (!const {'sanitaeter', 'sani_leitung', 'teacher', 'sekretariat'}.contains(role)) {
        errors.add('Rolle muss sanitaeter, sani_leitung, teacher oder sekretariat sein.');
      }
      if (action == UserBulkAction.update && !_isSanitaryRole(role)) {
        errors.add('Bestehende Accounts können per Bulk nur als Sanitäter oder Sani-Leitung geführt werden.');
      }
    }
    return errors;
  }

  List<UserBulkRow> _appendDuplicateErrors(List<UserBulkRow> rows) {
    final usernameCounts = <String, int>{};
    final emailCounts = <String, int>{};
    for (final row in rows) {
      if (row.action != UserBulkAction.create &&
          row.action != UserBulkAction.update) {
        continue;
      }
      usernameCounts.update(
        row.username.toLowerCase(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      emailCounts.update(
        row.email.toLowerCase(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return [
      for (final row in rows)
        UserBulkRow(
          rowNumber: row.rowNumber,
          action: row.action,
          rawAction: row.rawAction,
          id: row.id,
          firstName: row.firstName,
          lastName: row.lastName,
          username: row.username,
          email: row.email,
          temporaryPassword: row.temporaryPassword,
          role: row.role,
          sanitaeterSince: row.sanitaeterSince,
          localErrors: [
            ...row.localErrors,
            if (row.username.isNotEmpty &&
                (usernameCounts[row.username.toLowerCase()] ?? 0) > 1)
              'Benutzername kommt mehrfach in der Datei vor.',
            if (row.email.isNotEmpty &&
                (emailCounts[row.email.toLowerCase()] ?? 0) > 1)
              'E-Mail kommt mehrfach in der Datei vor.',
          ],
        ),
    ];
  }

  bool _isValidDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final date = DateTime.tryParse(value);
    return date != null &&
        date.year == int.parse(match.group(1)!) &&
        date.month == int.parse(match.group(2)!) &&
        date.day == int.parse(match.group(3)!);
  }

  bool _isSanitaryRole(String role) =>
      role == 'sanitaeter' || role == 'sani_leitung';
}
