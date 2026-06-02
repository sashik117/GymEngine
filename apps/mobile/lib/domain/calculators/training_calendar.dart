import '../models/analytics_snapshot.dart';

class TrainingCalendar {
  const TrainingCalendar._();

  static DateTime startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  static int weekNumber(DateTime date) {
    final yearStart = DateTime(date.year);
    final dayOfYear = date.difference(yearStart).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  static List<DateTime> uniqueTrainingDates(Iterable<DateTime> dates) {
    final normalized = {
      for (final date in dates) DateTime(date.year, date.month, date.day),
    }.toList()..sort((a, b) => b.compareTo(a));
    return normalized;
  }

  static int totalTrainingSeconds(
    List<LoggedWorkoutSession> sessions, {
    required DateTime now,
  }) {
    return sessions.fold<int>(0, (sum, session) {
      final finishedAt = session.finishedAt ?? now;
      if (finishedAt.isBefore(session.startedAt)) {
        return sum;
      }

      return sum + finishedAt.difference(session.startedAt).inSeconds;
    });
  }

  static int currentStreakDays(
    List<TrainingDaySummary> trainingDays,
    DateTime now,
  ) {
    if (trainingDays.isEmpty) {
      return 0;
    }

    final trainedDates = {
      for (final day in trainingDays)
        DateTime(day.date.year, day.date.month, day.date.day),
    };
    var cursor = DateTime(now.year, now.month, now.day);
    if (!trainedDates.contains(cursor)) {
      final yesterday = cursor.subtract(const Duration(days: 1));
      if (!trainedDates.contains(yesterday)) {
        return 0;
      }
      cursor = yesterday;
    }

    var streak = 0;
    while (trainedDates.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

class LoggedWorkoutSession {
  const LoggedWorkoutSession({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    this.templateName,
    this.templateDayNumber,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String? templateName;
  final int? templateDayNumber;
}
