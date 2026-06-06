import 'package:equatable/equatable.dart';

import 'workout_set.dart';

class WorkoutSessionDraft extends Equatable {
  const WorkoutSessionDraft({
    required this.sessionId,
    required this.startedAt,
    required this.sets,
    this.templateName,
    this.templateDayNumber,
    this.selectedExerciseId,
    this.restEndsAt,
    this.restDurationSeconds,
  });

  final String sessionId;
  final DateTime startedAt;
  final List<WorkoutSet> sets;
  final String? templateName;
  final int? templateDayNumber;
  final String? selectedExerciseId;
  final DateTime? restEndsAt;
  final int? restDurationSeconds;

  @override
  List<Object?> get props => [
    sessionId,
    startedAt,
    sets,
    templateName,
    templateDayNumber,
    selectedExerciseId,
    restEndsAt,
    restDurationSeconds,
  ];
}
