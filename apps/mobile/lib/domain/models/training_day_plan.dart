import 'package:equatable/equatable.dart';

import 'exercise.dart';

class TrainingDayPlan extends Equatable {
  const TrainingDayPlan({
    required this.id,
    required this.dayNumber,
    required this.name,
    required this.exercises,
    required this.restSeconds,
  });

  const TrainingDayPlan.empty(this.dayNumber)
    : id = null,
      name = '',
      exercises = const [],
      restSeconds = 90;

  final String? id;
  final int dayNumber;
  final String name;
  final List<TrainingPlanExercise> exercises;
  final int restSeconds;

  bool get isEmpty => id == null || exercises.isEmpty;

  @override
  List<Object?> get props => [id, dayNumber, name, exercises, restSeconds];
}

class TrainingPlanExercise extends Equatable {
  const TrainingPlanExercise({
    required this.exercise,
    required this.targetSets,
    required this.targetReps,
    this.comment = '',
  });

  final Exercise exercise;
  final int targetSets;
  final int targetReps;
  final String comment;

  TrainingPlanExercise copyWith({
    Exercise? exercise,
    int? targetSets,
    int? targetReps,
    String? comment,
  }) {
    return TrainingPlanExercise(
      exercise: exercise ?? this.exercise,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      comment: comment ?? this.comment,
    );
  }

  @override
  List<Object?> get props => [exercise, targetSets, targetReps, comment];
}
