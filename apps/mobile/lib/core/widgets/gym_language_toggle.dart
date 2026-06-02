import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/bloc/locale_cubit.dart';
import '../localization/gym_labels.dart';
import '../theme/app_theme.dart';

class GymLanguageToggle extends StatelessWidget {
  const GymLanguageToggle({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LocaleCubit>().state;

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 160),
        padding: EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(999),
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.lime.withValues(alpha: 0.08),
              blurRadius: 18,
              spreadRadius: -10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageButton(
              label: compact ? 'UA' : 'УКР',
              isSelected: language == GymLanguage.uk,
              compact: compact,
              onPressed: () =>
                  context.read<LocaleCubit>().setLanguage(GymLanguage.uk),
            ),
            _LanguageButton(
              label: compact ? 'EN' : 'ENG',
              isSelected: language == GymLanguage.en,
              compact: compact,
              onPressed: () =>
                  context.read<LocaleCubit>().setLanguage(GymLanguage.en),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.isSelected,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(5),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 160),
        width: compact ? 38 : 48,
        height: compact ? 30 : 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.ink : AppColors.muted,
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
