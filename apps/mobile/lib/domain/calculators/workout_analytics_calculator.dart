import '../models/analytics_snapshot.dart';
import '../models/dashboard_snapshot.dart';
import 'exercise_muscle_classifier.dart';
import 'training_calendar.dart';

class WorkoutAnalyticsCalculator {
  const WorkoutAnalyticsCalculator._();

  static DashboardSnapshot dashboard({
    required DateTime now,
    required List<LoggedWorkoutSession> sessions,
    required List<LoggedWorkoutSet> sets,
  }) {
    final weekStart = TrainingCalendar.startOfWeek(now);
    final weekVolumeKg = sets
        .where((set) => !set.loggedAt.isBefore(weekStart))
        .fold<double>(0, (sum, set) => sum + set.volumeKg);
    final orderedSets = [...sets]
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

    return DashboardSnapshot(
      weekNumber: TrainingCalendar.weekNumber(now),
      weekVolumeKg: weekVolumeKg,
      sessionCount: sessions
          .where((session) => session.finishedAt != null)
          .length,
      lastExerciseName: orderedSets.isEmpty
          ? null
          : orderedSets.first.exerciseName,
      recentTrainingDates: TrainingCalendar.uniqueTrainingDates(
        orderedSets.map((set) => set.loggedAt),
      ),
    );
  }

