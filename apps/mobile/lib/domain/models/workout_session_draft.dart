import 'package:equatable/equatable.dart';

import 'workout_set.dart';

class WorkoutSessionDraft extends Equatable {
  const WorkoutSessionDraft({
    required this.sessionId,
    required this.startedAt,
    required this.sets,
  });

  final String sessionId;
  final DateTime startedAt;
  final List<WorkoutSet> sets;

  @override
  List<Object?> get props => [sessionId, startedAt, sets];
}
