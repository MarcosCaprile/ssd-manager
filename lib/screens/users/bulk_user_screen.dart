import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../models/user_bulk.dart';
import '../../providers/api_providers.dart';
import '../../utils/user_error_message.dart';
import '../../widgets/confirm_dialog.dart';

class BulkUserScreen extends ConsumerStatefulWidget {
  const BulkUserScreen({super.key});

  @override
  ConsumerState<BulkUserScreen> createState() => _BulkUserScreenState();
}

class _BulkUserScreenState extends ConsumerState<BulkUserScreen> {
  List<UserBulkRow> _rows = [];
  UserBulkValidation? _validation;
  final Set<int> _pendingRows = {};
  String? _selectedFileName;
  bool _working = false;
  int _mappingRevision = 0;

  Future<void> _downloadTemplate() async {
    await _run(() async {
      final file = await ref
          .read(bulkUserSpreadsheetServiceProvider)
          .saveTemplate();
      await OpenFilex.open(file.path);
      if (mounted) {
        _message(
          'Die Vorlage wurde gespeichert und mit der verfügbaren Excel-App geöffnet.',
        );
      }
    });
  }

  Future<void> _chooseImport() async {
    const xlsx = XTypeGroup(
      label: 'Excel-Arbeitsmappe',
      extensions: ['xlsx'],
      uniformTypeIdentifiers: ['org.openxmlformats.spreadsheetml.sheet'],
    );
    final file = await openFile(acceptedTypeGroups: const [xlsx]);
    if (file == null || !mounted) return;

    await _run(() async {
      final rows = ref
          .read(bulkUserSpreadsheetServiceProvider)
          .parse(await file.readAsBytes());
      await _validateRows(rows, fileName: file.name);
    });
  }

  Future<void> _recheckImport() async {
    await _run(() => _validateRows(_rows));
  }

  Future<void> _validateRows(List<UserBulkRow> rows, {String? fileName}) async {
    final checked = ref
        .read(bulkUserSpreadsheetServiceProvider)
        .revalidate(rows);
    final server = await ref.read(userRepositoryProvider).validateBulk(checked);
    final merged = _mergeLocalErrors(server, checked);
    if (!mounted) return;
    setState(() {
      _rows = checked;
      _validation = merged;
      _pendingRows.clear();
      _mappingRevision++;
      if (fileName != null) _selectedFileName = fileName;
    });
  }

  void _updateRow(int rowNumber, UserBulkRow Function(UserBulkRow row) update) {
    setState(() {
      _rows = [
        for (final row in _rows)
          if (row.rowNumber == rowNumber) update(row) else row,
      ];
      _pendingRows.add(rowNumber);
    });
  }

