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
  String? _selectedFileName;
  bool _working = false;

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
      final server = await ref.read(userRepositoryProvider).validateBulk(rows);
      final merged = _mergeLocalErrors(server, rows);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _validation = merged;
        _selectedFileName = file.name;
      });
    });
  }

  Future<void> _applyImport() async {
    final validation = _validation;
    if (validation == null || !validation.valid || _rows.isEmpty) return;
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
                    '2. Import und Prüfung',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Jede ausgefüllte Zeile erstellt einen neuen Account. Startdatum wird für Sanitäter und Sani-Leitung als DD/MM/YYYY angegeben, bei Lehreraufsicht und Sekretariat als N/A. Die Datei wird vollständig geprüft; Teilimporte sind ausgeschlossen.',
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
                  if (_validation != null) ...[
                    const SizedBox(height: 14),
                    _ValidationSummary(validation: _validation!),
                    const SizedBox(height: 8),
                    for (final row in _validation!.rows)
                      _ValidationRowTile(row: row),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: !_working && _validation!.valid
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
  const _ValidationSummary({required this.validation});

  final UserBulkValidation validation;

  @override
  Widget build(BuildContext context) {
    final validCount = validation.rows.where((row) => row.valid).length;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: validation.valid
            ? scheme.primaryContainer
            : scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        validation.valid
            ? 'Alle $validCount Zeilen sind gültig.'
            : '$validCount von ${validation.rows.length} Zeilen sind gültig. Fehlerhafte Zeilen werden nicht angewendet.',
        style: TextStyle(
          color: validation.valid
              ? scheme.onPrimaryContainer
              : scheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ValidationRowTile extends StatelessWidget {
  const _ValidationRowTile({required this.row});

  final UserBulkValidationRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: Icon(
        row.valid ? Icons.check_circle_outline : Icons.error_outline,
        color: row.valid ? Colors.green : scheme.error,
      ),
      title: Text('Zeile ${row.rowNumber}: Neuer Account'),
      subtitle: Text(
        row.displayName.isEmpty ? 'Keine Person erkannt' : row.displayName,
      ),
      childrenPadding: const EdgeInsets.only(left: 40, bottom: 10),
      children: row.errors.isEmpty
          ? const [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Alle Angaben sind plausibel.'),
              ),
            ]
          : [
              for (final error in row.errors)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $error',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ),
            ],
    );
  }
}
