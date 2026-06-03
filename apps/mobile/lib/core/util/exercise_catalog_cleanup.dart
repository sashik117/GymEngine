import '../../domain/models/exercise.dart';
import '../localization/gym_labels.dart';

List<Exercise> dedupeExerciseCatalog(
  Iterable<Exercise> exercises,
  GymLabels labels,
) {
  final byKey = <String, Exercise>{};

  for (final exercise in exercises) {
    final key = exerciseDedupeKey(exercise, labels);
    final current = byKey[key];
    if (current == null ||
        exerciseCatalogQuality(exercise) > exerciseCatalogQuality(current)) {
      byKey[key] = exercise;
    }
  }

  return byKey.values.toList();
}

String exerciseDedupeKey(Exercise exercise, GymLabels labels) {
  final translated = labels.exerciseName(exercise.id, exercise.name);
  final name = normalizeExerciseLookup(
    translated.isEmpty ? exercise.name : translated,
  );
  return '$name|${exercise.primaryMuscle}';
}

int exerciseCatalogQuality(Exercise exercise) {
  var score = 0;
  final name = exercise.name.toLowerCase();
  if (exercise.imageUrl.trim().isNotEmpty) {
    score += 20;
  }
  if (exercise.videoUrl.trim().isNotEmpty) {
    score += 30;
  }
  if (exercise.sourceUrl.trim().isNotEmpty) {
    score += 8;
  }
  if (!RegExp(r'\((male|female)\)', caseSensitive: false).hasMatch(name)) {
    score += 8;
  }
  if (!RegExp(r'\bversion\b', caseSensitive: false).hasMatch(name)) {
    score += 5;
  }
  if (exercise.equipment.trim().isNotEmpty) {
    score += 3;
  }
  return score;
}

String normalizeExerciseLookup(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\((male|female)\)', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\b(male|female)\b', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\bversion\s*[-\s]*\d+\b', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\b\d+\b'), ' ')
      .replaceAll(RegExp(r'[_/\\|]+'), ' ')
      .replaceAll(RegExp(r'[^a-zа-яіїєґ0-9]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
