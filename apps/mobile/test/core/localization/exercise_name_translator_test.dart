import 'package:flutter_test/flutter_test.dart';
import 'package:gym_engine/core/localization/exercise_name_translator.dart';

void main() {
  group('translateExerciseNameUk', () {
    test('translates good morning variants into readable Ukrainian', () {
      expect(
        translateExerciseNameUk('Barbell Good Morning'),
        'Нахили зі штангою',
      );
      expect(
        translateExerciseNameUk('PVC Good Morning'),
        'Нахили з PVC-палицею',
      );
      expect(
        translateExerciseNameUk('Good Morning Squat'),
        'Присідання з нахилом корпусу',
      );
    });
  });
}
