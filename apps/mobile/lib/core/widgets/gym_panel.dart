import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GymPanel extends StatelessWidget {
  const GymPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(
          painter: const _KnurlPainter(),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _KnurlPainter extends CustomPainter {
  const _KnurlPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.lime.withValues(alpha: 0.035)
      ..strokeWidth = 1;

    for (var x = -size.height; x < size.width; x += 14) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
