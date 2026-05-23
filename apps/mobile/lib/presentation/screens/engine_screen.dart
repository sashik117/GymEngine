import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/gym_labels.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/weight_format.dart';
import '../../data/repos/workout_session_repository.dart';
import '../../domain/models/analytics_snapshot.dart';
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<AnalyticsCubit, AnalyticsState>(
        builder: (context, state) {
          final snapshot = state.snapshot;
          final labels = context.watch<LocaleCubit>().labels;
          final monthStats = _statsForMonth(snapshot, _visibleMonth);
          final trainingDays = _daysForMonth(snapshot, _visibleMonth);
          final selectedSummary = _selectedSummary(trainingDays);
          final previousMonth = _availableMonthBefore(snapshot, _visibleMonth);
          final nextMonth = _availableMonthAfter(snapshot, _visibleMonth);

          return ListView(
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
              _MonthStats(
                labels: labels,
                workoutCount: trainingDays.length,
                trackedCount: monthStats.length,
                bestWeightKg: _bestWeight(monthStats),
              ),
              SizedBox(height: 18),
              _TrainingCalendar(
                labels: labels,
                visibleMonth: _visibleMonth,
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
              SizedBox(height: 18),
              _ExerciseProgressList(labels: labels, stats: monthStats),
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
}

class _MonthStats extends StatelessWidget {
  const _MonthStats({
    required this.labels,
    required this.workoutCount,
    required this.trackedCount,
    required this.bestWeightKg,
  });

  final GymLabels labels;
  final int workoutCount;
  final int trackedCount;
  final double bestWeightKg;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _EngineStatCard(
            label: labels.t('workoutsThisMonth'),
            value: '$workoutCount',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _EngineStatCard(
            label: labels.t('liftsTracked'),
            value: '$trackedCount',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _EngineStatCard(
            label: labels.t('bestWeight'),
            value: formatKg(bestWeightKg, unit: labels.t('kg')),
          ),
        ),
      ],
    );
  }
}

class _EngineStatCard extends StatelessWidget {
  const _EngineStatCard({required this.label, required this.value});

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
        padding: EdgeInsets.all(16),
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