  Future<void> _applyImport() async {
    final validation = _validation;
    if (validation == null ||
        !validation.valid ||
        _rows.isEmpty ||
        _pendingRows.isNotEmpty) {
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: '${_rows.length} Accounts erstellen?',
      message:
          'Alle geprüften Accounts werden gemeinsam erstellt. Wenn eine Zeile inzwischen ungültig ist, wird kein Account aus der Datei angelegt.',
      confirmLabel: 'Accounts erstellen',
    );
    if (!confirmed || !mounted) return;

    await _run(() async {
      final result = await ref.read(userRepositoryProvider).applyBulk(_rows);
      if (!mounted) return;
      if (!result.applied) {
        setState(() => _validation = _mergeLocalErrors(result, _rows));
        _message('Die Datei enthält noch Fehler und wurde nicht angewendet.');
        return;
      }
      _message('${result.appliedCount} Accounts wurden erstellt.');
      Navigator.of(context).pop(true);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _message(
          error is FormatException
              ? error.message
              : userErrorMessage(
                  error,
                  fallback: 'Die Excel-Aktion konnte nicht ausgeführt werden.',
                ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validation = _validation;
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts per Excel importieren')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '1. Excel-Vorlage',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Die Vorlage zeigt genau die sieben Importspalten und je ein ausgefülltes Beispiel für Sanitäter, Sani-Leitung, Lehreraufsicht und Sekretariat.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _downloadTemplate,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Beispielvorlage öffnen'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '2. Import, Mapping und Prüfung',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nach dem Hochladen kannst du jede Angabe direkt in der Tabelle korrigieren. Geänderte Zeilen müssen vor dem Erstellen erneut geprüft werden. Fehlerhafte Zeilen sind rot markiert.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _working ? null : _chooseImport,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Excel-Datei auswählen'),
                  ),
                  if (_selectedFileName != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _selectedFileName!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (validation != null) ...[
                    const SizedBox(height: 14),
                    _ValidationSummary(
                      validation: validation,
                      pendingCount: _pendingRows.length,
                    ),
                    const SizedBox(height: 12),
                    _MappedAccountTable(
                      rows: _rows,
                      validation: validation,
                      pendingRows: _pendingRows,
                      enabled: !_working,
                      mappingRevision: _mappingRevision,
                      onChanged: _updateRow,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _working ? null : _recheckImport,
                      icon: const Icon(Icons.refresh_outlined),
                      label: Text(
                        _pendingRows.isEmpty
                            ? 'Prüfung erneut durchführen'
                            : 'Änderungen prüfen',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed:
                          !_working && validation.valid && _pendingRows.isEmpty
                          ? _applyImport
                          : null,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Geprüfte Accounts erstellen'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_working) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  UserBulkValidation _mergeLocalErrors(
    UserBulkValidation server,
    List<UserBulkRow> rows,
  ) {
    final localByNumber = {
      for (final row in rows) row.rowNumber: row.localErrors,
    };
    final mergedRows = [
      for (final row in server.rows)
        UserBulkValidationRow(
          rowNumber: row.rowNumber,
          action: row.action,
          targetUserId: row.targetUserId,
          displayName: row.displayName,
          valid:
              row.valid && (localByNumber[row.rowNumber] ?? const []).isEmpty,
          errors: <String>{
            ...(localByNumber[row.rowNumber] ?? const []),
            ...row.errors,
          }.toList(),
        ),
    ];
    return UserBulkValidation(
      valid: server.valid && mergedRows.every((row) => row.valid),
      applied: server.applied,
      appliedCount: server.appliedCount,
      rows: mergedRows,
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({
    required this.validation,
    required this.pendingCount,
  });

  final UserBulkValidation validation;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final validCount = validation.rows.where((row) => row.valid).length;
    final scheme = Theme.of(context).colorScheme;
    final needsReview = pendingCount > 0;
    final valid = validation.valid && !needsReview;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: valid
            ? scheme.primaryContainer
            : needsReview
            ? scheme.tertiaryContainer
            : scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        needsReview
            ? '$pendingCount geänderte Zeile(n) müssen noch geprüft werden.'
            : validation.valid
            ? 'Alle $validCount Zeilen sind gültig.'
            : '$validCount von ${validation.rows.length} Zeilen sind gültig. Fehlerhafte Zeilen werden nicht angewendet.',
        style: TextStyle(
          color: valid
              ? scheme.onPrimaryContainer
              : needsReview
              ? scheme.onTertiaryContainer
              : scheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MappedAccountTable extends StatelessWidget {
  const _MappedAccountTable({
    required this.rows,
    required this.validation,
    required this.pendingRows,
    required this.enabled,
    required this.mappingRevision,
    required this.onChanged,
  });

  final List<UserBulkRow> rows;
  final UserBulkValidation validation;
  final Set<int> pendingRows;
  final bool enabled;
  final int mappingRevision;
  final void Function(int rowNumber, UserBulkRow Function(UserBulkRow row))
  onChanged;

  @override
  Widget build(BuildContext context) {
    final resultByNumber = {
      for (final result in validation.rows) result.rowNumber: result,
    };
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12,
          horizontalMargin: 8,
          headingRowColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          columns: const [
            DataColumn(label: Text('Zeile')),
            DataColumn(label: Text('Vorname')),
            DataColumn(label: Text('Nachname')),
            DataColumn(label: Text('Benutzername')),
            DataColumn(label: Text('Schul-E-Mail')),
            DataColumn(label: Text('Startpasswort')),
            DataColumn(label: Text('Rolle')),
            DataColumn(label: Text('Startdatum')),
            DataColumn(label: Text('Prüfung')),
          ],
          rows: [
            for (final row in rows)
              _dataRow(context, row, resultByNumber[row.rowNumber]),
          ],
        ),
      ),
    );
  }

  DataRow _dataRow(
    BuildContext context,
    UserBulkRow row,
    UserBulkValidationRow? result,
  ) {
    final pending = pendingRows.contains(row.rowNumber);
    final invalid = result != null && !result.valid && !pending;
    final scheme = Theme.of(context).colorScheme;
    return DataRow(
      color: WidgetStatePropertyAll(
        invalid
            ? scheme.errorContainer.withValues(alpha: 0.72)
            : pending
            ? scheme.tertiaryContainer.withValues(alpha: 0.55)
            : null,
      ),
      cells: [
        DataCell(Text('${row.rowNumber}')),
        DataCell(_textField(row, row.firstName, 'firstName')),
        DataCell(_textField(row, row.lastName, 'lastName')),
        DataCell(_textField(row, row.username, 'username')),
        DataCell(_textField(row, row.email, 'email')),
        DataCell(
          _textField(
            row,
            row.temporaryPassword,
            'temporaryPassword',
            obscureText: true,
          ),
        ),
        DataCell(_roleField(row)),
        DataCell(_startDateField(row)),
        DataCell(_status(context, result, pending)),
      ],
    );
  }

  Widget _textField(
    UserBulkRow row,
    String value,
    String field, {
    bool obscureText = false,
  }) {
    return SizedBox(
      width: field == 'email' ? 210 : 145,
      child: TextFormField(
        key: ValueKey('$mappingRevision-${row.rowNumber}-$field'),
        initialValue: value,
        enabled: enabled,
        obscureText: obscureText,
        enableSuggestions: !obscureText,
        autocorrect: false,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onChanged: (newValue) => onChanged(
          row.rowNumber,
          (current) => switch (field) {
            'firstName' => current.copyWith(firstName: newValue.trim()),
            'lastName' => current.copyWith(lastName: newValue.trim()),
            'username' => current.copyWith(username: newValue.trim()),
            'email' => current.copyWith(email: newValue.trim().toLowerCase()),
            _ => current.copyWith(temporaryPassword: newValue),
          },
        ),
      ),
    );
  }

  Widget _roleField(UserBulkRow row) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        initialValue:
            const {
              'sanitaeter',
              'sani_leitung',
              'teacher',
              'sekretariat',
            }.contains(row.role)
            ? row.role
            : null,
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'sanitaeter', child: Text('Sanitäter')),
          DropdownMenuItem(value: 'sani_leitung', child: Text('Sani-Leitung')),
          DropdownMenuItem(value: 'teacher', child: Text('Lehreraufsicht')),
          DropdownMenuItem(value: 'sekretariat', child: Text('Sekretariat')),
        ],
        onChanged: !enabled
            ? null
            : (role) {
                if (role == null) return;
                onChanged(
                  row.rowNumber,
                  (current) => current.copyWith(
                    role: role,
                    sanitaeterSince: role == 'teacher' || role == 'sekretariat'
                        ? ''
                        : current.sanitaeterSince,
                  ),
                );
              },
      ),
    );
  }

  Widget _startDateField(UserBulkRow row) {
    return SizedBox(
      width: 135,
      child: TextFormField(
        key: ValueKey('$mappingRevision-${row.rowNumber}-startDate'),
        initialValue: row.startDateForDisplay,
        enabled: enabled,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          hintText: 'DD/MM/YYYY',
        ),
        onChanged: (value) => onChanged(row.rowNumber, (current) {
          if (current.role == 'teacher' || current.role == 'sekretariat') {
            return current.copyWith(sanitaeterSince: '');
          }
          final match = RegExp(
            r'^(\d{2})/(\d{2})/(\d{4})$',
          ).firstMatch(value.trim());
          return current.copyWith(
            sanitaeterSince: match == null
                ? value.trim()
                : '${match.group(3)}-${match.group(2)}-${match.group(1)}',
          );
        }),
      ),
    );
  }

  Widget _status(
    BuildContext context,
    UserBulkValidationRow? result,
    bool pending,
  ) {
    final scheme = Theme.of(context).colorScheme;
    if (pending) {
      return SizedBox(
        width: 260,
        child: Text(
          'Änderung noch nicht geprüft',
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
      );
    }
    if (result == null) {
      return const SizedBox(width: 260, child: Text('Nicht geprüft'));
    }
    if (result.valid) {
      return const SizedBox(
        width: 260,
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 6),
            Text('Alle Angaben passen'),
          ],
        ),
      );
    }
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: scheme.error),
              const SizedBox(width: 6),
              const Text('Angaben prüfen'),
            ],
          ),
          for (final error in result.errors)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                error,
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
