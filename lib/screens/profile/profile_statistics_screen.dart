import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile_statistics.dart';
import '../../providers/api_providers.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/status_views.dart';

class ProfileStatisticsScreen extends ConsumerStatefulWidget {
  const ProfileStatisticsScreen({super.key});

  @override
  ConsumerState<ProfileStatisticsScreen> createState() =>
      _ProfileStatisticsScreenState();
}

class _ProfileStatisticsScreenState
    extends ConsumerState<ProfileStatisticsScreen> {
  late Future<ProfileStatistics> _future;
  ProfileStatistics? _cachedStatistics;

  @override
  void initState() {
    super.initState();
    _future = _loadInitial();
  }

  Future<ProfileStatistics> _fetch() {
    return ref.read(userRepositoryProvider).myStatistics();
  }

  Future<ProfileStatistics> _loadInitial() async {
    final statistics = await _fetch();
    _cachedStatistics = statistics;
    return statistics;
  }

  Future<void> _refresh() async {
    if (_cachedStatistics != null) {
      await _refreshPreservingContent();
      return;
    }
    final next = _loadInitial();
    setState(() => _future = next);
    await next;
  }

  Future<void> _refreshPreservingContent() async {
    try {
      final next = await _fetch();
      if (mounted) setState(() => _cachedStatistics = next);
    } catch (_) {
      // Bereits sichtbare Statistiken bleiben bei einem kurzen
      // Verbindungsproblem erhalten.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(dutyRevisionProvider, (previous, next) {
      if (previous != next) _refreshPreservingContent();
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Dienststatistik')),
      body: FutureBuilder<ProfileStatistics>(
        future: _future,
        builder: (context, snapshot) {
          final stats = _cachedStatistics ?? snapshot.data;
          if (stats == null) {
            if (snapshot.hasError) {
              return ErrorView(error: snapshot.error, onRetry: _refresh);
            }
            return const DelayedLoadingView(
              message: 'Dienststatistik wird geladen ...',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Übersicht',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tatsächlich absolvierte Dienste: ${stats.completedCount}',
                        ),
                        Text(
                          'Zukünftige geplante Dienste: ${stats.upcomingCount}',
                        ),
                        Text('Krankmeldungen: ${stats.sickCount}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _DateCard(
                  title: 'Zukünftige Dienste',
                  dates: stats.upcomingDates,
                  emptyText: 'Keine geplanten Dienste vorhanden.',
                ),
                const SizedBox(height: 12),
                _DateCard(
                  title: 'Absolvierte Dienste',
                  dates: stats.completedDates,
                  emptyText:
                      'Du hast bisher noch keinen SSD-Dienst absolviert.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.title,
    required this.dates,
    required this.emptyText,
  });

  final String title;
  final List<DateTime> dates;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (dates.isEmpty)
              Text(emptyText)
            else
              for (final date in dates) Text(DateFormatters.dutyDate(date)),
          ],
        ),
      ),
    );
  }
}
