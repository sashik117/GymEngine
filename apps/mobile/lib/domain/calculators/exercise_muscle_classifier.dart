class ExerciseMuscleClassifier {
  const ExerciseMuscleClassifier._();

  static String classify({required String exerciseName, String? rawMuscle}) {
    return normalizePrimaryMuscle(rawMuscle) ??
        inferPrimaryMuscleFromName(exerciseName);
  }

  static String? normalizePrimaryMuscle(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    const known = {
      'Chest',
      'Quads',
      'Posterior',
      'Shoulders',
      'Back',
      'Glutes',
      'Hamstrings',
      'Biceps',
      'Triceps',
      'Core',
      'Calves',
      'Forearms',
      'Neck',
    };
    if (known.contains(normalized)) {
      return normalized;
    }

    final key = lookupKey(normalized);
    const localized = {
      'груди': 'Chest',
      'квадрицепси': 'Quads',
      'задній ланцюг': 'Posterior',
      'плечі': 'Shoulders',
      'спина': 'Back',
      'сідниці': 'Glutes',
      'біцепс стегна': 'Hamstrings',
      'біцепс': 'Biceps',
      'трицепс': 'Triceps',
      'прес': 'Core',
      'ікри': 'Calves',
      'передпліччя': 'Forearms',
      'шия': 'Neck',
    };
    return localized[key];
  }

  static String inferPrimaryMuscleFromName(String value) {
    final text = lookupKey(value);
    bool has(List<String> patterns) => patterns.any(text.contains);

    if (has(['трицепс'])) {
      return 'Triceps';
    }
    if (has(['біцепс', 'молот'])) {
      return 'Biceps';
    }
    if (has(['ікр', 'ікра'])) {
      return 'Calves';
    }
    if (has(['прес', 'планк'])) {
      return 'Core';
    }
    if (has(['сідниц', 'відведення ноги', 'відведення стегна', 'хіп'])) {
      return 'Glutes';
    }
    if (has(['згинання ніг'])) {
      return 'Hamstrings';
    }
    if (has(['станов', 'румун'])) {
      return 'Posterior';
    }
    if (has(['присід', 'жим ног', 'розгинання ніг', 'випад'])) {
      return 'Quads';
    }
    if (has(['плеч', 'дельт', 'махи'])) {
      return 'Shoulders';
    }
    if (has(['груд', 'жим леж'])) {
      return 'Chest';
    }
    if (has(['спин', 'тяга верх', 'горизонтальна тяга', 'підтяг'])) {
      return 'Back';
    }
    if (has(['передпліч'])) {
      return 'Forearms';
    }
    if (has(['шия'])) {
      return 'Neck';
    }

    if (has(['calf', 'ікр', 'ікра'])) {
      return 'Calves';
    }
    if (has(['neck', 'шия'])) {
      return 'Neck';
    }
    if (has([
      'wrist',
      'forearm',
      'finger',
      'fingers',
      'finger curl',
      'farmer',
      'передпліч',
    ])) {
      return 'Forearms';
    }
    if (has(['crunch', 'plank', 'abs', 'sit up', 'leg raise', 'прес'])) {
      return 'Core';
    }
    if (has(['triceps', 'трицепс', 'pushdown', 'skullcrusher', 'bench dip'])) {
      return 'Triceps';
    }
    if (has(['biceps', 'біцепс', 'brachialis', 'curl', 'hammer'])) {
      return 'Biceps';
    }
    if (has(['glute', 'hip thrust', 'bridge', 'kickback', 'сідниц'])) {
      return 'Glutes';
    }
    if (has(['hamstring', 'leg curl', 'nordic', 'згинання ніг'])) {
      return 'Hamstrings';
    }
    if (has([
      'deadlift',
      'good morning',
      'back extension',
      'станов',
      'румун',
    ])) {
      return 'Posterior';
    }
    if (has(['squat', 'leg press', 'leg extension', 'lunge', 'присід'])) {
      return 'Quads';
    }
    if (has([
      'shoulder',
      'delt',
      'lateral raise',
      'front raise',
      'face pull',
    ])) {
      return 'Shoulders';
    }
    if (has(['bench press', 'chest', 'fly', 'pec', 'push up', 'груд'])) {
      return 'Chest';
    }
    if (has(['row', 'pulldown', 'pull up', 'chin up', 'shrug', 'back'])) {
      return 'Back';
    }
    return 'Custom';
  }

  static String lookupKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\((male|female)\)', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(male|female)\b', caseSensitive: false), ' ')
        .replaceAll(
          RegExp(r'\bversion\s*[-\s]*\d+\b', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\b\d+\b'), ' ')
        .replaceAll(RegExp(r'[_/\\|°]+'), ' ')
        .replaceAll(RegExp(r'[^a-zа-яіїєґ0-9]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
