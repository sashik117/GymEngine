import 'package:equatable/equatable.dart';

class ProgressPhoto extends Equatable {
  const ProgressPhoto({
    required this.id,
    required this.imageDataUrl,
    required this.capturedAt,
    required this.createdAt,
    this.note = '',
  });

  final String id;
  final String imageDataUrl;
  final String note;
  final DateTime capturedAt;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, imageDataUrl, note, capturedAt, createdAt];
}
