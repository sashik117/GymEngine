import 'package:equatable/equatable.dart';

class AnalyticsSnapshot extends Equatable {
  const AnalyticsSnapshot({
    required this.totalVolumeKg,
    required this.bestEstimatedOneRepMaxKg,
    required this.heaviestSetKg,
    required this.totalSets,
    required this.dailyVolumes,
    required this.muscleVolumes,
    required this.exerciseStats,
    required this.trainingDates,
    required this.trainingDays,
  });

  const AnalyticsSnapshot.empty()
    : totalVolumeKg = 0,
      bestEstimatedOneRepMaxKg = 0,
      heaviestSetKg = 0,
      totalSets = 0,
      dailyVolumes = const [],
      muscleVolumes = const [],
      exerciseStats = const [],
      trainingDates = const [],
      trainingDays = const [];

  final double totalVolumeKg;
  final double bestEstimatedOneRepMaxKg;
  final double heaviestSetKg;
  final int totalSets;
  final List<DailyVolume> dailyVolumes;
  final List<MuscleVolume> muscleVolumes;
  final List<ExerciseWeightStats> exerciseStats;
  final List<DateTime> trainingDates;
  final List<TrainingDaySummary> trainingDays;

  @override
  List<Object?> get props => [
    totalVolumeKg,
    bestEstimatedOneRepMaxKg,
    heaviestSetKg,
    totalSets,
    dailyVolumes,
    muscleVolumes,
    exerciseStats,
    trainingDates,
    trainingDays,
  ];
}

class DailyVolume extends Equatable {
  const DailyVolume({required this.date, required this.volumeKg});

  final DateTime date;
  final double volumeKg;

  @override
  List<Object?> get props => [date, volumeKg];
}

class MuscleVolume extends Equatable {
  const MuscleVolume({required this.muscle, required this.volumeKg});

  final String muscle;
  final double volumeKg;

  @override
  List<Object?> get props => [muscle, volumeKg];
}

class ExerciseWeightStats extends Equatable {
  const ExerciseWeightStats({
    required this.exerciseId,
    required this.exerciseName,
    required this.minWeightKg,
    required this.maxWeightKg,
    required this.minReps,
    required this.maxReps,
    required this.totalSets,
    required this.lastLoggedAt,
  });

  final String? exerciseId;
  final String exerciseName;
  final double minWeightKg;
  final double maxWeightKg;
  final int minReps;
  final int maxReps;
  final int totalSets;
  final DateTime lastLoggedAt;

  @override
  List<Object?> get props => [
    exerciseId,
    exerciseName,
    minWeightKg,
    maxWeightKg,
    minReps,
    maxReps,
    totalSets,
    lastLoggedAt,
  ];
}

class TrainingDaySummary extends Equatable {
  const TrainingDaySummary({
    required this.date,
    required this.exercises,
    this.templateName,
    this.templateDayNumber,
  });

  final DateTime date;
  final List<ExerciseWeightStats> exercises;
  final String? templateName;
  final int? templateDayNumber;

  int get totalSets {
    return exercises.fold<int>(0, (sum, item) => sum + item.totalSets);
  }

  double get maxWeightKg {
    if (exercises.isEmpty) {
      return 0;
    }

    return exercises
        .map((item) => item.maxWeightKg)
        .reduce((best, value) => value > best ? value : best);
  }

  @override
  List<Object?> get props => [date, exercises, templateName, templateDayNumber];
}
