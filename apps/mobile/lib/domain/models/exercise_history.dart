import 'package:equatable/equatable.dart';

class ExerciseHistory extends Equatable {
  const ExerciseHistory({
    required this.lastWeightKg,
    required this.lastReps,
    required this.bestEstimatedOneRepMaxKg,
    required this.totalSets,
  });

  const ExerciseHistory.empty()
    : lastWeightKg = 0,
      lastReps = 0,
      bestEstimatedOneRepMaxKg = 0,
      totalSets = 0;

  final double lastWeightKg;
  final int lastReps;
  final double bestEstimatedOneRepMaxKg;
  final int totalSets;

  bool get hasData => totalSets > 0;

  @override
  List<Object?> get props => [
    lastWeightKg,
    lastReps,
    bestEstimatedOneRepMaxKg,
    totalSets,
  ];
}
