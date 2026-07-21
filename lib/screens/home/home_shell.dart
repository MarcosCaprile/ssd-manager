import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/deep_link_provider.dart';
import '../announcements/announcements_screen.dart';
import '../duties/duty_schedule_screen.dart';
import '../profile/profile_screen.dart';
import '../users/sani_list_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _screens = [
    DutyScheduleScreen(),
    AnnouncementsScreen(),
    SaniListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    ref.listen<AppDeepLink?>(deepLinkControllerProvider, (previous, next) {
      if (next == null) return;
      final targetIndex = switch (next.route) {
        'announcements' => 1,
        'profile_devices' => 3,
        'duty' => 0,
        _ => _index,
      };
      setState(() => _index = targetIndex);
      ref.read(deepLinkControllerProvider.notifier).consume();
      if (next.route == 'duty' && next.date != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dienst am ${next.date} geöffnet.')),
        );
      }
    });

    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Dienstplan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign),
            label: 'Ankündigungen',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'Sani-Liste',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
