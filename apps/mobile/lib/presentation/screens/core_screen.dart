import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/gym_labels.dart';
import '../../core/notifications/rest_notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/exercise_catalog_cleanup.dart';
import '../../core/util/external_link.dart';
import '../../core/util/photo_picker.dart';
import '../../core/widgets/bouncy_gym_button.dart';
import '../../core/widgets/gym_exercise_image.dart';
import '../../core/widgets/gym_panel.dart';
import '../../data/repos/workout_session_repository.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/training_day_plan.dart';
import '../../domain/models/workout_session_draft.dart';
import '../bloc/analytics_cubit.dart';
import '../bloc/dashboard_cubit.dart';
import '../bloc/locale_cubit.dart';
import '../bloc/session_cubit.dart';
import 'active_session_screen.dart';

class CoreScreen extends StatefulWidget {
  const CoreScreen({this.onOpenSearch, super.key});

  final ValueChanged<int>? onOpenSearch;

  @override
  State<CoreScreen> createState() => _CoreScreenState();
}

class _CoreScreenState extends State<CoreScreen> {
  var _selectedDayNumber = 1;
  TrainingDayPlan _selectedPlan = TrainingDayPlan.empty(1);
  List<Exercise> _allExercises = const [];
  List<TrainingDayPlan> _plannedPlans = const [];
  Set<int> _plannedDays = const {};
  WorkoutSessionDraft? _openSession;
  TrainingDayPlan? _openSessionPlan;
  Timer? _openSessionTicker;
  var _isLoadingPlan = true;

  @override
  void initState() {
    super.initState();
    _loadInitialDay();
  }

