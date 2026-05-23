import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repos/workout_session_repository.dart';
import '../../domain/models/dashboard_snapshot.dart';

part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._repository) : super(DashboardState.initial());

  final WorkoutSessionRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    final snapshot = await _repository.loadDashboardSnapshot();
    emit(DashboardState(snapshot: snapshot, isLoading: false));
  }
}
