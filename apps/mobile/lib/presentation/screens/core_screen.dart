import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/gym_labels.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bouncy_gym_button.dart';
import '../../core/widgets/gym_panel.dart';
import '../../data/repos/workout_session_repository.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/training_day_plan.dart';
import '../bloc/analytics_cubit.dart';
import '../bloc/dashboard_cubit.dart';
import '../bloc/locale_cubit.dart';
import '../bloc/session_cubit.dart';
import 'active_session_screen.dart';

class CoreScreen extends StatefulWidget {
  const CoreScreen({super.key});

  @override
  State<CoreScreen> createState() => _CoreScreenState();
}

class _CoreScreenState extends State<CoreScreen> {
  var _selectedDayNumber = 1;
  TrainingDayPlan _selectedPlan = TrainingDayPlan.empty(1);
  List<Exercise> _allExercises = const [];
  List<TrainingDayPlan> _plannedPlans = const [];
  Set<int> _plannedDays = const {};
  var _isLoadingPlan = true;

  @override
  void initState() {
    super.initState();
    _loadInitialDay();
  }

  Future<void> _loadInitialDay() async {
    final dayNumber = await context
        .read<WorkoutSessionRepository>()
        .loadSuggestedDayNumber();
    if (!mounted) {
      return;
    }
    await _loadDay(dayNumber);
  }

  Future<void> _loadDay(int dayNumber) async {
    setState(() {
      _selectedDayNumber = dayNumber;
      _isLoadingPlan = true;
    });

    final repository = context.read<WorkoutSessionRepository>();
    final exercises = await repository.loadExercises();
    final plan = await repository.loadTrainingDayPlan(dayNumber);
    final plannedPlans = await repository.loadTrainingDayPlans();
    final plannedDays = {for (final plan in plannedPlans) plan.dayNumber};
    if (!mounted) {
      return;
    }

    setState(() {
      _allExercises = exercises;
      _selectedPlan = plan;
      _plannedPlans = plannedPlans;
      _plannedDays = plannedDays;
      _isLoadingPlan = false;
    });
  }

