import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/notifications/rest_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/local/app_database.dart';
import 'data/repos/workout_session_repository.dart';
import 'presentation/bloc/analytics_cubit.dart';
import 'presentation/bloc/dashboard_cubit.dart';
import 'presentation/bloc/locale_cubit.dart';
import 'presentation/bloc/theme_cubit.dart';
import 'presentation/screens/app_shell_screen.dart';
import 'presentation/screens/auth_gate_screen.dart';

void main() {
  runApp(GymEngineApp());
}

class GymEngineApp extends StatelessWidget {
  const GymEngineApp({
    this.sessionRepository,
    this.skipAuthGate = false,
    super.key,
  });

  final WorkoutSessionRepository? sessionRepository;
  final bool skipAuthGate;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (_) =>
              sessionRepository ?? WorkoutSessionRepository(AppDatabase()),
        ),
        RepositoryProvider(
          create: (_) {
            final service = RestNotificationService();
            service.initialize();
            return service;
          },
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => LocaleCubit()),
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(
            create: (context) =>
                DashboardCubit(context.read<WorkoutSessionRepository>())
                  ..load(),
          ),
          BlocProvider(
            create: (context) =>
                AnalyticsCubit(context.read<WorkoutSessionRepository>())
                  ..load(),
          ),
        ],
        child: BlocBuilder<ThemeCubit, GymThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'GymEngine',
              theme: AppTheme.forMode(themeMode),
              home: skipAuthGate ? AppShellScreen() : AuthGateScreen(),
            );
          },
        ),
      ),
    );
  }
}
