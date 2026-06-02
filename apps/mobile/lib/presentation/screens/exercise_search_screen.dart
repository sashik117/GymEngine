import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/gym_labels.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/exercise_catalog_cleanup.dart';
import '../../core/util/photo_picker.dart';
import '../../core/widgets/bouncy_gym_button.dart';
import '../../core/widgets/gym_exercise_image.dart';
import '../../core/widgets/gym_panel.dart';
import '../../data/repos/workout_session_repository.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/training_day_plan.dart';
import '../bloc/analytics_cubit.dart';
import '../bloc/dashboard_cubit.dart';
import '../bloc/locale_cubit.dart';
import '../widgets/exercise_detail_sheet.dart';

class ExerciseSearchScreen extends StatefulWidget {
  const ExerciseSearchScreen({
    this.targetDayNumber,
    this.targetToken = 0,
    super.key,
  });

  final int? targetDayNumber;
  final int targetToken;

  @override
  State<ExerciseSearchScreen> createState() => _ExerciseSearchScreenState();
}

class _ExerciseSearchScreenState extends State<ExerciseSearchScreen> {
  final _searchController = TextEditingController();
  List<Exercise> _exercises = const [];
  List<TrainingDayPlan> _plans = const [];
  String? _selectedMuscle;
  int _selectedDayNumber = 1;
  var _isLoading = true;
  var _showOnlyWithVideo = false;

