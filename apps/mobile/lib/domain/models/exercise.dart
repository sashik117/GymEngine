import 'package:equatable/equatable.dart';

class Exercise extends Equatable {
  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
  });

  final String id;
  final String name;
  final String primaryMuscle;

  @override
  List<Object?> get props => [id, name, primaryMuscle];
}
