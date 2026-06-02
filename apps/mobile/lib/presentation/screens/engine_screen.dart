import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/gym_labels.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/photo_picker.dart';
import '../../core/util/weight_format.dart';
import '../../core/widgets/gym_exercise_image.dart';
import '../../data/repos/workout_session_repository.dart';
import '../../domain/models/analytics_snapshot.dart';
import '../../domain/models/progress_photo.dart';
import '../bloc/analytics_cubit.dart';
import '../bloc/dashboard_cubit.dart';
import '../bloc/locale_cubit.dart';

class EngineScreen extends StatefulWidget {
  const EngineScreen({super.key});

  @override
  State<EngineScreen> createState() => _EngineScreenState();
}

class _EngineScreenState extends State<EngineScreen> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;
  var _selectedTab = 0;
  var _progressPhotos = <ProgressPhoto>[];
  var _isPhotoBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProgressPhotos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<AnalyticsCubit, AnalyticsState>(
        builder: (context, state) {
          final snapshot = state.snapshot;
          final labels = context.watch<LocaleCubit>().labels;
          final visibleMonth = _effectiveVisibleMonth(snapshot);
          final monthStats = _statsForMonth(snapshot, visibleMonth);
          final trainingDays = _daysForMonth(snapshot, visibleMonth);
          final selectedSummary = _selectedSummary(trainingDays);
          final previousMonth = _availableMonthBefore(snapshot, visibleMonth);
          final nextMonth = _availableMonthAfter(snapshot, visibleMonth);

          return ListView(
            key: const ValueKey('progress-scroll'),
            padding: EdgeInsets.fromLTRB(20, 20, 20, 96),
            children: [
              Text(
                labels.t('engine'),
                style: TextStyle(
                  color: AppColors.lime,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 8),
              Text(
                labels.t('analytics'),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 24),
              _ProgressTabs(
                labels: labels,
                selectedIndex: _selectedTab,
                onSelected: (index) => setState(() => _selectedTab = index),
              ),
              SizedBox(height: 18),
              if (_selectedTab == 0) ...[
                _ProgressOverviewStats(
                  labels: labels,
                  snapshot: snapshot,
                  workoutCount: trainingDays.length,
                  trackedCount: monthStats.length,
                  bestWeightKg: _bestWeight(monthStats),
                ),
                SizedBox(height: 18),
                _ProgressCoachPanel(
                  labels: labels,
                  snapshot: snapshot,
                  monthStats: monthStats,
                  monthWorkoutCount: trainingDays.length,
                ),
                SizedBox(height: 18),
                _ChallengePanel(
                  labels: labels,
                  snapshot: snapshot,
                  monthStats: monthStats,
                  monthWorkoutCount: trainingDays.length,
                ),
                SizedBox(height: 18),
                _TrainingCalendar(
                  labels: labels,
                  visibleMonth: visibleMonth,
                  trainingDays: trainingDays,
                  selectedDate: selectedSummary?.date,
                  previousMonth: previousMonth,
                  nextMonth: nextMonth,
                  onMonthChanged: (month) {
                    setState(() {
                      _visibleMonth = month;
                      _selectedDate = null;
                    });
                  },
                  onDaySelected: (date) {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                ),
                SizedBox(height: 18),
                _DayDetails(
                  labels: labels,
                  summary: selectedSummary,
                  onDelete: selectedSummary == null
                      ? null
                      : () => _deleteTrainingDay(labels, selectedSummary.date),
                ),
              ] else if (_selectedTab == 1) ...[
                _ExerciseProgressList(labels: labels, stats: monthStats),
              ] else if (_selectedTab == 2) ...[
                _MuscleFocusPanel(labels: labels, stats: monthStats),
              ] else ...[
                _PhotoProgressPanel(
                  labels: labels,
                  photos: _progressPhotos,
                  isBusy: _isPhotoBusy,
                  onAdd: () => _addProgressPhoto(labels),
                  onDelete: (photo) => _deleteProgressPhoto(labels, photo),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  TrainingDaySummary? _selectedSummary(List<TrainingDaySummary> days) {
    if (days.isEmpty) {
      return null;
    }

    final selected = _selectedDate;
    if (selected != null) {
      for (final day in days) {
        if (_sameDay(day.date, selected)) {
          return day;
        }
      }
    }

    return days.last;
  }

  DateTime _effectiveVisibleMonth(AnalyticsSnapshot snapshot) {
    final availableMonths = _availableMonths(snapshot).toList()
      ..sort((a, b) => b.compareTo(a));
    if (availableMonths.isEmpty) {
      return _visibleMonth;
    }
    if (availableMonths.any((month) => _sameMonth(month, _visibleMonth))) {
      return _visibleMonth;
    }

    return availableMonths.first;
  }

  List<TrainingDaySummary> _daysForMonth(
    AnalyticsSnapshot snapshot,
    DateTime month,
  ) {
    return snapshot.trainingDays
        .where(
          (day) => day.date.year == month.year && day.date.month == month.month,
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<ExerciseWeightStats> _statsForMonth(
    AnalyticsSnapshot snapshot,
    DateTime month,
  ) {
    final buckets = <String, List<ExerciseWeightStats>>{};
    for (final day in _daysForMonth(snapshot, month)) {
      for (final exercise in day.exercises) {
        final key = exercise.exerciseId ?? exercise.exerciseName;
        buckets.putIfAbsent(key, () => []).add(exercise);
      }
    }

    final stats = [
      for (final bucket in buckets.values)
        ExerciseWeightStats(
          exerciseId: bucket.first.exerciseId,
          exerciseName: bucket.first.exerciseName,
          minWeightKg: bucket
              .map((item) => item.minWeightKg)
              .reduce((min, value) => value < min ? value : min),
          maxWeightKg: bucket
              .map((item) => item.maxWeightKg)
              .reduce((max, value) => value > max ? value : max),
          minReps: bucket
              .map((item) => item.minReps)
              .reduce((min, value) => value < min ? value : min),
          maxReps: bucket
              .map((item) => item.maxReps)
              .reduce((max, value) => value > max ? value : max),
          totalSets: bucket.fold<int>(0, (sum, item) => sum + item.totalSets),
          lastLoggedAt: bucket
              .map((item) => item.lastLoggedAt)
              .reduce((last, value) => value.isAfter(last) ? value : last),
          primaryMuscle: bucket.first.primaryMuscle,
          totalVolumeKg: bucket.fold<double>(
            0,
            (sum, item) => sum + item.totalVolumeKg,
          ),
        ),
    ]..sort((a, b) => b.lastLoggedAt.compareTo(a.lastLoggedAt));

    return stats;
  }

  DateTime? _availableMonthBefore(AnalyticsSnapshot snapshot, DateTime month) {
    final months =
        _availableMonths(
            snapshot,
          ).where((candidate) => candidate.isBefore(month)).toList()
          ..sort((a, b) => b.compareTo(a));
    return months.firstOrNull;
  }

  DateTime? _availableMonthAfter(AnalyticsSnapshot snapshot, DateTime month) {
    final months = _availableMonths(
      snapshot,
    ).where((candidate) => candidate.isAfter(month)).toList()..sort();
    return months.firstOrNull;
  }

  Set<DateTime> _availableMonths(AnalyticsSnapshot snapshot) {
    return {
      for (final date in snapshot.trainingDates)
        DateTime(date.year, date.month),
    };
  }

  double _bestWeight(List<ExerciseWeightStats> stats) {
    if (stats.isEmpty) {
      return 0;
    }

    return stats
        .map((item) => item.maxWeightKg)
        .reduce((best, value) => value > best ? value : best);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  Future<void> _deleteTrainingDay(GymLabels labels, DateTime date) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(labels.t('deleteTrainingDay')),
          content: Text(labels.t('deleteTrainingDayConfirm')),
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

    final repository = context.read<WorkoutSessionRepository>();
    final analyticsCubit = context.read<AnalyticsCubit>();
    final dashboardCubit = context.read<DashboardCubit>();

    await repository.deleteTrainingDay(date);
    await analyticsCubit.load();
    await dashboardCubit.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedDate = null;
    });
  }

  Future<void> _loadProgressPhotos() async {
    final photos = await context
        .read<WorkoutSessionRepository>()
        .loadProgressPhotos();
    if (!mounted) {
      return;
    }
    setState(() {
      _progressPhotos = photos;
    });
  }

  Future<void> _addProgressPhoto(GymLabels labels) async {
    if (_isPhotoBusy) {
      return;
    }
    setState(() {
      _isPhotoBusy = true;
    });
    final repository = context.read<WorkoutSessionRepository>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final picked = await pickPhotoFromDevice();
      if (picked == null) {
        return;
      }

      await repository.addProgressPhoto(
        imageDataUrl: gymImageDataUrlFromBytes(
          bytes: picked.bytes,
          mimeType: picked.mimeType,
        ),
      );
      await _loadProgressPhotos();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(labels.t('progressPhotoAdded'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPhotoBusy = false;
        });
      }
    }
  }

  Future<void> _deleteProgressPhoto(
    GymLabels labels,
    ProgressPhoto photo,
  ) async {
    if (_isPhotoBusy) {
      return;
    }
    setState(() {
      _isPhotoBusy = true;
    });
    final repository = context.read<WorkoutSessionRepository>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repository.deleteProgressPhoto(photo.id);
      await _loadProgressPhotos();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(labels.t('progressPhotoDeleted'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPhotoBusy = false;
        });
      }
    }
  }
}

class _ProgressTabs extends StatelessWidget {
  const _ProgressTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final GymLabels labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      labels.t('overview'),
      labels.t('exercises'),
      labels.t('measurements'),
      labels.t('photos'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in tabs.indexed) ...[
            _ProgressTabChip(
              label: entry.$2,
              isSelected: entry.$1 == selectedIndex,
              onTap: () => onSelected(entry.$1),
            ),
            if (entry.$1 != tabs.length - 1) SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ProgressTabChip extends StatelessWidget {
  const _ProgressTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lime : AppColors.surface,
          border: Border.all(
            color: isSelected ? AppColors.lime : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.ink : AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _ProgressOverviewStats extends StatelessWidget {
  const _ProgressOverviewStats({
    required this.labels,
    required this.snapshot,
    required this.workoutCount,
    required this.trackedCount,
    required this.bestWeightKg,
  });

  final GymLabels labels;
  final AnalyticsSnapshot snapshot;
  final int workoutCount;
  final int trackedCount;
  final double bestWeightKg;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _OverviewStat(
        icon: Icons.calendar_view_week,
        label: labels.t('weeklyWorkouts'),
        value: '${snapshot.weeklyWorkoutCount}',
      ),
      _OverviewStat(
        icon: Icons.timer,
        label: labels.t('totalTrainingTime'),
        value: _formatTrainingTime(snapshot.totalTrainingSeconds),
      ),
      _OverviewStat(
        icon: Icons.local_fire_department,
        label: labels.t('streak'),
        value: '${snapshot.currentStreakDays}${labels.t('days')}',
      ),
      _OverviewStat(
        icon: Icons.calendar_month,
        label: labels.t('workoutsThisMonth'),
        value: '$workoutCount',
      ),
      _OverviewStat(
        icon: Icons.fitness_center,
        label: labels.t('liftsTracked'),
        value: '$trackedCount',
      ),
      _OverviewStat(
        icon: Icons.trending_up,
        label: labels.t('bestWeight'),
        value: formatKg(bestWeightKg, unit: labels.t('kg')),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 360 ? 3 : 2;
        final gap = 10.0;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: itemWidth,
                child: _EngineStatCard(
                  icon: card.icon,
                  label: card.label,
                  value: card.value,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OverviewStat {
  const _OverviewStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _EngineStatCard extends StatelessWidget {
  const _EngineStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
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
        padding: EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.lime, size: 18),
                Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 8),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: AppColors.lime,
                  fontSize: 24,
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

class _ProgressCoachPanel extends StatelessWidget {
  const _ProgressCoachPanel({
    required this.labels,
    required this.snapshot,
    required this.monthStats,
    required this.monthWorkoutCount,
  });

  final GymLabels labels;
  final AnalyticsSnapshot snapshot;
  final List<ExerciseWeightStats> monthStats;
  final int monthWorkoutCount;

  static const _allSectors = [
    'Chest',
    'Shoulders',
    'Biceps',
    'Forearms',
    'Core',
    'Triceps',
    'Neck',
    'Quads',
    'Glutes',
    'Hamstrings',
    'Calves',
    'Back',
  ];

  @override
  Widget build(BuildContext context) {
    final activeSectors = {
      for (final item in monthStats)
        if (item.totalSets > 0) _sectorForMuscle(item.primaryMuscle),
    };
    final missingSectors = [
      for (final sector in _allSectors)
        if (!activeSectors.contains(sector)) sector,
    ];
    final totalMonthSets = monthStats.fold<int>(
      0,
      (sum, item) => sum + item.totalSets,
    );
    final topStat = [...monthStats]
      ..sort((a, b) => b.totalSets.compareTo(a.totalSets));
    final topMuscle = topStat.isEmpty
        ? null
        : _sectorForMuscle(topStat.first.primaryMuscle);
    final nextFocus = missingSectors.isEmpty
        ? _coachText(
            labels,
            uk: 'баланс уже закритий',
            en: 'balance is covered',
          )
        : _sectorLabel(labels, missingSectors.first);
    final tone = monthWorkoutCount >= 8
        ? _coachText(labels, uk: 'місяць іде сильно', en: 'strong month')
        : monthWorkoutCount >= 4
        ? _coachText(labels, uk: 'ритм нормальний', en: 'solid rhythm')
        : _coachText(
            labels,
            uk: 'ритм ще треба розігнати',
            en: 'build the rhythm',
          );

    final insights = [
      _CoachInsight(
        icon: Icons.radar,
        title: _coachText(labels, uk: 'Наступний фокус', en: 'Next focus'),
        value: nextFocus,
      ),
      _CoachInsight(
        icon: Icons.bolt,
        title: _coachText(labels, uk: 'Робота за місяць', en: 'Month work'),
        value: '$totalMonthSets ${labels.t('setsSmall')}',
      ),
      _CoachInsight(
        icon: Icons.star,
        title: _coachText(labels, uk: 'Найбільше уваги', en: 'Top attention'),
        value: topMuscle == null ? '--' : _sectorLabel(labels, topMuscle),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.lime.withValues(alpha: AppColors.isLight ? 0.08 : 0.1),
        border: Border.all(color: AppColors.lime.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology_alt, color: AppColors.lime, size: 22),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _coachText(
                      labels,
                      uk: 'РОЗУМНИЙ ВИСНОВОК',
                      en: 'SMART COACH',
                    ),
                    style: TextStyle(
                      color: AppColors.lime,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Text(
                  tone,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              _coachText(
                labels,
                uk: 'Серія: ${snapshot.currentStreakDays}${labels.t('days')}. Час у тренуваннях: ${_formatTrainingTime(snapshot.totalTrainingSeconds)}. Активних секторів: ${activeSectors.length}/12.',
                en: 'Streak: ${snapshot.currentStreakDays}${labels.t('days')}. Training time: ${_formatTrainingTime(snapshot.totalTrainingSeconds)}. Active sectors: ${activeSectors.length}/12.',
              ),
              style: TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth >= 420
                    ? (constraints.maxWidth - 20) / 3
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final insight in insights)
                      SizedBox(
                        width: itemWidth,
                        child: _CoachInsightChip(insight: insight),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _coachText(
    GymLabels labels, {
    required String uk,
    required String en,
  }) {
    return labels.language == GymLanguage.uk ? uk : en;
  }
}

class _CoachInsight {
  const _CoachInsight({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;
}

class _CoachInsightChip extends StatelessWidget {
  const _CoachInsightChip({required this.insight});

  final _CoachInsight insight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(insight.icon, color: AppColors.lime, size: 18),
            SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    insight.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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

class _TrainingCalendar extends StatelessWidget {
  const _TrainingCalendar({
    required this.labels,
    required this.visibleMonth,
    required this.trainingDays,
    required this.selectedDate,
    required this.previousMonth,
    required this.nextMonth,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  final GymLabels labels;
  final DateTime visibleMonth;
  final List<TrainingDaySummary> trainingDays;
  final DateTime? selectedDate;
  final DateTime? previousMonth;
  final DateTime? nextMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
    final dayCount = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final leadingEmptyCells = firstDay.weekday - 1;
    final totalCells = ((leadingEmptyCells + dayCount + 6) ~/ 7) * 7;
    final trainedDates = {
      for (final day in trainingDays)
        DateTime(day.date.year, day.date.month, day.date.day),
    };

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
              labels.t('trainingCalendar'),
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_monthName(labels.language, visibleMonth.month)} ${visibleMonth.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.lime,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                _MonthButton(
                  icon: Icons.chevron_left,
                  label: labels.t('previousMonth'),
                  month: previousMonth,
                  onMonthChanged: onMonthChanged,
                ),
                SizedBox(width: 8),
                _MonthButton(
                  icon: Icons.chevron_right,
                  label: labels.t('nextMonth'),
                  month: nextMonth,
                  onMonthChanged: onMonthChanged,
                ),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                for (final name in _weekdayNames(labels.language))
                  Expanded(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
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
            SizedBox(height: 7),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                childAspectRatio: 0.92,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                final dayNumber = index - leadingEmptyCells + 1;
                final day = DateTime(
                  visibleMonth.year,
                  visibleMonth.month,
                  dayNumber,
                );
                final isCurrentMonth = day.month == visibleMonth.month;
                final normalized = DateTime(day.year, day.month, day.day);
                final isTrained =
                    isCurrentMonth && trainedDates.contains(normalized);
                final isSelected =
                    selectedDate != null && _sameDay(selectedDate!, day);

                return _CalendarTile(
                  day: day,
                  isCurrentMonth: isCurrentMonth,
                  isTrained: isTrained,
                  isSelected: isSelected,
                  onTap: isTrained ? () => onDaySelected(day) : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<String> _weekdayNames(GymLanguage language) {
    return language == GymLanguage.uk
        ? const ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'НД']
        : const ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  }

  String _monthName(GymLanguage language, int month) {
    const uk = [
      'Січень',
      'Лютий',
      'Березень',
      'Квітень',
      'Травень',
      'Червень',
      'Липень',
      'Серпень',
      'Вересень',
      'Жовтень',
      'Листопад',
      'Грудень',
    ];
    const en = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return language == GymLanguage.uk ? uk[month - 1] : en[month - 1];
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.icon,
    required this.label,
    required this.month,
    required this.onMonthChanged,
  });

  final IconData icon;
  final String label;
  final DateTime? month;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: month == null ? null : () => onMonthChanged(month!),
      visualDensity: VisualDensity.compact,
      icon: Icon(icon),
      tooltip: label,
      style: IconButton.styleFrom(
        foregroundColor: month == null ? AppColors.muted : AppColors.lime,
        side: BorderSide(
          color: month == null ? AppColors.border : AppColors.lime,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({
    required this.day,
    required this.isCurrentMonth,
    required this.isTrained,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final bool isCurrentMonth;
  final bool isTrained;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = isTrained
        ? AppColors.lime
        : isCurrentMonth
        ? AppColors.panel
        : AppColors.black;
    final foreground = isTrained
        ? AppColors.ink
        : isCurrentMonth
        ? AppColors.muted
        : AppColors.muted.withValues(alpha: 0.38);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Border.all(
            color: isSelected
                ? AppColors.text
                : isTrained
                ? AppColors.lime
                : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayDetails extends StatelessWidget {
  const _DayDetails({
    required this.labels,
    required this.summary,
    required this.onDelete,
  });

  final GymLabels labels;
  final TrainingDaySummary? summary;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final day = summary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    labels.t('trainingDay'),
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline, color: AppColors.lime),
                    tooltip: labels.t('deleteTrainingDay'),
                  ),
              ],
            ),
            SizedBox(height: 12),
            if (day == null)
              Text(
                labels.t('selectTrainingDay'),
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              )
            else ...[
              if (day.templateDayNumber != null ||
                  (day.templateName?.trim().isNotEmpty ?? false)) ...[
                Text(
                  _templateTitle(day),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.lime,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 6),
              ],
              Text(
                _fullDate(labels.language, day.date),
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 12),
              for (final entry in day.exercises.indexed) ...[
                _ExerciseProgressRow(labels: labels, stats: entry.$2),
                if (entry.$1 != day.exercises.length - 1) SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _templateTitle(TrainingDaySummary day) {
    final dayNumber = day.templateDayNumber;
    final name = day.templateName?.trim();
    if (dayNumber == null) {
      return name ?? '';
    }
    if (name == null || name.isEmpty) {
      return '${labels.t('programDay')} $dayNumber';
    }
    return '${labels.t('programDay')} $dayNumber · $name';
  }

  String _fullDate(GymLanguage language, DateTime date) {
    if (language == GymLanguage.en) {
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    const weekdays = [
      'Понеділок',
      'Вівторок',
      'Середа',
      'Четвер',
      'Пʼятниця',
      'Субота',
      'Неділя',
    ];
    const months = [
      'січня',
      'лютого',
      'березня',
      'квітня',
      'травня',
      'червня',
      'липня',
      'серпня',
      'вересня',
      'жовтня',
      'листопада',
      'грудня',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _ExerciseProgressList extends StatelessWidget {
  const _ExerciseProgressList({required this.labels, required this.stats});

  final GymLabels labels;
  final List<ExerciseWeightStats> stats;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labels.t('exerciseProgress'),
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 14),
            if (stats.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Text(
                    labels.t('noExerciseStats'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              )
            else
              for (final entry in stats.indexed) ...[
                _ExerciseProgressRow(labels: labels, stats: entry.$2),
                if (entry.$1 != stats.length - 1) SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseProgressRow extends StatelessWidget {
  const _ExerciseProgressRow({required this.labels, required this.stats});

  final GymLabels labels;
  final ExerciseWeightStats stats;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labels.exerciseName(stats.exerciseId ?? '', stats.exerciseName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _WeightPill(
                    label: labels.t('minWeight'),
                    value: formatKg(stats.minWeightKg, unit: labels.t('kg')),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _WeightPill(
                    label: labels.t('maxWeight'),
                    value: formatKg(stats.maxWeightKg, unit: labels.t('kg')),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _WeightPill(
                    label: labels.t('minReps'),
                    value: '${stats.minReps}',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _WeightPill(
                    label: labels.t('maxReps'),
                    value: '${stats.maxReps}',
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '${stats.totalSets} ${labels.t('sets').toLowerCase()}',
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
    );
  }
}

class _WeightPill extends StatelessWidget {
  const _WeightPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 5),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: AppColors.lime,
                  fontSize: 20,
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

class _ChallengePanel extends StatelessWidget {
  const _ChallengePanel({
    required this.labels,
    required this.snapshot,
    required this.monthStats,
    required this.monthWorkoutCount,
  });

  final GymLabels labels;
  final AnalyticsSnapshot snapshot;
  final List<ExerciseWeightStats> monthStats;
  final int monthWorkoutCount;

  @override
  Widget build(BuildContext context) {
    final streakProgress = (snapshot.currentStreakDays / 3).clamp(0.0, 1.0);
    final monthSetCount = monthStats.fold<int>(
      0,
      (sum, item) => sum + item.totalSets,
    );
    final monthVolumeKg = monthStats.fold<double>(
      0,
      (sum, item) => sum + item.totalVolumeKg,
    );
    final activeSectorCount = _activeSectorCount(monthStats);
    final lowerBodyProgress = _groupProgress(monthStats, [
      'Quads',
      'Glutes',
      'Hamstrings',
      'Calves',
    ]);
    final pushProgress = _groupProgress(monthStats, [
      'Chest',
      'Shoulders',
      'Triceps',
    ]);
    final pullProgress = _groupProgress(monthStats, [
      'Back',
      'Biceps',
      'Forearms',
    ]);
    final coreProgress = _groupProgress(monthStats, ['Core']);
    final challenges = [
      _ProgressChallenge(
        icon: Icons.local_fire_department,
        title: labels.t('streakChallenge'),
        value: '${snapshot.currentStreakDays}/3',
        progress: streakProgress,
      ),
      _ProgressChallenge(
        icon: Icons.calendar_month,
        title: labels.t('weeklyChallenge'),
        value: '${snapshot.weeklyWorkoutCount}/3',
        progress: (snapshot.weeklyWorkoutCount / 3).clamp(0.0, 1.0),
      ),
      _ProgressChallenge(
        icon: Icons.event_available,
        title: _challengeText(labels, 'Місячний ритм', 'Monthly rhythm'),
        value: '$monthWorkoutCount/8',
        progress: (monthWorkoutCount / 8).clamp(0.0, 1.0),
      ),
      _ProgressChallenge(
        icon: Icons.done_all,
        title: _challengeText(labels, '30 підходів', '30 sets'),
        value: '$monthSetCount/30',
        progress: (monthSetCount / 30).clamp(0.0, 1.0),
      ),
      _ProgressChallenge(
        icon: Icons.timer,
        title: labels.t('timeChallenge'),
        value: _formatTrainingTime(snapshot.totalTrainingSeconds),
        progress: (snapshot.totalTrainingSeconds / (60 * 60 * 3)).clamp(
          0.0,
          1.0,
        ),
      ),
      _ProgressChallenge(
        icon: Icons.fitness_center,
        title: _challengeText(labels, 'Місячна робота', 'Monthly load'),
        value: formatKg(monthVolumeKg, unit: labels.t('kg')),
        progress: (monthVolumeKg / 10000).clamp(0.0, 1.0),
      ),
      _ProgressChallenge(
        icon: Icons.radar,
        title: labels.t('balanceChallenge'),
        value: '$activeSectorCount/12',
        progress: (activeSectorCount / 12).clamp(0.0, 1.0),
      ),
      _ProgressChallenge(
        icon: Icons.directions_run,
        title: _challengeText(labels, 'Ноги закриті', 'Lower body lock'),
        value: '${(lowerBodyProgress * 100).round()}%',
        progress: lowerBodyProgress,
      ),
      _ProgressChallenge(
        icon: Icons.north_east,
        title: _challengeText(labels, 'Push-сектор', 'Push sector'),
        value: '${(pushProgress * 100).round()}%',
        progress: pushProgress,
      ),
      _ProgressChallenge(
        icon: Icons.south_west,
        title: _challengeText(labels, 'Pull-сектор', 'Pull sector'),
        value: '${(pullProgress * 100).round()}%',
        progress: pullProgress,
      ),
      _ProgressChallenge(
        icon: Icons.hexagon,
        title: _challengeText(labels, 'Core контроль', 'Core control'),
        value: '${(coreProgress * 100).round()}%',
        progress: coreProgress,
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labels.t('challenges'),
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 320;
                final itemWidth = twoColumns
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final challenge in challenges)
                      SizedBox(
                        width: itemWidth,
                        child: _ChallengeRow(
                          icon: challenge.icon,
                          title: challenge.title,
                          value: challenge.value,
                          progress: challenge.progress,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _activeSectorCount(List<ExerciseWeightStats> stats) {
    return {
      for (final item in stats)
        if (item.totalSets > 0) _sectorForMuscle(item.primaryMuscle),
    }.length;
  }

  double _groupProgress(List<ExerciseWeightStats> stats, List<String> muscles) {
    final activeMuscles = {
      for (final item in stats)
        if (item.totalSets > 0) _sectorForMuscle(item.primaryMuscle),
    };
    final activeCount = muscles
        .where((muscle) => activeMuscles.contains(muscle))
        .length;
    return (activeCount / muscles.length).clamp(0.0, 1.0);
  }

  String _challengeText(GymLabels labels, String uk, String en) {
    return labels.language == GymLanguage.uk ? uk : en;
  }
}

class _ProgressChallenge {
  const _ProgressChallenge({
    required this.icon,
    required this.title,
    required this.value,
    required this.progress,
  });

  final IconData icon;
  final String title;
  final String value;
  final double progress;
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.progress,
  });

  final IconData icon;
  final String title;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.lime.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.lime.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(icon, color: AppColors.lime, size: 18),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.lime,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 9),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: safeProgress,
                minHeight: 5,
                backgroundColor: AppColors.black,
                color: safeProgress >= 1
                    ? AppColors.accentStrong
                    : AppColors.lime,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuscleFocusPanel extends StatelessWidget {
  const _MuscleFocusPanel({required this.labels, required this.stats});

  final GymLabels labels;
  final List<ExerciseWeightStats> stats;

  static const _sectors = [
    'Chest',
    'Shoulders',
    'Biceps',
    'Forearms',
    'Core',
    'Triceps',
    'Neck',
    'Quads',
    'Glutes',
    'Hamstrings',
    'Calves',
    'Back',
  ];

  @override
  Widget build(BuildContext context) {
    final setCountBySector = {for (final sector in _sectors) sector: 0};
    final volumeBySector = {for (final sector in _sectors) sector: 0.0};

    for (final item in stats) {
      final sector = _sectorForMuscle(item.primaryMuscle);
      if (!setCountBySector.containsKey(sector)) {
        continue;
      }
      setCountBySector[sector] =
          (setCountBySector[sector] ?? 0) + item.totalSets;
      volumeBySector[sector] =
          (volumeBySector[sector] ?? 0) + item.totalVolumeKg;
    }

    final totalSets = _sectors.fold<int>(
      0,
      (sum, sector) => sum + (setCountBySector[sector] ?? 0),
    );
    final maxSets = _sectors.fold<int>(
      0,
      (max, sector) => math.max(max, setCountBySector[sector] ?? 0),
    );
    final rows = [
      for (final entry in _sectors.indexed)
        (
          sectorId: entry.$1 + 1,
          muscle: entry.$2,
          sets: setCountBySector[entry.$2] ?? 0,
          volume: volumeBySector[entry.$2] ?? 0,
          percent: maxSets <= 0
              ? 0.0
              : (setCountBySector[entry.$2] ?? 0) / maxSets,
        ),
    ];
    final rankedRows = [...rows]
      ..sort((a, b) {
        final setCompare = b.sets.compareTo(a.sets);
        if (setCompare != 0) {
          return setCompare;
        }
        return a.sectorId.compareTo(b.sectorId);
      });
    final activeRows = rankedRows.where((row) => row.sets > 0).toList();
    final attentionRows = rows.where((row) => row.sets <= 0).take(5).toList();
    final lead = activeRows.firstOrNull;
    final percentBySector = {for (final row in rows) row.muscle: row.percent};

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labels.t('muscleFocus'),
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 8),
            Text(
              labels.t('muscleFocusHint'),
              style: TextStyle(
                color: AppColors.text,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 6),
            Text(
              labels.language == GymLanguage.uk
                  ? 'Кожна плашка рахується по кількості підходів. Найбільший сектор = 100%.'
                  : 'Each chip is calculated by set count. Top sector = 100%.',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 18),
            _MuscleRadarMap(labels: labels, valuesByMuscle: percentBySector),
            SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _MeasurementStatCard(
                        icon: Icons.format_list_numbered,
                        label: _measurementText(
                          labels,
                          uk: 'Усього підходів',
                          en: 'Total sets',
                        ),
                        value: '$totalSets',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _MeasurementStatCard(
                        icon: Icons.accessibility_new,
                        label: _measurementText(
                          labels,
                          uk: 'Активних зон',
                          en: 'Active zones',
                        ),
                        value: '${activeRows.length}/${_sectors.length}',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _MeasurementStatCard(
                        icon: Icons.trending_up,
                        label: _measurementText(
                          labels,
                          uk: 'Найбільше',
                          en: 'Top focus',
                        ),
                        value: lead == null
                            ? '--'
                            : _sectorLabel(labels, lead.muscle),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _MeasurementStatCard(
                        icon: Icons.priority_high,
                        label: _measurementText(
                          labels,
                          uk: 'Без роботи',
                          en: 'No work',
                        ),
                        value: '${attentionRows.length}',
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 18),
            if (activeRows.isEmpty)
              _EmptyMuscleFocus(labels: labels)
            else ...[
              _MeasurementSectionTitle(
                title: _measurementText(
                  labels,
                  uk: 'Таблиця секторів',
                  en: 'Sector table',
                ),
              ),
              SizedBox(height: 10),
              for (final row in activeRows) ...[
                _MuscleVolumeRow(
                  label: _sectorLabel(labels, row.muscle),
                  setCount: row.sets,
                  setUnitLabel: _measurementText(
                    labels,
                    uk: 'підх.',
                    en: row.sets == 1 ? 'set' : 'sets',
                  ),
                  percent: row.percent,
                  volumeKg: row.volume,
                  unit: labels.t('kg'),
                ),
                SizedBox(height: 10),
              ],
              if (attentionRows.isNotEmpty) ...[
                SizedBox(height: 8),
                _MeasurementSectionTitle(
                  title: _measurementText(
                    labels,
                    uk: 'Що варто підтягнути',
                    en: 'Needs attention',
                  ),
                ),
                SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final row in attentionRows)
                      _AttentionMuscleChip(
                        label: _sectorLabel(labels, row.muscle),
                      ),
                  ],
                ),
              ],
              SizedBox(height: 14),
              _MeasurementHint(
                text: _measurementText(
                  labels,
                  uk: 'Формула: підходи сектору / підходи максимального сектору × 100. Найсильніший сектор завжди 100%.',
                  en: 'Formula: sector sets / strongest sector sets × 100. The strongest sector is always 100%.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _sectorForMuscle(String muscle) {
  return switch (muscle) {
    'Posterior' => 'Back',
    _ => muscle,
  };
}

String _sectorLabel(GymLabels labels, String muscle) {
  if (labels.language == GymLanguage.uk) {
    return switch (muscle) {
      'Chest' => 'Груди',
      'Shoulders' => 'Плечі',
      'Biceps' => 'Біцепс',
      'Forearms' => 'Передпл.',
      'Core' => 'Прес',
      'Triceps' => 'Трицепс',
      'Neck' => 'Шия',
      'Quads' => 'Квадри',
      'Glutes' => 'Сідниці',
      'Hamstrings' => 'Біц. ст.',
      'Calves' => 'Ікри',
      'Back' => 'Спина',
      _ => labels.muscleName(muscle),
    };
  }

  return switch (muscle) {
    'Forearms' => 'Forearms',
    'Hamstrings' => 'Hamstrings',
    'Quads' => 'Quads',
    _ => labels.muscleName(muscle),
  };
}

class _MuscleVolumeRow extends StatelessWidget {
  const _MuscleVolumeRow({
    required this.label,
    required this.setCount,
    required this.setUnitLabel,
    required this.percent,
    required this.volumeKg,
    required this.unit,
  });

  final String label;
  final int setCount;
  final String setUnitLabel;
  final double percent;
  final double volumeKg;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final percentLabel = (percent * 100).round();
    final isStrong = percent >= 0.75 && setCount > 0;
    final barColor = isStrong ? AppColors.lime : Colors.grey.shade500;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.42),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  '$percentLabel%',
                  style: TextStyle(
                    color: barColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: AppColors.surface,
                color: barColor,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.done_all, color: AppColors.muted, size: 14),
                SizedBox(width: 6),
                Text(
                  '$setCount $setUnitLabel',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  formatKg(volumeKg, unit: unit),
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
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

class _MeasurementStatCard extends StatelessWidget {
  const _MeasurementStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.42),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.lime, size: 18),
            SizedBox(height: 10),
            Text(
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
            SizedBox(height: 6),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: AppColors.lime,
                  fontSize: 20,
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

class _MeasurementSectionTitle extends StatelessWidget {
  const _MeasurementSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.lime,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _AttentionMuscleChip extends StatelessWidget {
  const _AttentionMuscleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.42),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 11, vertical: 8),
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
    );
  }
}

class _MeasurementHint extends StatelessWidget {
  const _MeasurementHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.lime.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.lime.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

String _measurementText(
  GymLabels labels, {
  required String uk,
  required String en,
}) {
  return labels.language == GymLanguage.uk ? uk : en;
}

class _MuscleRadarMap extends StatelessWidget {
  const _MuscleRadarMap({required this.labels, required this.valuesByMuscle});

  final GymLabels labels;
  final Map<String, double> valuesByMuscle;

  @override
  Widget build(BuildContext context) {
    final muscles = valuesByMuscle.keys.toList();
    final muscleLabels = [
      for (final muscle in muscles) _sectorLabel(labels, muscle),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.72),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 12, 10, 10),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 330,
              child: CustomPaint(
                painter: _MuscleRadarPainter(
                  labels: muscleLabels,
                  values: [
                    for (final muscle in muscles) valuesByMuscle[muscle] ?? 0,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _MuscleFigurePainter extends CustomPainter {
  const _MuscleFigurePainter({required this.muscle, required this.active});

  final String muscle;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 54;
    final scaleY = size.height / 62;

    Offset p(double x, double y) => Offset(x * scaleX, y * scaleY);
    Rect r(double left, double top, double width, double height) {
      return Rect.fromLTWH(
        left * scaleX,
        top * scaleY,
        width * scaleX,
        height * scaleY,
      );
    }

    final outline = Paint()
      ..color = active ? Colors.white.withValues(alpha: 0.9) : AppColors.muted
      ..style = PaintingStyle.fill;
    final shade = Paint()
      ..color = active
          ? Colors.white.withValues(alpha: 0.66)
          : AppColors.muted.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;
    final hit = Paint()
      ..color = active ? Color(0xFFFF3434) : AppColors.border
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.black.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    void rounded(Rect rect, Paint paint, [double radius = 8]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        stroke,
      );
    }

    void path(List<Offset> points, Paint paint) {
      final figure = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        figure.lineTo(point.dx, point.dy);
      }
      figure.close();
      canvas.drawPath(figure, paint);
      canvas.drawPath(figure, stroke);
    }

    canvas.drawCircle(p(27, 7), 5.4 * scaleX, outline);
    rounded(r(24, 12, 6, 8), outline, 3);
    path([
      p(18, 18),
      p(36, 18),
      p(41, 38),
      p(30, 43),
      p(24, 43),
      p(13, 38),
    ], shade);
    rounded(r(7, 22, 8, 22), outline, 8);
    rounded(r(39, 22, 8, 22), outline, 8);
    rounded(r(19, 42, 7, 17), outline, 8);
    rounded(r(28, 42, 7, 17), outline, 8);

    final redMuscles = _activeShapes(muscle);
    if (redMuscles.contains('chest')) {
      rounded(r(18, 19, 8, 8), hit, 5);
      rounded(r(28, 19, 8, 8), hit, 5);
    }
    if (redMuscles.contains('back')) {
      path([p(18, 18), p(36, 18), p(38, 34), p(27, 39), p(16, 34)], hit);
    }
    if (redMuscles.contains('shoulders')) {
      canvas.drawCircle(p(13, 23), 4.2 * scaleX, hit);
      canvas.drawCircle(p(41, 23), 4.2 * scaleX, hit);
    }
    if (redMuscles.contains('biceps')) {
      rounded(r(8, 27, 6, 12), hit, 6);
      rounded(r(40, 27, 6, 12), hit, 6);
    }
    if (redMuscles.contains('triceps')) {
      rounded(r(6, 24, 6, 14), hit, 6);
      rounded(r(42, 24, 6, 14), hit, 6);
    }
    if (redMuscles.contains('forearms')) {
      rounded(r(7, 36, 7, 10), hit, 6);
      rounded(r(40, 36, 7, 10), hit, 6);
    }
    if (redMuscles.contains('core')) {
      rounded(r(22, 27, 4, 5), hit, 3);
      rounded(r(28, 27, 4, 5), hit, 3);
      rounded(r(22, 34, 4, 5), hit, 3);
      rounded(r(28, 34, 4, 5), hit, 3);
    }
    if (redMuscles.contains('glutes')) {
      rounded(r(18, 38, 8, 8), hit, 5);
      rounded(r(28, 38, 8, 8), hit, 5);
    }
    if (redMuscles.contains('quads')) {
      rounded(r(19, 43, 7, 11), hit, 6);
      rounded(r(28, 43, 7, 11), hit, 6);
    }
    if (redMuscles.contains('hamstrings')) {
      rounded(r(18, 44, 7, 10), hit, 6);
      rounded(r(29, 44, 7, 10), hit, 6);
    }
    if (redMuscles.contains('calves')) {
      rounded(r(19, 52, 7, 8), hit, 6);
      rounded(r(28, 52, 7, 8), hit, 6);
    }
    if (redMuscles.contains('neck')) {
      rounded(r(23, 13, 8, 7), hit, 4);
    }
    if (redMuscles.contains('posterior')) {
      path([p(18, 18), p(36, 18), p(39, 38), p(27, 45), p(15, 38)], hit);
      rounded(r(18, 44, 7, 11), hit, 6);
      rounded(r(29, 44, 7, 11), hit, 6);
    }
  }

  Set<String> _activeShapes(String muscle) {
    return switch (muscle) {
      'Chest' => {'chest'},
      'Back' => {'back'},
      'Quads' => {'quads'},
      'Glutes' => {'glutes'},
      'Hamstrings' => {'hamstrings'},
      'Calves' => {'calves'},
      'Shoulders' => {'shoulders'},
      'Biceps' => {'biceps'},
      'Triceps' => {'triceps'},
      'Forearms' => {'forearms'},
      'Core' => {'core'},
      'Posterior' => {'posterior'},
      'Neck' => {'neck'},
      _ => {'chest'},
    };
  }

  @override
  bool shouldRepaint(covariant _MuscleFigurePainter oldDelegate) {
    return oldDelegate.muscle != muscle || oldDelegate.active != active;
  }
}

class _MuscleRadarPainter extends CustomPainter {
  const _MuscleRadarPainter({required this.labels, required this.values});

  final List<String> labels;
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2 + 4);
    final radius = math.min(size.width, size.height) * 0.31;
    final gridPaint = Paint()
      ..color = AppColors.radarGrid.withValues(
        alpha: AppColors.isLight ? 0.3 : 0.2,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final axisPaint = Paint()
      ..color = AppColors.radarGrid.withValues(
        alpha: AppColors.isLight ? 0.24 : 0.16,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final fillPaint = Paint()
      ..color = AppColors.lime.withValues(
        alpha: AppColors.isLight ? 0.12 : 0.15,
      )
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = AppColors.accentStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final dotPaint = Paint()
      ..color = AppColors.accentStrong
      ..style = PaintingStyle.fill;

    Offset point(int index, double distance) {
      final angle = -math.pi / 2 + index * math.pi * 2 / values.length;
      return Offset(
        center.dx + math.cos(angle) * radius * distance.clamp(0.0, 1.0),
        center.dy + math.sin(angle) * radius * distance.clamp(0.0, 1.0),
      );
    }

    Offset dataPoint(int index, double value) {
      final angle = -math.pi / 2 + index * math.pi * 2 / values.length;
      return Offset(
        center.dx + math.cos(angle) * radius * value.clamp(0.0, 1.0),
        center.dy + math.sin(angle) * radius * value.clamp(0.0, 1.0),
      );
    }

    for (var ring = 1; ring <= 4; ring += 1) {
      final path = Path();
      for (var index = 0; index < values.length; index += 1) {
        final p = point(index, ring / 4);
        if (index == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var index = 0; index < values.length; index += 1) {
      canvas.drawLine(center, point(index, 1), axisPaint);
      _paintLabel(canvas, size, center, radius, index);
    }

    final dataPath = Path();
    for (var index = 0; index < values.length; index += 1) {
      final p = dataPoint(index, values[index]);
      if (index == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, linePaint);

    for (var index = 0; index < values.length; index += 1) {
      if (values[index] <= 0) {
        continue;
      }
      final p = dataPoint(index, values[index]);
      canvas.drawCircle(p, 3.6, dotPaint);
    }
  }

  void _paintLabel(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    int index,
  ) {
    final label = index < labels.length ? labels[index] : '';
    if (label.isEmpty) {
      return;
    }

    final active = values[index] > 0;
    final angle = -math.pi / 2 + index * math.pi * 2 / values.length;
    final offset = Offset(
      center.dx + math.cos(angle) * (radius + 28),
      center.dy + math.sin(angle) * (radius + 26),
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: active ? AppColors.text : AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      maxLines: 1,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 74);

    final x = (offset.dx - textPainter.width / 2).clamp(
      2.0,
      size.width - textPainter.width - 2,
    );
    final y = (offset.dy - textPainter.height / 2).clamp(
      2.0,
      size.height - textPainter.height - 2,
    );
    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _MuscleRadarPainter oldDelegate) {
    return oldDelegate.values.join(',') != values.join(',') ||
        oldDelegate.labels.join(',') != labels.join(',');
  }
}

class _EmptyMuscleFocus extends StatelessWidget {
  const _EmptyMuscleFocus({required this.labels});

  final GymLabels labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        labels.t('noDataYet'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PhotoProgressPanel extends StatelessWidget {
  const _PhotoProgressPanel({
    required this.labels,
    required this.photos,
    required this.isBusy,
    required this.onAdd,
    required this.onDelete,
  });

  final GymLabels labels;
  final List<ProgressPhoto> photos;
  final bool isBusy;
  final VoidCallback onAdd;
  final ValueChanged<ProgressPhoto> onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labels.t('photoProgressTitle'),
                        style: TextStyle(
                          color: AppColors.lime,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        labels.t('photoProgressHint'),
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: isBusy
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.ink,
                            ),
                          )
                        : Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: Text(
                      labels.t('addProgressPhoto'),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 220),
              child: photos.isEmpty
                  ? _EmptyProgressPhotos(labels: labels)
                  : Column(
                      key: ValueKey('progress-photo-list-${photos.length}'),
                      children: [
                        for (final entry in photos.indexed) ...[
                          _ProgressPhotoCard(
                            labels: labels,
                            photo: entry.$2,
                            onDelete: () => onDelete(entry.$2),
                          ),
                          if (entry.$1 != photos.length - 1)
                            SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProgressPhotos extends StatelessWidget {
  const _EmptyProgressPhotos({required this.labels});

  final GymLabels labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('empty-progress-photos'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Icon(Icons.photo_camera_outlined, color: AppColors.lime, size: 34),
          SizedBox(height: 12),
          Text(
            labels.t('noProgressPhotos'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPhotoCard extends StatelessWidget {
  const _ProgressPhotoCard({
    required this.labels,
    required this.photo,
    required this.onDelete,
  });

  final GymLabels labels;
  final ProgressPhoto photo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                width: 92,
                height: 116,
                child: GymExerciseImage(
                  imageUrl: photo.imageDataUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.surface,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.muted,
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labels.t('photoDate'),
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    _formatProgressPhotoDate(labels.language, photo.capturedAt),
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  if (photo.note.trim().isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      photo.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, color: AppColors.lime),
              tooltip: labels.t('deleteProgressPhoto'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatProgressPhotoDate(GymLanguage language, DateTime date) {
  if (language == GymLanguage.en) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  const months = [
    'січня',
    'лютого',
    'березня',
    'квітня',
    'травня',
    'червня',
    'липня',
    'серпня',
    'вересня',
    'жовтня',
    'листопада',
    'грудня',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatTrainingTime(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours <= 0) {
    return '${minutes}m';
  }
  return '${hours}h ${minutes}m';
}