  @override
  void dispose() {
    _openSessionTicker?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialDay() async {
    final repository = context.read<WorkoutSessionRepository>();
    final openSession = await repository.loadOpenSession();
    final suggestedDayNumber = await repository.loadSuggestedDayNumber();
    final dayNumber = openSession?.templateDayNumber ?? suggestedDayNumber;
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
    final openSession = await repository.loadOpenSession();
    final openSessionDay = openSession?.templateDayNumber;
    final openSessionPlan = openSessionDay == null
        ? null
        : await repository.loadTrainingDayPlan(openSessionDay);
    if (!mounted) {
      return;
    }

    setState(() {
      _allExercises = exercises;
      _selectedPlan = plan;
      _plannedPlans = plannedPlans;
      _plannedDays = plannedDays;
      _openSession = openSession;
      _openSessionPlan = openSessionPlan;
      _isLoadingPlan = false;
    });
    _syncOpenSessionTicker();
    _syncOngoingWorkoutNotification();
  }

  void _syncOpenSessionTicker() {
    _openSessionTicker?.cancel();
    if (_openSession == null) {
      _openSessionTicker = null;
      return;
    }

    _openSessionTicker = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _syncOngoingWorkoutNotification() async {
    final labels = context.read<LocaleCubit>().labels;
    final notifications = context.read<RestNotificationService>();
    if (_openSession == null) {
      await notifications.cancelTrainingOngoing();
      return;
    }

    await notifications.requestPermission();
    await notifications.showTrainingOngoing(
      title: labels.t('ongoingNotificationTitle'),
      body: labels.t('ongoingNotificationBody'),
    );
  }

  Future<void> _openCreateDayDialog(GymLabels labels) async {
    final repository = context.read<WorkoutSessionRepository>();
    final nameController = TextEditingController(
      text: _selectedPlan.name.isEmpty ? '' : _selectedPlan.name,
    );
    final catalogSearchController = TextEditingController();
    final customNameController = TextEditingController();
    final customMuscleController = TextEditingController();
    final selectedExercises = [..._selectedPlan.exercises];
    var allExercises = [..._allExercises];
    var isCatalogExpanded = false;
    String? selectedMuscle;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void addExerciseToSelection(Exercise exercise) {
              final alreadySelected = selectedExercises.any(
                (item) => item.exercise.id == exercise.id,
              );
              if (alreadySelected) {
                return;
              }
              selectedExercises.add(
                TrainingPlanExercise(
                  exercise: exercise,
                  targetSets: 3,
                  targetReps: 10,
                  comment: '',
                ),
              );
            }

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
                                addExerciseToSelection(exercise);
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
                      _SmartPackRail(
                        labels: labels,
                        exercises: allExercises,
                        onAddPack: (exercises) {
                          setDialogState(() {
                            final existingIds = {
                              for (final item in selectedExercises)
                                item.exercise.id,
                            };
                            for (final exercise in exercises) {
                              if (existingIds.add(exercise.id)) {
                                selectedExercises.add(
                                  TrainingPlanExercise(
                                    exercise: exercise,
                                    targetSets: 3,
                                    targetReps: 10,
                                    comment: '',
                                  ),
                                );
                              }
                            }
                          });
                        },
                      ),
                      SizedBox(height: 10),
                      _QuickExerciseRail(
                        labels: labels,
                        exercises: _suggestedExercises(
                          nameController.text,
                          allExercises,
                        ),
                        onAdd: (exercise) {
                          setDialogState(() {
                            addExerciseToSelection(exercise);
                          });
                        },
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
                            TextField(
                              controller: catalogSearchController,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: labels.t('exerciseSearch'),
                                prefixIcon: Icon(Icons.search),
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
                            SizedBox(height: 10),
                            Text(
                              labels.t('catalogHint'),
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                            SizedBox(height: 10),
                            _MuscleFilterRail(
                              labels: labels,
                              exercises: allExercises,
                              selectedMuscle: selectedMuscle,
                              onSelected: (muscle) {
                                setDialogState(() {
                                  selectedMuscle = muscle;
                                });
                              },
                            ),
                            SizedBox(height: 12),
                            _ExerciseCatalogList(
                              labels: labels,
                              exercises: _filteredCatalogExercises(
                                labels: labels,
                                query: catalogSearchController.text,
                                muscle: selectedMuscle,
                                exercises: allExercises,
                              ),
                              onAdd: (exercise) {
                                setDialogState(() {
                                  addExerciseToSelection(exercise);
                                });
                              },
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
                            Future<void> saveUpdatedExercise(
                              Exercise updated,
                            ) async {
                              final saved = await repository.updateExercise(
                                exercise: item.exercise,
                                name: updated.name,
                                primaryMuscle: updated.primaryMuscle,
                                bodyPart: updated.bodyPart,
                                equipment: updated.equipment,
                                exerciseType: updated.exerciseType,
                                imageUrl: updated.imageUrl,
                                videoUrl: updated.videoUrl,
                                sourceUrl: updated.sourceUrl,
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
                                  final current = selectedExercises[itemIndex];
                                  if (current.exercise.id == saved.id) {
                                    selectedExercises[itemIndex] = current
                                        .copyWith(exercise: saved);
                                  }
                                }
                              });
                            }

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
                                await saveUpdatedExercise(updated);
                              },
                              onPhoto: () async {
                                final updated = await _pickPhotoForExercise(
                                  item.exercise,
                                );
                                if (updated == null) {
                                  return;
                                }
                                await saveUpdatedExercise(updated);
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

  void _openSearchForSelectedDay() {
    widget.onOpenSearch?.call(_selectedDayNumber);
  }

  Future<Exercise?> _pickPhotoForExercise(Exercise exercise) async {
    try {
      final picked = await pickPhotoFromDevice();
      if (picked == null) {
        return null;
      }

      return exercise.copyWith(
        imageUrl: gymImageDataUrlFromBytes(
          bytes: picked.bytes,
          mimeType: picked.mimeType,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return null;
      }
      final labels = context.read<LocaleCubit>().labels;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            labels.language == GymLanguage.uk
                ? 'Не вдалося додати фото'
                : 'Could not add photo',
          ),
        ),
      );
      return null;
    }
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
    if (_selectedPlan.isEmpty) {
      return;
    }
    _openActiveSession(_selectedPlan);
  }

  void _continueOpenSession() {
    final plan = _openSessionPlan;
    if (plan == null || plan.isEmpty) {
      return;
    }
    _openActiveSession(plan);
  }

  void _openActiveSession(TrainingDayPlan plan) {
    final dashboardCubit = context.read<DashboardCubit>();
    final analyticsCubit = context.read<AnalyticsCubit>();

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider(
              create: (context) => SessionCubit(
                context.read<WorkoutSessionRepository>(),
                plan: plan,
              )..startSession(),
              child: ActiveSessionScreen(
                plannedExercises: plan.exercises,
                initialRestSeconds: plan.restSeconds,
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

  Future<void> _stopOpenSession(GymLabels labels) async {
    final openSession = _openSession;
    if (openSession == null) {
      return;
    }

    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(labels.t('stopSessionConfirmTitle')),
          content: Text(labels.t('stopSessionConfirmBody')),
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
              child: Text(labels.t('stopSession')),
            ),
          ],
        );
      },
    );

    if (shouldStop != true || !mounted) {
      return;
    }

    final repository = context.read<WorkoutSessionRepository>();
    final notifications = context.read<RestNotificationService>();
    final dashboardCubit = context.read<DashboardCubit>();
    final analyticsCubit = context.read<AnalyticsCubit>();
    await repository.finishSession(
      sessionId: openSession.sessionId,
      finishedAt: DateTime.now(),
    );
    await notifications.cancelRestComplete();
    await notifications.cancelTrainingOngoing();
    await dashboardCubit.load();
    await analyticsCubit.load();
    await _loadInitialDay();
  }

  @override
  Widget build(BuildContext context) {
    final labels = context.watch<LocaleCubit>().labels;
    final nextDayNumber = _nextDayNumber;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactPhone = screenWidth < 430;
    final floatingStartWidth = _selectedPlan.isEmpty
        ? (isCompactPhone ? 188.0 : 214.0)
        : (isCompactPhone ? 184.0 : 244.0);
    final floatingStartLabel = _selectedPlan.isEmpty
        ? labels.t('createDay')
        : (isCompactPhone
              ? (labels.language == GymLanguage.uk ? 'ПОЧАТИ' : 'START')
              : labels.t('startSession'));

    return SafeArea(
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              _openSession == null ? 188 : 260,
            ),
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
                InkWell(
                  onTap: () => _openNextDayDialog(labels),
                  borderRadius: BorderRadius.circular(8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.lime,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.add,
                                color: AppColors.ink,
                                size: 18,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              labels.language == GymLanguage.uk
                                  ? 'Створити День $nextDayNumber'
                                  : 'Create Day $nextDayNumber',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: AppColors.lime),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(height: 16),
              _HomeFocusPanel(
                labels: labels,
                plan: _selectedPlan,
                isLoading: _isLoadingPlan,
              ),
              SizedBox(height: 18),
              _CalendarStrip(labels: labels),
              SizedBox(height: _openSession == null ? 92 : 116),
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
                  onSearch: _openSearchForSelectedDay,
                  onDelete: () => _deleteSelectedDay(labels),
                ),
              ),
            ],
          ),
          Positioned(
            right: 20,
            bottom: _openSession == null ? 20 : 112,
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width - 40,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: floatingStartWidth,
                  child: BouncyGymButton(
                    label: floatingStartLabel,
                    height: isCompactPhone ? 54 : 58,
                    icon: _selectedPlan.isEmpty ? Icons.add : Icons.play_arrow,
                    onTap: _selectedPlan.isEmpty
                        ? () => _openCreateDayDialog(labels)
                        : (_openSession == null ? _startPlannedSession : null),
                  ),
                ),
              ),
            ),
          ),
          if (_openSession != null && _openSessionPlan != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: _OngoingSessionBar(
                labels: labels,
                session: _openSession!,
                plan: _openSessionPlan!,
                onContinue: _continueOpenSession,
                onStop: () => _stopOpenSession(labels),
              ),
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

class _QuickExerciseRail extends StatelessWidget {
  const _QuickExerciseRail({
    required this.labels,
    required this.exercises,
    required this.onAdd,
  });

  final GymLabels labels;
  final List<Exercise> exercises;
  final ValueChanged<Exercise> onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: exercises.length,
        separatorBuilder: (_, _) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final exercise = exercises[index];
          return _CompactExerciseCard(
            labels: labels,
            exercise: exercise,
            onAdd: () => onAdd(exercise),
          );
        },
      ),
    );
  }
}

