import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/api_providers.dart';
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

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;
  final Set<int> _visited = {0};

  static const _screens = [
    DutyScheduleScreen(),
    AnnouncementsScreen(),
    SaniListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(deepLinkControllerProvider);
      if (pending != null) _openDeepLink(pending);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppDeepLink?>(deepLinkControllerProvider, (previous, next) {
      if (next == null) return;
      _openDeepLink(next);
    });

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var index = 0; index < _screens.length; index++)
            if (_visited.contains(index))
              _screens[index]
            else
              const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) {
          setState(() {
            _index = index;
            _visited.add(index);
          });
          _refreshForIndex(index);
        },
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

  void _refreshForIndex(int index) {
    if (index == 0) {
      ref.read(dutyRevisionProvider.notifier).bump();
    } else if (index == 1) {
      ref.read(announcementRevisionProvider.notifier).bump();
      ref.read(pushServiceProvider).clearAnnouncementNotifications();
    } else if (index == 2) {
      ref.read(userRevisionProvider.notifier).bump();
    }
  }

  void _refreshAllData() {
    ref.read(dutyRevisionProvider.notifier).bump();
    ref.read(announcementRevisionProvider.notifier).bump();
    ref.read(userRevisionProvider.notifier).bump();
  }

  void _openDeepLink(AppDeepLink link) {
    final targetIndex = switch (link.route) {
      'announcements' => 1,
      'profile_devices' => 3,
      'duty' => 0,
      _ => _index,
    };
    setState(() {
      _index = targetIndex;
      _visited.add(targetIndex);
    });
    _refreshForIndex(targetIndex);
    ref.read(deepLinkControllerProvider.notifier).consume();
    if (link.route == 'duty' && link.date != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dienst am ${link.date} geöffnet.')),
      );
    }
  }
}