  static const _muscleOrder = [
    'Chest',
    'Back',
    'Posterior',
    'Shoulders',
    'Quads',
    'Glutes',
    'Hamstrings',
    'Calves',
    'Biceps',
    'Triceps',
    'Forearms',
    'Core',
    'Neck',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ExerciseSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetToken != oldWidget.targetToken &&
        widget.targetDayNumber != null) {
      setState(() {
        _selectedDayNumber = widget.targetDayNumber!.clamp(1, 7);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? keepSelectedDayNumber}) async {
    final repository = context.read<WorkoutSessionRepository>();
    final exercises = await repository.loadExercises();
    final plans = await repository.loadTrainingDayPlans();
    final suggestedDay =
        widget.targetDayNumber ?? await repository.loadSuggestedDayNumber();
    if (!mounted) {
      return;
    }

    setState(() {
      _exercises = exercises;
      _plans = plans;
      _selectedDayNumber = (keepSelectedDayNumber ?? suggestedDay).clamp(1, 7);
      _isLoading = false;
    });
  }

  Future<void> _addExerciseToSelectedDay(Exercise exercise) async {
    final labels = context.read<LocaleCubit>().labels;
    final repository = context.read<WorkoutSessionRepository>();
    final dashboardCubit = context.read<DashboardCubit>();
    final analyticsCubit = context.read<AnalyticsCubit>();
    final plan = await repository.loadTrainingDayPlan(_selectedDayNumber);
    final alreadyAdded = plan.exercises.any(
      (item) => item.exercise.id == exercise.id,
    );

    if (alreadyAdded) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              labels,
              uk: 'Вправа вже є в цьому дні',
              en: 'Already in this day',
            ),
          ),
        ),
      );
      return;
    }

    final nextExercises = [
      ...plan.exercises,
      TrainingPlanExercise(exercise: exercise, targetSets: 3, targetReps: 10),
    ];
    final nextName = plan.name.trim().isEmpty
        ? _defaultDayName(labels, _selectedDayNumber, exercise)
        : plan.name;

    final addedToDay = _selectedDayNumber;
    await repository.saveTrainingDayPlan(
      dayNumber: addedToDay,
      name: nextName,
      exercises: nextExercises,
      restSeconds: plan.restSeconds,
    );
    await dashboardCubit.load();
    await analyticsCubit.load();
    await _load(keepSelectedDayNumber: addedToDay);

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          _text(
            labels,
            uk: '${labels.exerciseName(exercise.id, exercise.name)} успішно додано в День $addedToDay',
            en: '${labels.exerciseName(exercise.id, exercise.name)} added to Day $addedToDay',
          ),
        ),
      ),
    );
  }

  Future<void> _createCustomExercise(GymLabels labels) async {
    final exercise = await showDialog<Exercise>(
      context: context,
      builder: (context) => _CustomExerciseDialog(labels: labels),
    );
    if (exercise == null || !mounted) {
      return;
    }

    await _addExerciseToSelectedDay(exercise);
  }

  List<Exercise> _filtered(GymLabels labels) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _exercises.where((exercise) {
      final matchesMuscle =
          _selectedMuscle == null || exercise.primaryMuscle == _selectedMuscle;
      final matchesVideo =
          !_showOnlyWithVideo || exercise.videoUrl.trim().isNotEmpty;
      final matchesQuery =
          query.isEmpty ||
          exercise.name.toLowerCase().contains(query) ||
          exercise.primaryMuscle.toLowerCase().contains(query) ||
          exercise.bodyPart.toLowerCase().contains(query) ||
          exercise.equipment.toLowerCase().contains(query) ||
          labels
              .exerciseName(exercise.id, exercise.name)
              .toLowerCase()
              .contains(query) ||
          labels
              .muscleName(exercise.primaryMuscle)
              .toLowerCase()
              .contains(query);

      return matchesMuscle && matchesVideo && matchesQuery;
    });

    return dedupeExerciseCatalog(filtered, labels)..sort((a, b) {
      final aPopular = _popularRank(a);
      final bPopular = _popularRank(b);
      if (_selectedMuscle == null && query.isEmpty && aPopular != bPopular) {
        return aPopular.compareTo(bPopular);
      }
      final aMedia = a.imageUrl.isNotEmpty ? 0 : 1;
      final bMedia = b.imageUrl.isNotEmpty ? 0 : 1;
      if (aMedia != bMedia) {
        return aMedia.compareTo(bMedia);
      }
      final muscleCompare = labels
          .muscleName(a.primaryMuscle)
          .compareTo(labels.muscleName(b.primaryMuscle));
      if (muscleCompare != 0 && _selectedMuscle != null) {
        return muscleCompare;
      }
      return a.name.compareTo(b.name);
    });
  }

  Map<String, int> _muscleCounts(List<Exercise> exercises) {
    final counts = <String, int>{};
    for (final exercise in exercises) {
      final muscle = exercise.primaryMuscle.trim();
      if (muscle.isEmpty || muscle == 'Unknown') {
        continue;
      }
      counts[muscle] = (counts[muscle] ?? 0) + 1;
    }
    return counts;
  }

  List<String> _orderedMuscles(
    Map<String, int> muscleCounts,
    GymLabels labels,
  ) {
    final ordered = [
      for (final muscle in _muscleOrder)
        if ((muscleCounts[muscle] ?? 0) > 0) muscle,
    ];
    final extras =
        muscleCounts.keys
            .where((muscle) => !_muscleOrder.contains(muscle))
            .toList()
          ..sort(
            (a, b) => labels.muscleName(a).compareTo(labels.muscleName(b)),
          );
    return [...ordered, ...extras];
  }

  int _popularRank(Exercise exercise) {
    final name = exercise.name.toLowerCase();
    final id = exercise.id.toLowerCase();
    const popular = [
      'barbell squat',
      'squat',
      'bench press',
      'deadlift',
      'romanian deadlift',
      'hip thrust',
      'leg press',
      'pull up',
      'lat pulldown',
      'seated row',
      'overhead press',
      'lateral raise',
      'biceps curl',
      'triceps pushdown',
      'plank',
      'calf raise',
    ];

    for (final entry in popular.indexed) {
      final term = entry.$2;
      if (name == term || id == term.replaceAll(' ', '_')) {
        return entry.$1;
      }
    }
    for (final entry in popular.indexed) {
      if (name.contains(entry.$2)) {
        return popular.length + entry.$1;
      }
    }
    return 10000 + exercise.name.toLowerCase().hashCode.abs() % 700;
  }

  List<int> get _visibleDayNumbers {
    final numbers = {for (final plan in _plans) plan.dayNumber};
    if (numbers.length < 7) {
      final next = numbers.isEmpty
          ? 1
          : (numbers.reduce((max, value) => value > max ? value : max) + 1)
                .clamp(1, 7);
      numbers.add(next);
    }
    numbers.add(_selectedDayNumber);
    return numbers.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final labels = context.watch<LocaleCubit>().labels;
    final exercises = _filtered(labels);
    final catalogExercises = dedupeExerciseCatalog(_exercises, labels);
    final totalExercises = catalogExercises.length;
    final muscleCounts = _muscleCounts(catalogExercises);
    final muscles = _orderedMuscles(muscleCounts, labels);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GYMENGINE',
                    style: TextStyle(
                      color: AppColors.lime,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    _text(labels, uk: 'ПОШУК ВПРАВ', en: 'EXERCISE SEARCH'),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: 14),
                  _DayTargetRail(
                    labels: labels,
                    days: _visibleDayNumbers,
                    plans: _plans,
                    selectedDayNumber: _selectedDayNumber,
                    onSelected: (day) {
                      setState(() => _selectedDayNumber = day);
                    },
                  ),
                  SizedBox(height: 14),
                  GymPanel(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: _text(
                              labels,
                              uk: 'Назва, мʼязи, обладнання...',
                              en: 'Name, muscle, equipment...',
                            ),
                            prefixIcon: Icon(Icons.search),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                    icon: Icon(Icons.close),
                                  ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.lime),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${exercises.length} / $totalExercises ${_text(labels, uk: 'вправ', en: 'exercises')}',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            FilterChip(
                              selected: _showOnlyWithVideo,
                              avatar: Icon(Icons.play_circle, size: 16),
                              label: Text(
                                _text(labels, uk: 'З відео', en: 'Video'),
                              ),
                              onSelected: (value) {
                                setState(() => _showOnlyWithVideo = value);
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: muscles.length + 1,
                            separatorBuilder: (_, _) => SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final muscle = index == 0
                                  ? null
                                  : muscles[index - 1];
                              final selected = muscle == _selectedMuscle;
                              return ChoiceChip(
                                selected: selected,
                                label: Text(
                                  muscle == null
                                      ? labels.t('allMuscles')
                                      : '${labels.muscleName(muscle)} ${muscleCounts[muscle] ?? 0}',
                                ),
                                onSelected: (_) {
                                  setState(() => _selectedMuscle = muscle);
                                },
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 12),
                        BouncyGymButton(
                          label: _text(
                            labels,
                            uk: 'ДОДАТИ СВОЮ ВПРАВУ',
                            en: 'ADD CUSTOM EXERCISE',
                          ),
                          height: 48,
                          icon: Icons.add_photo_alternate,
                          isOutlined: true,
                          onTap: () => _createCustomExercise(labels),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.lime),
              ),
            )
          else if (exercises.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  _text(
                    labels,
                    uk: 'Нічого не знайдено',
                    en: 'No exercises found',
                  ),
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 110),
              sliver: SliverList.separated(
                itemCount: exercises.length,
                separatorBuilder: (_, _) => SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final exercise = exercises[index];
                  return _SearchExerciseCard(
                    key: ValueKey('search-${exercise.id}-${exercise.imageUrl}'),
                    labels: labels,
                    exercise: exercise,
                    selectedDayNumber: _selectedDayNumber,
                    onOpen: () => showExerciseDetailSheet(
                      context: context,
                      labels: labels,
                      exercise: exercise,
                      addLabel:
                          '${_text(labels, uk: 'ДОДАТИ В ДЕНЬ', en: 'ADD TO DAY')} $_selectedDayNumber',
                      onAdd: () =>
                          unawaited(_addExerciseToSelectedDay(exercise)),
                    ),
                    onAdd: () => _addExerciseToSelectedDay(exercise),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DayTargetRail extends StatelessWidget {
  const _DayTargetRail({
    required this.labels,
    required this.days,
    required this.plans,
    required this.selectedDayNumber,
    required this.onSelected,
  });

  final GymLabels labels;
  final List<int> days;
  final List<TrainingDayPlan> plans;
  final int selectedDayNumber;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final plan = plans.where((item) => item.dayNumber == day).firstOrNull;
          final isSelected = day == selectedDayNumber;

          return InkWell(
            onTap: () => onSelected(day),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 180),
              width: 138,
              padding: EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.lime : AppColors.panel,
                border: Border.all(
                  color: isSelected ? AppColors.lime : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      color: isSelected ? AppColors.ink : AppColors.lime,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${labels.t('programDayShort')} $day',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? AppColors.ink : AppColors.text,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          plan?.name ??
                              _text(labels, uk: 'Новий день', en: 'New day'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.ink.withValues(alpha: 0.7)
                                : AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchExerciseCard extends StatelessWidget {
  const _SearchExerciseCard({
    required this.labels,
    required this.exercise,
    required this.selectedDayNumber,
    required this.onOpen,
    required this.onAdd,
    super.key,
  });

  final GymLabels labels;
  final Exercise exercise;
  final int selectedDayNumber;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: _accent(exercise.primaryMuscle).withValues(alpha: 0.11),
              blurRadius: 18,
              spreadRadius: -12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Row(
            children: [
              _ExerciseImage(exercise: exercise, size: 78),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labels.exerciseName(exercise.id, exercise.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniChip(
                          label: labels.muscleName(exercise.primaryMuscle),
                        ),
                        if (exercise.equipment.trim().isNotEmpty)
                          _MiniChip(
                            label: labels.catalogAttribute(exercise.equipment),
                          ),
                        if (exercise.videoUrl.trim().isNotEmpty)
                          _MiniChip(
                            label: _text(labels, uk: 'відео', en: 'video'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filled(
                    onPressed: onAdd,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(Icons.add),
                    tooltip:
                        '${_text(labels, uk: 'День', en: 'Day')} $selectedDayNumber',
                  ),
                  SizedBox(height: 4),
                  Icon(Icons.chevron_right, color: AppColors.lime),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseImage extends StatelessWidget {
  const _ExerciseImage({required this.exercise, required this.size});

  final Exercise exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = exercise.imageUrl.trim();
    final accent = _accent(exercise.primaryMuscle);

    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.black,
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: imageUrl.isEmpty
              ? Icon(Icons.fitness_center, color: accent, size: 34)
              : GymExerciseImage(
                  key: ValueKey('thumb-${exercise.id}-$imageUrl'),
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.fitness_center, color: accent, size: 34);
                  },
                ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.34),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _CustomExerciseDialog extends StatefulWidget {
  const _CustomExerciseDialog({required this.labels});

  final GymLabels labels;

  @override
  State<_CustomExerciseDialog> createState() => _CustomExerciseDialogState();
}

class _CustomExerciseDialogState extends State<_CustomExerciseDialog> {
  final _nameController = TextEditingController();
  final _muscleController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _imageController = TextEditingController();
  final _videoController = TextEditingController();
  var _isSaving = false;
  var _isPickingPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    _muscleController.dispose();
    _equipmentController.dispose();
    _imageController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty || _isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    final repository = context.read<WorkoutSessionRepository>();
    final exercise = await repository.createCustomExercise(
      name: _nameController.text,
      primaryMuscle: _muscleController.text.trim().isEmpty
          ? 'Custom'
          : _muscleController.text,
      equipment: _equipmentController.text,
      imageUrl: _imageController.text,
      videoUrl: _videoController.text,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(exercise);
  }

  Future<void> _pickPhoto() async {
    setState(() => _isPickingPhoto = true);
    try {
      final picked = await pickPhotoFromDevice();
      if (picked == null) {
        return;
      }
      _imageController.text = gymImageDataUrlFromBytes(
        bytes: picked.bytes,
        mimeType: picked.mimeType,
      );
      if (mounted) {
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      backgroundColor: AppColors.surface,
      title: Text(
        _text(labels, uk: 'СВОЯ ВПРАВА', en: 'CUSTOM EXERCISE'),
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogField(
              controller: _nameController,
              label: labels.t('exerciseName'),
              capitalization: TextCapitalization.words,
            ),
            SizedBox(height: 10),
            _DialogField(
              controller: _muscleController,
              label: labels.t('muscleGroup'),
              capitalization: TextCapitalization.words,
            ),
            SizedBox(height: 10),
            _DialogField(
              controller: _equipmentController,
              label: _text(labels, uk: 'Обладнання', en: 'Equipment'),
              capitalization: TextCapitalization.words,
            ),
            SizedBox(height: 10),
            _DialogPhotoPickerCard(
              labels: labels,
              imageUrl: _imageController.text.trim(),
              isPicking: _isPickingPhoto,
              onPick: _pickPhoto,
              onClear: () {
                _imageController.clear();
                setState(() {});
              },
            ),
            SizedBox(height: 10),
            _DialogField(
              controller: _videoController,
              label: _text(labels, uk: 'Відео URL', en: 'Video URL'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(labels.t('cancel')),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.lime,
            foregroundColor: AppColors.ink,
          ),
          child: Text(labels.t('save')),
        ),
      ],
    );
  }
}

class _DialogPhotoPickerCard extends StatelessWidget {
  const _DialogPhotoPickerCard({
    required this.labels,
    required this.imageUrl,
    required this.isPicking,
    required this.onPick,
    required this.onClear,
  });

  final GymLabels labels;
  final String imageUrl;
  final bool isPicking;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.25),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: 66,
                height: 66,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(
                      color: AppColors.lime.withValues(alpha: 0.35),
                    ),
                  ),
                  child: hasImage
                      ? GymExerciseImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.muted,
                            );
                          },
                        )
                      : Icon(Icons.add_photo_alternate, color: AppColors.lime),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text(labels, uk: 'Фото вправи', en: 'Exercise photo'),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _text(
                      labels,
                      uk: 'Обери картинку з телефону або компʼютера.',
                      en: 'Choose an image from your device.',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isPicking ? null : onPick,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.lime,
                            foregroundColor: AppColors.ink,
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          icon: isPicking
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.ink,
                                  ),
                                )
                              : Icon(Icons.photo_library_outlined, size: 16),
                          label: Text(
                            _text(labels, uk: 'Обрати', en: 'Choose'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (hasImage) ...[
                        SizedBox(width: 8),
                        IconButton(
                          onPressed: onClear,
                          icon: Icon(Icons.close, size: 18),
                          tooltip: labels.t('delete'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    this.capitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.lime),
        ),
      ),
    );
  }
}

String _defaultDayName(GymLabels labels, int dayNumber, Exercise exercise) {
  final muscle = labels.muscleName(exercise.primaryMuscle);
  return labels.language == GymLanguage.uk
      ? 'День $dayNumber · $muscle'
      : 'Day $dayNumber · $muscle';
}

String _text(GymLabels labels, {required String uk, required String en}) {
  return labels.language == GymLanguage.uk ? uk : en;
}

Color _accent(String muscle) {
  return switch (muscle) {
    'Chest' => Color(0xFFCCFF00),
    'Back' => Color(0xFF38BDF8),
    'Quads' => Color(0xFFFFD166),
    'Glutes' => Color(0xFFFF4D8D),
    'Hamstrings' => Color(0xFFA78BFA),
    'Posterior' => Color(0xFF22C55E),
    'Calves' => Color(0xFFFB923C),
    'Shoulders' => Color(0xFF67E8F9),
    'Biceps' => Color(0xFF60A5FA),
    'Triceps' => Color(0xFFF472B6),
    'Core' => Color(0xFFFAFAFA),
    _ => AppColors.lime,
  };
}
