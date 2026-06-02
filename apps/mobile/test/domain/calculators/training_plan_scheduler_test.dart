import 'package:flutter_test/flutter_test.dart';
import 'package:gym_engine/domain/calculators/training_plan_scheduler.dart';

void main() {
  group('TrainingPlanScheduler', () {
    test('keeps current day when it was finished today', () {
      final suggested = TrainingPlanScheduler.suggestedDayNumber(
        plannedDays: const [1, 2, 3, 4],
        lastFinishedDayNumber: 2,
        lastFinishedAt: DateTime(2026, 5, 20, 21),
        now: DateTime(2026, 5, 20, 22),
      );

      expect(suggested, 2);
    });

    test('moves to next planned day after a previous training date', () {
      final suggested = TrainingPlanScheduler.suggestedDayNumber(
        plannedDays: const [1, 2, 3, 4],
        lastFinishedDayNumber: 2,
        lastFinishedAt: DateTime(2026, 5, 19, 21),
        now: DateTime(2026, 5, 20, 8),
      );

      expect(suggested, 3);
    });

    test('wraps back to first planned day after the last one', () {
      final suggested = TrainingPlanScheduler.suggestedDayNumber(
        plannedDays: const [1, 2, 3],
        lastFinishedDayNumber: 3,
        lastFinishedAt: DateTime(2026, 5, 19, 21),
        now: DateTime(2026, 5, 20, 8),
      );

      expect(suggested, 1);
    });
  });
}
