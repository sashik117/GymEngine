part of 'session_cubit.dart';

class SessionState extends Equatable {
  const SessionState({
    required this.startedAt,
    required this.sets,
    this.sessionId,
    this.finishedAt,
    this.selectedExerciseId,
    this.restEndsAt,
    this.restDurationSeconds,
  });

  factory SessionState.initial() {
    return SessionState(startedAt: DateTime.now(), sets: const []);
  }

  final DateTime startedAt;
  final List<WorkoutSet> sets;
  final String? sessionId;
  final DateTime? finishedAt;
  final String? selectedExerciseId;
  final DateTime? restEndsAt;
  final int? restDurationSeconds;

  int get setCount => sets.length;

  double get totalVolumeKg {
    return sets.fold<double>(0, (sum, set) => sum + set.volumeKg);
  }

  double get bestEstimatedOneRepMaxKg {
    if (sets.isEmpty) {
      return 0;
    }

    return sets
        .map((set) => set.estimatedOneRepMaxKg)
        .reduce((best, current) => current > best ? current : best);
  }

  double get heaviestSetKg {
    if (sets.isEmpty) {
      return 0;
    }

    return sets
        .map((set) => set.weightKg)
        .reduce((best, current) => current > best ? current : best);
  }

  SessionState copyWith({
    String? sessionId,
    List<WorkoutSet>? sets,
    DateTime? finishedAt,
    String? selectedExerciseId,
    DateTime? restEndsAt,
    int? restDurationSeconds,
    bool clearRest = false,
  }) {
    return SessionState(
      startedAt: startedAt,
      sessionId: sessionId ?? this.sessionId,
      sets: sets ?? this.sets,
      finishedAt: finishedAt ?? this.finishedAt,
      selectedExerciseId: selectedExerciseId ?? this.selectedExerciseId,
      restEndsAt: clearRest ? null : restEndsAt ?? this.restEndsAt,
      restDurationSeconds: clearRest
          ? null
          : restDurationSeconds ?? this.restDurationSeconds,
    );
  }

  @override
  List<Object?> get props => [
    startedAt,
    sessionId,
    sets,
    finishedAt,
    selectedExerciseId,
    restEndsAt,
    restDurationSeconds,
  ];
}
