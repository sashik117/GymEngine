import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/localization/gym_labels.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/external_link.dart';
import '../../core/widgets/bouncy_gym_button.dart';
import '../../core/widgets/gym_exercise_image.dart';
import '../../domain/models/exercise.dart';
import 'exercise_video_preview.dart';

Future<void> showExerciseDetailSheet({
  required BuildContext context,
  required GymLabels labels,
  required Exercise exercise,
  VoidCallback? onAdd,
  String? addLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _ExerciseDetailSheet(
        labels: labels,
        exercise: exercise,
        onAdd: onAdd,
        addLabel: addLabel,
      );
    },
  );
}

class _ExerciseDetailSheet extends StatelessWidget {
  const _ExerciseDetailSheet({
    required this.labels,
    required this.exercise,
    required this.onAdd,
    required this.addLabel,
  });

  final GymLabels labels;
  final Exercise exercise;
  final VoidCallback? onAdd;
  final String? addLabel;

  @override
  Widget build(BuildContext context) {
    final imageUrl = exercise.imageUrl.trim();
    final videoUrl = exercise.videoUrl.trim();
    final name = labels.exerciseName(exercise.id, exercise.name);

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.52,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.lime.withValues(alpha: 0.16),
                blurRadius: 34,
                spreadRadius: -18,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 1.28,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl.isNotEmpty)
                          GymExerciseImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stackTrace) {
                              return _TechniqueFallback(
                                muscle: exercise.primaryMuscle,
                              );
                            },
                          )
                        else
                          _TechniqueFallback(muscle: exercise.primaryMuscle),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppColors.black.withValues(alpha: 0.18),
                                AppColors.black.withValues(alpha: 0.72),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                              if (videoUrl.isNotEmpty) ...[
                                SizedBox(width: 12),
                                IconButton.filled(
                                  onPressed: () =>
                                      unawaited(openExternalLink(videoUrl)),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.lime,
                                    foregroundColor: AppColors.ink,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: Icon(Icons.play_arrow),
                                  tooltip: _text(
                                    labels,
                                    uk: 'Відео техніки',
                                    en: 'Technique video',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailChip(
                    icon: Icons.bolt,
                    label: labels.muscleName(exercise.primaryMuscle),
                  ),
                  if (exercise.bodyPart.trim().isNotEmpty)
                    _DetailChip(
                      icon: Icons.accessibility_new,
                      label: labels.catalogAttribute(exercise.bodyPart),
                    ),
                  if (exercise.equipment.trim().isNotEmpty)
                    _DetailChip(
                      icon: Icons.fitness_center,
                      label: labels.catalogAttribute(exercise.equipment),
                    ),
                  if (exercise.exerciseType.trim().isNotEmpty)
                    _DetailChip(
                      icon: Icons.repeat,
                      label: labels.catalogAttribute(exercise.exerciseType),
                    ),
                ],
              ),
              if (videoUrl.isNotEmpty) ...[
                SizedBox(height: 16),
                ExerciseVideoPreview(
                  videoUrl: videoUrl,
                  posterUrl: imageUrl,
                  title: _text(
                    labels,
                    uk: 'Відео техніки',
                    en: 'Technique video',
                  ),
                  openLabel: _text(labels, uk: 'Відкрити', en: 'Open'),
                ),
              ],
              SizedBox(height: 16),
              _TechniqueAction(
                icon: Icons.play_circle_fill,
                title: _text(
                  labels,
                  uk: 'Відео техніки виконання',
                  en: 'Technique video',
                ),
                body: videoUrl.isEmpty
                    ? _text(
                        labels,
                        uk: 'Для цієї вправи поки немає відео.',
                        en: 'No video is linked for this exercise yet.',
                      )
                    : _text(
                        labels,
                        uk: 'Відкриє відео з технікою виконання.',
                        en: 'Opens the exercise technique video.',
                      ),
                onTap: videoUrl.isEmpty
                    ? null
                    : () => unawaited(openExternalLink(videoUrl)),
              ),
              if (onAdd != null) ...[
                SizedBox(height: 18),
                BouncyGymButton(
                  label:
                      addLabel ??
                      _text(labels, uk: 'ДОДАТИ В ДЕНЬ', en: 'ADD TO DAY'),
                  height: 56,
                  icon: Icons.add,
                  onTap: () {
                    onAdd?.call();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TechniqueFallback extends StatelessWidget {
  const _TechniqueFallback({required this.muscle});

  final String muscle;

  @override
  Widget build(BuildContext context) {
    final accent = _accent(muscle);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            AppColors.panel,
            AppColors.black,
          ],
        ),
      ),
      child: Center(child: Icon(Icons.fitness_center, color: accent, size: 76)),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
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
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.lime, size: 15),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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

class _TechniqueAction extends StatelessWidget {
  const _TechniqueAction({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(
            color: onTap == null ? AppColors.border : AppColors.lime,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                icon,
                color: onTap == null ? AppColors.muted : AppColors.lime,
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                SizedBox(width: 8),
                Icon(Icons.chevron_right, color: AppColors.lime),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
