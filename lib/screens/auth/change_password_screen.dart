import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../themes/app_colors.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key, required this.forceChange});

  final bool forceChange;

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _revokeOthers = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
            revokeOtherDevices: _revokeOthers,
          );
      if (mounted && !widget.forceChange) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwort wurde geändert.')),
        );
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Passwort ändern',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.forceChange
                    ? 'Bitte ändere dein Startpasswort, bevor du die App weiter nutzt.'
                    : 'Wähle ein neues Passwort für deinen Account.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Aktuelles Passwort'),
                validator: (value) => value == null || value.isEmpty ? 'Bitte aktuelles Passwort eingeben.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _new,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Neues Passwort'),
                validator: (value) {
                  if (value == null || value.length < 10) {
                    return 'Das neue Passwort muss mindestens 10 Zeichen haben.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _repeat,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Neues Passwort wiederholen'),
                validator: (value) => value != _new.text ? 'Die Passwörter stimmen nicht überein.' : null,
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: _revokeOthers,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) => setState(() => _revokeOthers = value ?? true),
                title: const Text('Alle anderen Geräte abmelden'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Passwort speichern'),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.forceChange) {
      return Scaffold(body: content);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Passwort ändern')),
      body: content,
    );
  }
}
