import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const infoEmail = 'info@ssd-manager.minutmate.com';
  static const supportEmail = 'support@ssd-manager.minutmate.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kontakt und Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('SSD Manager', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Für neue Schulen, allgemeine Fragen und die manuelle Freischaltung einer Schulumgebung:',
          ),
          const SizedBox(height: 8),
          _EmailTile(label: 'Allgemeiner Kontakt', email: infoEmail),
          const SizedBox(height: 12),
          const Text('Für technische Probleme mit der App:'),
          const SizedBox(height: 8),
          _EmailTile(label: 'Support', email: supportEmail),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Account-, Auskunfts- und Löschanfragen werden durch die zuständige Schule geprüft. Bitte sende keine Passwörter, Krankheitsgründe oder Patientendaten per E-Mail.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailTile extends StatelessWidget {
  const _EmailTile({required this.label, required this.email});

  final String label;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: SelectableText(email),
        trailing: IconButton(
          tooltip: 'Adresse kopieren',
          icon: const Icon(Icons.copy_outlined),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: email));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('E-Mail-Adresse wurde kopiert.')),
              );
            }
          },
        ),
      ),
    );
  }
}