  Future<void> _openCreateDayDialog(GymLabels labels) async {
    final repository = context.read<WorkoutSessionRepository>();
    final nameController = TextEditingController(
      text: _selectedPlan.name.isEmpty ? '' : _selectedPlan.name,
    );
    final customNameController = TextEditingController();
    final customMuscleController = TextEditingController();
    final selectedExercises = [..._selectedPlan.exercises];
    var allExercises = [..._allExercises];
    var isCatalogExpanded = false;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              insetPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              title: Text(
                '${_selectedPlan.isEmpty ? labels.t('createDay') : labels.t('editDay')} · ${labels.t('programDay')} $_selectedDayNumber',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: labels.t('dayName'),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.lime),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      _DialogSectionLabel(text: labels.t('customExercise')),
                      SizedBox(height: 8),
                      TextField(
                        controller: customNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: labels.t('exerciseName'),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.lime),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customMuscleController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: labels.t('muscleGroup'),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.lime),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          IconButton.filled(
                            onPressed: () async {
                              if (customNameController.text.trim().isEmpty) {
                                return;
                              }
                              final exercise = await repository
                                  .createCustomExercise(
                                    name: customNameController.text,
                                    primaryMuscle: customMuscleController.text,
                                  );
                              setDialogState(() {
                                allExercises = [
                                  ...allExercises.where(
                                    (item) => item.id != exercise.id,
                                  ),
                                  exercise,
                                ];
                                selectedExercises.add(
                                  TrainingPlanExercise(
                                    exercise: exercise,
                                    targetSets: 3,
                                    targetReps: 10,
                                    comment: '',
                                  ),
                                );
                                customNameController.clear();
                                customMuscleController.clear();
                              });
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.lime,
                              foregroundColor: AppColors.ink,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            icon: Icon(Icons.add),
                            tooltip: labels.t('addExercise'),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _DialogSectionLabel(text: labels.t('quickAdd')),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final exercise in _suggestedExercises(
                            nameController.text,
                            allExercises,
                          ))
                            ActionChip(
                              avatar: Icon(Icons.add, size: 16),
                              label: Text(
                                labels.exerciseName(exercise.id, exercise.name),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  selectedExercises.add(
                                    TrainingPlanExercise(
                                      exercise: exercise,
                                      targetSets: 3,
                                      targetReps: 10,
                                      comment: '',
                                    ),
                                  );
                                });
                              },
                            ),
                        ],
                      ),
                      SizedBox(height: 10),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: AppColors.panel,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: isCatalogExpanded,
                          onExpansionChanged: (value) {
                            setDialogState(() => isCatalogExpanded = value);
                          },
                          leading: Icon(
                            Icons.library_add,
                            color: AppColors.lime,
                          ),
                          title: Text(
                            labels.t('addExercise'),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                          childrenPadding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final exercise in allExercises)
                                  ActionChip(
                                    avatar: Icon(Icons.add, size: 16),
                                    label: Text(
                                      labels.exerciseName(
                                        exercise.id,
                                        exercise.name,
                                      ),
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        selectedExercises.add(
                                          TrainingPlanExercise(
                                            exercise: exercise,
                                            targetSets: 3,
                                            targetReps: 10,
                                            comment: '',
                                          ),
                                        );
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      _DialogSectionLabel(text: labels.t('planOrder')),
                      SizedBox(height: 8),
                      if (selectedExercises.isEmpty)
                        Text(
                          labels.t('emptyDaySubtitle'),
                          style: TextStyle(color: AppColors.muted),
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: selectedExercises.length,
                          onReorder: (oldIndex, newIndex) {
                            setDialogState(() {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              final item = selectedExercises.removeAt(oldIndex);
                              selectedExercises.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final item = selectedExercises[index];
                            return _SelectedExerciseRow(
                              key: ValueKey(
                                '${item.exercise.id}-$index-${item.targetSets}-${item.targetReps}',
                              ),
                              labels: labels,
                              index: index,
                              item: item,
                              onChanged: (updated) {
                                setDialogState(() {
                                  selectedExercises[index] = updated;
                                });
                              },
                              onEditExercise: () async {
                                final updated = await showDialog<Exercise>(
                                  context: dialogContext,
                                  builder: (_) => _EditExerciseDialog(
                                    labels: labels,
                                    exercise: item.exercise,
                                  ),
                                );
                                if (updated == null) {
                                  return;
                                }
                                final saved = await repository.updateExercise(
                                  exercise: item.exercise,
                                  name: updated.name,
                                  primaryMuscle: updated.primaryMuscle,
                                );
                                setDialogState(() {
                                  allExercises = [
                                    for (final exercise in allExercises)
                                      if (exercise.id == saved.id)
                                        saved
                                      else
                                        exercise,
                                  ];
                                  for (
                                    var itemIndex = 0;
                                    itemIndex < selectedExercises.length;
                                    itemIndex += 1
                                  ) {
                                    final current =
                                        selectedExercises[itemIndex];
                                    if (current.exercise.id == saved.id) {
                                      selectedExercises[itemIndex] = current
                                          .copyWith(exercise: saved);
                                    }
                                  }
                                });
                              },
                              onDeleteExercise:
                                  item.exercise.id.startsWith('custom_')
                                  ? () async {
                                      await repository.deleteCustomExercise(
                                        item.exercise,
                                      );
                                      setDialogState(() {
                                        allExercises = [
                                          for (final exercise in allExercises)
                                            if (exercise.id != item.exercise.id)
                                              exercise,
                                        ];
                                        selectedExercises.removeWhere(
                                          (current) =>
                                              current.exercise.id ==
                                              item.exercise.id,
                                        );
                                      });
                                    }
                                  : null,
                              onSettings: () async {
                                final updated =
                                    await showDialog<TrainingPlanExercise>(
                                      context: dialogContext,
                                      builder: (_) =>
                                          _PlanExerciseSettingsDialog(
                                            labels: labels,
                                            item: item,
                                          ),
                                    );
                                if (updated == null) {
                                  return;
                                }
                                setDialogState(() {
                                  selectedExercises[index] = updated;
                                });
                              },
                              onRemove: () {
                                setDialogState(() {
                                  selectedExercises.removeAt(index);
                                });
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(labels.t('cancel')),
                ),
                FilledButton(
                  onPressed: selectedExercises.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.ink,
                  ),
                  child: Text(labels.t('saveDay')),
                ),
              ],
            );
          },
        );
      },
    );

    final planName = nameController.text;

    if (shouldSave != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    await context.read<WorkoutSessionRepository>().saveTrainingDayPlan(
      dayNumber: _selectedDayNumber,
      name: planName,
      exercises: selectedExercises,
      restSeconds: _selectedPlan.restSeconds,
    );
    await _loadDay(_selectedDayNumber);
  }

  Future<void> _openNextDayDialog(GymLabels labels) async {
    final nextDayNumber = _nextDayNumber;
    if (nextDayNumber == null) {
      return;
    }

    await _loadDay(nextDayNumber);
    if (!mounted) {
      return;
    }
    await _openCreateDayDialog(labels);
  }

  Future<void> _deleteSelectedDay(GymLabels labels) async {
    if (_selectedPlan.isEmpty) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(labels.t('deleteDay')),
          content: Text(labels.t('deleteDayConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(labels.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: AppColors.ink,
              ),
              child: Text(labels.t('delete')),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    await context.read<WorkoutSessionRepository>().deleteTrainingDayPlan(
      _selectedPlan.dayNumber,
    );
    await _loadInitialDay();
  }

  int? get _nextDayNumber {
    if (_plannedPlans.length >= 7) {
      return null;
    }
    if (_plannedPlans.isEmpty) {
      return 1;
    }
    final lastDayNumber = _plannedPlans
        .map((plan) => plan.dayNumber)
        .reduce((max, value) => value > max ? value : max);
    return (lastDayNumber + 1).clamp(1, 7);
  }

  void _startPlannedSession() {
    final dashboardCubit = context.read<DashboardCubit>();
    final analyticsCubit = context.read<AnalyticsCubit>();

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider(
              create: (context) => SessionCubit(
                context.read<WorkoutSessionRepository>(),
                plan: _selectedPlan,
              )..startSession(),
              child: ActiveSessionScreen(
                plannedExercises: _selectedPlan.exercises,
                initialRestSeconds: _selectedPlan.restSeconds,
              ),
            ),
          ),
        )
        .then((_) async {
          await dashboardCubit.load();
          await analyticsCubit.load();
          if (mounted) {
            await _loadInitialDay();
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final labels = context.watch<LocaleCubit>().labels;
    final nextDayNumber = _nextDayNumber;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 112),
        children: [
          _Header(labels: labels),
          SizedBox(height: 20),
          _DayStrip(
            labels: labels,
            selectedDayNumber: _selectedDayNumber,
            plannedPlans: _plannedPlans,
            onSelected: _loadDay,
          ),
          if (nextDayNumber != null && _plannedDays.isNotEmpty) ...[
            SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: Icon(Icons.add, size: 17),
                label: Text('${labels.t('addProgramDay')} $nextDayNumber'),
                onPressed: () => _openNextDayDialog(labels),
              ),
            ),
          ],
          SizedBox(height: 18),
          _CalendarStrip(labels: labels),
          SizedBox(height: 18),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation);

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: _DayPlanCard(
              key: ValueKey(
                'day-plan-${_selectedPlan.dayNumber}-${_selectedPlan.id}',
              ),
              labels: labels,
              plan: _selectedPlan,
              isLoading: _isLoadingPlan,
              onCreate: () => _openCreateDayDialog(labels),
              onDelete: () => _deleteSelectedDay(labels),
            ),
          ),
          SizedBox(height: 14),
          BouncyGymButton(
            label: _selectedPlan.isEmpty
                ? labels.t('createDay')
                : labels.t('startSession'),
            height: 64,
            icon: _selectedPlan.isEmpty ? Icons.add : Icons.play_arrow,
            onTap: _selectedPlan.isEmpty
                ? () => _openCreateDayDialog(labels)
                : _startPlannedSession,
          ),
        ],
      ),
    );
  }
}

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.lime,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

