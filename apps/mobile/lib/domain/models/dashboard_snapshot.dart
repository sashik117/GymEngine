import 'package:equatable/equatable.dart';

class DashboardSnapshot extends Equatable {
  const DashboardSnapshot({
    required this.weekNumber,
    required this.weekVolumeKg,
    required this.sessionCount,
    required this.lastExerciseName,
    required this.recentTrainingDates,
  });

  const DashboardSnapshot.empty()
    : weekNumber = 1,
      weekVolumeKg = 0,
      sessionCount = 0,
      lastExerciseName = null,
      recentTrainingDates = const [];

  final int weekNumber;
  final double weekVolumeKg;
  final int sessionCount;
  final String? lastExerciseName;
  final List<DateTime> recentTrainingDates;

  @override
  List<Object?> get props => [
    weekNumber,
    weekVolumeKg,
    sessionCount,
    lastExerciseName,
    recentTrainingDates,
  ];
}