class _SmartPackRail extends StatelessWidget {
  const _SmartPackRail({
    required this.labels,
    required this.exercises,
    required this.onAddPack,
  });

  final GymLabels labels;
  final List<Exercise> exercises;
  final ValueChanged<List<Exercise>> onAddPack;

  @override
  Widget build(BuildContext context) {
    final packs = _buildSmartPacks(labels, exercises);

    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: packs.length,
        separatorBuilder: (_, _) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pack = packs[index];
          return InkWell(
            onTap: pack.exercises.isEmpty
                ? null
                : () => onAddPack(pack.exercises),
            borderRadius: BorderRadius.circular(7),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 160),
              width: 132,
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.34),
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Icon(pack.icon, color: AppColors.lime, size: 22),
                  SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pack.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${pack.exercises.length} ${labels.t('plannedCount')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.muted,
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

class _SmartExercisePack {
  const _SmartExercisePack({
    required this.title,
    required this.icon,
    required this.exercises,
  });

  final String title;
  final IconData icon;
  final List<Exercise> exercises;
}

class _MuscleFilterRail extends StatelessWidget {
  const _MuscleFilterRail({
    required this.labels,
    required this.exercises,
    required this.selectedMuscle,
    required this.onSelected,
  });

  final GymLabels labels;
  final List<Exercise> exercises;
  final String? selectedMuscle;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final muscles =
        {for (final exercise in exercises) exercise.primaryMuscle}.toList()
          ..sort(
            (a, b) => labels.muscleName(a).compareTo(labels.muscleName(b)),
          );

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: muscles.length + 1,
        separatorBuilder: (_, _) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final muscle = index == 0 ? null : muscles[index - 1];
          final isSelected = muscle == selectedMuscle;

          return ChoiceChip(
            selected: isSelected,
            label: Text(
              muscle == null
                  ? labels.t('allMuscles')
                  : labels.muscleName(muscle),
            ),
            onSelected: (_) => onSelected(muscle),
          );
        },
      ),
    );
  }
}

