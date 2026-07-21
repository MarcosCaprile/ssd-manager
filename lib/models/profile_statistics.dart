class ProfileStatistics {
  const ProfileStatistics({
    required this.completedCount,
    required this.upcomingCount,
    required this.sickCount,
    required this.completedDates,
    required this.upcomingDates,
  });

  final int completedCount;
  final int upcomingCount;
  final int sickCount;
  final List<DateTime> completedDates;
  final List<DateTime> upcomingDates;

  factory ProfileStatistics.fromJson(Map<String, dynamic> json) {
    List<DateTime> parseDates(String key) => ((json[key] ?? []) as List<dynamic>)
        .map((value) => DateTime.parse(value as String))
        .toList();

    return ProfileStatistics(
      completedCount: ((json['completed_count'] ?? 0) as num).toInt(),
      upcomingCount: ((json['upcoming_count'] ?? 0) as num).toInt(),
      sickCount: ((json['sick_count'] ?? 0) as num).toInt(),
      completedDates: parseDates('completed_dates'),
      upcomingDates: parseDates('upcoming_dates'),
    );
  }
}
