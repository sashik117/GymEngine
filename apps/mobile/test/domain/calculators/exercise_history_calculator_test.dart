import 'package:flutter_test/flutter_test.dart';
import 'package:gym_engine/domain/calculators/exercise_history_calculator.dart';
import 'package:gym_engine/domain/calculators/workout_analytics_calculator.dart';

void main() {
  group('ExerciseHistoryCalculator', () {
    test('uses latest set for quick history and best set for 1RM', () {
      final history = ExerciseHistoryCalculator.build([
        LoggedWorkoutSet(
          sessionId: 'session-a',
          exerciseName: 'Squat',
          weightKg: 100,
          reps: 5,
          loggedAt: DateTime(2026, 5, 18, 10),
        ),
        LoggedWorkoutSet(
          sessionId: 'session-b',
          exerciseName: 'Squat',
          weightKg: 95,
          reps: 10,
          loggedAt: DateTime(2026, 5, 20, 10),
        ),
      ]);

      expect(history.lastWeightKg, 95);
      expect(history.lastReps, 10);
      expect(history.bestEstimatedOneRepMaxKg, closeTo(126.67, 0.01));
      expect(history.totalSets, 2);
    });
  });
}
