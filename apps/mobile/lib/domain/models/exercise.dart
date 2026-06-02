import 'package:equatable/equatable.dart';

class Exercise extends Equatable {
  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    this.bodyPart = '',
    this.equipment = '',
    this.exerciseType = '',
    this.imageUrl = '',
    this.videoUrl = '',
    this.sourceUrl = '',
  });

  final String id;
  final String name;
  final String primaryMuscle;
  final String bodyPart;
  final String equipment;
  final String exerciseType;
  final String imageUrl;
  final String videoUrl;
  final String sourceUrl;

  Exercise copyWith({
    String? id,
    String? name,
    String? primaryMuscle,
    String? bodyPart,
    String? equipment,
    String? exerciseType,
    String? imageUrl,
    String? videoUrl,
    String? sourceUrl,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryMuscle: primaryMuscle ?? this.primaryMuscle,
      bodyPart: bodyPart ?? this.bodyPart,
      equipment: equipment ?? this.equipment,
      exerciseType: exerciseType ?? this.exerciseType,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    primaryMuscle,
    bodyPart,
    equipment,
    exerciseType,
    imageUrl,
    videoUrl,
    sourceUrl,
  ];
}
