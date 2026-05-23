import 'package:equatable/equatable.dart';

class WorkoutSet extends Equatable {
  const WorkoutSet({
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.loggedAt,
    this.id,
    this.exerciseId,
  });

  final String? id;
  final String? exerciseId;
  final String exerciseName;
  final double weightKg;
  final int reps;
  final DateTime loggedAt;

  double get volumeKg => weightKg * reps;

  double get estimatedOneRepMaxKg => weightKg * (1 + reps / 30);

  WorkoutSet copyWith({String? id}) {
    return WorkoutSet(
      id: id ?? this.id,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      weightKg: weightKg,
      reps: reps,
      loggedAt: loggedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    exerciseId,
    exerciseName,
    weightKg,
    reps,
    loggedAt,
  ];
}