  static AnalyticsSnapshot analytics({
    required DateTime now,
    required List<LoggedWorkoutSet> sets,
    required List<LoggedWorkoutSession> sessions,
    required List<ExerciseMuscleRef> exercises,
  }) {
    if (sets.isEmpty) {
      return const AnalyticsSnapshot.empty();
    }

    final rangeStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final totalVolumeKg = sets.fold<double>(
      0,
      (sum, set) => sum + set.volumeKg,
    );
    final bestEstimatedOneRepMaxKg = sets
        .map((set) => set.estimatedOneRepMaxKg)
        .reduce((best, current) => current > best ? current : best);
    final heaviestSetKg = sets
        .map((set) => set.weightKg)
        .reduce((best, current) => current > best ? current : best);
    final dailyVolumes = [
      for (var index = 0; index < 7; index += 1)
        _dailyVolume(sets, rangeStart.add(Duration(days: index))),
    ];
    final trainingDays = buildTrainingDaySummaries(sets, sessions, exercises);
    final weekStart = TrainingCalendar.startOfWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 7));

    return AnalyticsSnapshot(
      totalVolumeKg: totalVolumeKg,
      bestEstimatedOneRepMaxKg: bestEstimatedOneRepMaxKg,
      heaviestSetKg: heaviestSetKg,
      totalSets: sets.length,
      dailyVolumes: dailyVolumes,
      muscleVolumes: buildMuscleVolumes(sets, exercises),
      exerciseStats: buildExerciseStats(sets, exercises: exercises),
      trainingDates: TrainingCalendar.uniqueTrainingDates(
        sets.map((set) => set.loggedAt),
      ),
      trainingDays: trainingDays,
      weeklyWorkoutCount: trainingDays
          .where(
            (day) =>
                !day.date.isBefore(weekStart) && day.date.isBefore(weekEnd),
          )
          .length,
      totalTrainingSeconds: TrainingCalendar.totalTrainingSeconds(
        sessions,
        now: now,
      ),
      currentStreakDays: TrainingCalendar.currentStreakDays(trainingDays, now),
    );
  }

  static List<MuscleVolume> buildMuscleVolumes(
    List<LoggedWorkoutSet> sets,
    List<ExerciseMuscleRef> exercises,
  ) {
    final exerciseMusclesById = {
      for (final exercise in exercises) exercise.id: exercise.primaryMuscle,
    };
    final exerciseMusclesByName = {
      for (final exercise in exercises) exercise.name: exercise.primaryMuscle,
    };
    final muscleTotals = <String, double>{};
    final muscleSetCounts = <String, int>{};

    for (final set in sets) {
      final rawMuscle =
          (set.exerciseId == null
              ? null
              : exerciseMusclesById[set.exerciseId]) ??
          exerciseMusclesByName[set.exerciseName];
      final muscle = ExerciseMuscleClassifier.classify(
        exerciseName: set.exerciseName,
        rawMuscle: rawMuscle,
      );
      muscleTotals[muscle] = (muscleTotals[muscle] ?? 0) + set.volumeKg;
      muscleSetCounts[muscle] = (muscleSetCounts[muscle] ?? 0) + 1;
    }

    return [
      for (final entry in muscleTotals.entries)
        MuscleVolume(
          muscle: entry.key,
          volumeKg: entry.value,
          setCount: muscleSetCounts[entry.key] ?? 0,
        ),
    ]..sort((a, b) {
      final setCompare = b.setCount.compareTo(a.setCount);
      if (setCompare != 0) {
        return setCompare;
      }
      return b.volumeKg.compareTo(a.volumeKg);
    });
  }

  static List<ExerciseWeightStats> buildExerciseStats(
    List<LoggedWorkoutSet> sets, {
    bool sortByFirstLoggedAt = false,
    List<ExerciseMuscleRef> exercises = const [],
  }) {
    final exerciseMusclesById = {
      for (final exercise in exercises) exercise.id: exercise.primaryMuscle,
    };
    final exerciseMusclesByName = {
      for (final exercise in exercises) exercise.name: exercise.primaryMuscle,
    };
    final buckets = <String, List<LoggedWorkoutSet>>{};
    for (final set in sets) {
      final key = set.exerciseId ?? set.exerciseName;
      buckets.putIfAbsent(key, () => []).add(set);
    }

    final bucketEntries = buckets.entries.toList()
      ..sort((a, b) {
        if (sortByFirstLoggedAt) {
          return _firstLoggedAt(a.value).compareTo(_firstLoggedAt(b.value));
        }

        return _lastLoggedAt(b.value).compareTo(_lastLoggedAt(a.value));
      });

    return [
      for (final entry in bucketEntries)
        _exerciseStatsForBucket(
          entry.value,
          exerciseMusclesById: exerciseMusclesById,
          exerciseMusclesByName: exerciseMusclesByName,
        ),
    ];
  }

  static List<TrainingDaySummary> buildTrainingDaySummaries(
    List<LoggedWorkoutSet> sets,
    List<LoggedWorkoutSession> sessions,
    List<ExerciseMuscleRef> exercises,
  ) {
    final sessionsById = {for (final session in sessions) session.id: session};
    final buckets = <DateTime, List<LoggedWorkoutSet>>{};
    for (final set in sets) {
      final date = DateTime(
        set.loggedAt.year,
        set.loggedAt.month,
        set.loggedAt.day,
      );
      buckets.putIfAbsent(date, () => []).add(set);
    }

    return [
      for (final entry in buckets.entries)
        _buildTrainingDaySummary(
          date: entry.key,
          sets: entry.value,
          sessionsById: sessionsById,
          exercises: exercises,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  static DailyVolume _dailyVolume(List<LoggedWorkoutSet> sets, DateTime day) {
    final nextDay = day.add(const Duration(days: 1));
    final volumeKg = sets
        .where(
          (set) =>
              !set.loggedAt.isBefore(day) && set.loggedAt.isBefore(nextDay),
        )
        .fold<double>(0, (sum, set) => sum + set.volumeKg);
    return DailyVolume(date: day, volumeKg: volumeKg);
  }

  static TrainingDaySummary _buildTrainingDaySummary({
    required DateTime date,
    required List<LoggedWorkoutSet> sets,
    required Map<String, LoggedWorkoutSession> sessionsById,
    required List<ExerciseMuscleRef> exercises,
  }) {
    final orderedSets = [...sets]
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    final daySessions = <LoggedWorkoutSession>[];
    final seenSessionIds = <String>{};

    for (final set in orderedSets) {
      if (!seenSessionIds.add(set.sessionId)) {
        continue;
      }

      final session = sessionsById[set.sessionId];
      if (session != null) {
        daySessions.add(session);
      }
    }

    daySessions.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final primarySession =
        daySessions
            .where(
              (session) =>
                  session.templateDayNumber != null ||
                  (session.templateName?.trim().isNotEmpty ?? false),
            )
            .firstOrNull ??
        daySessions.firstOrNull;

    return TrainingDaySummary(
      date: date,
      exercises: buildExerciseStats(
        orderedSets,
        sortByFirstLoggedAt: true,
        exercises: exercises,
      ),
      templateName: primarySession?.templateName,
      templateDayNumber: primarySession?.templateDayNumber,
    );
  }

  static ExerciseWeightStats _exerciseStatsForBucket(
    List<LoggedWorkoutSet> sets, {
    required Map<String, String> exerciseMusclesById,
    required Map<String, String> exerciseMusclesByName,
  }) {
    final first = sets.first;
    final rawMuscle =
        (first.exerciseId == null
            ? null
            : exerciseMusclesById[first.exerciseId]) ??
        exerciseMusclesByName[first.exerciseName];
    return ExerciseWeightStats(
      exerciseId: first.exerciseId,
      exerciseName: first.exerciseName,
      minWeightKg: sets
          .map((set) => set.weightKg)
          .reduce((min, value) => value < min ? value : min),
      maxWeightKg: sets
          .map((set) => set.weightKg)
          .reduce((max, value) => value > max ? value : max),
      minReps: sets
          .map((set) => set.reps)
          .reduce((min, value) => value < min ? value : min),
      maxReps: sets
          .map((set) => set.reps)
          .reduce((max, value) => value > max ? value : max),
      totalSets: sets.length,
      lastLoggedAt: _lastLoggedAt(sets),
      primaryMuscle: ExerciseMuscleClassifier.classify(
        exerciseName: first.exerciseName,
        rawMuscle: rawMuscle,
      ),
      totalVolumeKg: sets.fold<double>(0, (sum, set) => sum + set.volumeKg),
    );
  }

  static DateTime _firstLoggedAt(List<LoggedWorkoutSet> sets) {
    return sets
        .map((set) => set.loggedAt)
        .reduce((first, value) => value.isBefore(first) ? value : first);
  }

  static DateTime _lastLoggedAt(List<LoggedWorkoutSet> sets) {
    return sets
        .map((set) => set.loggedAt)
        .reduce((last, value) => value.isAfter(last) ? value : last);
  }
}

class LoggedWorkoutSet {
  const LoggedWorkoutSet({
    required this.sessionId,
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.loggedAt,
    this.id,
    this.exerciseId,
  });

  final String? id;
  final String sessionId;
  final String? exerciseId;
  final String exerciseName;
  final double weightKg;
  final int reps;
  final DateTime loggedAt;

  double get volumeKg => weightKg * reps;

  double get estimatedOneRepMaxKg => weightKg * (1 + reps / 30);
}

class ExerciseMuscleRef {
  const ExerciseMuscleRef({
    required this.id,
    required this.name,
    required this.primaryMuscle,
  });

  final String id;
  final String name;
  final String primaryMuscle;
}
