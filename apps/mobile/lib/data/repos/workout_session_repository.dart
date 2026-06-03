import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/analytics_snapshot.dart';
import '../../domain/models/dashboard_snapshot.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_history.dart';
import '../../domain/models/progress_photo.dart';
import '../../domain/models/training_day_plan.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/workout_set.dart';
import '../../domain/models/workout_session_draft.dart';
import '../catalog/lyfta_exercise_catalog.dart';
import '../local/app_database.dart' hide Exercise, UserProfile;
import '../sync/sync_api_client.dart';
import '../../domain/calculators/exercise_history_calculator.dart';
import '../../domain/calculators/exercise_muscle_classifier.dart';
import '../../domain/calculators/training_calendar.dart';
import '../../domain/calculators/training_plan_scheduler.dart';
import '../../domain/calculators/workout_analytics_calculator.dart';

class WorkoutSessionRepository {
  WorkoutSessionRepository(this._db, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;
  var _isAutoSyncing = false;
  var _didEnsureDefaultExercises = false;

  static final _defaultExercises = [
    Exercise(id: 'bench_press', name: 'Bench Press', primaryMuscle: 'Chest'),
    Exercise(
      id: 'barbell_bench_press',
      name: 'Barbell Bench Press',
      primaryMuscle: 'Chest',
    ),
    Exercise(
      id: 'dumbbell_bench_press',
      name: 'Dumbbell Bench Press',
      primaryMuscle: 'Chest',
    ),
    Exercise(
      id: 'incline_press',
      name: 'Incline Press',
      primaryMuscle: 'Chest',
    ),
    Exercise(
      id: 'incline_bench_press',
      name: 'Incline Bench Press',
      primaryMuscle: 'Chest',
    ),
    Exercise(
      id: 'dumbbell_incline_bench_press',
      name: 'Dumbbell Incline Bench Press',
      primaryMuscle: 'Chest',
    ),
    Exercise(
      id: 'decline_bench_press',
      name: 'Decline Bench Press',
      primaryMuscle: 'Chest',
    ),
    Exercise(id: 'chest_dip', name: 'Chest Dip', primaryMuscle: 'Chest'),
    Exercise(id: 'push_up', name: 'Push-Up', primaryMuscle: 'Chest'),
    Exercise(
      id: 'decline_push_up',
      name: 'Decline Push-Up',
      primaryMuscle: 'Chest',
    ),
    Exercise(
      id: 'lever_chest_press',
      name: 'Lever Chest Press',
      primaryMuscle: 'Chest',
    ),
    Exercise(id: 'pec_deck_fly', name: 'Pec Deck Fly', primaryMuscle: 'Chest'),
    Exercise(id: 'dumbbell_fly', name: 'Dumbbell Fly', primaryMuscle: 'Chest'),
    Exercise(id: 'cable_fly', name: 'Cable Fly', primaryMuscle: 'Chest'),
    Exercise(
      id: 'cable_middle_fly',
      name: 'Cable Middle Fly',
      primaryMuscle: 'Chest',
    ),
    Exercise(id: 'squat', name: 'Squat', primaryMuscle: 'Quads'),
    Exercise(id: 'front_squat', name: 'Front Squat', primaryMuscle: 'Quads'),
    Exercise(id: 'goblet_squat', name: 'Goblet Squat', primaryMuscle: 'Quads'),
    Exercise(id: 'smith_squat', name: 'Smith Squat', primaryMuscle: 'Quads'),
    Exercise(id: 'hack_squat', name: 'Hack Squat', primaryMuscle: 'Quads'),
    Exercise(
      id: 'bulgarian_split_squat',
      name: 'Bulgarian Split Squat',
      primaryMuscle: 'Quads',
    ),
    Exercise(
      id: 'walking_lunge',
      name: 'Walking Lunge',
      primaryMuscle: 'Quads',
    ),
    Exercise(id: 'leg_press', name: 'Leg Press', primaryMuscle: 'Quads'),
    Exercise(
      id: 'sled_45_leg_press',
      name: '45 Degree Leg Press',
      primaryMuscle: 'Quads',
    ),
    Exercise(id: 'lunge', name: 'Lunge', primaryMuscle: 'Quads'),
    Exercise(
      id: 'leg_extension',
      name: 'Leg Extension',
      primaryMuscle: 'Quads',
    ),
    Exercise(
      id: 'lever_leg_extension',
      name: 'Lever Leg Extension',
      primaryMuscle: 'Quads',
    ),
    Exercise(id: 'deadlift', name: 'Deadlift', primaryMuscle: 'Posterior'),
    Exercise(
      id: 'straight_leg_deadlift',
      name: 'Straight Leg Deadlift',
      primaryMuscle: 'Posterior',
    ),
    Exercise(
      id: 'sumo_deadlift',
      name: 'Sumo Deadlift',
      primaryMuscle: 'Posterior',
    ),
    Exercise(
      id: 'good_morning',
      name: 'Good Morning',
      primaryMuscle: 'Posterior',
    ),
    Exercise(
      id: 'back_extension',
      name: 'Back Extension',
      primaryMuscle: 'Posterior',
    ),
    Exercise(
      id: 'romanian_deadlift',
      name: 'Romanian Deadlift',
      primaryMuscle: 'Posterior',
    ),
    Exercise(id: 'hip_thrust', name: 'Hip Thrust', primaryMuscle: 'Glutes'),
    Exercise(
      id: 'single_leg_hip_thrust',
      name: 'Single Leg Hip Thrust',
      primaryMuscle: 'Glutes',
    ),
    Exercise(id: 'glute_bridge', name: 'Glute Bridge', primaryMuscle: 'Glutes'),
    Exercise(
      id: 'cable_kickback',
      name: 'Cable Kickback',
      primaryMuscle: 'Glutes',
    ),
    Exercise(
      id: 'hip_abduction',
      name: 'Hip Abduction',
      primaryMuscle: 'Glutes',
    ),
    Exercise(
      id: 'lever_hip_abduction',
      name: 'Lever Hip Abduction',
      primaryMuscle: 'Glutes',
    ),
    Exercise(id: 'leg_curl', name: 'Leg Curl', primaryMuscle: 'Hamstrings'),
    Exercise(
      id: 'lying_leg_curl',
      name: 'Lying Leg Curl',
      primaryMuscle: 'Hamstrings',
    ),
    Exercise(
      id: 'seated_leg_curl',
      name: 'Seated Leg Curl',
      primaryMuscle: 'Hamstrings',
    ),
    Exercise(
      id: 'nordic_curl',
      name: 'Nordic Curl',
      primaryMuscle: 'Hamstrings',
    ),
    Exercise(
      id: 'standing_calf_raise',
      name: 'Standing Calf Raise',
      primaryMuscle: 'Calves',
    ),
    Exercise(
      id: 'seated_calf_raise',
      name: 'Seated Calf Raise',
      primaryMuscle: 'Calves',
    ),
    Exercise(
      id: 'smith_calf_raise',
      name: 'Smith Calf Raise',
      primaryMuscle: 'Calves',
    ),
    Exercise(
      id: 'overhead_press',
      name: 'Overhead Press',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'military_press',
      name: 'Military Press',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'seated_shoulder_press',
      name: 'Seated Shoulder Press',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'dumbbell_shoulder_press',
      name: 'Dumbbell Shoulder Press',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'arnold_press',
      name: 'Arnold Press',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'lateral_raise',
      name: 'Lateral Raise',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'seated_lateral_raise',
      name: 'Seated Lateral Raise',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'front_raise',
      name: 'Front Raise',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'rear_delt_fly',
      name: 'Rear Delt Fly',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(id: 'face_pull', name: 'Face Pull', primaryMuscle: 'Shoulders'),
    Exercise(
      id: 'upright_row',
      name: 'Upright Row',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(id: 'barbell_row', name: 'Barbell Row', primaryMuscle: 'Back'),
    Exercise(id: 'bent_over_row', name: 'Bent Over Row', primaryMuscle: 'Back'),
    Exercise(id: 'one_arm_row', name: 'One Arm Row', primaryMuscle: 'Back'),
    Exercise(id: 't_bar_row', name: 'T-Bar Row', primaryMuscle: 'Back'),
    Exercise(id: 'pull_up', name: 'Pull-Up', primaryMuscle: 'Back'),
    Exercise(id: 'chin_up', name: 'Chin-Up', primaryMuscle: 'Back'),
    Exercise(id: 'lat_pulldown', name: 'Lat Pulldown', primaryMuscle: 'Back'),
    Exercise(
      id: 'v_bar_pulldown',
      name: 'V-Bar Pulldown',
      primaryMuscle: 'Back',
    ),
    Exercise(
      id: 'straight_arm_pulldown',
      name: 'Straight Arm Pulldown',
      primaryMuscle: 'Back',
    ),
    Exercise(id: 'seated_row', name: 'Seated Row', primaryMuscle: 'Back'),
    Exercise(
      id: 'low_seated_row',
      name: 'Low Seated Row',
      primaryMuscle: 'Back',
    ),
    Exercise(id: 'shrug', name: 'Shrug', primaryMuscle: 'Back'),
    Exercise(
      id: 'dumbbell_shrug',
      name: 'Dumbbell Shrug',
      primaryMuscle: 'Back',
    ),
    Exercise(id: 'biceps_curl', name: 'Biceps Curl', primaryMuscle: 'Biceps'),
    Exercise(id: 'barbell_curl', name: 'Barbell Curl', primaryMuscle: 'Biceps'),
    Exercise(id: 'hammer_curl', name: 'Hammer Curl', primaryMuscle: 'Biceps'),
    Exercise(
      id: 'preacher_curl',
      name: 'Preacher Curl',
      primaryMuscle: 'Biceps',
    ),
    Exercise(
      id: 'incline_dumbbell_curl',
      name: 'Incline Dumbbell Curl',
      primaryMuscle: 'Biceps',
    ),
    Exercise(
      id: 'cable_biceps_curl',
      name: 'Cable Biceps Curl',
      primaryMuscle: 'Biceps',
    ),
    Exercise(
      id: 'concentration_curl',
      name: 'Concentration Curl',
      primaryMuscle: 'Biceps',
    ),
    Exercise(
      id: 'triceps_pushdown',
      name: 'Triceps Pushdown',
      primaryMuscle: 'Triceps',
    ),
    Exercise(
      id: 'rope_pushdown',
      name: 'Rope Pushdown',
      primaryMuscle: 'Triceps',
    ),
    Exercise(
      id: 'skull_crusher',
      name: 'Skull Crusher',
      primaryMuscle: 'Triceps',
    ),
    Exercise(
      id: 'overhead_triceps_extension',
      name: 'Overhead Triceps Extension',
      primaryMuscle: 'Triceps',
    ),
    Exercise(
      id: 'close_grip_push_up',
      name: 'Close-Grip Push-Up',
      primaryMuscle: 'Triceps',
    ),
    Exercise(id: 'triceps_dip', name: 'Triceps Dip', primaryMuscle: 'Triceps'),
    Exercise(
      id: 'weighted_triceps_dip',
      name: 'Weighted Triceps Dip',
      primaryMuscle: 'Triceps',
    ),
    Exercise(id: 'plank', name: 'Plank', primaryMuscle: 'Core'),
    Exercise(id: 'front_plank', name: 'Front Plank', primaryMuscle: 'Core'),
    Exercise(id: 'side_plank', name: 'Side Plank', primaryMuscle: 'Core'),
    Exercise(id: 'crunch', name: 'Crunch', primaryMuscle: 'Core'),
    Exercise(id: 'sit_up', name: 'Sit-Up', primaryMuscle: 'Core'),
    Exercise(id: 'cable_crunch', name: 'Cable Crunch', primaryMuscle: 'Core'),
    Exercise(id: 'russian_twist', name: 'Russian Twist', primaryMuscle: 'Core'),
    Exercise(
      id: 'bicycle_crunch',
      name: 'Bicycle Crunch',
      primaryMuscle: 'Core',
    ),
    Exercise(
      id: 'hanging_leg_raise',
      name: 'Hanging Leg Raise',
      primaryMuscle: 'Core',
    ),
    Exercise(id: 'wrist_curl', name: 'Wrist Curl', primaryMuscle: 'Forearms'),
    Exercise(
      id: 'reverse_wrist_curl',
      name: 'Reverse Wrist Curl',
      primaryMuscle: 'Forearms',
    ),
    Exercise(
      id: 'smith_bench_press',
      name: 'Smith Bench Press',
      primaryMuscle: 'Chest',
    ),
    Exercise(
      id: 'close_grip_bench_press',
      name: 'Close-Grip Bench Press',
      primaryMuscle: 'Triceps',
    ),
    Exercise(
      id: 'incline_dumbbell_fly',
      name: 'Incline Dumbbell Fly',
      primaryMuscle: 'Chest',
    ),
    Exercise(
      id: 'decline_dumbbell_press',
      name: 'Decline Dumbbell Press',
      primaryMuscle: 'Chest',
    ),
    Exercise(
      id: 'machine_chest_press',
      name: 'Machine Chest Press',
      primaryMuscle: 'Chest',
    ),
    Exercise(
      id: 'cable_low_fly',
      name: 'Cable Low Fly',
      primaryMuscle: 'Chest',
    ),
    Exercise(
      id: 'cable_high_fly',
      name: 'Cable High Fly',
      primaryMuscle: 'Chest',
    ),
    Exercise(
      id: 'dumbbell_pullover',
      name: 'Dumbbell Pullover',
      primaryMuscle: 'Chest',
    ),
    Exercise(id: 'step_up', name: 'Step-Up', primaryMuscle: 'Quads'),
    Exercise(
      id: 'reverse_lunge',
      name: 'Reverse Lunge',
      primaryMuscle: 'Quads',
    ),
    Exercise(id: 'smith_lunge', name: 'Smith Lunge', primaryMuscle: 'Quads'),
    Exercise(id: 'sissy_squat', name: 'Sissy Squat', primaryMuscle: 'Quads'),
    Exercise(id: 'wall_sit', name: 'Wall Sit', primaryMuscle: 'Quads'),
    Exercise(
      id: 'hip_adduction',
      name: 'Hip Adduction',
      primaryMuscle: 'Glutes',
    ),
    Exercise(
      id: 'cable_abduction',
      name: 'Cable Hip Abduction',
      primaryMuscle: 'Glutes',
    ),
    Exercise(id: 'frog_pump', name: 'Frog Pump', primaryMuscle: 'Glutes'),
    Exercise(
      id: 'glute_ham_raise',
      name: 'Glute Ham Raise',
      primaryMuscle: 'Hamstrings',
    ),
    Exercise(
      id: 'single_leg_rdl',
      name: 'Single Leg Romanian Deadlift',
      primaryMuscle: 'Posterior',
    ),
    Exercise(
      id: 'stiff_leg_deadlift',
      name: 'Stiff Leg Deadlift',
      primaryMuscle: 'Posterior',
    ),
    Exercise(
      id: 'kettlebell_swing',
      name: 'Kettlebell Swing',
      primaryMuscle: 'Posterior',
    ),
    Exercise(
      id: 'donkey_calf_raise',
      name: 'Donkey Calf Raise',
      primaryMuscle: 'Calves',
    ),
    Exercise(id: 'calf_press', name: 'Calf Press', primaryMuscle: 'Calves'),
    Exercise(
      id: 'wide_grip_lat_pulldown',
      name: 'Wide Grip Lat Pulldown',
      primaryMuscle: 'Back',
    ),
    Exercise(
      id: 'reverse_grip_pulldown',
      name: 'Reverse Grip Pulldown',
      primaryMuscle: 'Back',
    ),
    Exercise(id: 'cable_row', name: 'Cable Row', primaryMuscle: 'Back'),
    Exercise(id: 'machine_row', name: 'Machine Row', primaryMuscle: 'Back'),
    Exercise(
      id: 'chest_supported_row',
      name: 'Chest Supported Row',
      primaryMuscle: 'Back',
    ),
    Exercise(id: 'inverted_row', name: 'Inverted Row', primaryMuscle: 'Back'),
    Exercise(id: 'rack_pull', name: 'Rack Pull', primaryMuscle: 'Back'),
    Exercise(
      id: 'assisted_pull_up',
      name: 'Assisted Pull-Up',
      primaryMuscle: 'Back',
    ),
    Exercise(
      id: 'single_arm_pulldown',
      name: 'Single Arm Pulldown',
      primaryMuscle: 'Back',
    ),
    Exercise(
      id: 'machine_pullover',
      name: 'Machine Pullover',
      primaryMuscle: 'Back',
    ),
    Exercise(
      id: 'cable_lateral_raise',
      name: 'Cable Lateral Raise',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'machine_lateral_raise',
      name: 'Machine Lateral Raise',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'bent_over_lateral_raise',
      name: 'Bent Over Lateral Raise',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'reverse_pec_deck',
      name: 'Reverse Pec Deck',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'cable_rear_delt_fly',
      name: 'Cable Rear Delt Fly',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'machine_shoulder_press',
      name: 'Machine Shoulder Press',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(
      id: 'landmine_press',
      name: 'Landmine Press',
      primaryMuscle: 'Shoulders',
    ),
    Exercise(id: 'y_raise', name: 'Y Raise', primaryMuscle: 'Shoulders'),
    Exercise(id: 'ez_bar_curl', name: 'EZ-Bar Curl', primaryMuscle: 'Biceps'),
    Exercise(id: 'spider_curl', name: 'Spider Curl', primaryMuscle: 'Biceps'),
    Exercise(
      id: 'cable_hammer_curl',
      name: 'Cable Hammer Curl',
      primaryMuscle: 'Biceps',
    ),
    Exercise(id: 'reverse_curl', name: 'Reverse Curl', primaryMuscle: 'Biceps'),
    Exercise(id: 'zottman_curl', name: 'Zottman Curl', primaryMuscle: 'Biceps'),
    Exercise(id: 'drag_curl', name: 'Drag Curl', primaryMuscle: 'Biceps'),
    Exercise(
      id: 'machine_preacher_curl',
      name: 'Machine Preacher Curl',
      primaryMuscle: 'Biceps',
    ),
    Exercise(
      id: 'cable_overhead_extension',
      name: 'Cable Overhead Triceps Extension',
      primaryMuscle: 'Triceps',
    ),
    Exercise(
      id: 'dumbbell_triceps_extension',
      name: 'Dumbbell Triceps Extension',
      primaryMuscle: 'Triceps',
    ),
    Exercise(id: 'bench_dip', name: 'Bench Dip', primaryMuscle: 'Triceps'),
    Exercise(
      id: 'triceps_kickback',
      name: 'Triceps Kickback',
      primaryMuscle: 'Triceps',
    ),
    Exercise(
      id: 'machine_triceps_extension',
      name: 'Machine Triceps Extension',
      primaryMuscle: 'Triceps',
    ),
    Exercise(id: 'ab_wheel', name: 'Ab Wheel', primaryMuscle: 'Core'),
    Exercise(
      id: 'reverse_crunch',
      name: 'Reverse Crunch',
      primaryMuscle: 'Core',
    ),
    Exercise(id: 'dead_bug', name: 'Dead Bug', primaryMuscle: 'Core'),
    Exercise(
      id: 'mountain_climber',
      name: 'Mountain Climber',
      primaryMuscle: 'Core',
    ),
    Exercise(
      id: 'hanging_knee_raise',
      name: 'Hanging Knee Raise',
      primaryMuscle: 'Core',
    ),
    Exercise(
      id: 'decline_sit_up',
      name: 'Decline Sit-Up',
      primaryMuscle: 'Core',
    ),
    Exercise(id: 'pallof_press', name: 'Pallof Press', primaryMuscle: 'Core'),
    Exercise(id: 'wood_chop', name: 'Wood Chop', primaryMuscle: 'Core'),
    Exercise(
      id: 'farmer_carry',
      name: 'Farmer Carry',
      primaryMuscle: 'Forearms',
    ),
    Exercise(id: 'hollow_hold', name: 'Hollow Hold', primaryMuscle: 'Core'),
    Exercise(id: 'neck_flexion', name: 'Neck Flexion', primaryMuscle: 'Neck'),
    for (final seed in lyftaExerciseCatalog) _exerciseFromLyftaSeed(seed),
  ];

  static String get defaultSyncBaseUrl =>
      kIsWeb ? 'http://127.0.0.1:3017/api' : 'http://192.168.1.104:3017/api';
  static const _syncChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _manualCatalogAliases = {
    'bench_press': 'Barbell Bench Press',
    'incline_press': 'Barbell Incline Bench Press',
    'dumbbell_fly': 'Dumbbell Fly',
    'squat': 'Barbell Squat',
    'front_squat': 'Barbell Front Squat',
    'leg_press': 'Sled 45° Leg Press',
    'sled_45_leg_press': 'Sled 45° Leg Press',
    'leg_extension': 'Lever Leg Extension',
    'deadlift': 'Barbell Deadlift',
    'romanian_deadlift': 'Barbell Romanian Deadlift',
    'hip_thrust': 'Barbell Hip Thrust',
    'glute_bridge': 'Barbell Glute Bridge',
    'leg_curl': 'Lever Lying Leg Curl',
    'overhead_press': 'Barbell Standing Overhead Press',
    'lateral_raise': 'Dumbbell Lateral Raise',
    'rear_delt_fly': 'Dumbbell Rear Lateral Raise',
    'barbell_row': 'Barbell Bent Over Row',
    'one_arm_row': 'One Arm Row',
    'pull_up': 'Pull-Up',
    'lat_pulldown': 'Cable Lat Pulldown Full Range Of Motion',
    'seated_row': 'Cable Seated Row',
    'biceps_curl': 'Dumbbell Biceps Curl',
    'hammer_curl': 'Dumbbell Hammer Curl',
    'triceps_pushdown': 'Cable Triceps Pushdown',
    'skull_crusher': 'EZ Bar California Skullcrusher',
    'plank': 'Front Plank',
    'cable_crunch': 'Cable Kneeling Crunch',
  };
  static final _catalogMediaById = _buildCatalogMediaById();
  static final _catalogMediaByName = _buildCatalogMediaByName();

  static Exercise _exerciseFromLyftaSeed(LyftaExerciseSeed seed) {
    final primaryMuscle = _catalogPrimaryMuscle(
      name: seed.name,
      rawMuscle: seed.primaryMuscle,
      bodyPart: seed.bodyPart,
      imageUrl: seed.imageUrl,
    );
    return Exercise(
      id: seed.id,
      name: _capitalizeWords(seed.name),
      primaryMuscle: primaryMuscle,
      bodyPart: seed.bodyPart,
      equipment: seed.equipment,
      exerciseType: seed.exerciseType,
      imageUrl: _safeCatalogMediaUrl(seed.imageUrl, primaryMuscle),
      videoUrl: _safeCatalogMediaUrl(seed.videoUrl, primaryMuscle),
      sourceUrl: seed.sourceUrl,
    );
  }

  static String _catalogPrimaryMuscle({
    required String name,
    required String rawMuscle,
    required String bodyPart,
    required String imageUrl,
  }) {
    final inferred = ExerciseMuscleClassifier.inferPrimaryMuscleFromName(name);
    if (inferred != 'Custom') {
      return inferred;
    }

    final mediaMuscle = _catalogMediaPrimaryMuscle(
      name: name,
      imageUrl: imageUrl,
    );
    if (mediaMuscle != null) {
      return mediaMuscle;
    }

    final normalizedRaw = ExerciseMuscleClassifier.normalizePrimaryMuscle(
      rawMuscle,
    );
    if (normalizedRaw != null && normalizedRaw != 'Custom') {
      return normalizedRaw;
    }

    return _catalogBodyPartMuscle(bodyPart) ?? 'Custom';
  }

  static String? _catalogMediaPrimaryMuscle({
    required String name,
    required String imageUrl,
  }) {
    final lowerImageUrl = _decodeCatalogUrl(imageUrl).toLowerCase();
    final target = _mediaTargetFromUrl(lowerImageUrl);
    if (target == null) {
      return null;
    }

    final text = ExerciseMuscleClassifier.lookupKey(name);
    bool has(List<String> patterns) => patterns.any(text.contains);

    return switch (target) {
      'Chest' => 'Chest',
      'Back' => 'Back',
      'Waist' => 'Core',
      'Hips' => 'Glutes',
      'Shoulders' => 'Shoulders',
      'Calves' => 'Calves',
      'Forearms' => 'Forearms',
      'Neck' => 'Neck',
      'UpperArms' when has(['tricep', 'triceps', 'pushdown', 'extension']) =>
        'Triceps',
      'UpperArms' when has(['bicep', 'biceps', 'brachialis', 'curl']) =>
        'Biceps',
      'UpperArms' => null,
      'Thighs' when has(['hamstring', 'leg curl', 'nordic']) => 'Hamstrings',
      'Thighs' when has(['deadlift', 'good morning', 'hyperextension']) =>
        'Posterior',
      'Thighs' when has(['glute', 'hip thrust', 'bridge']) => 'Glutes',
      'Thighs' => 'Quads',
      _ => null,
    };
  }

  static String _decodeCatalogUrl(String url) {
    try {
      return Uri.decodeFull(url);
    } on FormatException {
      return url;
    }
  }

  static String? _catalogBodyPartMuscle(String value) {
    final key = _exerciseLookupKey(value);
    if (key.isEmpty) {
      return null;
    }
    if (key.contains('chest')) {
      return 'Chest';
    }
    if (key.contains('back')) {
      return 'Back';
    }
    if (key.contains('shoulder')) {
      return 'Shoulders';
    }
    if (key.contains('calf') || key.contains('calves')) {
      return 'Calves';
    }
    if (key.contains('forearm')) {
      return 'Forearms';
    }
    if (key.contains('neck')) {
      return 'Neck';
    }
    if (key.contains('waist') || key.contains('abs')) {
      return 'Core';
    }
    if (key.contains('hip')) {
      return 'Glutes';
    }
    return null;
  }

  Future<List<Exercise>> loadExercises() async {
    await ensureDefaultExercises();
    final rows = await (_db.select(
      _db.exercises,
    )..orderBy([(exercise) => OrderingTerm.asc(exercise.name)])).get();

    return [
      for (final row in rows)
        _withCatalogMedia(
          Exercise(
            id: row.id,
            name: row.name,
            primaryMuscle: row.primaryMuscle,
            bodyPart: row.bodyPart,
            equipment: row.equipment,
            exerciseType: row.exerciseType,
            imageUrl: row.imageUrl,
            videoUrl: row.videoUrl,
            sourceUrl: row.sourceUrl,
          ),
        ),
    ];
  }

  Future<ExerciseHistory> loadExerciseHistory(Exercise exercise) async {
    final sets =
        await (_db.select(_db.workoutSetEntries)
              ..where(
                (set) =>
                    set.exerciseId.equals(exercise.id) |
                    set.exerciseName.equals(exercise.name),
              )
              ..orderBy([(set) => OrderingTerm.desc(set.loggedAt)]))
            .get();

    return ExerciseHistoryCalculator.build([
      for (final set in sets) _loggedSetFromRow(set),
    ]);
  }

  Future<void> ensureDefaultExercises() async {
    if (_didEnsureDefaultExercises) {
      return;
    }

    final now = DateTime.now();

    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.exercises, [
        for (final exercise in _defaultExercises)
          ExercisesCompanion.insert(
            id: exercise.id,
            name: exercise.name,
            primaryMuscle: exercise.primaryMuscle,
            bodyPart: Value(exercise.bodyPart),
            equipment: Value(exercise.equipment),
            exerciseType: Value(exercise.exerciseType),
            imageUrl: Value(exercise.imageUrl),
            videoUrl: Value(exercise.videoUrl),
            sourceUrl: Value(exercise.sourceUrl),
            createdAt: now,
          ),
      ]);
    });
    _didEnsureDefaultExercises = true;
  }

  Exercise _withCatalogMedia(Exercise exercise) {
    final safeExercise = exercise.copyWith(
      imageUrl: _safeCatalogMediaUrl(exercise.imageUrl, exercise.primaryMuscle),
      videoUrl: _safeCatalogMediaUrl(exercise.videoUrl, exercise.primaryMuscle),
    );

    if (safeExercise.imageUrl.trim().isNotEmpty &&
        safeExercise.videoUrl.trim().isNotEmpty &&
        safeExercise.sourceUrl.trim().isNotEmpty) {
      return safeExercise;
    }

    final alias = _manualCatalogAliases[safeExercise.id];
    final media =
        _catalogMediaById[safeExercise.id] ??
        (alias == null
            ? null
            : _catalogMediaByName[_exerciseLookupKey(alias)]) ??
        _catalogMediaByName[_exerciseLookupKey(safeExercise.name)];

    if (media == null) {
      return safeExercise;
    }

    return safeExercise.copyWith(
      bodyPart: safeExercise.bodyPart.trim().isEmpty ? media.bodyPart : null,
      equipment: safeExercise.equipment.trim().isEmpty ? media.equipment : null,
      exerciseType: safeExercise.exerciseType.trim().isEmpty
          ? media.exerciseType
          : null,
      imageUrl: safeExercise.imageUrl.trim().isEmpty ? media.imageUrl : null,
      videoUrl: safeExercise.videoUrl.trim().isEmpty ? media.videoUrl : null,
      sourceUrl: safeExercise.sourceUrl.trim().isEmpty ? media.sourceUrl : null,
    );
  }

  static Map<String, _CatalogMedia> _buildCatalogMediaByName() {
    final result = <String, _CatalogMedia>{};
    for (final seed in lyftaExerciseCatalog) {
      final primaryMuscle = _catalogPrimaryMuscle(
        name: seed.name,
        rawMuscle: seed.primaryMuscle,
        bodyPart: seed.bodyPart,
        imageUrl: seed.imageUrl,
      );
      final media = _CatalogMedia(
        bodyPart: seed.bodyPart,
        equipment: seed.equipment,
        exerciseType: seed.exerciseType,
        imageUrl: _safeCatalogMediaUrl(seed.imageUrl, primaryMuscle),
        videoUrl: _safeCatalogMediaUrl(seed.videoUrl, primaryMuscle),
        sourceUrl: seed.sourceUrl,
        quality: _catalogMediaQuality(
          name: seed.name,
          imageUrl: _safeCatalogMediaUrl(seed.imageUrl, primaryMuscle),
          videoUrl: _safeCatalogMediaUrl(seed.videoUrl, primaryMuscle),
          sourceUrl: seed.sourceUrl,
        ),
      );
      final key = _exerciseLookupKey(seed.name);
      final current = result[key];
      if (current == null || media.quality > current.quality) {
        result[key] = media;
      }
    }
    return result;
  }

  static Map<String, _CatalogMedia> _buildCatalogMediaById() {
    return {
      for (final seed in lyftaExerciseCatalog)
        seed.id: _catalogMediaFromSeed(seed),
    };
  }

  static _CatalogMedia _catalogMediaFromSeed(LyftaExerciseSeed seed) {
    final primaryMuscle = _catalogPrimaryMuscle(
      name: seed.name,
      rawMuscle: seed.primaryMuscle,
      bodyPart: seed.bodyPart,
      imageUrl: seed.imageUrl,
    );
    final imageUrl = _safeCatalogMediaUrl(seed.imageUrl, primaryMuscle);
    final videoUrl = _safeCatalogMediaUrl(seed.videoUrl, primaryMuscle);
    return _CatalogMedia(
      bodyPart: seed.bodyPart,
      equipment: seed.equipment,
      exerciseType: seed.exerciseType,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      sourceUrl: seed.sourceUrl,
      quality: _catalogMediaQuality(
        name: seed.name,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        sourceUrl: seed.sourceUrl,
      ),
    );
  }

  static int _catalogMediaQuality({
    required String name,
    required String imageUrl,
    required String videoUrl,
    required String sourceUrl,
  }) {
    var score = 0;
    if (imageUrl.trim().isNotEmpty) {
      score += 20;
    }
    if (videoUrl.trim().isNotEmpty) {
      score += 30;
    }
    if (sourceUrl.trim().isNotEmpty) {
      score += 8;
    }
    if (!RegExp(r'\((male|female)\)', caseSensitive: false).hasMatch(name)) {
      score += 8;
    }
    if (!RegExp(r'\bversion\b', caseSensitive: false).hasMatch(name)) {
      score += 5;
    }
    return score;
  }

  static String _safeCatalogMediaUrl(String url, String primaryMuscle) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || _isCatalogMediaUrlSafe(trimmed, primaryMuscle)) {
      return trimmed;
    }
    return '';
  }

  static bool _isCatalogMediaUrlSafe(String url, String primaryMuscle) {
    final lower = Uri.decodeFull(url).toLowerCase();
    if (!lower.contains('apilyfta.com/static/gymvisual')) {
      return true;
    }

    final mediaTarget = _mediaTargetFromUrl(lower);
    if (mediaTarget == null) {
      return true;
    }

    final allowedTargets = switch (primaryMuscle) {
      'Chest' => const {'Chest'},
      'Back' => const {'Back'},
      'Quads' => const {'Thighs'},
      'Posterior' => const {'Back', 'Hips', 'Thighs'},
      'Shoulders' => const {'Shoulders'},
      'Glutes' => const {'Hips', 'Thighs', 'Back'},
      'Hamstrings' => const {'Thighs', 'Hips', 'Back'},
      'Biceps' => const {'UpperArms'},
      'Triceps' => const {'UpperArms'},
      'Core' => const {'Waist'},
      'Calves' => const {'Calves'},
      'Forearms' => const {'Forearms'},
      'Neck' => const {'Neck'},
      _ => const <String>{},
    };

    return allowedTargets.isEmpty || allowedTargets.contains(mediaTarget);
  }

  static String? _mediaTargetFromUrl(String lowerUrl) {
    final path = Uri.tryParse(lowerUrl)?.path.toLowerCase() ?? lowerUrl;
    final normalized = path
        .replaceAll('-', '_')
        .replaceAll(' ', '_')
        .replaceAll('__', '_');
    final matches = RegExp(
      r'(^|_)(calves?|claves|feet|chest|back|waist|hips?|shoulders?|upper_arms?|forearms?|thighs?|neck)(_|\.|$)',
    ).allMatches(normalized).toList();
    if (matches.isEmpty) {
      return null;
    }

    return switch (matches.last.group(2)) {
      'calf' || 'calves' || 'claves' || 'feet' => 'Calves',
      'chest' => 'Chest',
      'back' => 'Back',
      'waist' => 'Waist',
      'hip' || 'hips' => 'Hips',
      'shoulder' || 'shoulders' => 'Shoulders',
      'upper_arm' || 'upper_arms' => 'UpperArms',
      'forearm' || 'forearms' => 'Forearms',
      'thigh' || 'thighs' => 'Thighs',
      'neck' => 'Neck',
      _ => null,
    };
  }

  static String _exerciseLookupKey(String value) {
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

  Future<Exercise> createCustomExercise({
    required String name,
    required String primaryMuscle,
    String bodyPart = '',
    String equipment = '',
    String exerciseType = '',
    String imageUrl = '',
    String videoUrl = '',
    String sourceUrl = '',
  }) async {
    await ensureDefaultExercises();

    final normalizedName = _capitalizeWords(name);
    final normalizedMuscle = _capitalizeWords(primaryMuscle);
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Exercise name cannot be empty');
    }

    final existing =
        await (_db.select(_db.exercises)
              ..where((exercise) => exercise.name.equals(normalizedName)))
            .getSingleOrNull();
    if (existing != null) {
      return Exercise(
        id: existing.id,
        name: existing.name,
        primaryMuscle: existing.primaryMuscle,
        bodyPart: existing.bodyPart,
        equipment: existing.equipment,
        exerciseType: existing.exerciseType,
        imageUrl: existing.imageUrl,
        videoUrl: existing.videoUrl,
        sourceUrl: existing.sourceUrl,
      );
    }

    final exercise = Exercise(
      id: 'custom_${_uuid.v4()}',
      name: normalizedName,
      primaryMuscle: normalizedMuscle.isEmpty ? 'Custom' : normalizedMuscle,
      bodyPart: bodyPart.trim(),
      equipment: equipment.trim(),
      exerciseType: exerciseType.trim(),
      imageUrl: imageUrl.trim(),
      videoUrl: videoUrl.trim(),
      sourceUrl: sourceUrl.trim(),
    );

    await _db
        .into(_db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: exercise.id,
            name: exercise.name,
            primaryMuscle: exercise.primaryMuscle,
            bodyPart: Value(exercise.bodyPart),
            equipment: Value(exercise.equipment),
            exerciseType: Value(exercise.exerciseType),
            imageUrl: Value(exercise.imageUrl),
            videoUrl: Value(exercise.videoUrl),
            sourceUrl: Value(exercise.sourceUrl),
            createdAt: DateTime.now(),
            syncStatus: const Value('pending'),
          ),
        );

    unawaited(_autoSync());
    return exercise;
  }

  Future<Exercise> updateExercise({
    required Exercise exercise,
    required String name,
    required String primaryMuscle,
    String? bodyPart,
    String? equipment,
    String? exerciseType,
    String? imageUrl,
    String? videoUrl,
    String? sourceUrl,
  }) async {
    final normalizedName = _capitalizeWords(name);
    final normalizedMuscle = _capitalizeWords(primaryMuscle);
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Exercise name cannot be empty');
    }

    await (_db.update(
      _db.exercises,
    )..where((row) => row.id.equals(exercise.id))).write(
      ExercisesCompanion(
        name: Value(normalizedName),
        primaryMuscle: Value(
          normalizedMuscle.isEmpty ? exercise.primaryMuscle : normalizedMuscle,
        ),
        bodyPart: Value(bodyPart?.trim() ?? exercise.bodyPart),
        equipment: Value(equipment?.trim() ?? exercise.equipment),
        exerciseType: Value(exerciseType?.trim() ?? exercise.exerciseType),
        imageUrl: Value(imageUrl?.trim() ?? exercise.imageUrl),
        videoUrl: Value(videoUrl?.trim() ?? exercise.videoUrl),
        sourceUrl: Value(sourceUrl?.trim() ?? exercise.sourceUrl),
        syncStatus: const Value('pending'),
      ),
    );

    await (_db.update(_db.workoutSetEntries)
          ..where((row) => row.exerciseId.equals(exercise.id)))
        .write(WorkoutSetEntriesCompanion(exerciseName: Value(normalizedName)));

    unawaited(_autoSync());
    return exercise.copyWith(
      name: normalizedName,
      primaryMuscle: normalizedMuscle.isEmpty
          ? exercise.primaryMuscle
          : normalizedMuscle,
      bodyPart: bodyPart?.trim(),
      equipment: equipment?.trim(),
      exerciseType: exerciseType?.trim(),
      imageUrl: imageUrl?.trim(),
      videoUrl: videoUrl?.trim(),
      sourceUrl: sourceUrl?.trim(),
    );
  }

  Future<void> deleteCustomExercise(Exercise exercise) async {
    if (!exercise.id.startsWith('custom_')) {
      return;
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.plannedDayExercises,
      )..where((row) => row.exerciseId.equals(exercise.id))).go();
      await (_db.delete(
        _db.exercises,
      )..where((row) => row.id.equals(exercise.id))).go();
    });

    unawaited(_autoSync());
  }

  Future<TrainingDayPlan> loadTrainingDayPlan(int dayNumber) async {
    await ensureDefaultExercises();

    final day = await (_db.select(
      _db.plannedWorkoutDays,
    )..where((row) => row.dayNumber.equals(dayNumber))).getSingleOrNull();

    if (day == null) {
      return TrainingDayPlan.empty(dayNumber);
    }

    final plannedRows =
        await (_db.select(_db.plannedDayExercises)
              ..where((row) => row.dayId.equals(day.id))
              ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
            .get();
    final exercises = <TrainingPlanExercise>[];

    for (final planned in plannedRows) {
      final row =
          await (_db.select(_db.exercises)
                ..where((exercise) => exercise.id.equals(planned.exerciseId)))
              .getSingleOrNull();
      if (row != null) {
        exercises.add(
          TrainingPlanExercise(
            exercise: _withCatalogMedia(
              Exercise(
                id: row.id,
                name: row.name,
                primaryMuscle: row.primaryMuscle,
                bodyPart: row.bodyPart,
                equipment: row.equipment,
                exerciseType: row.exerciseType,
                imageUrl: row.imageUrl,
                videoUrl: row.videoUrl,
                sourceUrl: row.sourceUrl,
              ),
            ),
            targetSets: planned.targetSets,
            targetReps: planned.targetReps,
            comment: planned.comment,
          ),
        );
      }
    }

    return TrainingDayPlan(
      id: day.id,
      dayNumber: day.dayNumber,
      name: day.customName,
      exercises: exercises,
      restSeconds: day.restSeconds,
    );
  }

  Future<List<TrainingDayPlan>> loadTrainingDayPlans() async {
    await ensureDefaultExercises();

    final days = await (_db.select(
      _db.plannedWorkoutDays,
    )..orderBy([(row) => OrderingTerm.asc(row.dayNumber)])).get();

    final plans = <TrainingDayPlan>[];
    for (final day in days) {
      plans.add(await loadTrainingDayPlan(day.dayNumber));
    }

    return plans.where((plan) => !plan.isEmpty).toList();
  }

  Future<Set<int>> loadPlannedDayNumbers() async {
    final days = await _db.select(_db.plannedWorkoutDays).get();
    final dayIds = {for (final day in days) day.id: day.dayNumber};
    final plannedRows = await _db.select(_db.plannedDayExercises).get();

    return {
      for (final row in plannedRows)
        if (dayIds[row.dayId] != null) dayIds[row.dayId]!,
    };
  }

  Future<int> loadSuggestedDayNumber() async {
    final plannedDays = (await loadPlannedDayNumbers()).toList()..sort();
    if (plannedDays.isEmpty) {
      return 1;
    }

    final lastSession =
        await (_db.select(_db.workoutSessions)
              ..where(
                (session) =>
                    session.templateDayNumber.isNotNull() &
                    session.finishedAt.isNotNull(),
              )
              ..orderBy([
                (session) => OrderingTerm.desc(session.finishedAt),
                (session) => OrderingTerm.desc(session.startedAt),
              ])
              ..limit(1))
            .getSingleOrNull();
    return TrainingPlanScheduler.suggestedDayNumber(
      plannedDays: plannedDays,
      lastFinishedDayNumber: lastSession?.templateDayNumber,
      lastFinishedAt: lastSession?.finishedAt,
      now: DateTime.now(),
    );
  }

  Future<void> saveTrainingDayPlan({
    required int dayNumber,
    required String name,
    required List<TrainingPlanExercise> exercises,
    required int restSeconds,
  }) async {
    await ensureDefaultExercises();

    final now = DateTime.now();
    final existing = await (_db.select(
      _db.plannedWorkoutDays,
    )..where((row) => row.dayNumber.equals(dayNumber))).getSingleOrNull();
    final dayId = existing?.id ?? _uuid.v4();

    await _db.transaction(() async {
      await _db
          .into(_db.plannedWorkoutDays)
          .insertOnConflictUpdate(
            PlannedWorkoutDaysCompanion.insert(
              id: dayId,
              dayOfWeek: _legacyWeekdayFromDayNumber(dayNumber),
              dayNumber: Value(dayNumber),
              customName: name.trim().isEmpty
                  ? 'Тренувальний день'
                  : _capitalizeFirst(name),
              restSeconds: Value(restSeconds.clamp(15, 600)),
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
            ),
          );

      await (_db.delete(
        _db.plannedDayExercises,
      )..where((row) => row.dayId.equals(dayId))).go();

      await _db.batch((batch) {
        batch.insertAll(_db.plannedDayExercises, [
          for (final entry in exercises.indexed)
            PlannedDayExercisesCompanion.insert(
              id: _uuid.v4(),
              dayId: dayId,
              exerciseId: entry.$2.exercise.id,
              sortOrder: entry.$1,
              targetSets: Value(entry.$2.targetSets.clamp(1, 20)),
              targetReps: Value(entry.$2.targetReps.clamp(1, 100)),
              comment: Value(entry.$2.comment.trim()),
            ),
        ]);
      });
    });

    unawaited(_autoSync());
  }

  Future<void> deleteTrainingDayPlan(int dayNumber) async {
    final day = await (_db.select(
      _db.plannedWorkoutDays,
    )..where((row) => row.dayNumber.equals(dayNumber))).getSingleOrNull();
    if (day == null) {
      return;
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.plannedDayExercises,
      )..where((row) => row.dayId.equals(day.id))).go();
      await (_db.delete(
        _db.plannedWorkoutDays,
      )..where((row) => row.id.equals(day.id))).go();

      final daysToShift =
          await (_db.select(_db.plannedWorkoutDays)
                ..where((row) => row.dayNumber.isBiggerThanValue(dayNumber))
                ..orderBy([(row) => OrderingTerm.asc(row.dayNumber)]))
              .get();

      for (final item in daysToShift) {
        final shiftedDayNumber = item.dayNumber - 1;
        await (_db.update(
          _db.plannedWorkoutDays,
        )..where((row) => row.id.equals(item.id))).write(
          PlannedWorkoutDaysCompanion(
            dayNumber: Value(shiftedDayNumber),
            dayOfWeek: Value(_legacyWeekdayFromDayNumber(shiftedDayNumber)),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });

    unawaited(_autoSync());
  }

  Future<String> createSession(
    DateTime startedAt, {
    String? templateName,
    int? templateDayNumber,
  }) async {
    final id = _uuid.v4();

    await _db
        .into(_db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            id: id,
            startedAt: startedAt,
            templateName: Value(templateName),
            templateDayNumber: Value(templateDayNumber),
          ),
        );

    unawaited(_autoSync());
    return id;
  }

  Future<WorkoutSessionDraft?> loadOpenSession({
    String? templateName,
    int? templateDayNumber,
  }) async {
    final query = _db.select(_db.workoutSessions)
      ..where((session) => session.finishedAt.isNull());

    if (templateDayNumber != null) {
      query.where(
        (session) => session.templateDayNumber.equals(templateDayNumber),
      );
    } else if (templateName?.trim().isNotEmpty ?? false) {
      query.where(
        (session) => session.templateName.equals(templateName!.trim()),
      );
    }

    query
      ..orderBy([(session) => OrderingTerm.desc(session.startedAt)])
      ..limit(1);

    final session = await query.getSingleOrNull();
    if (session == null) {
      return null;
    }

    final rows =
        await (_db.select(_db.workoutSetEntries)
              ..where((set) => set.sessionId.equals(session.id))
              ..orderBy([(set) => OrderingTerm.asc(set.loggedAt)]))
            .get();

    return WorkoutSessionDraft(
      sessionId: session.id,
      startedAt: session.startedAt,
      templateName: session.templateName,
      templateDayNumber: session.templateDayNumber,
      sets: [
        for (final row in rows)
          WorkoutSet(
            id: row.id,
            exerciseId: row.exerciseId,
            exerciseName: row.exerciseName,
            weightKg: row.weightKg,
            reps: row.reps,
            loggedAt: row.loggedAt,
          ),
      ],
    );
  }

  Future<String> logSet({
    required String sessionId,
    required WorkoutSet set,
  }) async {
    final id = set.id ?? _uuid.v4();
    await _db
        .into(_db.workoutSetEntries)
        .insert(
          WorkoutSetEntriesCompanion.insert(
            id: id,
            sessionId: sessionId,
            exerciseId: Value(set.exerciseId),
            exerciseName: set.exerciseName,
            weightKg: set.weightKg,
            reps: set.reps,
            loggedAt: set.loggedAt,
          ),
        );
    unawaited(_autoSync());
    return id;
  }

  Future<void> deleteSet(String setId) async {
    await (_db.delete(
      _db.workoutSetEntries,
    )..where((set) => set.id.equals(setId))).go();
    unawaited(_autoSync());
  }

  Future<void> deleteTrainingDay(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final setsOnDate =
        await (_db.select(_db.workoutSetEntries)..where(
              (set) =>
                  set.loggedAt.isBiggerOrEqualValue(start) &
                  set.loggedAt.isSmallerThanValue(end),
            ))
            .get();
    final sessionsOnDate =
        await (_db.select(_db.workoutSessions)..where(
              (session) =>
                  session.startedAt.isBiggerOrEqualValue(start) &
                  session.startedAt.isSmallerThanValue(end),
            ))
            .get();
    final sessionIds = {
      for (final set in setsOnDate) set.sessionId,
      for (final session in sessionsOnDate) session.id,
    };

    if (sessionIds.isEmpty) {
      return;
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.workoutSetEntries,
      )..where((set) => set.sessionId.isIn(sessionIds))).go();
      await (_db.delete(
        _db.workoutSessions,
      )..where((session) => session.id.isIn(sessionIds))).go();
    });

    unawaited(_autoSync());
  }

  Future<void> finishSession({
    required String sessionId,
    required DateTime finishedAt,
  }) async {
    await (_db.update(_db.workoutSessions)
          ..where((session) => session.id.equals(sessionId)))
        .write(WorkoutSessionsCompanion(finishedAt: Value(finishedAt)));
    unawaited(_autoSync());
  }

  Future<DashboardSnapshot> loadDashboardSnapshot({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    final sessions = await _db.select(_db.workoutSessions).get();
    final sets = await _db.select(_db.workoutSetEntries).get();

    return WorkoutAnalyticsCalculator.dashboard(
      now: currentTime,
      sessions: [
        for (final session in sessions) _loggedSessionFromRow(session),
      ],
      sets: [for (final set in sets) _loggedSetFromRow(set)],
    );
  }

  Future<AnalyticsSnapshot> loadAnalyticsSnapshot({DateTime? now}) async {
    await ensureDefaultExercises();

    final currentTime = now ?? DateTime.now();
    final sets = await _db.select(_db.workoutSetEntries).get();
    final exercises = await _db.select(_db.exercises).get();
    final sessions = await _db.select(_db.workoutSessions).get();

    return WorkoutAnalyticsCalculator.analytics(
      now: currentTime,
      sets: [for (final set in sets) _loggedSetFromRow(set)],
      sessions: [
        for (final session in sessions) _loggedSessionFromRow(session),
      ],
      exercises: [
        for (final exercise in exercises)
          ExerciseMuscleRef(
            id: exercise.id,
            name: exercise.name,
            primaryMuscle: exercise.primaryMuscle,
          ),
      ],
    );
  }

  Future<List<ProgressPhoto>> loadProgressPhotos() async {
    final rows = await (_db.select(
      _db.progressPhotoEntries,
    )..orderBy([(row) => OrderingTerm.desc(row.capturedAt)])).get();
    return [for (final row in rows) _progressPhotoFromRow(row)];
  }

  Future<ProgressPhoto> addProgressPhoto({
    required String imageDataUrl,
    String note = '',
    DateTime? capturedAt,
  }) async {
    final trimmedImage = imageDataUrl.trim();
    if (trimmedImage.isEmpty) {
      throw ArgumentError.value(imageDataUrl, 'imageDataUrl', 'Photo is empty');
    }

    final now = DateTime.now();
    final photo = ProgressPhoto(
      id: _uuid.v4(),
      imageDataUrl: trimmedImage,
      note: note.trim(),
      capturedAt: capturedAt ?? now,
      createdAt: now,
    );

    await _db
        .into(_db.progressPhotoEntries)
        .insert(
          ProgressPhotoEntriesCompanion.insert(
            id: photo.id,
            imageDataUrl: photo.imageDataUrl,
            note: Value(photo.note),
            capturedAt: photo.capturedAt,
            createdAt: photo.createdAt,
          ),
        );
    unawaited(_autoSync());
    return photo;
  }

  Future<void> deleteProgressPhoto(String photoId) async {
    await (_db.delete(
      _db.progressPhotoEntries,
    )..where((photo) => photo.id.equals(photoId))).go();
    unawaited(_autoSync());
  }

  Future<UserProfile> loadProfile() async {
    final row = await (_db.select(
      _db.userProfiles,
    )..where((profile) => profile.id.equals('local'))).getSingleOrNull();
    if (row == null) {
      return const UserProfile.empty();
    }

    return UserProfile(
      displayName: row.displayName,
      bodyWeightKg: row.bodyWeightKg,
      userId: row.userId ?? '',
      email: row.email ?? '',
      authToken: row.authToken ?? '',
      syncCode: row.syncCode ?? '',
      syncBaseUrl: row.syncBaseUrl ?? '',
    );
  }

  Future<void> saveProfile(
    UserProfile profile, {
    bool shouldSync = true,
  }) async {
    final now = DateTime.now();
    final existing = await (_db.select(
      _db.userProfiles,
    )..where((row) => row.id.equals('local'))).getSingleOrNull();

    await _db
        .into(_db.userProfiles)
        .insertOnConflictUpdate(
          UserProfilesCompanion.insert(
            id: 'local',
            displayName: Value(profile.displayName.trim()),
            bodyWeightKg: Value(profile.bodyWeightKg),
            userId: Value(profile.userId.trim()),
            email: Value(profile.email.trim().toLowerCase()),
            authToken: Value(profile.authToken.trim()),
            syncCode: Value(profile.syncCode.trim().toUpperCase()),
            syncBaseUrl: Value(_normalizeBaseUrl(profile.syncBaseUrl)),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );

    if (shouldSync) {
      unawaited(_autoSync());
    }
  }

  String createSyncCode() {
    final random = Random.secure();
    String block() {
      return List.generate(
        4,
        (_) => _syncChars[random.nextInt(_syncChars.length)],
      ).join();
    }

    return 'GE-${block()}-${block()}';
  }

  Future<AuthRunResult> registerAccount({
    required UserProfile profile,
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    final session = await SyncApiClient(baseUrl: normalizedBaseUrl)
        .requestRegistrationCode(
          email: email,
          password: password,
          name: profile.displayName,
        );
    if (session.token.trim().isNotEmpty) {
      return _completeAuth(
        profile: profile,
        baseUrl: normalizedBaseUrl,
        session: session,
        shouldRestore: false,
        successMessage: 'Registered and synced',
      );
    }
    try {
      final loginSession = await SyncApiClient(
        baseUrl: normalizedBaseUrl,
      ).login(email: email, password: password);
      if (loginSession.token.trim().isNotEmpty) {
        return _completeAuth(
          profile: profile,
          baseUrl: normalizedBaseUrl,
          session: loginSession,
          shouldRestore: false,
          successMessage: 'Registered and synced',
        );
      }
    } catch (_) {
      // Some API modes require an email code before login. In that case the UI
      // should continue to the verification step.
    }
    throw SyncException('verification_required', session.devCode);
  }

  Future<AuthSession> requestRegistrationCode({
    required String baseUrl,
    required String email,
    required String password,
    String? name,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    return SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).requestRegistrationCode(email: email, password: password, name: name);
  }

  Future<AuthRunResult> verifyRegistrationCode({
    required UserProfile profile,
    required String baseUrl,
    required String email,
    required String code,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    final session = await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).verifyRegistrationCode(email: email, code: code);

    return _completeAuth(
      profile: profile,
      baseUrl: normalizedBaseUrl,
      session: session,
      shouldRestore: false,
      successMessage: 'Registered and synced',
    );
  }

  Future<String?> requestPasswordResetCode({
    required String baseUrl,
    required String email,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    final result = await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).requestPasswordResetCode(email: email);
    return result.devCode.trim().isEmpty ? null : result.devCode.trim();
  }

  Future<AuthRunResult> confirmPasswordReset({
    required UserProfile profile,
    required String baseUrl,
    required String email,
    required String code,
    required String password,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    final session = await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).confirmPasswordReset(email: email, code: code, password: password);

    return _completeAuth(
      profile: profile,
      baseUrl: normalizedBaseUrl,
      session: session,
      shouldRestore: true,
      successMessage: 'Password reset and restored',
    );
  }

  Future<AuthRunResult> loginAccount({
    required UserProfile profile,
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    final session = await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).login(email: email, password: password);

    return _completeAuth(
      profile: profile,
      baseUrl: normalizedBaseUrl,
      session: session,
      shouldRestore: true,
      successMessage: 'Logged in and restored',
    );
  }

  Future<AuthRunResult> _completeAuth({
    required UserProfile profile,
    required String baseUrl,
    required AuthSession session,
    required bool shouldRestore,
    required String successMessage,
  }) async {
    final authenticatedProfile = profile.copyWith(
      userId: session.userId,
      email: session.email,
      authToken: session.token,
      syncBaseUrl: baseUrl,
    );
    await saveProfile(authenticatedProfile, shouldSync: false);

    if (shouldRestore) {
      try {
        final result = await restoreFromServer(
          baseUrl: baseUrl,
          authToken: session.token,
          userId: session.userId,
          email: session.email,
        );
        final restoredProfile = await loadProfile();
        return AuthRunResult(
          message: successMessage,
          profile: restoredProfile,
          setCount: result.setCount,
          sessionCount: result.sessionCount,
          trainingDayCount: result.trainingDayCount,
        );
      } catch (_) {
        return AuthRunResult(
          message: 'Logged in',
          profile: authenticatedProfile,
          setCount: 0,
          sessionCount: 0,
          trainingDayCount: 0,
        );
      }
    }

    try {
      final syncResult = await syncToServer(
        profile: authenticatedProfile,
        baseUrl: baseUrl,
      );
      return AuthRunResult(
        message: successMessage,
        profile: authenticatedProfile,
        setCount: syncResult.setCount,
        sessionCount: syncResult.sessionCount,
        trainingDayCount: syncResult.trainingDayCount,
      );
    } catch (_) {
      return AuthRunResult(
        message: successMessage,
        profile: authenticatedProfile,
        setCount: 0,
        sessionCount: 0,
        trainingDayCount: 0,
      );
    }
  }

  Future<UserProfile> logoutAccount(UserProfile profile) async {
    final nextProfile = profile.copyWith(userId: '', email: '', authToken: '');
    await saveProfile(nextProfile, shouldSync: false);
    return nextProfile;
  }

  Future<SyncRunResult> syncToServer({
    required UserProfile profile,
    required String baseUrl,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    if (profile.authToken.trim().isEmpty) {
      throw SyncException('auth');
    }
    final nextProfile = profile.copyWith(syncBaseUrl: normalizedBaseUrl);
    await saveProfile(nextProfile, shouldSync: false);

    final snapshot = await exportSyncSnapshot(profile: nextProfile);
    final result = await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).uploadMine(token: nextProfile.authToken, snapshot: snapshot);

    return SyncRunResult(
      message:
          'Saved ${result.setCount} sets and ${result.trainingDayCount} days',
      syncCode: nextProfile.userId,
      setCount: result.setCount,
      sessionCount: result.sessionCount,
      trainingDayCount: result.trainingDayCount,
    );
  }

  Future<SyncRunResult> restoreFromServer({
    required String baseUrl,
    required String authToken,
    required String userId,
    required String email,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    if (authToken.trim().isEmpty) {
      throw SyncException('auth');
    }
    final snapshot = await SyncApiClient(
      baseUrl: normalizedBaseUrl,
    ).downloadMine(token: authToken);

    final counts = await importSyncSnapshot(
      snapshot,
      syncCode: '',
      syncBaseUrl: normalizedBaseUrl,
      userId: userId,
      email: email,
      authToken: authToken,
    );

    return SyncRunResult(
      message: 'Restored ${counts.setCount} sets',
      syncCode: userId,
      setCount: counts.setCount,
      sessionCount: counts.sessionCount,
      trainingDayCount: counts.trainingDayCount,
    );
  }

  Future<Map<String, Object?>> exportSyncSnapshot({
    required UserProfile profile,
  }) async {
    await ensureDefaultExercises();

    final exercises = await _db.select(_db.exercises).get();
    final trainingDays = await _db.select(_db.plannedWorkoutDays).get();
    final plannedExercises = await _db.select(_db.plannedDayExercises).get();
    final sessions = await _db.select(_db.workoutSessions).get();
    final sets = await _db.select(_db.workoutSetEntries).get();
    final progressPhotos = await _db.select(_db.progressPhotoEntries).get();

    return {
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'profile': {
        'displayName': profile.displayName,
        'bodyWeightKg': profile.bodyWeightKg,
        'userId': profile.userId,
        'email': profile.email,
        'authBaseUrl': profile.syncBaseUrl,
        'syncCode': profile.syncCode,
        'syncBaseUrl': profile.syncBaseUrl,
      },
      'exercises': [
        for (final row in exercises)
          {
            'id': row.id,
            'name': row.name,
            'primaryMuscle': row.primaryMuscle,
            'bodyPart': row.bodyPart,
            'equipment': row.equipment,
            'exerciseType': row.exerciseType,
            'imageUrl': row.imageUrl,
            'videoUrl': row.videoUrl,
            'sourceUrl': row.sourceUrl,
            'createdAt': row.createdAt.toIso8601String(),
            'syncStatus': row.syncStatus,
          },
      ],
      'trainingDays': [
        for (final row in trainingDays)
          {
            'id': row.id,
            'dayOfWeek': row.dayOfWeek,
            'dayNumber': row.dayNumber,
            'customName': row.customName,
            'restSeconds': row.restSeconds,
            'setTargetSeconds': row.setTargetSeconds,
            'createdAt': row.createdAt.toIso8601String(),
            'updatedAt': row.updatedAt.toIso8601String(),
            'syncStatus': row.syncStatus,
          },
      ],
      'plannedExercises': [
        for (final row in plannedExercises)
          {
            'id': row.id,
            'dayId': row.dayId,
            'exerciseId': row.exerciseId,
            'sortOrder': row.sortOrder,
            'targetSets': row.targetSets,
            'targetReps': row.targetReps,
            'comment': row.comment,
          },
      ],
      'sessions': [
        for (final row in sessions)
          {
            'id': row.id,
            'startedAt': row.startedAt.toIso8601String(),
            'finishedAt': row.finishedAt?.toIso8601String(),
            'templateName': row.templateName,
            'templateDayNumber': row.templateDayNumber,
            'syncStatus': row.syncStatus,
          },
      ],
      'sets': [
        for (final row in sets)
          {
            'id': row.id,
            'sessionId': row.sessionId,
            'exerciseId': row.exerciseId,
            'exerciseName': row.exerciseName,
            'weightKg': row.weightKg,
            'reps': row.reps,
            'loggedAt': row.loggedAt.toIso8601String(),
            'syncStatus': row.syncStatus,
          },
      ],
      'progressPhotos': [
        for (final row in progressPhotos)
          {
            'id': row.id,
            'imageDataUrl': row.imageDataUrl,
            'note': row.note,
            'capturedAt': row.capturedAt.toIso8601String(),
            'createdAt': row.createdAt.toIso8601String(),
            'syncStatus': row.syncStatus,
          },
      ],
    };
  }

  Future<SyncRunResult> importSyncSnapshot(
    Map<String, Object?> snapshot, {
    required String syncCode,
    required String syncBaseUrl,
    String userId = '',
    String email = '',
    String authToken = '',
  }) async {
    final exercises = _listOfMaps(snapshot['exercises']);
    final trainingDays = _listOfMaps(snapshot['trainingDays']);
    final plannedExercises = _listOfMaps(snapshot['plannedExercises']);
    final sessions = _listOfMaps(snapshot['sessions']);
    final sets = _listOfMaps(snapshot['sets']);
    final progressPhotos = _listOfMaps(snapshot['progressPhotos']);
    final profileData = (snapshot['profile'] as Map?)?.cast<String, Object?>();
    final now = DateTime.now();

    await _db.transaction(() async {
      await _db.delete(_db.progressPhotoEntries).go();
      await _db.delete(_db.workoutSetEntries).go();
      await _db.delete(_db.workoutSessions).go();
      await _db.delete(_db.plannedDayExercises).go();
      await _db.delete(_db.plannedWorkoutDays).go();
      await _db.delete(_db.exercises).go();
      await _db.delete(_db.userProfiles).go();

      await _db.batch((batch) {
        batch.insertAll(_db.exercises, [
          for (final row in exercises)
            ExercisesCompanion.insert(
              id: _string(row, 'id'),
              name: _string(row, 'name'),
              primaryMuscle: _string(row, 'primaryMuscle', fallback: 'Custom'),
              bodyPart: Value(_string(row, 'bodyPart', fallback: '')),
              equipment: Value(_string(row, 'equipment', fallback: '')),
              exerciseType: Value(_string(row, 'exerciseType', fallback: '')),
              imageUrl: Value(_string(row, 'imageUrl', fallback: '')),
              videoUrl: Value(_string(row, 'videoUrl', fallback: '')),
              sourceUrl: Value(_string(row, 'sourceUrl', fallback: '')),
              createdAt: _date(row, 'createdAt', fallback: now),
              syncStatus: Value(_string(row, 'syncStatus', fallback: 'synced')),
            ),
        ]);

        batch.insertAll(_db.plannedWorkoutDays, [
          for (final row in trainingDays)
            PlannedWorkoutDaysCompanion.insert(
              id: _string(row, 'id'),
              dayOfWeek: _int(row, 'dayOfWeek', fallback: 1),
              dayNumber: Value(_int(row, 'dayNumber', fallback: 1)),
              customName: _string(row, 'customName'),
              restSeconds: Value(_int(row, 'restSeconds', fallback: 90)),
              setTargetSeconds: Value(
                _int(row, 'setTargetSeconds', fallback: 45),
              ),
              createdAt: _date(row, 'createdAt', fallback: now),
              updatedAt: _date(row, 'updatedAt', fallback: now),
              syncStatus: Value(_string(row, 'syncStatus', fallback: 'synced')),
            ),
        ]);

        batch.insertAll(_db.plannedDayExercises, [
          for (final row in plannedExercises)
            PlannedDayExercisesCompanion.insert(
              id: _string(row, 'id'),
              dayId: _string(row, 'dayId'),
              exerciseId: _string(row, 'exerciseId'),
              sortOrder: _int(row, 'sortOrder'),
              targetSets: Value(_int(row, 'targetSets', fallback: 3)),
              targetReps: Value(_int(row, 'targetReps', fallback: 10)),
              comment: Value(_string(row, 'comment', fallback: '')),
            ),
        ]);

        batch.insertAll(_db.workoutSessions, [
          for (final row in sessions)
            WorkoutSessionsCompanion.insert(
              id: _string(row, 'id'),
              startedAt: _date(row, 'startedAt', fallback: now),
              finishedAt: Value(_nullableDate(row, 'finishedAt')),
              templateName: Value(_nullableString(row, 'templateName')),
              templateDayNumber: Value(_nullableInt(row['templateDayNumber'])),
              syncStatus: Value(_string(row, 'syncStatus', fallback: 'synced')),
            ),
        ]);

        batch.insertAll(_db.workoutSetEntries, [
          for (final row in sets)
            WorkoutSetEntriesCompanion.insert(
              id: _string(row, 'id'),
              sessionId: _string(row, 'sessionId'),
              exerciseId: Value(_nullableString(row, 'exerciseId')),
              exerciseName: _string(row, 'exerciseName'),
              weightKg: _double(row, 'weightKg'),
              reps: _int(row, 'reps'),
              loggedAt: _date(row, 'loggedAt', fallback: now),
              syncStatus: Value(_string(row, 'syncStatus', fallback: 'synced')),
            ),
        ]);

        batch.insertAll(_db.progressPhotoEntries, [
          for (final row in progressPhotos)
            ProgressPhotoEntriesCompanion.insert(
              id: _string(row, 'id'),
              imageDataUrl: _string(row, 'imageDataUrl'),
              note: Value(_string(row, 'note', fallback: '')),
              capturedAt: _date(row, 'capturedAt', fallback: now),
              createdAt: _date(row, 'createdAt', fallback: now),
              syncStatus: Value(_string(row, 'syncStatus', fallback: 'synced')),
            ),
        ]);

        batch.insert(
          _db.userProfiles,
          UserProfilesCompanion.insert(
            id: 'local',
            displayName: Value(
              profileData?['displayName']?.toString().trim() ?? '',
            ),
            bodyWeightKg: Value(_nullableDouble(profileData?['bodyWeightKg'])),
            userId: Value(
              userId.trim().isNotEmpty
                  ? userId.trim()
                  : profileData?['userId']?.toString().trim(),
            ),
            email: Value(
              email.trim().isNotEmpty
                  ? email.trim().toLowerCase()
                  : profileData?['email']?.toString().trim().toLowerCase(),
            ),
            authToken: Value(authToken.trim()),
            syncCode: Value(syncCode),
            syncBaseUrl: Value(_normalizeBaseUrl(syncBaseUrl)),
            createdAt: now,
            updatedAt: now,
          ),
        );
      });
    });

    await ensureDefaultExercises();

    return SyncRunResult(
      message: 'Restored ${sets.length} sets',
      syncCode: syncCode,
      setCount: sets.length,
      sessionCount: sessions.length,
      trainingDayCount: trainingDays.length,
    );
  }

  Future<void> _autoSync() async {
    if (_isAutoSyncing) {
      return;
    }

    final profile = await loadProfile();
    if (!profile.isAuthenticated) {
      return;
    }

    _isAutoSyncing = true;
    try {
      final snapshot = await exportSyncSnapshot(profile: profile);
      await SyncApiClient(
        baseUrl: _normalizeBaseUrl(profile.syncBaseUrl),
      ).uploadMine(token: profile.authToken, snapshot: snapshot);
    } catch (_) {
      // Auto-sync must never block the workout flow. The next write retries.
    } finally {
      _isAutoSyncing = false;
    }
  }

  int _legacyWeekdayFromDayNumber(int dayNumber) {
    if (dayNumber < 1) {
      return 1;
    }
    if (dayNumber > 7) {
      return 7;
    }
    return dayNumber;
  }

  LoggedWorkoutSet _loggedSetFromRow(WorkoutSetEntry row) {
    return LoggedWorkoutSet(
      id: row.id,
      sessionId: row.sessionId,
      exerciseId: row.exerciseId,
      exerciseName: row.exerciseName,
      weightKg: row.weightKg,
      reps: row.reps,
      loggedAt: row.loggedAt,
    );
  }

  LoggedWorkoutSession _loggedSessionFromRow(WorkoutSession row) {
    return LoggedWorkoutSession(
      id: row.id,
      startedAt: row.startedAt,
      finishedAt: row.finishedAt,
      templateName: row.templateName,
      templateDayNumber: row.templateDayNumber,
    );
  }

  ProgressPhoto _progressPhotoFromRow(ProgressPhotoEntry row) {
    return ProgressPhoto(
      id: row.id,
      imageDataUrl: row.imageDataUrl,
      note: row.note,
      capturedAt: row.capturedAt,
      createdAt: row.createdAt,
    );
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim().isEmpty ? defaultSyncBaseUrl : value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  List<Map<String, Object?>> _listOfMaps(Object? value) {
    if (value is! List) {
      return const [];
    }

    return [
      for (final item in value)
        if (item is Map) item.cast<String, Object?>(),
    ];
  }

  String _string(Map<String, Object?> row, String key, {String fallback = ''}) {
    final value = row[key]?.toString();
    return value == null || value.isEmpty ? fallback : value;
  }

  String? _nullableString(Map<String, Object?> row, String key) {
    final value = row[key]?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  int _int(Map<String, Object?> row, String key, {int fallback = 0}) {
    final value = row[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int? _nullableInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  double _double(Map<String, Object?> row, String key, {double fallback = 0}) {
    return _nullableDouble(row[key]) ?? fallback;
  }

  double? _nullableDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  DateTime _date(
    Map<String, Object?> row,
    String key, {
    required DateTime fallback,
  }) {
    return _nullableDate(row, key) ?? fallback;
  }

  DateTime? _nullableDate(Map<String, Object?> row, String key) {
    final raw = row[key]?.toString();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }

  static String _capitalizeFirst(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return '${trimmed.substring(0, 1).toUpperCase()}${trimmed.substring(1)}';
  }

  static String _capitalizeWords(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(_capitalizeFirst)
        .join(' ');
  }
}

class _CatalogMedia {
  const _CatalogMedia({
    required this.bodyPart,
    required this.equipment,
    required this.exerciseType,
    required this.imageUrl,
    required this.videoUrl,
    required this.sourceUrl,
    required this.quality,
  });

  final String bodyPart;
  final String equipment;
  final String exerciseType;
  final String imageUrl;
  final String videoUrl;
  final String sourceUrl;
  final int quality;
}

class SyncRunResult {
  const SyncRunResult({
    required this.message,
    required this.syncCode,
    required this.setCount,
    required this.sessionCount,
    required this.trainingDayCount,
  });

  final String message;
  final String syncCode;
  final int setCount;
  final int sessionCount;
  final int trainingDayCount;
}

class AuthRunResult {
  const AuthRunResult({
    required this.message,
    required this.profile,
    required this.setCount,
    required this.sessionCount,
    required this.trainingDayCount,
  });

  final String message;
  final UserProfile profile;
  final int setCount;
  final int sessionCount;
  final int trainingDayCount;
}

class SyncException implements Exception {
  SyncException(this.code, [this.cause]);

  final String code;
  final Object? cause;
}
