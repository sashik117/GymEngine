// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/external_link.dart';

class ExerciseVideoPreview extends StatefulWidget {
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
  State<ExerciseVideoPreview> createState() => _ExerciseVideoPreviewState();
}

class _ExerciseVideoPreviewState extends State<ExerciseVideoPreview> {
  late final String _viewType = 'gym-engine-video-${identityHashCode(this)}';

  @override
  void initState() {
    super.initState();
    final video = html.VideoElement()
      ..src = widget.videoUrl
      ..controls = true
      ..muted = true
      ..preload = 'metadata'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.border = '0'
      ..style.backgroundColor = '#000000';
    video
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true')
      ..setAttribute('controlsList', 'nodownload');

    if (widget.posterUrl.trim().isNotEmpty) {
      video.poster = widget.posterUrl.trim();
    }

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => video);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.black,
            border: Border.all(color: AppColors.lime.withValues(alpha: 0.42)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              HtmlElementView(viewType: _viewType),
              Positioned(
                left: 10,
                top: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.74),
                    border: Border.all(
                      color: AppColors.lime.withValues(alpha: 0.55),
                    ),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.lime,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: TextButton.icon(
                  onPressed: () => unawaited(openExternalLink(widget.videoUrl)),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.ink,
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(Icons.open_in_new, size: 15),
                  label: Text(
                    widget.openLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
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