List<Exercise> _suggestedExercises(String dayName, List<Exercise> exercises) {
  final query = dayName.toLowerCase();
  final keywords = <String>{
    if (_matchesAny(query, [
      'рук',
      'біцеп',
      'трицеп',
      'arm',
      'bicep',
      'tricep',
    ])) ...[
      'Biceps',
      'Triceps',
    ],
    if (_matchesAny(query, ['ніг', 'квад', 'leg', 'quad'])) ...[
      'Quads',
      'Hamstrings',
      'Posterior',
      'Glutes',
    ],
    if (_matchesAny(query, ['сід', 'ягод', 'glute', 'booty'])) ...[
      'Glutes',
      'Posterior',
      'Hamstrings',
    ],
    if (_matchesAny(query, ['спин', 'back', 'pull'])) ...['Back', 'Posterior'],
    if (_matchesAny(query, ['груд', 'жим', 'chest', 'push'])) ...[
      'Chest',
      'Triceps',
      'Shoulders',
    ],
    if (_matchesAny(query, ['плеч', 'shoulder', 'дельт'])) ...['Shoulders'],
    if (_matchesAny(query, ['прес', 'core', 'abs'])) ...['Core'],
    if (_matchesAny(query, ['верх', 'upper'])) ...[
      'Chest',
      'Back',
      'Shoulders',
      'Biceps',
      'Triceps',
    ],
    if (_matchesAny(query, ['фул', 'full', 'все'])) ...[
      'Quads',
      'Chest',
      'Back',
      'Shoulders',
      'Glutes',
    ],
  };

  final suggested = keywords.isEmpty
      ? exercises.take(8).toList()
      : exercises
            .where((exercise) => keywords.contains(exercise.primaryMuscle))
            .take(10)
            .toList();

  return suggested.isEmpty ? exercises.take(8).toList() : suggested;
}

