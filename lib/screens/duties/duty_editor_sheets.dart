import 'package:flutter/material.dart';

import '../../models/duty_day.dart';
import '../../repositories/duty_repository.dart';
import '../../utils/date_formatters.dart';
import '../../utils/duty_rules.dart';
import '../../utils/user_error_message.dart';
import '../../widgets/confirm_dialog.dart';

Future<bool> showDutyDayEditor({
  required BuildContext context,
  required DutyRepository repository,
  DutyDay? day,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _DutyDayEditor(repository: repository, day: day),
  );
  return result ?? false;
}

Future<bool> showClosureEditor({
  required BuildContext context,
  required DutyRepository repository,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ClosureEditor(repository: repository),
  );
  return result ?? false;
}

Future<bool> showClosureResetEditor({
  required BuildContext context,
  required DutyRepository repository,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ClosureResetEditor(repository: repository),
  );
  return result ?? false;
}

class _DutyDayEditor extends StatefulWidget {
  const _DutyDayEditor({required this.repository, this.day});

  final DutyRepository repository;
  final DutyDay? day;

  @override
  State<_DutyDayEditor> createState() => _DutyDayEditorState();
}

class _DutyDayEditorState extends State<_DutyDayEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _date;
  late int _capacity;
  late bool _isClosed;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.day != null;

  @override
  void initState() {
    super.initState();
    final day = widget.day;
    _date = day?.date ?? _nextWeekday(DateTime.now());
    _capacity = day?.capacity ?? 3;
    _isClosed = day?.isClosed ?? false;
    _titleController = TextEditingController(text: day?.title);
    _descriptionController = TextEditingController(text: day?.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Diensttag bearbeiten' : 'Diensttag hinzufügen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              _isEditing
                  ? 'Passe den Namen, die Beschreibung und die benötigte Besetzung an.'
                  : 'Lege einen zusätzlichen Schultag mit allen Dienstplanangaben an.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            _DateField(
              label: 'Datum',
              date: _date,
              enabled: !_isEditing && !_saving,
              onTap: _pickDate,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleController,
              enabled: !_saving,
              maxLength: 180,
              decoration: InputDecoration(
                labelText: _isClosed
                    ? 'Name des Ausfalls'
                    : 'Name des Tages (optional)',
                hintText: _isClosed ? 'z. B. Feiertag' : 'z. B. Sportfest',
              ),
              validator: (value) {
                if (_isClosed && (value == null || value.trim().isEmpty)) {
                  return 'Bitte gib dem Ausfall einen Namen.';
                }
                return null;
              },
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _descriptionController,
              enabled: !_saving,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Beschreibung (optional)',
                hintText: 'Hinweise, die alle Sanis sehen sollen',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: _capacity,
              decoration: const InputDecoration(
                labelText: 'Benötigte Sanis',
                prefixIcon: Icon(Icons.groups_2_outlined),
              ),
              items: [
                for (var value = 1; value <= 20; value++)
                  DropdownMenuItem(value: value, child: Text('$value')),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _capacity = value);
                    },
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tag fällt aus'),
                subtitle: const Text(
                  'Ausfalltage werden rot markiert und können nicht belegt werden.',
                ),
                value: _isClosed,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isClosed = value),
              ),
              if (widget.day!.isClosed ||
                  widget.day!.title != null ||
                  widget.day!.description != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _resetDay,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Besonderen Eintrag entfernen'),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Speichern'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 3, 12, 31),
      helpText: 'DIENSTTAG AUSWÄHLEN',
      cancelText: 'ABBRECHEN',
      confirmText: 'ÜBERNEHMEN',
      selectableDayPredicate: (date) => !DutyRules.isWeekend(date),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showConfirmDialog(
      context,
      title: _isEditing ? 'Änderungen speichern?' : 'Diensttag anlegen?',
      message: _isEditing
          ? 'Die Änderungen sind anschließend für alle Nutzer sichtbar.'
          : 'Der neue Diensttag wird für alle Nutzer sichtbar.',
      confirmLabel: 'Speichern',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEditing) {
        await widget.repository.updateDay(
          date: _date,
          capacity: _capacity,
          isClosed: _isClosed,
          title: _titleController.text,
          description: _descriptionController.text,
        );
      } else {
        await widget.repository.createDay(
          date: _date,
          capacity: _capacity,
          title: _titleController.text,
          description: _descriptionController.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userErrorMessage(error);
        });
      }
    }
  }

  Future<void> _resetDay() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Tag zurücksetzen?',
      message:
          'Name, Beschreibung und Ausfallmarkierung werden entfernt. Bestehende Sani-Eintragungen bleiben erhalten.',
      confirmLabel: 'Zurücksetzen',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.resetDay(_date);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userErrorMessage(error);
        });
      }
    }
  }
}

