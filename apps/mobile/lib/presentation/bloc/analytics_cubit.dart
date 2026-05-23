import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repos/workout_session_repository.dart';
import '../../domain/models/analytics_snapshot.dart';

part 'analytics_state.dart';

class AnalyticsCubit extends Cubit<AnalyticsState> {
  AnalyticsCubit(this._repository) : super(AnalyticsState.initial());

  final WorkoutSessionRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    final snapshot = await _repository.loadAnalyticsSnapshot();
    emit(AnalyticsState(snapshot: snapshot, isLoading: false));
  }
}
