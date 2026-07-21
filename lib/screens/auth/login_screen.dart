import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../themes/app_colors.dart';
import '../../widgets/app_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).login(
          _identifier.text.trim(),
          _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.status == AuthStatus.checking;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 92)),
                    const SizedBox(height: 24),
                    Text(
                      'Willkommen bei SSD Manager',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Melde dich mit deiner Schul-E-Mail oder deinem Benutzernamen an.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _identifier,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'E-Mail oder Benutzername',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Bitte E-Mail oder Benutzername eingeben.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Passwort',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Passwort anzeigen' : 'Passwort ausblenden',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Bitte Passwort eingeben.' : null,
                    ),
                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        auth.errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : _submit,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Anmelden'),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Accounts werden von der SSD-Leitung oder der Lehreraufsicht erstellt. '
                        'Es gibt keine offene Registrierung.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
