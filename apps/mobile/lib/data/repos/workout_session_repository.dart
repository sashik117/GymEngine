import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/analytics_snapshot.dart';
import '../../domain/models/dashboard_snapshot.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_history.dart';
import '../../domain/models/training_day_plan.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/workout_set.dart';
import '../../domain/models/workout_session_draft.dart';
import '../local/app_database.dart' hide Exercise, UserProfile;
import '../sync/sync_api_client.dart';

class WorkoutSessionRepository {
  WorkoutSessionRepository(this._db, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;
  var _isAutoSyncing = false;

  static const _defaultExercises = [
    Exercise(id: 'bench_press', name: 'Bench Press', primaryMuscle: 'Chest'),
    Exercise(
      id: 'incline_press',
      name: 'Incline Press',
      primaryMuscle: 'Chest',
    ),
    Exercise(id: 'dumbbell_fly', name: 'Dumbbell Fly', primaryMuscle: 'Chest'),
    Exercise(id: 'squat', name: 'Squat', primaryMuscle: 'Quads'),
    Exercise(id: 'leg_press', name: 'Leg Press', primaryMuscle: 'Quads'),
    Exercise(id: 'lunge', name: 'Lunge', primaryMuscle: 'Quads'),
    Exercise(
      id: 'leg_extension',
      name: 'Leg Extension',
      primaryMuscle: 'Quads',
    ),
    Exercise(id: 'deadlift', name: 'Deadlift', primaryMuscle: 'Posterior'),
    Exercise(
      id: 'romanian_deadlift',
      name: 'Romanian Deadlift',
      primaryMuscle: 'Posterior',
    ),
    Exercise(id: 'hip_thrust', name: 'Hip Thrust', primaryMuscle: 'Glutes'),
    Exercise(id: 'glute_bridge', name: 'Glute Bridge', primaryMuscle: 'Glutes'),
    Exercise(id: 'leg_curl', name: 'Leg Curl', primaryMuscle: 'Hamstrings'),
    Exercise(
      id: 'overhead_press',
      name: 'Overhead Press',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'lateral_raise',
      name: 'Lateral Raise',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'rear_delt_fly',
      name: 'Rear Delt Fly',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(id: 'barbell_row', name: 'Barbell Row', primaryMuscle: 'Back'),
    Exercise(id: 'pull_up', name: 'Pull-Up', primaryMuscle: 'Back'),
    Exercise(id: 'lat_pulldown', name: 'Lat Pulldown', primaryMuscle: 'Back'),
    Exercise(id: 'seated_row', name: 'Seated Row', primaryMuscle: 'Back'),
    Exercise(id: 'biceps_curl', name: 'Biceps Curl', primaryMuscle: 'Biceps'),
    Exercise(id: 'hammer_curl', name: 'Hammer Curl', primaryMuscle: 'Biceps'),
    Exercise(
      id: 'triceps_pushdown',
      name: 'Triceps Pushdown',
      primaryMuscle: 'Triceps',
    ),
    Exercise(
      id: 'skull_crusher',
      name: 'Skull Crusher',
      primaryMuscle: 'Triceps',
    ),
    Exercise(id: 'plank', name: 'Plank', primaryMuscle: 'Core'),
    Exercise(id: 'cable_crunch', name: 'Cable Crunch', primaryMuscle: 'Core'),
  ];

  static const defaultSyncBaseUrl = 'http://192.168.1.104:3000/api';
  static const _syncChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Future<List<Exercise>> loadExercises() async {
    await ensureDefaultExercises();
    final rows = await (_db.select(
      _db.exercises,
    )..orderBy([(exercise) => OrderingTerm.asc(exercise.name)])).get();

    return [
      for (final row in rows)
        Exercise(id: row.id, name: row.name, primaryMuscle: row.primaryMuscle),
    ];
  }

  Future<ExerciseHistory> loadExerciseHistory(Exercise exercise) async {
    final sets =
        await (_db.select(_db.workoutSetEntries)
              ..where(
                (set) =>
                    set.exerciseId.equals(exercise.id) |
                    set.exerciseName.equals(exercise.name),
              )
              ..orderBy([(set) => OrderingTerm.desc(set.loggedAt)]))
            .get();

    if (sets.isEmpty) {
      return const ExerciseHistory.empty();
    }

    final bestEstimatedOneRepMaxKg = sets
        .map((set) => set.weightKg * (1 + set.reps / 30))
        .reduce((best, current) => current > best ? current : best);
    final last = sets.first;

    return ExerciseHistory(
      lastWeightKg: last.weightKg,
      lastReps: last.reps,
      bestEstimatedOneRepMaxKg: bestEstimatedOneRepMaxKg,
      totalSets: sets.length,
    );
  }

  Future<void> ensureDefaultExercises() async {
    final now = DateTime.now();

    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.exercises, [
        for (final exercise in _defaultExercises)
          ExercisesCompanion.insert(
            id: exercise.id,
            name: exercise.name,
            primaryMuscle: exercise.primaryMuscle,
            createdAt: now,
          ),
      ]);
    });
  }

  Future<Exercise> createCustomExercise({
    required String name,
    required String primaryMuscle,
  }) async {
    await ensureDefaultExercises();

    final normalizedName = _capitalizeWords(name);
    final normalizedMuscle = _capitalizeWords(primaryMuscle);
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Exercise name cannot be empty');
    }

    final existing =
        await (_db.select(_db.exercises)
              ..where((exercise) => exercise.name.equals(normalizedName)))
            .getSingleOrNull();
    if (existing != null) {
      return Exercise(
        id: existing.id,
        name: existing.name,
        primaryMuscle: existing.primaryMuscle,
      );
    }

    final exercise = Exercise(
      id: 'custom_${_uuid.v4()}',
      name: normalizedName,
      primaryMuscle: normalizedMuscle.isEmpty ? 'Custom' : normalizedMuscle,
    );

    await _db
        .into(_db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: exercise.id,
            name: exercise.name,
            primaryMuscle: exercise.primaryMuscle,
            createdAt: DateTime.now(),
            syncStatus: const Value('pending'),
          ),
        );

    unawaited(_autoSync());
    return exercise;
  }

  Future<Exercise> updateExercise({
    required Exercise exercise,
    required String name,
    required String primaryMuscle,
  }) async {
    final normalizedName = _capitalizeWords(name);
    final normalizedMuscle = _capitalizeWords(primaryMuscle);
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Exercise name cannot be empty');
    }

    await (_db.update(
      _db.exercises,
    )..where((row) => row.id.equals(exercise.id))).write(
      ExercisesCompanion(
        name: Value(normalizedName),
        primaryMuscle: Value(
          normalizedMuscle.isEmpty ? exercise.primaryMuscle : normalizedMuscle,
        ),
        syncStatus: const Value('pending'),
      ),
    );

    await (_db.update(_db.workoutSetEntries)
          ..where((row) => row.exerciseId.equals(exercise.id)))
        .write(WorkoutSetEntriesCompanion(exerciseName: Value(normalizedName)));

    unawaited(_autoSync());
    return Exercise(
      id: exercise.id,
      name: normalizedName,
      primaryMuscle: normalizedMuscle.isEmpty
          ? exercise.primaryMuscle
          : normalizedMuscle,
    );
  }

  Future<void> deleteCustomExercise(Exercise exercise) async {
    if (!exercise.id.startsWith('custom_')) {
      return;
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.plannedDayExercises,
      )..where((row) => row.exerciseId.equals(exercise.id))).go();
      await (_db.delete(
        _db.exercises,
      )..where((row) => row.id.equals(exercise.id))).go();
    });

    unawaited(_autoSync());
  }

  Future<TrainingDayPlan> loadTrainingDayPlan(int dayNumber) async {
    await ensureDefaultExercises();

    final day = await (_db.select(
      _db.plannedWorkoutDays,
    )..where((row) => row.dayNumber.equals(dayNumber))).getSingleOrNull();

    if (day == null) {
      return TrainingDayPlan.empty(dayNumber);
    }

    final plannedRows =
        await (_db.select(_db.plannedDayExercises)
              ..where((row) => row.dayId.equals(day.id))
              ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
            .get();
    final exercises = <TrainingPlanExercise>[];

    for (final planned in plannedRows) {
      final row =
          await (_db.select(_db.exercises)
                ..where((exercise) => exercise.id.equals(planned.exerciseId)))
              .getSingleOrNull();
      if (row != null) {
        exercises.add(
          TrainingPlanExercise(
            exercise: Exercise(
              id: row.id,
              name: row.name,
              primaryMuscle: row.primaryMuscle,
            ),
            targetSets: planned.targetSets,
            targetReps: planned.targetReps,
            comment: planned.comment,
          ),
        );
      }
    }

    return TrainingDayPlan(
      id: day.id,
      dayNumber: day.dayNumber,
      name: day.customName,
      exercises: exercises,
      restSeconds: day.restSeconds,
    );
  }

  Future<List<TrainingDayPlan>> loadTrainingDayPlans() async {
    await ensureDefaultExercises();

    final days = await (_db.select(
      _db.plannedWorkoutDays,
    )..orderBy([(row) => OrderingTerm.asc(row.dayNumber)])).get();

    final plans = <TrainingDayPlan>[];
    for (final day in days) {
      plans.add(await loadTrainingDayPlan(day.dayNumber));
    }

    return plans.where((plan) => !plan.isEmpty).toList();
  }

  Future<Set<int>> loadPlannedDayNumbers() async {
    final days = await _db.select(_db.plannedWorkoutDays).get();
    final dayIds = {for (final day in days) day.id: day.dayNumber};
    final plannedRows = await _db.select(_db.plannedDayExercises).get();

    return {
      for (final row in plannedRows)
        if (dayIds[row.dayId] != null) dayIds[row.dayId]!,
    };
  }

  Future<int> loadSuggestedDayNumber() async {
    final plannedDays = (await loadPlannedDayNumbers()).toList()..sort();
    if (plannedDays.isEmpty) {
      return 1;
    }

    final lastSession =
        await (_db.select(_db.workoutSessions)
              ..where(
                (session) =>
                    session.templateDayNumber.isNotNull() &
                    session.finishedAt.isNotNull(),
              )
              ..orderBy([
                (session) => OrderingTerm.desc(session.finishedAt),
                (session) => OrderingTerm.desc(session.startedAt),
              ])
              ..limit(1))
            .getSingleOrNull();
    final lastDayNumber = lastSession?.templateDayNumber;
    if (lastDayNumber == null) {
      return plannedDays.first;
    }

    for (final dayNumber in plannedDays) {
      if (dayNumber > lastDayNumber) {
        return dayNumber;
      }
    }

    return plannedDays.first;
  }

  Future<void> saveTrainingDayPlan({
    required int dayNumber,
    required String name,
    required List<TrainingPlanExercise> exercises,
    required int restSeconds,
  }) async {
    await ensureDefaultExercises();

    final now = DateTime.now();
    final existing = await (_db.select(
      _db.plannedWorkoutDays,
    )..where((row) => row.dayNumber.equals(dayNumber))).getSingleOrNull();
    final dayId = existing?.id ?? _uuid.v4();

    await _db.transaction(() async {
      await _db
          .into(_db.plannedWorkoutDays)
          .insertOnConflictUpdate(
            PlannedWorkoutDaysCompanion.insert(
              id: dayId,
              dayOfWeek: _legacyWeekdayFromDayNumber(dayNumber),
              dayNumber: Value(dayNumber),
              customName: name.trim().isEmpty
                  ? 'Тренувальний день'
                  : _capitalizeFirst(name),
              restSeconds: Value(restSeconds.clamp(15, 600)),
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
            ),
          );

      await (_db.delete(
        _db.plannedDayExercises,
      )..where((row) => row.dayId.equals(dayId))).go();

      await _db.batch((batch) {
        batch.insertAll(_db.plannedDayExercises, [
          for (final entry in exercises.indexed)
            PlannedDayExercisesCompanion.insert(
              id: _uuid.v4(),
              dayId: dayId,
              exerciseId: entry.$2.exercise.id,
              sortOrder: entry.$1,
              targetSets: Value(entry.$2.targetSets.clamp(1, 20)),
              targetReps: Value(entry.$2.targetReps.clamp(1, 100)),
              comment: Value(entry.$2.comment.trim()),
            ),
        ]);
      });
    });

    unawaited(_autoSync());
  }

  Future<void> deleteTrainingDayPlan(int dayNumber) async {
    final day = await (_db.select(
      _db.plannedWorkoutDays,
    )..where((row) => row.dayNumber.equals(dayNumber))).getSingleOrNull();
    if (day == null) {
      return;
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.plannedDayExercises,
      )..where((row) => row.dayId.equals(day.id))).go();
      await (_db.delete(
        _db.plannedWorkoutDays,
      )..where((row) => row.id.equals(day.id))).go();

      final daysToShift =
          await (_db.select(_db.plannedWorkoutDays)
                ..where((row) => row.dayNumber.isBiggerThanValue(dayNumber))
                ..orderBy([(row) => OrderingTerm.asc(row.dayNumber)]))
              .get();

      for (final item in daysToShift) {
        final shiftedDayNumber = item.dayNumber - 1;
        await (_db.update(
          _db.plannedWorkoutDays,
        )..where((row) => row.id.equals(item.id))).write(
          PlannedWorkoutDaysCompanion(
            dayNumber: Value(shiftedDayNumber),
            dayOfWeek: Value(_legacyWeekdayFromDayNumber(shiftedDayNumber)),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });

    unawaited(_autoSync());
  }

  Future<String> createSession(
    DateTime startedAt, {
    String? templateName,
    int? templateDayNumber,
  }) async {
    final id = _uuid.v4();

    await _db
        .into(_db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            id: id,
            startedAt: startedAt,
            templateName: Value(templateName),
            templateDayNumber: Value(templateDayNumber),
          ),
        );

    unawaited(_autoSync());
    return id;
  }

  Future<WorkoutSessionDraft?> loadOpenSession({
    String? templateName,
    int? templateDayNumber,
  }) async {
    final query = _db.select(_db.workoutSessions)
      ..where((session) => session.finishedAt.isNull());

    if (templateDayNumber != null) {
      query.where(
        (session) => session.templateDayNumber.equals(templateDayNumber),
      );
    } else if (templateName?.trim().isNotEmpty ?? false) {
      query.where(
        (session) => session.templateName.equals(templateName!.trim()),
      );
    }

    query
      ..orderBy([(session) => OrderingTerm.desc(session.startedAt)])
      ..limit(1);

    final session = await query.getSingleOrNull();
    if (session == null) {
      return null;
    }

    final rows =
        await (_db.select(_db.workoutSetEntries)
              ..where((set) => set.sessionId.equals(session.id))
              ..orderBy([(set) => OrderingTerm.asc(set.loggedAt)]))
            .get();

    return WorkoutSessionDraft(
      sessionId: session.id,
      startedAt: session.startedAt,
      sets: [
        for (final row in rows)
          WorkoutSet(
            id: row.id,
            exerciseId: row.exerciseId,
            exerciseName: row.exerciseName,
            weightKg: row.weightKg,
            reps: row.reps,
            loggedAt: row.loggedAt,
          ),
      ],
    );
  }

  Future<String> logSet({
    required String sessionId,
    required WorkoutSet set,
  }) async {
    final id = set.id ?? _uuid.v4();
    await _db
        .into(_db.workoutSetEntries)
        .insert(
          WorkoutSetEntriesCompanion.insert(
            id: id,
            sessionId: sessionId,
            exerciseId: Value(set.exerciseId),
            exerciseName: set.exerciseName,
            weightKg: set.weightKg,
            reps: set.reps,
            loggedAt: set.loggedAt,
          ),
        );
    unawaited(_autoSync());
    return id;
  }

  Future<void> deleteSet(String setId) async {
    await (_db.delete(
      _db.workoutSetEntries,
    )..where((set) => set.id.equals(setId))).go();
    unawaited(_autoSync());
  }

  Future<void> deleteTrainingDay(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final setsOnDate =
        await (_db.select(_db.workoutSetEntries)..where(
              (set) =>
                  set.loggedAt.isBiggerOrEqualValue(start) &
                  set.loggedAt.isSmallerThanValue(end),
            ))
            .get();
    final sessionsOnDate =
        await (_db.select(_db.workoutSessions)..where(
              (session) =>
                  session.startedAt.isBiggerOrEqualValue(start) &
                  session.startedAt.isSmallerThanValue(end),
            ))
            .get();
    final sessionIds = {
      for (final set in setsOnDate) set.sessionId,
      for (final session in sessionsOnDate) session.id,
    };

    if (sessionIds.isEmpty) {
      return;
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.workoutSetEntries,
      )..where((set) => set.sessionId.isIn(sessionIds))).go();
      await (_db.delete(
        _db.workoutSessions,
      )..where((session) => session.id.isIn(sessionIds))).go();
    });

    unawaited(_autoSync());
  }

  Future<void> finishSession({
    required String sessionId,
    required DateTime finishedAt,
  }) async {
    await (_db.update(_db.workoutSessions)
          ..where((session) => session.id.equals(sessionId)))
        .write(WorkoutSessionsCompanion(finishedAt: Value(finishedAt)));
    unawaited(_autoSync());
  }

  Future<DashboardSnapshot> loadDashboardSnapshot({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    final weekStart = _startOfWeek(currentTime);

    final sessions = await _db.select(_db.workoutSessions).get();
    final sets = await _db.select(_db.workoutSetEntries).get();

    final weekVolumeKg = sets
        .where((set) => !set.loggedAt.isBefore(weekStart))
        .fold<double>(0, (sum, set) => sum + set.weightKg * set.reps);

    sets.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

    return DashboardSnapshot(
      weekNumber: _weekNumber(currentTime),
      weekVolumeKg: weekVolumeKg,
      sessionCount: sessions
          .where((session) => session.finishedAt != null)
          .length,
      lastExerciseName: sets.isEmpty ? null : sets.first.exerciseName,
      recentTrainingDates: _uniqueTrainingDates(
        sets.map((set) => set.loggedAt),
      ),
    );
  }

  Future<AnalyticsSnapshot> loadAnalyticsSnapshot({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    final rangeStart = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    ).subtract(const Duration(days: 6));
    final sets = await _db.select(_db.workoutSetEntries).get();
    final exercises = await _db.select(_db.exercises).get();
    final sessions = await _db.select(_db.workoutSessions).get();

    if (sets.isEmpty) {
      return const AnalyticsSnapshot.empty();
    }

    final totalVolumeKg = sets.fold<double>(
      0,
      (sum, set) => sum + set.weightKg * set.reps,
    );
    final bestEstimatedOneRepMaxKg = sets
        .map((set) => set.weightKg * (1 + set.reps / 30))
        .reduce((best, current) => current > best ? current : best);
    final heaviestSetKg = sets
        .map((set) => set.weightKg)
        .reduce((best, current) => current > best ? current : best);

    final recentDailyVolumes = <DailyVolume>[];
    for (var index = 0; index < 7; index += 1) {
      final day = rangeStart.add(Duration(days: index));
      final nextDay = day.add(const Duration(days: 1));
      final volumeKg = sets
          .where(
            (set) =>
                !set.loggedAt.isBefore(day) && set.loggedAt.isBefore(nextDay),
          )
          .fold<double>(0, (sum, set) => sum + set.weightKg * set.reps);
      recentDailyVolumes.add(DailyVolume(date: day, volumeKg: volumeKg));
    }

    final exerciseMusclesById = {
      for (final exercise in exercises) exercise.id: exercise.primaryMuscle,
    };
    final exerciseMusclesByName = {
      for (final exercise in exercises) exercise.name: exercise.primaryMuscle,
    };
    final muscleTotals = <String, double>{};

    for (final set in sets) {
      final muscle =
          (set.exerciseId == null
              ? null
              : exerciseMusclesById[set.exerciseId]) ??
          exerciseMusclesByName[set.exerciseName] ??
          'Unknown';
      muscleTotals[muscle] =
          (muscleTotals[muscle] ?? 0) + set.weightKg * set.reps;
    }

    final muscleVolumes = [
      for (final entry in muscleTotals.entries)
        MuscleVolume(muscle: entry.key, volumeKg: entry.value),
    ]..sort((a, b) => b.volumeKg.compareTo(a.volumeKg));
    final exerciseStats = _buildExerciseStats(sets);
    final trainingDays = _buildTrainingDaySummaries(sets, sessions);

    return AnalyticsSnapshot(
      totalVolumeKg: totalVolumeKg,
      bestEstimatedOneRepMaxKg: bestEstimatedOneRepMaxKg,
      heaviestSetKg: heaviestSetKg,
      totalSets: sets.length,
      dailyVolumes: recentDailyVolumes,
      muscleVolumes: muscleVolumes,
      exerciseStats: exerciseStats,
      trainingDates: _uniqueTrainingDates(sets.map((set) => set.loggedAt)),
      trainingDays: trainingDays,
    );
  }

  Future<UserProfile> loadProfile() async {
    final row = await (_db.select(
      _db.userProfiles,
    )..where((profile) => profile.id.equals('local'))).getSingleOrNull();
    if (row == null) {
      return const UserProfile.empty();
    }

    return UserProfile(
      displayName: row.displayName,
      bodyWeightKg: row.bodyWeightKg,
      userId: row.userId ?? '',
      email: row.email ?? '',
      authToken: row.authToken ?? '',
      syncCode: row.syncCode ?? '',
      syncBaseUrl: row.syncBaseUrl ?? '',
    );
  }

  Future<void> saveProfile(
    UserProfile profile, {
    bool shouldSync = true,
  }) async {
    final now = DateTime.now();
    final existing = await (_db.select(
      _db.userProfiles,
    )..where((row) => row.id.equals('local'))).getSingleOrNull();

    await _db
        .into(_db.userProfiles)
        .insertOnConflictUpdate(
          UserProfilesCompanion.insert(
            id: 'local',
            displayName: Value(profile.displayName.trim()),
            bodyWeightKg: Value(profile.bodyWeightKg),
            userId: Value(profile.userId.trim()),
            email: Value(profile.email.trim().toLowerCase()),
            authToken: Value(profile.authToken.trim()),
            syncCode: Value(profile.syncCode.trim().toUpperCase()),
            syncBaseUrl: Value(_normalizeBaseUrl(profile.syncBaseUrl)),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );

    if (shouldSync) {
      unawaited(_autoSync());
    }
  }

  String createSyncCode() {
    final random = Random.secure();
    String block() {
      return List.generate(
        4,
        (_) => _syncChars[random.nextInt(_syncChars.length)],
      ).join();
    }

    return 'GE-${block()}-${block()}';
  }

  Future<AuthRunResult> registerAccount({
    required UserProfile profile,
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).requestRegistrationCode(email: email, password: password);
    throw SyncException('verification_required');
  }

  Future<void> requestRegistrationCode({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).requestRegistrationCode(email: email, password: password);
  }

  Future<AuthRunResult> verifyRegistrationCode({
    required UserProfile profile,
    required String baseUrl,
    required String email,
    required String code,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    final session = await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).verifyRegistrationCode(email: email, code: code);

    return _completeAuth(
      profile: profile,
      baseUrl: normalizedBaseUrl,
      session: session,
      shouldRestore: false,
      successMessage: 'Registered and synced',
    );
  }

  Future<void> requestPasswordResetCode({
    required String baseUrl,
    required String email,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).requestPasswordResetCode(email: email);
  }

  Future<AuthRunResult> confirmPasswordReset({
    required UserProfile profile,
    required String baseUrl,
    required String email,
    required String code,
    required String password,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    final session = await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).confirmPasswordReset(email: email, code: code, password: password);

    return _completeAuth(
      profile: profile,
      baseUrl: normalizedBaseUrl,
      session: session,
      shouldRestore: true,
      successMessage: 'Password reset and restored',
    );
  }

  Future<AuthRunResult> loginAccount({
    required UserProfile profile,
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    final session = await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).login(email: email, password: password);

    return _completeAuth(
      profile: profile,
      baseUrl: normalizedBaseUrl,
      session: session,
      shouldRestore: true,
      successMessage: 'Logged in and restored',
    );
  }

  Future<AuthRunResult> _completeAuth({
    required UserProfile profile,
    required String baseUrl,
    required AuthSession session,
    required bool shouldRestore,
    required String successMessage,
  }) async {
    final authenticatedProfile = profile.copyWith(
      userId: session.userId,
      email: session.email,
      authToken: session.token,
      syncBaseUrl: baseUrl,
    );
    await saveProfile(authenticatedProfile, shouldSync: false);

    if (shouldRestore) {
      try {
        final result = await restoreFromServer(
          baseUrl: baseUrl,
          authToken: session.token,
          userId: session.userId,
          email: session.email,
        );
        final restoredProfile = await loadProfile();
        return AuthRunResult(
          message: successMessage,
          profile: restoredProfile,
          setCount: result.setCount,
          sessionCount: result.sessionCount,
          trainingDayCount: result.trainingDayCount,
        );
      } catch (_) {
        return AuthRunResult(
          message: 'Logged in',
          profile: authenticatedProfile,
          setCount: 0,
          sessionCount: 0,
          trainingDayCount: 0,
        );
      }
    }

    try {
      final syncResult = await syncToServer(
        profile: authenticatedProfile,
        baseUrl: baseUrl,
      );
      return AuthRunResult(
        message: successMessage,
        profile: authenticatedProfile,
        setCount: syncResult.setCount,
        sessionCount: syncResult.sessionCount,
        trainingDayCount: syncResult.trainingDayCount,
      );
    } catch (_) {
      return AuthRunResult(
        message: successMessage,
        profile: authenticatedProfile,
        setCount: 0,
        sessionCount: 0,
        trainingDayCount: 0,
      );
    }
  }

  Future<UserProfile> logoutAccount(UserProfile profile) async {
    final nextProfile = profile.copyWith(userId: '', email: '', authToken: '');
    await saveProfile(nextProfile, shouldSync: false);
    return nextProfile;
  }

  Future<SyncRunResult> syncToServer({
    required UserProfile profile,
    required String baseUrl,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    if (profile.authToken.trim().isEmpty) {
      throw SyncException('auth');
    }
    final nextProfile = profile.copyWith(syncBaseUrl: normalizedBaseUrl);
    await saveProfile(nextProfile, shouldSync: false);

    final snapshot = await exportSyncSnapshot(profile: nextProfile);
    final result = await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).uploadMine(token: nextProfile.authToken, snapshot: snapshot);

    return SyncRunResult(
      message:
          'Saved ${result.setCount} sets and ${result.trainingDayCount} days',
      syncCode: nextProfile.userId,
      setCount: result.setCount,
      sessionCount: result.sessionCount,
      trainingDayCount: result.trainingDayCount,
    );
  }

  Future<SyncRunResult> restoreFromServer({
    required String baseUrl,
    required String authToken,
    required String userId,
    required String email,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    if (authToken.trim().isEmpty) {
      throw SyncException('auth');
    }
    final snapshot = await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).downloadMine(token: authToken);

    final counts = await importSyncSnapshot(
      snapshot,
      syncCode: '',
      syncBaseUrl: normalizedBaseUrl,
      userId: userId,
      email: email,
      authToken: authToken,
    );

    return SyncRunResult(
      message: 'Restored ${counts.setCount} sets',
      syncCode: userId,
      setCount: counts.setCount,
      sessionCount: counts.sessionCount,
      trainingDayCount: counts.trainingDayCount,
    );
  }

  Future<Map<String, Object?>> exportSyncSnapshot({
    required UserProfile profile,
  }) async {
    await ensureDefaultExercises();

    final exercises = await _db.select(_db.exercises).get();
    final trainingDays = await _db.select(_db.plannedWorkoutDays).get();
    final plannedExercises = await _db.select(_db.plannedDayExercises).get();
    final sessions = await _db.select(_db.workoutSessions).get();
    final sets = await _db.select(_db.workoutSetEntries).get();

    return {
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'profile': {
        'displayName': profile.displayName,
        'bodyWeightKg': profile.bodyWeightKg,
        'userId': profile.userId,
        'email': profile.email,
        'authBaseUrl': profile.syncBaseUrl,
        'syncCode': profile.syncCode,
        'syncBaseUrl': profile.syncBaseUrl,
      },
      'exercises': [
        for (final row in exercises)
          {
            'id': row.id,
            'name': row.name,
            'primaryMuscle': row.primaryMuscle,
            'createdAt': row.createdAt.toIso8601String(),
            'syncStatus': row.syncStatus,
          },
      ],
      'trainingDays': [
        for (final row in trainingDays)
          {
            'id': row.id,
            'dayOfWeek': row.dayOfWeek,
            'dayNumber': row.dayNumber,
            'customName': row.customName,
            'restSeconds': row.restSeconds,
            'setTargetSeconds': row.setTargetSeconds,
            'createdAt': row.createdAt.toIso8601String(),
            'updatedAt': row.updatedAt.toIso8601String(),
            'syncStatus': row.syncStatus,
          },
      ],
      'plannedExercises': [
        for (final row in plannedExercises)
          {
            'id': row.id,
            'dayId': row.dayId,
            'exerciseId': row.exerciseId,
            'sortOrder': row.sortOrder,
            'targetSets': row.targetSets,
            'targetReps': row.targetReps,
            'comment': row.comment,
          },
      ],
      'sessions': [
        for (final row in sessions)
          {
            'id': row.id,
            'startedAt': row.startedAt.toIso8601String(),
            'finishedAt': row.finishedAt?.toIso8601String(),
            'templateName': row.templateName,
            'templateDayNumber': row.templateDayNumber,
            'syncStatus': row.syncStatus,
          },
      ],
      'sets': [
        for (final row in sets)
          {
            'id': row.id,
            'sessionId': row.sessionId,
            'exerciseId': row.exerciseId,
            'exerciseName': row.exerciseName,
            'weightKg': row.weightKg,
            'reps': row.reps,
            'loggedAt': row.loggedAt.toIso8601String(),
            'syncStatus': row.syncStatus,
          },
      ],
    };
  }

  Future<SyncRunResult> importSyncSnapshot(
    Map<String, Object?> snapshot, {
    required String syncCode,
    required String syncBaseUrl,
    String userId = '',
    String email = '',
    String authToken = '',
  }) async {
    final exercises = _listOfMaps(snapshot['exercises']);
    final trainingDays = _listOfMaps(snapshot['trainingDays']);
    final plannedExercises = _listOfMaps(snapshot['plannedExercises']);
    final sessions = _listOfMaps(snapshot['sessions']);
    final sets = _listOfMaps(snapshot['sets']);
    final profileData = (snapshot['profile'] as Map?)?.cast<String, Object?>();
    final now = DateTime.now();

    await _db.transaction(() async {
      await _db.delete(_db.workoutSetEntries).go();
      await _db.delete(_db.workoutSessions).go();
      await _db.delete(_db.plannedDayExercises).go();
      await _db.delete(_db.plannedWorkoutDays).go();
      await _db.delete(_db.exercises).go();
      await _db.delete(_db.userProfiles).go();

      await _db.batch((batch) {
        batch.insertAll(_db.exercises, [
          for (final row in exercises)
            ExercisesCompanion.insert(
              id: _string(row, 'id'),
              name: _string(row, 'name'),
              primaryMuscle: _string(row, 'primaryMuscle', fallback: 'Custom'),
              createdAt: _date(row, 'createdAt', fallback: now),
              syncStatus: Value(_string(row, 'syncStatus', fallback: 'synced')),
            ),
        ]);

        batch.insertAll(_db.plannedWorkoutDays, [
          for (final row in trainingDays)
            PlannedWorkoutDaysCompanion.insert(
              id: _string(row, 'id'),
              dayOfWeek: _int(row, 'dayOfWeek', fallback: 1),
              dayNumber: Value(_int(row, 'dayNumber', fallback: 1)),
              customName: _string(row, 'customName'),
              restSeconds: Value(_int(row, 'restSeconds', fallback: 90)),
              setTargetSeconds: Value(
                _int(row, 'setTargetSeconds', fallback: 45),
              ),
              createdAt: _date(row, 'createdAt', fallback: now),
              updatedAt: _date(row, 'updatedAt', fallback: now),
              syncStatus: Value(_string(row, 'syncStatus', fallback: 'synced')),
            ),
        ]);

        batch.insertAll(_db.plannedDayExercises, [
          for (final row in plannedExercises)
            PlannedDayExercisesCompanion.insert(
              id: _string(row, 'id'),
              dayId: _string(row, 'dayId'),
              exerciseId: _string(row, 'exerciseId'),
              sortOrder: _int(row, 'sortOrder'),
              targetSets: Value(_int(row, 'targetSets', fallback: 3)),
              targetReps: Value(_int(row, 'targetReps', fallback: 10)),
              comment: Value(_string(row, 'comment', fallback: '')),
            ),
        ]);

        batch.insertAll(_db.workoutSessions, [
          for (final row in sessions)
            WorkoutSessionsCompanion.insert(
              id: _string(row, 'id'),
              startedAt: _date(row, 'startedAt', fallback: now),
              finishedAt: Value(_nullableDate(row, 'finishedAt')),
              templateName: Value(_nullableString(row, 'templateName')),
              templateDayNumber: Value(_nullableInt(row['templateDayNumber'])),
              syncStatus: Value(_string(row, 'syncStatus', fallback: 'synced')),
            ),
        ]);

        batch.insertAll(_db.workoutSetEntries, [
          for (final row in sets)
            WorkoutSetEntriesCompanion.insert(
              id: _string(row, 'id'),
              sessionId: _string(row, 'sessionId'),
              exerciseId: Value(_nullableString(row, 'exerciseId')),
              exerciseName: _string(row, 'exerciseName'),
              weightKg: _double(row, 'weightKg'),
              reps: _int(row, 'reps'),
              loggedAt: _date(row, 'loggedAt', fallback: now),
              syncStatus: Value(_string(row, 'syncStatus', fallback: 'synced')),
            ),
        ]);

        batch.insert(
          _db.userProfiles,
          UserProfilesCompanion.insert(
            id: 'local',
            displayName: Value(
              profileData?['displayName']?.toString().trim() ?? '',
            ),
            bodyWeightKg: Value(_nullableDouble(profileData?['bodyWeightKg'])),
            userId: Value(
              userId.trim().isNotEmpty
                  ? userId.trim()
                  : profileData?['userId']?.toString().trim(),
            ),
            email: Value(
              email.trim().isNotEmpty
                  ? email.trim().toLowerCase()
                  : profileData?['email']?.toString().trim().toLowerCase(),
            ),
            authToken: Value(authToken.trim()),
            syncCode: Value(syncCode),
            syncBaseUrl: Value(_normalizeBaseUrl(syncBaseUrl)),
            createdAt: now,
            updatedAt: now,
          ),
        );
      });
    });

    await ensureDefaultExercises();

    return SyncRunResult(
      message: 'Restored ${sets.length} sets',
      syncCode: syncCode,
      setCount: sets.length,
      sessionCount: sessions.length,
      trainingDayCount: trainingDays.length,
    );
  }

  Future<void> _autoSync() async {
    if (_isAutoSyncing) {
      return;
    }

    final profile = await loadProfile();
    if (!profile.isAuthenticated) {
      return;
    }

    _isAutoSyncing = true;
    try {
      final snapshot = await exportSyncSnapshot(profile: profile);
      await SyncApiClient(
        baseUrl: _normalizeBaseUrl(profile.syncBaseUrl),
      ).uploadMine(token: profile.authToken, snapshot: snapshot);
    } catch (_) {
      // Auto-sync must never block the workout flow. The next write retries.
    } finally {
      _isAutoSyncing = false;
    }
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  int _weekNumber(DateTime date) {
    final yearStart = DateTime(date.year);
    final dayOfYear = date.difference(yearStart).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  int _legacyWeekdayFromDayNumber(int dayNumber) {
    if (dayNumber < 1) {
      return 1;
    }
    if (dayNumber > 7) {
      return 7;
    }
    return dayNumber;
  }

  List<DateTime> _uniqueTrainingDates(Iterable<DateTime> dates) {
    final normalized = {
      for (final date in dates) DateTime(date.year, date.month, date.day),
    }.toList()..sort((a, b) => b.compareTo(a));
    return normalized;
  }

  List<ExerciseWeightStats> _buildExerciseStats(
    List<WorkoutSetEntry> sets, {
    bool sortByFirstLoggedAt = false,
  }) {
    final buckets = <String, List<WorkoutSetEntry>>{};
    for (final set in sets) {
      final key = set.exerciseId ?? set.exerciseName;
      buckets.putIfAbsent(key, () => []).add(set);
    }

    final bucketEntries = buckets.entries.toList()
      ..sort((a, b) {
        if (sortByFirstLoggedAt) {
          return _firstLoggedAt(a.value).compareTo(_firstLoggedAt(b.value));
        }

        return _lastLoggedAt(b.value).compareTo(_lastLoggedAt(a.value));
      });

    return [
      for (final entry in bucketEntries)
        ExerciseWeightStats(
          exerciseId: entry.value.first.exerciseId,
          exerciseName: entry.value.first.exerciseName,
          minWeightKg: entry.value
              .map((set) => set.weightKg)
              .reduce((min, value) => value < min ? value : min),
          maxWeightKg: entry.value
              .map((set) => set.weightKg)
              .reduce((max, value) => value > max ? value : max),
          minReps: entry.value
              .map((set) => set.reps)
              .reduce((min, value) => value < min ? value : min),
          maxReps: entry.value
              .map((set) => set.reps)
              .reduce((max, value) => value > max ? value : max),
          totalSets: entry.value.length,
          lastLoggedAt: _lastLoggedAt(entry.value),
        ),
    ];
  }

  List<TrainingDaySummary> _buildTrainingDaySummaries(
    List<WorkoutSetEntry> sets,
    List<WorkoutSession> sessions,
  ) {
    final sessionsById = {for (final session in sessions) session.id: session};
    final buckets = <DateTime, List<WorkoutSetEntry>>{};
    for (final set in sets) {
      final date = DateTime(
        set.loggedAt.year,
        set.loggedAt.month,
        set.loggedAt.day,
      );
      buckets.putIfAbsent(date, () => []).add(set);
    }

    final summaries = [
      for (final entry in buckets.entries)
        _buildTrainingDaySummary(
          date: entry.key,
          sets: entry.value,
          sessionsById: sessionsById,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return summaries;
  }

  TrainingDaySummary _buildTrainingDaySummary({
    required DateTime date,
    required List<WorkoutSetEntry> sets,
    required Map<String, WorkoutSession> sessionsById,
  }) {
    final orderedSets = [...sets]
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    final daySessions = <WorkoutSession>[];
    final seenSessionIds = <String>{};

    for (final set in orderedSets) {
      if (!seenSessionIds.add(set.sessionId)) {
        continue;
      }

      final session = sessionsById[set.sessionId];
      if (session != null) {
        daySessions.add(session);
      }
    }

    daySessions.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final primarySession =
        daySessions
            .where(
              (session) =>
                  session.templateDayNumber != null ||
                  (session.templateName?.trim().isNotEmpty ?? false),
            )
            .firstOrNull ??
        daySessions.firstOrNull;

    return TrainingDaySummary(
      date: date,
      exercises: _buildExerciseStats(orderedSets, sortByFirstLoggedAt: true),
      templateName: primarySession?.templateName,
      templateDayNumber: primarySession?.templateDayNumber,
    );
  }

  DateTime _firstLoggedAt(List<WorkoutSetEntry> sets) {
    return sets
        .map((set) => set.loggedAt)
        .reduce((first, value) => value.isBefore(first) ? value : first);
  }

  DateTime _lastLoggedAt(List<WorkoutSetEntry> sets) {
    return sets
        .map((set) => set.loggedAt)
        .reduce((last, value) => value.isAfter(last) ? value : last);
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim().isEmpty ? defaultSyncBaseUrl : value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  List<Map<String, Object?>> _listOfMaps(Object? value) {
    if (value is! List) {
      return const [];
    }

    return [
      for (final item in value)
        if (item is Map) item.cast<String, Object?>(),
    ];
  }

  String _string(Map<String, Object?> row, String key, {String fallback = ''}) {
    final value = row[key]?.toString();
    return value == null || value.isEmpty ? fallback : value;
  }

  String? _nullableString(Map<String, Object?> row, String key) {
    final value = row[key]?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  int _int(Map<String, Object?> row, String key, {int fallback = 0}) {
    final value = row[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int? _nullableInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  double _double(Map<String, Object?> row, String key, {double fallback = 0}) {
    return _nullableDouble(row[key]) ?? fallback;
  }

  double? _nullableDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  DateTime _date(
    Map<String, Object?> row,
    String key, {
    required DateTime fallback,
  }) {
    return _nullableDate(row, key) ?? fallback;
  }

  DateTime? _nullableDate(Map<String, Object?> row, String key) {
    final raw = row[key]?.toString();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }

  String _capitalizeFirst(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return '${trimmed.substring(0, 1).toUpperCase()}${trimmed.substring(1)}';
  }

  String _capitalizeWords(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(_capitalizeFirst)
        .join(' ');
  }
}

class SyncRunResult {
  const SyncRunResult({
    required this.message,
    required this.syncCode,
    required this.setCount,
    required this.sessionCount,
    required this.trainingDayCount,
  });

  final String message;
  final String syncCode;
  final int setCount;
  final int sessionCount;
  final int trainingDayCount;
}

class AuthRunResult {
  const AuthRunResult({
    required this.message,
    required this.profile,
    required this.setCount,
    required this.sessionCount,
    required this.trainingDayCount,
  });

  final String message;
  final UserProfile profile;
  final int setCount;
  final int sessionCount;
  final int trainingDayCount;
}

class SyncException implements Exception {
  SyncException(this.code, [this.cause]);

  final String code;
  final Object? cause;
}
