import 'package:flutter_test/flutter_test.dart';
import 'package:gym_engine/domain/calculators/training_calendar.dart';
import 'package:gym_engine/domain/calculators/workout_analytics_calculator.dart';

void main() {
  group('WorkoutAnalyticsCalculator', () {
    final now = DateTime(2026, 5, 20, 10, 30);
    final sessions = [
      LoggedWorkoutSession(
        id: 'session-a',
        startedAt: DateTime(2026, 5, 19, 10),
        finishedAt: DateTime(2026, 5, 19, 11),
        templateName: 'Leg day',
        templateDayNumber: 1,
      ),
      LoggedWorkoutSession(
        id: 'session-b',
        startedAt: DateTime(2026, 5, 20, 10),
        templateName: 'Pull day',
        templateDayNumber: 2,
      ),
    ];
    final sets = [
      LoggedWorkoutSet(
        sessionId: 'session-a',
        exerciseId: 'squat',
        exerciseName: 'Squat',
        weightKg: 100,
        reps: 5,
        loggedAt: DateTime(2026, 5, 19, 10, 10),
      ),
      LoggedWorkoutSet(
        sessionId: 'session-a',
        exerciseId: 'bench',
        exerciseName: 'Bench Press',
        weightKg: 60,
        reps: 8,
        loggedAt: DateTime(2026, 5, 19, 10, 20),
      ),
      LoggedWorkoutSet(
        sessionId: 'session-b',
        exerciseId: 'curl',
        exerciseName: 'Barbell Curl',
        weightKg: 20,
        reps: 12,
        loggedAt: DateTime(2026, 5, 20, 10, 10),
      ),
    ];
    final exercises = [
      const ExerciseMuscleRef(
        id: 'squat',
        name: 'Squat',
        primaryMuscle: 'Quads',
      ),
      const ExerciseMuscleRef(
        id: 'bench',
        name: 'Bench Press',
        primaryMuscle: 'Chest',
      ),
      const ExerciseMuscleRef(
        id: 'curl',
        name: 'Barbell Curl',
        primaryMuscle: 'Biceps',
      ),
    ];

    test('builds dashboard values without repository logic', () {
      final dashboard = WorkoutAnalyticsCalculator.dashboard(
        now: now,
        sessions: sessions,
        sets: sets,
      );

      expect(dashboard.weekVolumeKg, 1220);
      expect(dashboard.sessionCount, 1);
      expect(dashboard.lastExerciseName, 'Barbell Curl');
      expect(
        dashboard.recentTrainingDates,
        orderedEquals([DateTime(2026, 5, 20), DateTime(2026, 5, 19)]),
      );
    });

    test('builds progress, muscle sectors, calendar and streak stats', () {
      final analytics = WorkoutAnalyticsCalculator.analytics(
        now: now,
        sets: sets,
        sessions: sessions,
        exercises: exercises,
      );

      expect(analytics.totalVolumeKg, 1220);
      expect(analytics.heaviestSetKg, 100);
      expect(analytics.totalSets, 3);
      expect(analytics.weeklyWorkoutCount, 2);
      expect(analytics.currentStreakDays, 2);
      expect(analytics.totalTrainingSeconds, 5400);

      final quads = analytics.muscleVolumes.singleWhere(
        (item) => item.muscle == 'Quads',
      );
      expect(quads.volumeKg, 500);
      expect(quads.setCount, 1);

      expect(analytics.trainingDays.first.date, DateTime(2026, 5, 20));
      expect(analytics.trainingDays.last.date, DateTime(2026, 5, 19));
      expect(analytics.trainingDays.last.templateName, 'Leg day');
      expect(
        analytics.trainingDays.last.exercises.map((item) => item.exerciseName),
        orderedEquals(['Squat', 'Bench Press']),
      );
    });
  });

  group('TrainingCalendar', () {
    test('counts active and finished session time', () {
      final seconds = TrainingCalendar.totalTrainingSeconds([
        LoggedWorkoutSession(
          id: 'finished',
          startedAt: DateTime(2026, 5, 20, 8),
          finishedAt: DateTime(2026, 5, 20, 9),
        ),
        LoggedWorkoutSession(id: 'open', startedAt: DateTime(2026, 5, 20, 10)),
      ], now: DateTime(2026, 5, 20, 10, 30));

      expect(seconds, 5400);
    });
  });
}
