class TrainingPlanScheduler {
  const TrainingPlanScheduler._();

  static int suggestedDayNumber({
    required List<int> plannedDays,
    int? lastFinishedDayNumber,
    DateTime? lastFinishedAt,
    required DateTime now,
  }) {
    final sortedDays = plannedDays.toSet().toList()..sort();
    if (sortedDays.isEmpty) {
      return 1;
    }

    if (lastFinishedDayNumber == null) {
      return sortedDays.first;
    }

    if (lastFinishedAt != null) {
      final lastFinishedDay = DateTime(
        lastFinishedAt.year,
        lastFinishedAt.month,
        lastFinishedAt.day,
      );
      final today = DateTime(now.year, now.month, now.day);
      if (lastFinishedDay == today &&
          sortedDays.contains(lastFinishedDayNumber)) {
        return lastFinishedDayNumber;
      }
    }

    for (final dayNumber in sortedDays) {
      if (dayNumber > lastFinishedDayNumber) {
        return dayNumber;
      }
    }

    return sortedDays.first;
  }
}
