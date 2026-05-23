import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/bloc/locale_cubit.dart';
import '../localization/gym_labels.dart';
import '../theme/app_theme.dart';

class GymLanguageToggle extends StatelessWidget {
  const GymLanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LocaleCubit>().state;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
        color: AppColors.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LanguageButton(
            label: 'УКР',
            isSelected: language == GymLanguage.uk,
            onPressed: () =>
                context.read<LocaleCubit>().setLanguage(GymLanguage.uk),
          ),
          _LanguageButton(
            label: 'ENG',
            isSelected: language == GymLanguage.en,
            onPressed: () =>
                context.read<LocaleCubit>().setLanguage(GymLanguage.en),
          ),
        ],
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(5),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.ink : AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
