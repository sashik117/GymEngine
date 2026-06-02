import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/gym_labels.dart';
import '../../core/theme/app_theme.dart';
import '../bloc/analytics_cubit.dart';
import '../bloc/dashboard_cubit.dart';
import '../bloc/locale_cubit.dart';
import '../bloc/theme_cubit.dart';
import 'core_screen.dart';
import 'engine_screen.dart';
import 'exercise_search_screen.dart';
import 'profile_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  var _currentIndex = 0;
  int? _searchTargetDayNumber;
  var _searchTargetToken = 0;

  void _selectDestination(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (index == 0) {
      context.read<DashboardCubit>().load();
    } else if (index == 2) {
      context.read<AnalyticsCubit>().load();
    }
  }

  void _openSearchForDay(int dayNumber) {
    setState(() {
      _searchTargetDayNumber = dayNumber;
      _searchTargetToken += 1;
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeCubit>().state;
    final labels = context.watch<LocaleCubit>().labels;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          CoreScreen(onOpenSearch: _openSearchForDay),
          ExerciseSearchScreen(
            targetDayNumber: _searchTargetDayNumber,
            targetToken: _searchTargetToken,
          ),
          EngineScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.black,
          indicatorColor: AppColors.lime,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              color: isSelected ? AppColors.lime : AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: isSelected ? AppColors.ink : AppColors.muted,
            );
          }),
        ),
        child: NavigationBar(
          key: ValueKey(themeMode),
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectDestination,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: labels.t('base'),
            ),
            NavigationDestination(
              icon: Icon(Icons.search),
              selectedIcon: Icon(Icons.manage_search),
              label: labels.language == GymLanguage.uk ? 'ПОШУК' : 'SEARCH',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: labels.t('engine'),
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: labels.t('profile'),
            ),
          ],
        ),
      ),
    );
  }
}