bool _matchesAny(String value, List<String> patterns) {
  return patterns.any(value.contains);
}

class _SelectedExerciseRow extends StatelessWidget {
  const _SelectedExerciseRow({
    super.key,
    required this.labels,
    required this.index,
    required this.item,
    required this.onChanged,
    required this.onEditExercise,
    required this.onDeleteExercise,
    required this.onSettings,
    required this.onRemove,
  });

  final GymLabels labels;
  final int index;
  final TrainingPlanExercise item;
  final ValueChanged<TrainingPlanExercise> onChanged;
  final VoidCallback onEditExercise;
  final VoidCallback? onDeleteExercise;
  final VoidCallback onSettings;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final exercise = item.exercise;

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 8, 8, 10),
          child: Column(
            children: [
              Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(Icons.drag_indicator, color: AppColors.lime),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      labels.exerciseName(exercise.id, exercise.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: AppColors.panel,
                    icon: Icon(Icons.more_vert, color: AppColors.lime),
                    onSelected: (value) {
                      if (value == 'settings') {
                        onSettings();
                      } else if (value == 'edit') {
                        onEditExercise();
                      } else if (value == 'delete') {
                        onDeleteExercise?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'settings',
                        child: Text(labels.t('exerciseSettings')),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(labels.t('editExercise')),
                      ),
                      if (onDeleteExercise != null)
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(labels.t('deleteExercise')),
                        ),
                    ],
                  ),
                  InkWell(
                    onTap: onRemove,
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.close),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _CompactPlanCounter(
                      label: labels.t('targetSets'),
                      value: item.targetSets,
                      min: 1,
                      max: 20,
                      onChanged: (value) =>
                          onChanged(item.copyWith(targetSets: value)),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _CompactPlanCounter(
                      label: labels.t('targetReps'),
                      value: item.targetReps,
                      min: 1,
                      max: 100,
                      onChanged: (value) =>
                          onChanged(item.copyWith(targetReps: value)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              TextFormField(
                initialValue: item.comment,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 1,
                onChanged: (value) => onChanged(item.copyWith(comment: value)),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: labels.t('exerciseComment'),
                  prefixIcon: Icon(Icons.notes, size: 18),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.lime),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactPlanCounter extends StatelessWidget {
  const _CompactPlanCounter({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value <= min ? null : () => onChanged(value - 1),
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.remove, size: 18),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  '$value',
                  style: TextStyle(
                    color: AppColors.lime,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: value >= max ? null : () => onChanged(value + 1),
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

class _PlanExerciseSettingsDialog extends StatefulWidget {
  const _PlanExerciseSettingsDialog({required this.labels, required this.item});

  final GymLabels labels;
  final TrainingPlanExercise item;

  @override
  State<_PlanExerciseSettingsDialog> createState() =>
      _PlanExerciseSettingsDialogState();
}

class _PlanExerciseSettingsDialogState
    extends State<_PlanExerciseSettingsDialog> {
  late int _targetSets;
  late int _targetReps;

  @override
  void initState() {
    super.initState();
    _targetSets = widget.item.targetSets;
    _targetReps = widget.item.targetReps;
  }

  void _save() {
    Navigator.of(context).pop(
      widget.item.copyWith(targetSets: _targetSets, targetReps: _targetReps),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final exercise = widget.item.exercise;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      title: Text(labels.t('exerciseSettings')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            labels.exerciseName(exercise.id, exercise.name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.lime,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 16),
          _PlanCounter(
            label: labels.t('targetSets'),
            value: _targetSets,
            min: 1,
            max: 20,
            onChanged: (value) => setState(() => _targetSets = value),
          ),
          SizedBox(height: 10),
          _PlanCounter(
            label: labels.t('targetReps'),
            value: _targetReps,
            min: 1,
            max: 100,
            onChanged: (value) => setState(() => _targetReps = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(labels.t('cancel')),
        ),
        FilledButton(
          onPressed: _save,
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

class _EditExerciseDialog extends StatefulWidget {
  const _EditExerciseDialog({required this.labels, required this.exercise});

  final GymLabels labels;
  final Exercise exercise;

  @override
  State<_EditExerciseDialog> createState() => _EditExerciseDialogState();
}

class _EditExerciseDialogState extends State<_EditExerciseDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _muscleController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exercise.name);
    _muscleController = TextEditingController(
      text: widget.exercise.primaryMuscle,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _muscleController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      Exercise(
        id: widget.exercise.id,
        name: _nameController.text.trim(),
        primaryMuscle: _muscleController.text.trim().isEmpty
            ? widget.exercise.primaryMuscle
            : _muscleController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      backgroundColor: AppColors.surface,
      title: Text(labels.t('editExercise')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: labels.t('exerciseName'),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.lime),
              ),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _muscleController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: labels.t('muscleGroup'),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.lime),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(labels.t('cancel')),
        ),
        FilledButton(
          onPressed: _save,
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

class _PlanCounter extends StatelessWidget {
  const _PlanCounter({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            IconButton(
              onPressed: value <= min ? null : () => onChanged(value - 1),
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.remove),
            ),
            SizedBox(
              width: 46,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.lime,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            IconButton(
              onPressed: value >= max ? null : () => onChanged(value + 1),
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.labels});

  final GymLabels labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GYMENGINE',
          style: TextStyle(
            color: AppColors.lime,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: 8),
        Text(
          labels.t('base'),
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            height: 0.95,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.labels,
    required this.selectedDayNumber,
    required this.plannedPlans,
    required this.onSelected,
  });

  final GymLabels labels;
  final int selectedDayNumber;
  final List<TrainingDayPlan> plannedPlans;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final visiblePlans = plannedPlans.isEmpty
        ? const [TrainingDayPlan.empty(1)]
        : plannedPlans;

    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: PageScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.symmetric(horizontal: 1),
        itemCount: visiblePlans.length,
        separatorBuilder: (_, _) => SizedBox(width: 7),
        itemBuilder: (context, index) {
          final plan = visiblePlans[index];
          final day = plan.dayNumber;
          final isSelected = day == selectedDayNumber;
          final hasPlan = !plan.isEmpty;
          final subtitle = hasPlan ? plan.name : labels.t('emptyDayShort');

          return _ProgramDayTile(
            labels: labels,
            dayNumber: day,
            subtitle: subtitle,
            isSelected: isSelected,
            isEnabled: hasPlan || plannedPlans.isEmpty,
            onTap: () => onSelected(day),
          );
        },
      ),
    );
  }
}

class _ProgramDayTile extends StatefulWidget {
  const _ProgramDayTile({
    required this.labels,
    required this.dayNumber,
    required this.subtitle,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final GymLabels labels;
  final int dayNumber;
  final String subtitle;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  State<_ProgramDayTile> createState() => _ProgramDayTileState();
}

class _ProgramDayTileState extends State<_ProgramDayTile> {
  var _isPressed = false;

  void _setPressed(bool value) {
    if (!widget.isEnabled || _isPressed == value) {
      return;
    }
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final foreground = isSelected ? AppColors.text : AppColors.muted;
    final borderColor = isSelected ? AppColors.lime : AppColors.border;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) {
        _setPressed(false);
        if (widget.isEnabled) {
          widget.onTap();
        }
      },
      child: AnimatedScale(
        duration: Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _isPressed ? 0.96 : (isSelected ? 1.02 : 1),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 132,
          height: 56,
          padding: EdgeInsets.fromLTRB(8, 7, 8, 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.panel : AppColors.surface,
            border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.lime.withValues(alpha: 0.24),
                      blurRadius: 16,
                      spreadRadius: -8,
                      offset: Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: 34,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.lime : AppColors.black,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${widget.dayNumber}',
                      style: TextStyle(
                        color: isSelected ? AppColors.ink : AppColors.lime,
                        fontSize: 22,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.labels.t('programDayShort')} ${widget.dayNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        SizedBox(height: 5),
                        AnimatedSwitcher(
                          duration: Duration(milliseconds: 180),
                          child: Text(
                            widget.subtitle,
                            key: ValueKey(widget.subtitle),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.text
                                  : AppColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 5),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 220),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.lime : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: isSelected ? 1 : 0),
                  duration: Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarStrip extends StatelessWidget {
  const _CalendarStrip({required this.labels});

  final GymLabels labels;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        final snapshot = state.snapshot;
        final today = DateTime.now();
        final days = [
          for (var offset = 6; offset >= 0; offset -= 1)
            DateTime(
              today.year,
              today.month,
              today.day,
            ).subtract(Duration(days: offset)),
        ];
        final trainedDates = {
          for (final date in snapshot.recentTrainingDates)
            DateTime(date.year, date.month, date.day),
        };

        return GymPanel(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      labels.t('calendar'),
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Text(
                    '${snapshot.sessionCount} ${labels.t('trained').toLowerCase()}',
                    style: TextStyle(
                      color: AppColors.lime,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  for (final day in days) ...[
                    Expanded(
                      child: _CalendarDay(
                        date: day,
                        isTrained: trainedDates.contains(day),
                      ),
                    ),
                    if (day != days.last) SizedBox(width: 7),
                  ],
                ],
              ),
              if (snapshot.lastExerciseName != null) ...[
                SizedBox(height: 12),
                Text(
                  '${labels.t('lastLiftShort')}: ${snapshot.lastExerciseName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.date, required this.isTrained});

  final DateTime date;
  final bool isTrained;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isTrained ? AppColors.lime : AppColors.surface,
        border: Border.all(
          color: isTrained ? AppColors.lime : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              _weekday(date.weekday),
              style: TextStyle(
                color: isTrained ? AppColors.ink : AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '${date.day}',
              style: TextStyle(
                color: isTrained ? AppColors.ink : AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _weekday(int weekday) {
    const names = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'НД'];
    return names[weekday - 1];
  }
}

class _DayPlanCard extends StatelessWidget {
  const _DayPlanCard({
    super.key,
    required this.labels,
    required this.plan,
    required this.isLoading,
    required this.onCreate,
    required this.onDelete,
  });

  final GymLabels labels;
  final TrainingDayPlan plan;
  final bool isLoading;
  final VoidCallback onCreate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.lime));
    }

    if (plan.isEmpty) {
      return GymPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labels.t('nextUp'),
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '${labels.t('programDay')} ${plan.dayNumber}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 4),
            Text(
              labels.t('emptyDayTitle'),
              style: TextStyle(
                color: AppColors.lime,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 8),
            Text(
              labels.t('emptyDaySubtitle'),
              style: TextStyle(
                color: AppColors.muted,
                height: 1.35,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      );
    }

    return GymPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labels.t('plannedExercises'),
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '${labels.t('programDay')} ${plan.dayNumber}',
            style: TextStyle(
              color: AppColors.lime,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 6),
          Text(
            plan.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: Icon(Icons.tune, size: 16),
                label: Text(labels.t('editDay')),
                onPressed: onCreate,
              ),
              ActionChip(
                avatar: Icon(Icons.delete_outline, size: 16),
                label: Text(labels.t('deleteDay')),
                onPressed: onDelete,
              ),
            ],
          ),
          SizedBox(height: 14),
          for (final entry in plan.exercises.indexed) ...[
            _PlanPreviewRow(labels: labels, item: entry.$2),
            if (entry.$1 != plan.exercises.length - 1) SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _PlanPreviewRow extends StatelessWidget {
  const _PlanPreviewRow({required this.labels, required this.item});

  final GymLabels labels;
  final TrainingPlanExercise item;

  @override
  Widget build(BuildContext context) {
    final comment = item.comment.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.35),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(Icons.drag_indicator, color: AppColors.lime),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labels.exerciseName(item.exercise.id, item.exercise.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  if (comment.isNotEmpty) ...[
                    SizedBox(height: 3),
                    Text(
                      comment,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8),
            Text(
              '${item.targetSets}x · ${item.targetReps} ${labels.t('repsSmall')}',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
