part of 'dashboard_cubit.dart';

class DashboardState extends Equatable {
  const DashboardState({required this.snapshot, required this.isLoading});

  DashboardState.initial()
    : snapshot = DashboardSnapshot.empty(),
      isLoading = true;

  final DashboardSnapshot snapshot;
  final bool isLoading;

  DashboardState copyWith({DashboardSnapshot? snapshot, bool? isLoading}) {
    return DashboardState(
      snapshot: snapshot ?? this.snapshot,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [snapshot, isLoading];
}
