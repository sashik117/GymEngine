import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BouncyGymButton extends StatefulWidget {
  const BouncyGymButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.height = 60,
    this.isOutlined = false,
    this.backgroundColor = AppColors.lime,
    this.foregroundColor = AppColors.ink,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final bool isOutlined;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  State<BouncyGymButton> createState() => _BouncyGymButtonState();
}

class _BouncyGymButtonState extends State<BouncyGymButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _isEnabled => widget.onTap != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 90),
      lowerBound: 0.95,
      upperBound: 1,
    )..value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    if (_isEnabled) {
      _controller.reverse();
    }
  }

  void _release({bool shouldTap = false}) {
    _controller.forward();
    if (shouldTap && _isEnabled) {
      widget.onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.isOutlined
        ? Colors.transparent
        : (_isEnabled ? widget.backgroundColor : AppColors.surface);
    final foreground = _isEnabled
        ? (widget.isOutlined ? widget.backgroundColor : widget.foregroundColor)
        : AppColors.muted;
    final borderColor = _isEnabled ? widget.backgroundColor : AppColors.border;

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(),
        onTapCancel: _release,
        onTapUp: (_) => _release(shouldTap: true),
        child: ScaleTransition(
          scale: _controller,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 120),
            width: double.infinity,
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(6),
              boxShadow: _isEnabled && !widget.isOutlined
                  ? [
                      BoxShadow(
                        color: widget.backgroundColor.withValues(alpha: 0.28),
                        blurRadius: 18,
                        spreadRadius: -6,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: foreground, size: 20),
                  SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
