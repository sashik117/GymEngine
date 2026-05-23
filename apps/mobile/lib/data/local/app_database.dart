import 'package:drift/drift.dart';

import 'database_connection/database_connection_unsupported.dart'
    if (dart.library.io) 'database_connection/database_connection_native.dart'
    if (dart.library.js_interop) 'database_connection/database_connection_web.dart';

part 'app_database.g.dart';

class WorkoutSessions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get templateName => text().nullable()();
  IntColumn get templateDayNumber => integer().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get primaryMuscle => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('seeded'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class WorkoutSetEntries extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(WorkoutSessions, #id)();
  TextColumn get exerciseId => text().nullable().references(Exercises, #id)();
  TextColumn get exerciseName => text()();
  RealColumn get weightKg => real()();
  IntColumn get reps => integer()();
  DateTimeColumn get loggedAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PlannedWorkoutDays extends Table {
  TextColumn get id => text()();
  IntColumn get dayOfWeek => integer()();
  IntColumn get dayNumber => integer().withDefault(const Constant(1))();
  TextColumn get customName => text()();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();
  IntColumn get setTargetSeconds => integer().withDefault(const Constant(45))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PlannedDayExercises extends Table {
  TextColumn get id => text()();
  TextColumn get dayId => text().references(PlannedWorkoutDays, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get sortOrder => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetReps => integer().withDefault(const Constant(10))();
  TextColumn get comment => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class UserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  RealColumn get bodyWeightKg => real().nullable()();
  TextColumn get userId => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get authToken => text().nullable()();
  TextColumn get syncCode => text().nullable()();
  TextColumn get syncBaseUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    WorkoutSessions,
    Exercises,
    WorkoutSetEntries,
    PlannedWorkoutDays,
    PlannedDayExercises,
    UserProfiles,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) => migrator.createAll(),
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.createTable(exercises);
          await migrator.addColumn(
            workoutSetEntries,
            workoutSetEntries.exerciseId,
          );
        }
        if (from < 3) {
          await migrator.createTable(plannedWorkoutDays);
          await migrator.createTable(plannedDayExercises);
        }
        if (from < 4) {
          await migrator.addColumn(
            plannedWorkoutDays,
            plannedWorkoutDays.restSeconds,
          );
          await migrator.addColumn(
            plannedWorkoutDays,
            plannedWorkoutDays.setTargetSeconds,
          );
        }
        if (from < 5) {
          await migrator.addColumn(
            plannedDayExercises,
            plannedDayExercises.targetSets,
          );
        }
        if (from < 6) {
          await migrator.addColumn(
            plannedDayExercises,
            plannedDayExercises.targetReps,
          );
        }
        if (from < 7) {
          await migrator.createTable(userProfiles);
        }
        if (from < 8) {
          await migrator.addColumn(
            plannedWorkoutDays,
            plannedWorkoutDays.dayNumber,
          );
          await migrator.addColumn(
            workoutSessions,
            workoutSessions.templateName,
          );
          await migrator.addColumn(
            workoutSessions,
            workoutSessions.templateDayNumber,
          );
          await customStatement(
            'UPDATE planned_workout_days SET day_number = day_of_week',
          );
        }
        if (from < 9) {
          await migrator.addColumn(userProfiles, userProfiles.syncCode);
          await migrator.addColumn(userProfiles, userProfiles.syncBaseUrl);
        }
        if (from < 10) {
          await migrator.addColumn(userProfiles, userProfiles.userId);
          await migrator.addColumn(userProfiles, userProfiles.email);
          await migrator.addColumn(userProfiles, userProfiles.authToken);
        }
        if (from < 11) {
          await migrator.addColumn(
            plannedDayExercises,
            plannedDayExercises.comment,
          );
        }
      },
    );
  }
}
