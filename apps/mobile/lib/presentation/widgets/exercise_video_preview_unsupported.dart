import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/external_link.dart';

class ExerciseVideoPreview extends StatelessWidget {
  const ExerciseVideoPreview({
    required this.videoUrl,
    required this.posterUrl,
    required this.title,
    this.openLabel = 'Open',
    super.key,
  });

  final String videoUrl;
  final String posterUrl;
  final String title;
  final String openLabel;

  @override
  Widget build(BuildContext context) {
    return _ExternalVideoPreview(
      videoUrl: videoUrl,
      posterUrl: posterUrl,
      title: title,
      openLabel: openLabel,
    );
  }
}

class _ExternalVideoPreview extends StatelessWidget {
  const _ExternalVideoPreview({
    required this.videoUrl,
    required this.posterUrl,
    required this.title,
    required this.openLabel,
  });

  final String videoUrl;
  final String posterUrl;
  final String title;
  final String openLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => unawaited(openExternalLink(videoUrl)),
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.black,
            border: Border.all(color: AppColors.lime.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (posterUrl.trim().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.network(
                    posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.lime.withValues(alpha: 0.28),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.ink,
                      size: 34,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 96,
                bottom: 12,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      openLabel,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
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
