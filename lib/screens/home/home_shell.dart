import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(pushServiceProvider).setAnnouncementsVisible(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateAnnouncementVisibility();
      _syncAnnouncementUnreadCount();
      final pending = ref.read(deepLinkControllerProvider);
      if (pending != null) _openDeepLink(pending);
    });
  }

  @override
  void dispose() {
    ref.read(pushServiceProvider).setAnnouncementsVisible(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _updateAnnouncementVisibility();
    if (state == AppLifecycleState.resumed) {
      unawaited(_updatePushTokenSafely());
      _refreshAllData();
      if (_index == 1) {
        ref.read(announcementUnreadProvider.notifier).clear();
      } else {
        _syncAnnouncementUnreadCount();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppDeepLink?>(deepLinkControllerProvider, (previous, next) {
      if (next == null) return;
      _openDeepLink(next);
    });
    final unreadAnnouncements = ref.watch(announcementUnreadProvider);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          if (_visited.contains(0))
            DutyScheduleScreen(active: _index == 0)
          else
            const SizedBox.shrink(),
          if (_visited.contains(1))
            AnnouncementsScreen(active: _index == 1)
          else
            const SizedBox.shrink(),
          if (_visited.contains(2))
            SaniListScreen(active: _index == 2)
          else
            const SizedBox.shrink(),
          if (_visited.contains(3))
            const ProfileScreen()
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
          _updateAnnouncementVisibility();
          _refreshForIndex(index);
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Dienstplan',
          ),
          BottomNavigationBarItem(
            icon: _AnnouncementNavigationIcon(
              icon: Icons.campaign_outlined,
              unreadCount: unreadAnnouncements,
            ),
            activeIcon: _AnnouncementNavigationIcon(
              icon: Icons.campaign,
              unreadCount: unreadAnnouncements,
            ),
            label: 'Ankündigungen',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'Sani-Liste',
          ),
          const BottomNavigationBarItem(
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
      ref.read(announcementUnreadProvider.notifier).clear();
    } else if (index == 2) {
      ref.read(userRevisionProvider.notifier).bump();
    }
  }

  void _refreshAllData() {
    ref.read(dutyRevisionProvider.notifier).bump();
    ref.read(announcementRevisionProvider.notifier).bump();
    ref.read(userRevisionProvider.notifier).bump();
  }

  void _updateAnnouncementVisibility() {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    ref
        .read(pushServiceProvider)
        .setAnnouncementsVisible(isForeground && _index == 1);
  }

  Future<void> _syncAnnouncementUnreadCount() async {
    final count = await ref.read(pushServiceProvider).announcementUnreadCount();
    if (!mounted) return;
    ref.read(announcementUnreadProvider.notifier).setCount(count);
  }

  Future<void> _updatePushTokenSafely() async {
    try {
      await ref.read(authRepositoryProvider).updatePushToken();
    } catch (_) {
      // Login and the next foreground resume retry token registration.
    }
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
    _updateAnnouncementVisibility();
    _refreshForIndex(targetIndex);
    ref.read(deepLinkControllerProvider.notifier).consume();
    if (link.route == 'duty' && link.date != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dienst am ${link.date} geöffnet.')),
      );
    }
  }
}

class _AnnouncementNavigationIcon extends StatelessWidget {
  const _AnnouncementNavigationIcon({
    required this.icon,
    required this.unreadCount,
  });

  final IconData icon;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Badge.count(
      count: unreadCount,
      isLabelVisible: unreadCount > 0,
      backgroundColor: Theme.of(context).colorScheme.error,
      textColor: Theme.of(context).colorScheme.onError,
      child: Icon(icon),
    );
  }
}
