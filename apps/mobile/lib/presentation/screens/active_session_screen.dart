import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/gym_labels.dart';
import '../../core/notifications/rest_notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/weight_format.dart';
import '../../core/widgets/bouncy_gym_button.dart';
import '../../core/widgets/gym_panel.dart';
import '../../data/repos/workout_session_repository.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_history.dart';
import '../../domain/models/training_day_plan.dart';
import '../../domain/models/workout_set.dart';
import '../bloc/locale_cubit.dart';
import '../bloc/session_cubit.dart';
import 'summary_screen.dart';

class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({
    this.plannedExercises = const [],
    this.initialRestSeconds = 90,
    super.key,
  });

  final List<TrainingPlanExercise> plannedExercises;
  final int initialRestSeconds;

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  final _weightController = TextEditingController(text: '60');
  final _repsController = TextEditingController(text: '5');
  final _scrollController = ScrollController();
  List<TrainingPlanExercise> _exercises = const [];
  TrainingPlanExercise? _selectedExercise;
  var _selectedExerciseIndex = 0;
  ExerciseHistory _exerciseHistory = ExerciseHistory.empty();
  Timer? _restTimer;
  late int _restDurationSeconds;
  late _RestUnit _restUnit;
  int _restSeconds = 0;
  var _restFlash = false;

  @override
  void initState() {
    super.initState();
    _restDurationSeconds = widget.initialRestSeconds.clamp(15, 600);
    _restUnit = _restDurationSeconds >= 60
        ? _RestUnit.minutes
        : _RestUnit.seconds;
    _loadExercises();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _scrollController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    final exercises = widget.plannedExercises.isNotEmpty
        ? widget.plannedExercises
        : [
            for (final exercise
                in await context
                    .read<WorkoutSessionRepository>()
                    .loadExercises())
              TrainingPlanExercise(
                exercise: exercise,
                targetSets: 3,
                targetReps: 10,
              ),
          ];
    if (!mounted) {
      return;
    }

    setState(() {
      _exercises = exercises;
      _selectedExercise = widget.plannedExercises.isEmpty
          ? exercises
                .where((item) => item.exercise.id == 'bench_press')
                .firstOrNull
          : exercises.firstOrNull;
      _selectedExercise ??= exercises.isEmpty ? null : exercises.first;
      _selectedExerciseIndex = _selectedExercise == null
          ? 0
          : exercises.indexWhere(
              (item) => item.exercise.id == _selectedExercise!.exercise.id,
            );
      if (_selectedExerciseIndex < 0) {
        _selectedExerciseIndex = 0;
      }
      if (_selectedExercise != null) {
        _repsController.text = _selectedExercise!.targetReps.toString();
      }
    });
    await _loadExerciseHistory(_selectedExercise?.exercise);
  }

  Future<void> _loadExerciseHistory(Exercise? exercise) async {
    if (exercise == null) {
      setState(() {
        _exerciseHistory = ExerciseHistory.empty();
      });
      return;
    }

    final history = await context
        .read<WorkoutSessionRepository>()
        .loadExerciseHistory(exercise);
    if (!mounted) {
      return;
    }

    setState(() {
      _exerciseHistory = history;
    });
  }

  Future<void> _logSet() async {
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));
    final reps = int.tryParse(_repsController.text);
    final planExercise = _selectedExercise;
    final exercise = planExercise?.exercise;

    if (exercise == null || weight == null || reps == null) {
      return;
    }

    final didLog = await context.read<SessionCubit>().logSet(
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      weightKg: weight,
      reps: reps,
    );
    if (didLog) {
      await _loadExerciseHistory(exercise);
      _startRestTimer();
      HapticFeedback.mediumImpact();
    }
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _restSeconds = _restDurationSeconds;
    });
    final labels = context.read<LocaleCubit>().labels;
    unawaited(_scheduleRestNotification(labels));

    _restTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_restSeconds <= 1) {
        timer.cancel();
        setState(() {
          _restSeconds = 0;
          _restFlash = true;
        });
        _signalRestComplete();
        return;
      }

      setState(() {
        _restSeconds -= 1;
      });
    });
  }

  void _cancelRestTimer() {
    _restTimer?.cancel();
    unawaited(context.read<RestNotificationService>().cancelRestComplete());
    setState(() {
      _restSeconds = 0;
      _restFlash = false;
    });
  }

  Future<void> _scheduleRestNotification(GymLabels labels) async {
    final notifications = context.read<RestNotificationService>();
    await notifications.requestPermission();
    await notifications.scheduleRestComplete(
      seconds: _restDurationSeconds,
      title: labels.t('restNotificationTitle'),
      body: labels.t('restNotificationBody'),
    );
  }

  Future<void> _signalRestComplete() async {
    for (var index = 0; index < 3; index += 1) {
      HapticFeedback.lightImpact();
      await Future<void>.delayed(Duration(milliseconds: 90));
    }
    await Future<void>.delayed(Duration(milliseconds: 220));
    if (!mounted) {
      return;
    }
    setState(() {
      _restFlash = false;
    });
  }

  void _selectExerciseAt(int index) {
    if (index < 0 || index >= _exercises.length) {
      return;
    }

    final exercise = _exercises[index];
    setState(() {
      _selectedExerciseIndex = index;
      _selectedExercise = exercise;
      _repsController.text = exercise.targetReps.toString();
    });
    _loadExerciseHistory(exercise.exercise);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finishSession() async {
    _restTimer?.cancel();
    unawaited(context.read<RestNotificationService>().cancelRestComplete());
    setState(() {
      _restSeconds = 0;
    });
    final cubit = context.read<SessionCubit>();
    await cubit.finishSession();
    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SummaryScreen(session: cubit.state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = context.watch<LocaleCubit>().labels;

    return Scaffold(
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: BlocBuilder<SessionCubit, SessionState>(
          builder: (context, session) {
            return BouncyGymButton(
              label: labels.t('finishSession'),
              height: 56,
              isOutlined: true,
              backgroundColor: session.sets.isEmpty
                  ? AppColors.border
                  : AppColors.lime,
              foregroundColor: AppColors.text,
              icon: Icons.flag,
              onTap: session.sets.isEmpty ? null : _finishSession,
            );
          },
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _RestBackgroundFill(
              isFlashing: _restFlash,
              progress: _restDurationSeconds <= 0
                  ? 0
                  : _restSeconds / _restDurationSeconds,
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: BlocBuilder<SessionCubit, SessionState>(
                builder: (context, session) {
                  return ListView(
                    controller: _scrollController,
                    children: [
                      _SessionHeader(
                        labels: labels,
                        setCount: session.setCount,
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      SizedBox(height: 22),
                      if (_exercises.isNotEmpty) ...[
                        _PlanProgressPanel(
                          labels: labels,
                          exercises: _exercises,
                          selectedIndex: _selectedExerciseIndex,
                          onSelect: _selectExerciseAt,
                        ),
                        SizedBox(height: 14),
                      ],
                      _LiftInputs(
                        exercises: _exercises,
                        selectedExercise: _selectedExercise,
                        onExerciseChanged: (exercise) {
                          setState(() {
                            _selectedExercise = exercise;
                            _repsController.text = exercise.targetReps
                                .toString();
                            _selectedExerciseIndex = _exercises.indexWhere(
                              (item) =>
                                  item.exercise.id == exercise.exercise.id,
                            );
                            if (_selectedExerciseIndex < 0) {
                              _selectedExerciseIndex = 0;
                            }
                          });
                          _loadExerciseHistory(exercise.exercise);
                        },
                        exerciseHistory: _exerciseHistory,
                        weightController: _weightController,
                        repsController: _repsController,
                        onLogSet: _logSet,
                        labels: labels,
                      ),
                      SizedBox(height: 20),
                      if (_restSeconds > 0)
                        _RestTimerBanner(
                          labels: labels,
                          secondsRemaining: _restSeconds,
                          totalSeconds: _restDurationSeconds,
                          onCancel: _cancelRestTimer,
                        )
                      else
                        _RestControls(
                          labels: labels,
                          seconds: _restDurationSeconds,
                          unit: _restUnit,
                          onUnitChanged: (value) {
                            setState(() {
                              _restUnit = value;
                              if (value == _RestUnit.minutes &&
                                  _restDurationSeconds < 60) {
                                _restDurationSeconds = 60;
                              }
                            });
                          },
                          onChanged: (value) {
                            setState(() {
                              _restDurationSeconds = value;
                            });
                          },
                        ),
                      SizedBox(height: 14),
                      _SessionStats(labels: labels, session: session),
                      SizedBox(height: 14),
                      _ExerciseStepper(
                        labels: labels,
                        canGoBack: _selectedExerciseIndex > 0,
                        canGoNext:
                            _selectedExerciseIndex < _exercises.length - 1,
                        onBack: () =>
                            _selectExerciseAt(_selectedExerciseIndex - 1),
                        onNext: () =>
                            _selectExerciseAt(_selectedExerciseIndex + 1),
                      ),
                      SizedBox(height: 18),
                      _SetList(
                        labels: labels,
                        session: session,
                        onCancelSet: context.read<SessionCubit>().cancelSet,
                      ),
                      SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestBackgroundFill extends StatelessWidget {
  const _RestBackgroundFill({required this.progress, required this.isFlashing});

  final double progress;
  final bool isFlashing;

  @override
  Widget build(BuildContext context) {
    final fill = progress.clamp(0.0, 1.0);

    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              height: MediaQuery.sizeOf(context).height * fill,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.lime.withValues(alpha: 0.20),
                    AppColors.lime.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            duration: Duration(milliseconds: 90),
            opacity: isFlashing ? 0.28 : 0,
            child: ColoredBox(color: Color(0xFFFF2A2A)),
          ),
        ],
      ),
    );
  }
}

enum _RestUnit { seconds, minutes }

class _RestTimerBanner extends StatelessWidget {
  const _RestTimerBanner({
    required this.labels,
    required this.secondsRemaining,
    required this.totalSeconds,
    required this.onCancel,
  });

  final GymLabels labels;
  final int secondsRemaining;
  final int totalSeconds;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds <= 0 ? 0.0 : secondsRemaining / totalSeconds;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.surface, AppColors.lime, 1 - progress),
        border: Border.all(color: AppColors.lime),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                labels.t('rest'),
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            Text(
              _formatRestTime(labels, secondsRemaining),
              style: TextStyle(
                color: progress < 0.25 ? AppColors.ink : AppColors.text,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              onPressed: onCancel,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close,
                color: progress < 0.25 ? AppColors.ink : AppColors.lime,
              ),
              tooltip: labels.t('cancel'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRestTime(GymLabels labels, int seconds) {
    if (seconds < 60) {
      return '$seconds${labels.t('shortSeconds')}';
    }
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }
}

class _PlanProgressPanel extends StatelessWidget {
  const _PlanProgressPanel({
    required this.labels,
    required this.exercises,
    required this.selectedIndex,
    required this.onSelect,
  });

  final GymLabels labels;
  final List<TrainingPlanExercise> exercises;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return GymPanel(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  labels.t('sessionPlan'),
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: exercises.length,
              separatorBuilder: (_, _) => SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = exercises[index];
                final exercise = item.exercise;
                final isSelected = index == selectedIndex;

                return InkWell(
                  onTap: () => onSelect(index),
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 160),
                    constraints: BoxConstraints(minWidth: 72),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.lime : AppColors.surface,
                      border: Border.all(
                        color: isSelected ? AppColors.lime : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${labels.exerciseName(exercise.id, exercise.name)} · ${item.targetSets}x · ${item.targetReps}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? AppColors.ink : AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseStepper extends StatelessWidget {
  const _ExerciseStepper({
    required this.labels,
    required this.canGoBack,
    required this.canGoNext,
    required this.onBack,
    required this.onNext,
  });

  final GymLabels labels;
  final bool canGoBack;
  final bool canGoNext;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BouncyGymButton(
            label: labels.t('previousExercise'),
            icon: Icons.chevron_left,
            height: 44,
            isOutlined: true,
            backgroundColor: AppColors.border,
            foregroundColor: AppColors.text,
            onTap: canGoBack ? onBack : null,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: BouncyGymButton(
            label: canGoNext ? labels.t('nextExercise') : labels.t('done'),
            icon: Icons.chevron_right,
            height: 44,
            onTap: canGoNext ? onNext : null,
          ),
        ),
      ],
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.labels,
    required this.setCount,
    required this.onBack,
  });

  final GymLabels labels;
  final int setCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          style: IconButton.styleFrom(
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          icon: Icon(Icons.arrow_back, color: AppColors.lime),
          tooltip: labels.t('back'),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                labels.t('lift'),
                style: TextStyle(
                  color: AppColors.lime,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 8),
              Text(
                labels.t('activeSession'),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              '$setCount ${labels.t('sets')}',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiftInputs extends StatelessWidget {
  const _LiftInputs({
    required this.exercises,
    required this.selectedExercise,
    required this.onExerciseChanged,
    required this.exerciseHistory,
    required this.weightController,
    required this.repsController,
    required this.onLogSet,
    required this.labels,
  });

  final List<TrainingPlanExercise> exercises;
  final TrainingPlanExercise? selectedExercise;
  final ValueChanged<TrainingPlanExercise> onExerciseChanged;
  final ExerciseHistory exerciseHistory;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final VoidCallback onLogSet;
  final GymLabels labels;

  @override
  Widget build(BuildContext context) {
    return GymPanel(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _ExerciseSelector(
              exercises: exercises,
              selectedExercise: selectedExercise,
              onChanged: onExerciseChanged,
              labels: labels,
            ),
            if ((selectedExercise?.comment.trim().isNotEmpty ?? false)) ...[
              SizedBox(height: 8),
              _ExerciseCommentBanner(comment: selectedExercise!.comment),
            ],
            SizedBox(height: 10),
            _SmartHistoryPanel(labels: labels, history: exerciseHistory),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: weightController,
                    label: labels.t('kg'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _NumberField(
                    controller: repsController,
                    label: labels.t('reps'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            BouncyGymButton(
              key: ValueKey('log-set-button'),
              label: labels.t('logSet'),
              height: 54,
              icon: Icons.add,
              onTap: selectedExercise == null ? null : onLogSet,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCommentBanner extends StatelessWidget {
  const _ExerciseCommentBanner({required this.comment});

  final String comment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.35),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.notes, color: AppColors.lime, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                comment.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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

class _ExerciseSelector extends StatelessWidget {
  const _ExerciseSelector({
    required this.exercises,
    required this.selectedExercise,
    required this.onChanged,
    required this.labels,
  });

  final List<TrainingPlanExercise> exercises;
  final TrainingPlanExercise? selectedExercise;
  final ValueChanged<TrainingPlanExercise> onChanged;
  final GymLabels labels;

  @override
  Widget build(BuildContext context) {
    final planExercise = selectedExercise;
    final exercise = planExercise?.exercise;

    return PopupMenuButton<TrainingPlanExercise>(
      enabled: exercises.isNotEmpty,
      color: AppColors.panel,
      onSelected: onChanged,
      itemBuilder: (context) {
        return [
          for (final item in exercises)
            PopupMenuItem(
              value: item,
              child: Text(
                '${labels.exerciseName(item.exercise.id, item.exercise.name)} / ${item.targetSets}x / ${item.targetReps} ${labels.t('repsSmall')}',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
        ];
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labels.t('exercise'),
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      exercise == null
                          ? labels.t('loading')
                          : labels.exerciseName(exercise.id, exercise.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (exercise != null) ...[
                SizedBox(width: 10),
                Text(
                  labels.muscleName(exercise.primaryMuscle).toUpperCase(),
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
              SizedBox(width: 8),
              Icon(Icons.expand_more, color: AppColors.lime),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmartHistoryPanel extends StatelessWidget {
  const _SmartHistoryPanel({required this.labels, required this.history});

  final GymLabels labels;
  final ExerciseHistory history;

  @override
  Widget build(BuildContext context) {
    final value = history.hasData
        ? '${formatKg(history.lastWeightKg, unit: labels.t('kg'))} x ${history.lastReps}'
        : labels.t('noPreviousSets');
    final detail = history.hasData
        ? '${history.totalSets} ${labels.t('sets').toLowerCase()}'
        : labels.t('unlockTargets');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: AppColors.lime, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    labels.t('smartHistory'),
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      style: TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.lime, width: 2),
        ),
      ),
    );
  }
}

class _SessionStats extends StatelessWidget {
  const _SessionStats({required this.labels, required this.session});

  final GymLabels labels;
  final SessionState session;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: labels.t('setsLogged'),
            value: '${session.setCount}',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: labels.t('trained'),
            value: session.sets.isEmpty ? '0' : labels.t('done'),
          ),
        ),
      ],
    );
  }
}

class _RestControls extends StatelessWidget {
  const _RestControls({
    required this.labels,
    required this.seconds,
    required this.unit,
    required this.onUnitChanged,
    required this.onChanged,
  });

  final GymLabels labels;
  final int seconds;
  final _RestUnit unit;
  final ValueChanged<_RestUnit> onUnitChanged;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isMinutes = unit == _RestUnit.minutes;
    final step = isMinutes ? 60 : 15;
    final min = isMinutes ? 60 : 15;
    final presets = isMinutes ? const [60, 120, 180] : const [30, 60, 90];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labels.t('restControl'),
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text(labels.t('secondsUnit')),
                    selected: unit == _RestUnit.seconds,
                    onSelected: (_) => onUnitChanged(_RestUnit.seconds),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Text(labels.t('minutesUnit')),
                    selected: unit == _RestUnit.minutes,
                    onSelected: (_) => onUnitChanged(_RestUnit.minutes),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  onPressed: seconds <= min
                      ? null
                      : () => onChanged((seconds - step).clamp(min, 600)),
                  icon: Icon(Icons.remove),
                  style: IconButton.styleFrom(
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _durationLabel(labels, seconds, unit),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.lime,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: seconds >= 600
                      ? null
                      : () => onChanged((seconds + step).clamp(min, 600)),
                  icon: Icon(Icons.add),
                  style: IconButton.styleFrom(
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                for (final preset in presets) ...[
                  Expanded(
                    child: ChoiceChip(
                      label: Text(_durationLabel(labels, preset, unit)),
                      selected: seconds == preset,
                      onSelected: (_) => onChanged(preset),
                    ),
                  ),
                  if (preset != presets.last) SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _durationLabel(GymLabels labels, int seconds, _RestUnit unit) {
    if (unit == _RestUnit.seconds) {
      return '$seconds${labels.t('shortSeconds')}';
    }
    final minutes = seconds / 60;
    final text = minutes % 1 == 0
        ? minutes.toInt().toString()
        : minutes.toStringAsFixed(1);
    return '$text${labels.t('shortMinutes')}';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
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

class _SetList extends StatelessWidget {
  const _SetList({
    required this.labels,
    required this.session,
    required this.onCancelSet,
  });

  final GymLabels labels;
  final SessionState session;
  final ValueChanged<WorkoutSet> onCancelSet;

  @override
  Widget build(BuildContext context) {
    if (session.sets.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Text(
          labels.t('noSets'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final entry in session.sets.indexed) ...[
          Builder(
            builder: (context) {
              final setNumber = _setNumberForExercise(entry.$1);

              return DecoratedBox(
                key: ValueKey('set-row-${entry.$1 + 1}'),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Text(
                        '$setNumber.',
                        style: TextStyle(
                          color: AppColors.lime,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          labels.exerciseName(
                            entry.$2.exerciseId ?? '',
                            entry.$2.exerciseName,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${formatKg(entry.$2.weightKg, unit: labels.t('kg'))} x ${entry.$2.reps}',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      IconButton(
                        onPressed: () => onCancelSet(entry.$2),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.undo, color: AppColors.lime),
                        tooltip: labels.t('cancelSet'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (entry.$1 != session.sets.length - 1) SizedBox(height: 10),
        ],
      ],
    );
  }

  int _setNumberForExercise(int index) {
    final current = session.sets[index];
    var count = 0;
    for (var i = 0; i <= index; i += 1) {
      final candidate = session.sets[i];
      if (_exerciseKey(candidate) == _exerciseKey(current)) {
        count += 1;
      }
    }
    return count;
  }

  String _exerciseKey(WorkoutSet set) {
    return set.exerciseId ?? set.exerciseName.trim().toLowerCase();
  }
}
