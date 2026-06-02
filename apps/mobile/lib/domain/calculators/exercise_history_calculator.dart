import '../models/exercise_history.dart';
import 'workout_analytics_calculator.dart';

class ExerciseHistoryCalculator {
  const ExerciseHistoryCalculator._();

  static ExerciseHistory build(List<LoggedWorkoutSet> sets) {
    if (sets.isEmpty) {
      return const ExerciseHistory.empty();
    }

    final ordered = [...sets]..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    final bestEstimatedOneRepMaxKg = ordered
        .map((set) => set.estimatedOneRepMaxKg)
        .reduce((best, current) => current > best ? current : best);
    final last = ordered.first;

    return ExerciseHistory(
      lastWeightKg: last.weightKg,
      lastReps: last.reps,
      bestEstimatedOneRepMaxKg: bestEstimatedOneRepMaxKg,
      totalSets: ordered.length,
    );
  }
}