class _ExerciseCatalogList extends StatelessWidget {
  const _ExerciseCatalogList({
    required this.labels,
    required this.exercises,
    required this.onAdd,
  });

  final GymLabels labels;
  final List<Exercise> exercises;
  final ValueChanged<Exercise> onAdd;

  @override
  Widget build(BuildContext context) {
    final visible = exercises.take(36).toList();

    return Column(
      children: [
        for (final exercise in visible.indexed) ...[
          _ExerciseCatalogRow(
            labels: labels,
            exercise: exercise.$2,
            onAdd: () => onAdd(exercise.$2),
          ),
          if (exercise.$1 != visible.length - 1) SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CompactExerciseCard extends StatelessWidget {
  const _CompactExerciseCard({
    required this.labels,
    required this.exercise,
    required this.onAdd,
  });

  final GymLabels labels;
  final Exercise exercise;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('quick-add-${exercise.id}'),
      onTap: onAdd,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 156,
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            _ExerciseMediaThumb(exercise: exercise, size: 42),
            SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labels.exerciseName(exercise.id, exercise.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '${labels.muscleName(exercise.primaryMuscle)} В· ${_exerciseEquipment(exercise)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.muted,
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
  }
}

class _ExerciseCatalogRow extends StatelessWidget {
  const _ExerciseCatalogRow({
    required this.labels,
    required this.exercise,
    required this.onAdd,
  });

  final GymLabels labels;
  final Exercise exercise;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(7),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.black.withValues(alpha: 0.35),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Row(
            children: [
              _ExerciseMediaThumb(
                exercise: exercise,
                size: 58,
                onOpen: _exerciseMediaUrl(exercise) == null
                    ? null
                    : () => unawaited(
                        _openExerciseMedia(_exerciseMediaUrl(exercise)!),
                      ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labels.exerciseName(exercise.id, exercise.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniMetaChip(
                          label: labels.muscleName(exercise.primaryMuscle),
                        ),
                        if (exercise.bodyPart.trim().isNotEmpty &&
                            exercise.bodyPart != exercise.primaryMuscle)
                          _MiniMetaChip(
                            label: labels.catalogAttribute(exercise.bodyPart),
                          ),
                        _MiniMetaChip(
                          label: labels.catalogAttribute(
                            _exerciseEquipment(exercise),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              if (_exerciseMediaUrl(exercise) != null) ...[
                IconButton(
                  onPressed: () => unawaited(
                    _openExerciseMedia(_exerciseMediaUrl(exercise)!),
                  ),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: Icon(Icons.play_circle_fill, color: AppColors.lime),
                  tooltip: 'Technique',
                ),
                SizedBox(width: 4),
              ],
              IconButton.filled(
                key: ValueKey('catalog-add-${exercise.id}'),
                onPressed: onAdd,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.lime,
                  foregroundColor: AppColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: Icon(Icons.add),
                tooltip: labels.t('add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMetaChip extends StatelessWidget {
  const _MiniMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
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

class _ExerciseMediaThumb extends StatelessWidget {
  const _ExerciseMediaThumb({
    required this.exercise,
    required this.size,
    this.onOpen,
  });

  final Exercise exercise;
  final double size;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final imageUrl = exercise.imageUrl.trim();
    if (imageUrl.isEmpty) {
      return _MuscleThumb(muscle: exercise.primaryMuscle, size: size);
    }

    final accent = _muscleAccent(exercise.primaryMuscle);

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(7),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.black,
                border: Border.all(color: accent.withValues(alpha: 0.5)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GymExerciseImage(
                    key: ValueKey('plan-thumb-${exercise.id}-$imageUrl'),
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) {
                      return _MuscleThumb(
                        muscle: exercise.primaryMuscle,
                        size: size,
                      );
                    },
                  ),
                  if (_exerciseMediaUrl(exercise) != null)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: AppColors.lime.withValues(alpha: 0.8),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(3),
                          child: Icon(
                            Icons.play_arrow,
                            color: AppColors.lime,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MuscleThumb extends StatelessWidget {
  const _MuscleThumb({required this.muscle, required this.size});

  final String muscle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = _muscleAccent(muscle);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.black,
              border: Border.all(color: accent.withValues(alpha: 0.58)),
              borderRadius: BorderRadius.circular(7),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: AppColors.isLight ? 0.24 : 0.18),
                  AppColors.panel,
                  AppColors.black,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: -9,
                ),
              ],
            ),
          ),
          Center(
            child: Icon(_muscleIcon(muscle), color: accent, size: size * 0.46),
          ),
          Positioned(
            left: 5,
            right: 5,
            bottom: 5,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _muscleIcon(String muscle) {
  return switch (muscle) {
    'Chest' => Icons.view_week,
    'Back' => Icons.vertical_align_center,
    'Quads' ||
    'Hamstrings' ||
    'Glutes' ||
    'Posterior' ||
    'Calves' => Icons.directions_run,
    'Shoulders' => Icons.expand,
    'Biceps' || 'Triceps' || 'Forearms' => Icons.sports_martial_arts,
    'Core' => Icons.hexagon,
    'Neck' => Icons.circle,
    _ => Icons.fitness_center,
  };
}

Color _muscleAccent(String muscle) {
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
    'Forearms' => Color(0xFF94A3B8),
    'Core' => Color(0xFFFAFAFA),
    'Neck' => Color(0xFFE5E7EB),
    _ => AppColors.lime,
  };
}

class _OngoingSessionBar extends StatelessWidget {
  const _OngoingSessionBar({
    required this.labels,
    required this.session,
    required this.plan,
    required this.onContinue,
    required this.onStop,
  });

  final GymLabels labels;
  final WorkoutSessionDraft session;
  final TrainingDayPlan plan;
  final VoidCallback onContinue;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(session.startedAt);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.lime),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.lime.withValues(alpha: 0.22),
            blurRadius: 26,
            spreadRadius: -12,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            Icon(Icons.timer, color: AppColors.lime, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labels.t('workoutRunning'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.lime,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${labels.t('programDay')} ${plan.dayNumber} · ${plan.name} · ${_formatDuration(elapsed)} · ${session.sets.length} ${labels.t('sets').toLowerCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            IconButton.filled(
              onPressed: onContinue,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: Icon(Icons.play_arrow),
              tooltip: labels.t('continueSession'),
            ),
            SizedBox(width: 6),
            IconButton(
              onPressed: onStop,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: Icon(Icons.close, color: AppColors.lime),
              tooltip: labels.t('stopSession'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
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

  final suggested =
      keywords.isEmpty
            ? exercises.take(8).toList()
            : exercises
                  .where(
                    (exercise) => keywords.contains(exercise.primaryMuscle),
                  )
                  .toList()
        ..sort((a, b) {
          final priorityCompare = _exercisePriority(
            a.id,
          ).compareTo(_exercisePriority(b.id));
          if (priorityCompare != 0) {
            return priorityCompare;
          }
          return a.name.compareTo(b.name);
        });

  final visible = keywords.isEmpty ? suggested : suggested.take(10).toList();

  return visible.isEmpty ? exercises.take(8).toList() : visible;
}

List<_SmartExercisePack> _buildSmartPacks(
  GymLabels labels,
  List<Exercise> exercises,
) {
  List<Exercise> byIds(List<String> ids) {
    final byId = {for (final exercise in exercises) exercise.id: exercise};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  String title(String uk, String en) {
    return labels.language == GymLanguage.uk ? uk : en;
  }

  return [
    _SmartExercisePack(
      title: title('НОГИ', 'LEGS'),
      icon: Icons.directions_run,
      exercises: byIds([
        'squat',
        'leg_press',
        'leg_extension',
        'romanian_deadlift',
      ]),
    ),
    _SmartExercisePack(
      title: title('СІДНИЦІ', 'GLUTES'),
      icon: Icons.fitness_center,
      exercises: byIds([
        'hip_thrust',
        'glute_bridge',
        'cable_kickback',
        'hip_abduction',
      ]),
    ),
    _SmartExercisePack(
      title: title('PUSH', 'PUSH'),
      icon: Icons.north_east,
      exercises: byIds([
        'bench_press',
        'incline_bench_press',
        'overhead_press',
        'triceps_pushdown',
      ]),
    ),
    _SmartExercisePack(
      title: title('PULL', 'PULL'),
      icon: Icons.south_west,
      exercises: byIds([
        'pull_up',
        'lat_pulldown',
        'seated_row',
        'barbell_row',
      ]),
    ),
    _SmartExercisePack(
      title: title('РУКИ', 'ARMS'),
      icon: Icons.sports_martial_arts,
      exercises: byIds([
        'barbell_curl',
        'hammer_curl',
        'triceps_pushdown',
        'overhead_triceps_extension',
      ]),
    ),
    _SmartExercisePack(
      title: title('ПРЕС', 'CORE'),
      icon: Icons.hexagon,
      exercises: byIds([
        'plank',
        'cable_crunch',
        'hanging_leg_raise',
        'russian_twist',
      ]),
    ),
    _SmartExercisePack(
      title: title('ФУЛБОДІ', 'FULL BODY'),
      icon: Icons.bolt,
      exercises: byIds(['squat', 'bench_press', 'lat_pulldown', 'hip_thrust']),
    ),
  ];
}

int _exercisePriority(String id) {
  const priorities = {
    'bench_press': 0,
    'pull_up': 1,
    'lat_pulldown': 2,
    'overhead_press': 3,
    'squat': 0,
    'leg_press': 1,
    'hip_thrust': 2,
    'romanian_deadlift': 3,
    'biceps_curl': 0,
    'triceps_pushdown': 1,
    'lateral_raise': 2,
    'plank': 0,
  };

  return priorities[id] ?? 100;
}

String _exerciseEquipment(Exercise exercise) {
  final explicitEquipment = exercise.equipment.trim();
  if (explicitEquipment.isNotEmpty) {
    return explicitEquipment;
  }

  final name = exercise.name.toLowerCase();
  final id = exercise.id.toLowerCase();
  if (id.startsWith('custom_')) {
    return 'Custom';
  }
  if (name.contains('barbell') ||
      name.contains('bench press') ||
      name.contains('squat') ||
      name.contains('deadlift') ||
      name.contains('good morning') ||
      name.contains('curl')) {
    return 'Barbell';
  }
  if (name.contains('dumbbell') ||
      name.contains('hammer') ||
      name.contains('arnold')) {
    return 'Dumbbell';
  }
  if (name.contains('cable') ||
      name.contains('pushdown') ||
      name.contains('pulldown') ||
      name.contains('face pull')) {
    return 'Cable';
  }
  if (name.contains('lever') ||
      name.contains('machine') ||
      name.contains('smith') ||
      name.contains('press') ||
      name.contains('extension') ||
      name.contains('curl') ||
      name.contains('raise')) {
    return 'Machine';
  }
  if (name.contains('kettlebell')) {
    return 'Kettlebell';
  }
  return 'Bodyweight';
}

String? _exerciseMediaUrl(Exercise exercise) {
  final videoUrl = exercise.videoUrl.trim();
  if (videoUrl.isNotEmpty) {
    return videoUrl;
  }

  final sourceUrl = exercise.sourceUrl.trim();
  if (sourceUrl.isNotEmpty) {
    return sourceUrl;
  }

  return null;
}

Future<void> _openExerciseMedia(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return;
  }

  await openExternalLink(uri.toString());
}

List<Exercise> _filteredCatalogExercises({
  required GymLabels labels,
  required String query,
  required String? muscle,
  required List<Exercise> exercises,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final filtered = exercises.where((exercise) {
    final matchesMuscle = muscle == null || exercise.primaryMuscle == muscle;
    final matchesQuery =
        normalizedQuery.isEmpty ||
        exercise.name.toLowerCase().contains(normalizedQuery) ||
        exercise.primaryMuscle.toLowerCase().contains(normalizedQuery) ||
        exercise.bodyPart.toLowerCase().contains(normalizedQuery) ||
        exercise.equipment.toLowerCase().contains(normalizedQuery) ||
        exercise.exerciseType.toLowerCase().contains(normalizedQuery) ||
        labels
            .exerciseName(exercise.id, exercise.name)
            .toLowerCase()
            .contains(normalizedQuery) ||
        labels
            .muscleName(exercise.primaryMuscle)
            .toLowerCase()
            .contains(normalizedQuery);
    return matchesMuscle && matchesQuery;
  });

  return dedupeExerciseCatalog(filtered, labels)..sort((a, b) {
    final muscleCompare = a.primaryMuscle.compareTo(b.primaryMuscle);
    if (muscleCompare != 0) {
      return muscleCompare;
    }
    return a.name.compareTo(b.name);
  });
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
    required this.onPhoto,
    required this.onDeleteExercise,
    required this.onSettings,
    required this.onRemove,
  });

  final GymLabels labels;
  final int index;
  final TrainingPlanExercise item;
  final ValueChanged<TrainingPlanExercise> onChanged;
  final VoidCallback onEditExercise;
  final VoidCallback onPhoto;
  final VoidCallback? onDeleteExercise;
  final VoidCallback onSettings;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final exercise = item.exercise;
    final mediaUrl = _exerciseMediaUrl(exercise);

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
                  SizedBox(width: 8),
                  _ExerciseMediaThumb(
                    exercise: exercise,
                    size: 48,
                    onOpen: mediaUrl == null
                        ? null
                        : () => unawaited(_openExerciseMedia(mediaUrl)),
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
                      } else if (value == 'photo') {
                        onPhoto();
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
                      PopupMenuItem(
                        value: 'photo',
                        child: Text(
                          labels.language == GymLanguage.uk ? 'Фото' : 'Photo',
                        ),
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
  late final TextEditingController _equipmentController;
  late final TextEditingController _imageController;
  late final TextEditingController _videoController;
  var _isPickingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exercise.name);
    _muscleController = TextEditingController(
      text: widget.exercise.primaryMuscle,
    );
    _equipmentController = TextEditingController(
      text: widget.exercise.equipment,
    );
    _imageController = TextEditingController(text: widget.exercise.imageUrl);
    _videoController = TextEditingController(text: widget.exercise.videoUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _muscleController.dispose();
    _equipmentController.dispose();
    _imageController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      widget.exercise.copyWith(
        name: _nameController.text.trim(),
        primaryMuscle: _muscleController.text.trim().isEmpty
            ? widget.exercise.primaryMuscle
            : _muscleController.text.trim(),
        equipment: _equipmentController.text.trim(),
        imageUrl: _imageController.text.trim(),
        videoUrl: _videoController.text.trim(),
      ),
    );
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
      title: Text(labels.t('editExercise')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EditExerciseField(
              controller: _nameController,
              label: labels.t('exerciseName'),
              capitalization: TextCapitalization.words,
            ),
            SizedBox(height: 10),
            _EditExerciseField(
              controller: _muscleController,
              label: labels.t('muscleGroup'),
              capitalization: TextCapitalization.words,
            ),
            SizedBox(height: 10),
            _EditExerciseField(
              controller: _equipmentController,
              label: labels.language == GymLanguage.uk
                  ? 'Обладнання'
                  : 'Equipment',
              capitalization: TextCapitalization.words,
            ),
            SizedBox(height: 10),
            _ExercisePhotoPickerCard(
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
            _EditExerciseField(
              controller: _videoController,
              label: labels.language == GymLanguage.uk
                  ? 'Відео URL'
                  : 'Video URL',
            ),
          ],
        ),
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

class _ExercisePhotoPickerCard extends StatelessWidget {
  const _ExercisePhotoPickerCard({
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
        color: AppColors.black.withValues(alpha: 0.35),
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
                    labels.language == GymLanguage.uk
                        ? 'Фото вправи'
                        : 'Exercise photo',
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    labels.language == GymLanguage.uk
                        ? 'Обери картинку з телефону або компʼютера.'
                        : 'Choose an image from your device.',
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: isPicking ? null : onPick,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: AppColors.ink,
                          visualDensity: VisualDensity.compact,
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
                          labels.language == GymLanguage.uk ? 'Обрати' : 'Pick',
                        ),
                      ),
                      if (hasImage)
                        TextButton(
                          onPressed: onClear,
                          child: Text(
                            labels.language == GymLanguage.uk
                                ? 'Прибрати'
                                : 'Remove',
                          ),
                        ),
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

class _EditExerciseField extends StatelessWidget {
  const _EditExerciseField({
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

class _HomeFocusPanel extends StatelessWidget {
  const _HomeFocusPanel({
    required this.labels,
    required this.plan,
    required this.isLoading,
  });

  final GymLabels labels;
  final TrainingDayPlan plan;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final muscles = {
      for (final item in plan.exercises) item.exercise.primaryMuscle,
    }.toList();

    return GymPanel(
      padding: EdgeInsets.all(14),
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 220),
        child: isLoading
            ? SizedBox(
                height: 108,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.lime),
                ),
              )
            : Column(
                key: ValueKey('home-focus-${plan.dayNumber}-${plan.id}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          labels.t('nextWorkout'),
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      if (!plan.isEmpty)
                        Text(
                          '${plan.exercises.length} ${labels.t('plannedCount')}',
                          style: TextStyle(
                            color: AppColors.lime,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _HomeFocusIcon(muscle: muscles.firstOrNull ?? 'Chest'),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.isEmpty
                                  ? labels.t('emptyDayTitle')
                                  : '${labels.t('programDay')} ${plan.dayNumber} · ${plan.name}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              plan.isEmpty
                                  ? labels.t('emptyDaySubtitle')
                                  : labels.language == GymLanguage.uk
                                  ? 'План по порядку: підходи, повтори і техніка без зайвих кнопок.'
                                  : 'Ordered plan: sets, reps, and technique without extra noise.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!plan.isEmpty) ...[
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in plan.exercises.take(4))
                          _HomeExercisePill(labels: labels, item: item),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _HomeExercisePill extends StatelessWidget {
  const _HomeExercisePill({required this.labels, required this.item});

  final GymLabels labels;
  final TrainingPlanExercise item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.32),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(7, 5, 10, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MuscleThumb(muscle: item.exercise.primaryMuscle, size: 24),
            SizedBox(width: 7),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 140),
              child: Text(
                '${labels.exerciseName(item.exercise.id, item.exercise.name)} В· ${item.targetSets}x${item.targetReps}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeFocusIcon extends StatelessWidget {
  const _HomeFocusIcon({required this.muscle});

  final String muscle;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 220),
      width: 68,
      height: 68,
      padding: EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: AppColors.lime.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.lime.withValues(alpha: 0.14),
            blurRadius: 24,
            spreadRadius: -10,
          ),
        ],
      ),
      child: _MuscleThumb(muscle: muscle, size: 50),
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
    required this.onSearch,
    required this.onDelete,
  });

  final GymLabels labels;
  final TrainingDayPlan plan;
  final bool isLoading;
  final VoidCallback onCreate;
  final VoidCallback onSearch;
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
            SizedBox(height: 14),
            BouncyGymButton(
              label: labels.language == GymLanguage.uk
                  ? 'ЗНАЙТИ ВПРАВИ'
                  : 'FIND EXERCISES',
              height: 50,
              icon: Icons.search,
              onTap: onSearch,
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
                avatar: Icon(Icons.search, size: 16),
                label: Text(
                  labels.language == GymLanguage.uk ? 'Пошук вправ' : 'Search',
                ),
                onPressed: onSearch,
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
            _ExerciseMediaThumb(exercise: item.exercise, size: 44),
            SizedBox(width: 10),
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
