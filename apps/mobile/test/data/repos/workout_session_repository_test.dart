import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_engine/data/local/app_database.dart' hide UserProfile;
import 'package:gym_engine/data/repos/workout_session_repository.dart';
import 'package:gym_engine/domain/models/training_day_plan.dart';
import 'package:gym_engine/domain/models/user_profile.dart';
import 'package:gym_engine/domain/models/workout_set.dart';

void main() {
  test('persists a workout session with sets', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = WorkoutSessionRepository(database);
    final exercises = await repository.loadExercises();

    expect(exercises.map((exercise) => exercise.name), contains('Bench Press'));
    expect(exercises.map((exercise) => exercise.name), contains('Squat'));

    await repository.saveTrainingDayPlan(
      dayNumber: 1,
      name: 'День Ніг',
      exercises: [
        TrainingPlanExercise(
          exercise: exercises.firstWhere((exercise) => exercise.id == 'squat'),
          targetSets: 4,
          targetReps: 8,
        ),
      ],
      restSeconds: 120,
    );

    final dayOnePlan = await repository.loadTrainingDayPlan(1);
    expect(dayOnePlan.dayNumber, 1);
    expect(dayOnePlan.name, 'День Ніг');
    expect(dayOnePlan.exercises, hasLength(1));
    expect(dayOnePlan.exercises.single.exercise.id, 'squat');
    expect(dayOnePlan.exercises.single.targetSets, 4);
    expect(dayOnePlan.exercises.single.targetReps, 8);
    expect(dayOnePlan.restSeconds, 120);

    await repository.saveTrainingDayPlan(
      dayNumber: 2,
      name: 'День Верха',
      exercises: [
        TrainingPlanExercise(
          exercise: exercises.firstWhere(
            (exercise) => exercise.id == 'bench_press',
          ),
          targetSets: 3,
          targetReps: 10,
        ),
      ],
      restSeconds: 90,
    );

    final startedAt = DateTime(2026, 5, 15, 10);
    final sessionId = await repository.createSession(
      startedAt,
      templateName: dayOnePlan.name,
      templateDayNumber: dayOnePlan.dayNumber,
    );

    final squatSetId = await repository.logSet(
      sessionId: sessionId,
      set: WorkoutSet(
        exerciseId: 'squat',
        exerciseName: 'Squat',
        weightKg: 100,
        reps: 5,
        loggedAt: startedAt.add(const Duration(minutes: 3)),
      ),
    );
    await repository.logSet(
      sessionId: sessionId,
      set: WorkoutSet(
        exerciseId: 'bench_press',
        exerciseName: 'Bench Press',
        weightKg: 60,
        reps: 8,
        loggedAt: startedAt.add(const Duration(minutes: 8)),
      ),
    );

    final openSession = await repository.loadOpenSession(templateDayNumber: 1);
    expect(openSession, isNotNull);
    expect(openSession!.sessionId, sessionId);
    expect(openSession.sets, hasLength(2));
    expect(openSession.sets.first.reps, 5);

    final finishedAt = startedAt.add(const Duration(minutes: 45));
    await repository.finishSession(
      sessionId: sessionId,
      finishedAt: finishedAt,
    );
    expect(await repository.loadOpenSession(templateDayNumber: 1), isNull);
    expect(await repository.loadSuggestedDayNumber(), 2);

    final sessions = await database.select(database.workoutSessions).get();
    final sets = await database.select(database.workoutSetEntries).get();

    expect(sessions, hasLength(1));
    expect(sessions.single.id, sessionId);
    expect(sessions.single.finishedAt, finishedAt);
    expect(sessions.single.templateName, 'День Ніг');
    expect(sessions.single.templateDayNumber, 1);

    expect(sets, hasLength(2));
    final squatSet = sets.singleWhere((set) => set.exerciseId == 'squat');
    expect(squatSet.sessionId, sessionId);
    expect(squatSet.exerciseName, 'Squat');
    expect(squatSet.weightKg, 100);
    expect(squatSet.reps, 5);

    final snapshot = await repository.loadDashboardSnapshot(
      now: DateTime(2026, 5, 15, 12),
    );

    expect(snapshot.weekVolumeKg, 980);
    expect(snapshot.sessionCount, 1);
    expect(snapshot.lastExerciseName, 'Bench Press');

    final analytics = await repository.loadAnalyticsSnapshot(
      now: DateTime(2026, 5, 15, 12),
    );

    expect(analytics.totalVolumeKg, 980);
    expect(analytics.bestEstimatedOneRepMaxKg, closeTo(116.67, 0.01));
    expect(analytics.heaviestSetKg, 100);
    expect(analytics.totalSets, 2);
    expect(analytics.dailyVolumes.map((item) => item.volumeKg), contains(980));
    expect(analytics.muscleVolumes, hasLength(2));
    expect(analytics.exerciseStats.first.exerciseName, 'Bench Press');
    expect(analytics.exerciseStats.first.minWeightKg, 60);
    expect(analytics.exerciseStats.first.maxWeightKg, 60);
    expect(analytics.exerciseStats.first.minReps, 8);
    expect(analytics.exerciseStats.first.maxReps, 8);
    expect(analytics.trainingDates.single, DateTime(2026, 5, 15));
    expect(analytics.trainingDays.single.date, DateTime(2026, 5, 15));
    expect(analytics.trainingDays.single.templateName, 'День Ніг');
    expect(analytics.trainingDays.single.templateDayNumber, 1);
    expect(analytics.trainingDays.single.exercises.first.exerciseName, 'Squat');
    expect(analytics.trainingDays.single.exercises.first.minReps, 5);
    expect(analytics.trainingDays.single.exercises.first.maxReps, 5);
    expect(
      analytics.trainingDays.single.exercises.last.exerciseName,
      'Bench Press',
    );

    final history = await repository.loadExerciseHistory(
      exercises.firstWhere((exercise) => exercise.id == 'squat'),
    );

    expect(history.lastWeightKg, 100);
    expect(history.lastReps, 5);
    expect(history.bestEstimatedOneRepMaxKg, closeTo(116.67, 0.01));
    expect(history.totalSets, 1);

    await repository.saveProfile(
      const UserProfile(
        displayName: 'Аня',
        bodyWeightKg: 62.5,
        userId: '',
        email: '',
        authToken: '',
        syncCode: '',
        syncBaseUrl: '',
      ),
    );
    final profile = await repository.loadProfile();
    expect(profile.displayName, 'Аня');
    expect(profile.bodyWeightKg, 62.5);

    final syncProfile = profile.copyWith(
      syncCode: repository.createSyncCode(),
      syncBaseUrl: WorkoutSessionRepository.defaultSyncBaseUrl,
    );
    final syncSnapshot = await repository.exportSyncSnapshot(
      profile: syncProfile,
    );
    final restoredDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(restoredDatabase.close);
    final restoredRepository = WorkoutSessionRepository(restoredDatabase);

    final restoreResult = await restoredRepository.importSyncSnapshot(
      syncSnapshot,
      syncCode: syncProfile.syncCode,
      syncBaseUrl: syncProfile.syncBaseUrl,
    );
    final restoredProfile = await restoredRepository.loadProfile();
    final restoredAnalytics = await restoredRepository.loadAnalyticsSnapshot(
      now: DateTime(2026, 5, 15, 12),
    );

    expect(restoreResult.setCount, 2);
    expect(restoredProfile.displayName, 'Аня');
    expect(restoredProfile.syncCode, syncProfile.syncCode);
    expect(restoredAnalytics.totalSets, 2);
    expect(restoredAnalytics.trainingDays.single.templateDayNumber, 1);

    final plansBeforeDelete = await repository.loadTrainingDayPlans();
    expect(
      plansBeforeDelete.map((plan) => plan.dayNumber),
      orderedEquals([1, 2]),
    );

    await repository.deleteTrainingDayPlan(1);
    final plansAfterDelete = await repository.loadTrainingDayPlans();
    expect(plansAfterDelete, hasLength(1));
    expect(plansAfterDelete.single.dayNumber, 1);
    expect(plansAfterDelete.single.name, 'День Верха');

    await repository.deleteSet(squatSetId);
    final setsAfterSetDelete = await database
        .select(database.workoutSetEntries)
        .get();
    expect(setsAfterSetDelete, hasLength(1));

    await repository.deleteTrainingDay(DateTime(2026, 5, 15));
    final setsAfterDelete = await database
        .select(database.workoutSetEntries)
        .get();
    final sessionsAfterDelete = await database
        .select(database.workoutSessions)
        .get();
    expect(setsAfterDelete, isEmpty);
    expect(sessionsAfterDelete, isEmpty);
  });
}
