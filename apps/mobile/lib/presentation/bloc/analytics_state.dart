part of 'analytics_cubit.dart';

class AnalyticsState extends Equatable {
  const AnalyticsState({required this.snapshot, required this.isLoading});

  AnalyticsState.initial()
    : snapshot = AnalyticsSnapshot.empty(),
      isLoading = true;

  final AnalyticsSnapshot snapshot;
  final bool isLoading;

  AnalyticsState copyWith({AnalyticsSnapshot? snapshot, bool? isLoading}) {
    return AnalyticsState(
      snapshot: snapshot ?? this.snapshot,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [snapshot, isLoading];
}