class _ClosureEditor extends StatefulWidget {
  const _ClosureEditor({required this.repository});

  final DutyRepository repository;

  @override
  State<_ClosureEditor> createState() => _ClosureEditorState();
}

class _ClosureEditorState extends State<_ClosureEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late DateTimeRange _range;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final date = _nextWeekday(DateTime.now());
    _range = DateTimeRange(start: date, end: date);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ausfall oder Ferien eintragen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Wähle einen einzelnen Tag oder einen längeren Zeitraum. Wochenenden werden automatisch ausgelassen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            _DateRangeField(range: _range, onTap: _pickRange),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              maxLength: 180,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'z. B. Herbstferien oder Pfingstmontag',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Bitte gib dem Ausfall einen Namen.'
                  : null,
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _descriptionController,
              enabled: !_saving,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Beschreibung (optional)',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Eintragen'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final today = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(today.year - 1, 1, 1),
      lastDate: DateTime(today.year + 3, 12, 31),
      helpText: 'AUSFALLZEITRAUM AUSWÄHLEN',
      cancelText: 'ABBRECHEN',
      confirmText: 'ÜBERNEHMEN',
      saveText: 'ÜBERNEHMEN',
    );
    if (selected != null) setState(() => _range = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Ausfall eintragen?',
      message:
          'Alle Schultage im gewählten Zeitraum werden als Ausfall markiert und können nicht belegt werden.',
      confirmLabel: 'Eintragen',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createClosureRange(
        startDate: _range.start,
        endDate: _range.end,
        name: _nameController.text,
        description: _descriptionController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userErrorMessage(error);
        });
      }
    }
  }
}

class _ClosureResetEditor extends StatefulWidget {
  const _ClosureResetEditor({required this.repository});

  final DutyRepository repository;

  @override
  State<_ClosureResetEditor> createState() => _ClosureResetEditorState();
}

class _ClosureResetEditorState extends State<_ClosureResetEditor> {
  late DateTimeRange _range;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final date = _nextWeekday(DateTime.now());
    _range = DateTimeRange(start: date, end: date);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ausfall oder Ferien aufheben',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Wähle den zuvor eingetragenen Tag oder Zeitraum. Wochenenden werden automatisch ausgelassen.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          _DateRangeField(range: _range, onTap: _pickRange),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Aufheben'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickRange() async {
    final today = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(today.year - 1, 1, 1),
      lastDate: DateTime(today.year + 3, 12, 31),
      helpText: 'AUSFALLZEITRAUM AUSWÄHLEN',
      cancelText: 'ABBRECHEN',
      confirmText: 'ÜBERNEHMEN',
      saveText: 'ÜBERNEHMEN',
    );
    if (selected != null) setState(() => _range = selected);
  }

  Future<void> _submit() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Ausfall aufheben?',
      message:
          'Die Ausfallmarkierung wird für alle betroffenen Schultage entfernt.',
      confirmLabel: 'Aufheben',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.resetClosureRange(
        startDate: _range.start,
        endDate: _range.end,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userErrorMessage(error);
        });
      }
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_month_outlined),
          suffixIcon: enabled ? const Icon(Icons.arrow_drop_down) : null,
          enabled: enabled,
        ),
        child: Text(
          '${DateFormatters.dutyWeekday(date)}, ${DateFormatters.dutyDate(date)}',
        ),
      ),
    );
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({required this.range, required this.onTap});

  final DateTimeRange range;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sameDay =
        range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day;
    final value = sameDay
        ? DateFormatters.dutyDate(range.start)
        : '${DateFormatters.dutyDate(range.start)} – ${DateFormatters.dutyDate(range.end)}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Tag oder Zeitraum',
          prefixIcon: Icon(Icons.date_range_outlined),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(value),
      ),
    );
  }
}

DateTime _nextWeekday(DateTime value) {
  var date = DateTime(value.year, value.month, value.day);
  while (DutyRules.isWeekend(date)) {
    date = date.add(const Duration(days: 1));
  }
  return date;
}
