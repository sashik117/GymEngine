import 'package:flutter_test/flutter_test.dart';
import 'package:gym_engine/domain/calculators/exercise_muscle_classifier.dart';

void main() {
  group('ExerciseMuscleClassifier', () {
    test('keeps known raw muscle values', () {
      expect(
        ExerciseMuscleClassifier.classify(
          exerciseName: 'Machine chest press',
          rawMuscle: 'Chest',
        ),
        'Chest',
      );
    });

    test('infers muscle from exercise names when raw value is missing', () {
      expect(
        ExerciseMuscleClassifier.classify(exerciseName: 'Barbell curl'),
        'Biceps',
      );
      expect(
        ExerciseMuscleClassifier.classify(exerciseName: 'Standing calf raise'),
        'Calves',
      );
      expect(
        ExerciseMuscleClassifier.classify(exerciseName: 'Hip thrust'),
        'Glutes',
      );
    });
  });
}
