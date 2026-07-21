import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../../providers/api_providers.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_colors.dart';
import '../../widgets/status_views.dart';
import 'user_detail_screen.dart';

class SaniListScreen extends ConsumerStatefulWidget {
  const SaniListScreen({super.key});

  @override
  ConsumerState<SaniListScreen> createState() => _SaniListScreenState();
}

class _SaniListScreenState extends ConsumerState<SaniListScreen> {
  late Future<List<User>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<User>> _load() => ref.read(userRepositoryProvider).users();

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).user;
    final canManage = currentUser?.role.canManageUsers == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Sani-Liste')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => const _CreateUserSheet(),
                );
                await _refresh();
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Account'),
            )
          : null,
      body: FutureBuilder<List<User>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView(message: 'Sani-Liste wird geladen ...');
          }
          if (snapshot.hasError) {
            return ErrorView(message: snapshot.error.toString(), onRetry: _refresh);
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const EmptyView(
              icon: Icons.groups_outlined,
              title: 'Keine Sanis gefunden',
              message: 'Aktive Sanis erscheinen hier, sobald Accounts erstellt wurden.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final user = users[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.lightBlue,
                      foregroundColor: AppColors.primaryBlue,
                      child: Text(user.firstName.isEmpty ? '?' : user.firstName.characters.first),
                    ),
                    title: Text(user.fullName),
                    subtitle: Text('${user.role.label} · ${_statusLabel(user.status)}'),
                    trailing: canManage ? const Icon(Icons.chevron_right) : null,
                    onTap: canManage
                        ? () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => UserDetailScreen(userId: user.id)),
                            );
                            await _refresh();
                          }
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'active' => 'aktiv',
        'inactive' => 'deaktiviert',
        'pending_deletion' => 'Löschung vorgemerkt',
        _ => status,
      };
}

class _CreateUserSheet extends ConsumerStatefulWidget {
  const _CreateUserSheet();

  @override
  ConsumerState<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends ConsumerState<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.sanitaeter;
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).createUser(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            username: _username.text.trim(),
            email: _email.text.trim(),
            temporaryPassword: _password.text,
            role: _role.toJson(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).user;
    final canCreateTeacher = currentUser?.role == UserRole.teacher;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Account erstellen', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _first,
                  decoration: const InputDecoration(labelText: 'Vorname'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _last,
                  decoration: const InputDecoration(labelText: 'Nachname'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Benutzername'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Schul-E-Mail'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Temporäres Startpasswort'),
                  validator: (value) =>
                      value == null || value.length < 10 ? 'Mindestens 10 Zeichen erforderlich.' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Rolle'),
                  items: [
                    const DropdownMenuItem(
                      value: UserRole.sanitaeter,
                      child: Text('Schulsanitäter'),
                    ),
                    if (canCreateTeacher)
                      const DropdownMenuItem(
                        value: UserRole.saniLeitung,
                        child: Text('Sani-Leitung'),
                      ),
                    if (canCreateTeacher)
                      const DropdownMenuItem(
                        value: UserRole.teacher,
                        child: Text('Lehreraufsicht'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _role = value ?? UserRole.sanitaeter),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Account erstellen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Pflichtfeld' : null;
}
