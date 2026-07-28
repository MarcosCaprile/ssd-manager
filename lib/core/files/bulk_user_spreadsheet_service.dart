import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/user_bulk.dart';

class BulkUserSpreadsheetService {
  static const templateAsset =
      'assets/templates/ssd_manager_sani_bulk_template.xlsx';
  static const _headers = [
    'Vorname',
    'Nachname',
    'Benutzername',
    'Schul-E-Mail',
    'Temporäres Startpasswort',
    'Rolle',
    'Startdatum',
  ];

  Future<File> saveTemplate() async {
    final data = await rootBundle.load(templateAsset);
    return _writeFile(
      'SSD-Manager-Bulk-Import-Vorlage.xlsx',
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  List<UserBulkRow> parse(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables['Accounts'] ?? excel.tables.values.firstOrNull;
    if (sheet == null) {
      throw const FormatException(
        'Die Excel-Datei enthält kein Tabellenblatt.',
      );
    }
    final headerRowIndex = _findHeaderRow(sheet);
    if (headerRowIndex == null) {
      throw const FormatException(
        'Die erwarteten sieben Spaltenüberschriften wurden nicht gefunden.',
      );
    }
    final headerMap = <String, int>{};
    final headerRow = sheet.rows[headerRowIndex];
    for (var index = 0; index < headerRow.length; index++) {
      final name = _cellText(headerRow[index]?.value).trim().toLowerCase();
      if (name.isNotEmpty) headerMap[name] = index;
    }
    for (final header in _headers) {
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

      if (_headers.every((header) => value(header).isEmpty)) continue;
      final firstName = value('Vorname');
      final lastName = value('Nachname');
      final username = value('Benutzername');
      final email = value('Schul-E-Mail').toLowerCase();
      final temporaryPassword = value('Temporäres Startpasswort');
      final role = _normalizeRole(value('Rolle'));
      final rawStartDate = value('Startdatum');
      final sanitaeterSince = _apiStartDate(rawStartDate, role);
      final errors = _localErrors(
        firstName: firstName,
        lastName: lastName,
        username: username,
        email: email,
        temporaryPassword: temporaryPassword,
        role: role,
        rawStartDate: rawStartDate,
        sanitaeterSince: sanitaeterSince,
      );
      rows.add(
        UserBulkRow(
          rowNumber: rowIndex + 1,
          action: UserBulkAction.create,
          rawAction: UserBulkAction.create.apiValue,
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
      throw const FormatException('Die Excel-Datei enthält keine Accounts.');
    }
    return revalidate(rows);
  }

  /// Re-applies client-side spreadsheet rules after a mapped row was edited.
  List<UserBulkRow> revalidate(List<UserBulkRow> rows) {
    final checkedRows = [
      for (final row in rows)
        row.copyWith(
          localErrors: _localErrors(
            firstName: row.firstName,
            lastName: row.lastName,
            username: row.username,
            email: row.email,
            temporaryPassword: row.temporaryPassword,
            role: row.role,
            rawStartDate: row.startDateForDisplay,
            sanitaeterSince: row.sanitaeterSince,
          ),
        ),
    ];
    return _appendDuplicateErrors(checkedRows);
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
    for (var index = 0; index < sheet.rows.take(20).length; index++) {
      final values = sheet.rows[index]
          .map((cell) => _cellText(cell?.value).trim().toLowerCase())
          .toSet();
      if (_headers.every((header) => values.contains(header.toLowerCase()))) {
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
        '${value.day.toString().padLeft(2, '0')}/'
            '${value.month.toString().padLeft(2, '0')}/'
            '${value.year.toString().padLeft(4, '0')}',
      DateTimeCellValue() =>
        '${value.day.toString().padLeft(2, '0')}/'
            '${value.month.toString().padLeft(2, '0')}/'
            '${value.year.toString().padLeft(4, '0')}',
      TimeCellValue() => value.asDuration().toString(),
    };
  }

  String _normalizeRole(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'sanitäter' || 'sanitaeter' || 'schulsanitäter' => 'sanitaeter',
      'sani-leitung' || 'sani_leitung' || 'sanileitung' => 'sani_leitung',
      'lehreraufsicht' || 'teacher' || 'lehrer' => 'teacher',
      'sekretariat' || 'sekretärin' || 'sekretaerin' => 'sekretariat',
      _ => normalized,
    };
  }

  String _apiStartDate(String value, String role) {
    if (!_isSanitaryRole(role)) return '';
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
    if (match == null) return value;
    return '${match.group(3)}-${match.group(2)}-${match.group(1)}';
  }

  List<String> _localErrors({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String temporaryPassword,
    required String role,
    required String rawStartDate,
    required String sanitaeterSince,
  }) {
    final errors = <String>[];
    if (firstName.isEmpty ||
        lastName.isEmpty ||
        username.isEmpty ||
        email.isEmpty) {
      errors.add(
        'Vorname, Nachname, Benutzername und Schul-E-Mail sind erforderlich.',
      );
    }
    if (!email.contains('@') || email.startsWith('@') || email.endsWith('@')) {
      errors.add('Die Schul-E-Mail-Adresse ist nicht plausibel.');
    }
    if (temporaryPassword.length < 10) {
      errors.add('Das temporäre Startpasswort benötigt mindestens 10 Zeichen.');
    }
    if (!const {
      'sanitaeter',
      'sani_leitung',
      'teacher',
      'sekretariat',
    }.contains(role)) {
      errors.add(
        'Rolle muss Sanitäter, Sani-Leitung, Lehreraufsicht oder Sekretariat sein.',
      );
    }
    if (_isSanitaryRole(role)) {
      if (!_isValidApiDate(sanitaeterSince) ||
          !RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(rawStartDate)) {
        errors.add('Startdatum muss als DD/MM/YYYY angegeben werden.');
      }
    } else if (rawStartDate.trim().toUpperCase() != 'N/A') {
      errors.add(
        'Bei Lehreraufsicht und Sekretariat muss Startdatum N/A sein.',
      );
    }
    return errors;
  }

  List<UserBulkRow> _appendDuplicateErrors(List<UserBulkRow> rows) {
    final usernameCounts = <String, int>{};
    final emailCounts = <String, int>{};
    for (final row in rows) {
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
              'Schul-E-Mail kommt mehrfach in der Datei vor.',
          ],
        ),
    ];
  }

  bool _isValidApiDate(String value) {
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
