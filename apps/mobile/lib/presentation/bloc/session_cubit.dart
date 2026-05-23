import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repos/workout_session_repository.dart';
import '../../domain/models/training_day_plan.dart';
import '../../domain/models/workout_set.dart';

part 'session_state.dart';

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._repository, {TrainingDayPlan? plan})
    : _plan = plan,
      super(SessionState.initial());

  final WorkoutSessionRepository _repository;
  final TrainingDayPlan? _plan;

  Future<void> startSession() async {
    if (state.sessionId != null) {
      return;
    }

    final openSession = await _repository.loadOpenSession(
      templateName: _plan?.name,
      templateDayNumber: _plan?.dayNumber,
    );
    if (openSession != null) {
      emit(
        SessionState(
          startedAt: openSession.startedAt,
          sessionId: openSession.sessionId,
          sets: openSession.sets,
        ),
      );
      return;
    }

    final sessionId = await _repository.createSession(
      state.startedAt,
      templateName: _plan?.name,
      templateDayNumber: _plan?.dayNumber,
    );
    emit(state.copyWith(sessionId: sessionId));
  }

  Future<bool> logSet({
    required String? exerciseId,
    required String exerciseName,
    required double weightKg,
    required int reps,
  }) async {
    final sessionId = await _ensureSessionId();
    if (exerciseName.trim().isEmpty || weightKg <= 0 || reps <= 0) {
      return false;
    }

    final set = WorkoutSet(
      exerciseId: exerciseId,
      exerciseName: exerciseName.trim(),
      weightKg: weightKg,
      reps: reps,
      loggedAt: DateTime.now(),
    );

    final setId = await _repository.logSet(sessionId: sessionId, set: set);
    emit(
      state.copyWith(
        sets: [
          ...state.sets,
          set.copyWith(id: setId),
        ],
      ),
    );
    return true;
  }

  Future<void> cancelSet(WorkoutSet set) async {
    final setId = set.id;
    if (setId != null) {
      await _repository.deleteSet(setId);
    }
    emit(
      state.copyWith(sets: state.sets.where((item) => item != set).toList()),
    );
  }

  Future<void> finishSession() async {
    final sessionId = await _ensureSessionId();
    final finishedAt = DateTime.now();
    await _repository.finishSession(
      sessionId: sessionId,
      finishedAt: finishedAt,
    );
    emit(state.copyWith(finishedAt: finishedAt));
  }

  Future<String> _ensureSessionId() async {
    final existingSessionId = state.sessionId;
    if (existingSessionId != null) {
      return existingSessionId;
    }

    final sessionId = await _repository.createSession(
      state.startedAt,
      templateName: _plan?.name,
      templateDayNumber: _plan?.dayNumber,
    );
    emit(state.copyWith(sessionId: sessionId));
    return sessionId;
  }
}
