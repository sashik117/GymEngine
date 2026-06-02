import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/gym_labels.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/weight_format.dart';
import '../../core/widgets/bouncy_gym_button.dart';
import '../../core/widgets/gym_language_toggle.dart';
import '../../core/widgets/gym_panel.dart';
import '../../data/repos/workout_session_repository.dart';
import '../../domain/models/analytics_snapshot.dart';
import '../../domain/models/user_profile.dart';
import '../bloc/analytics_cubit.dart';
import '../bloc/dashboard_cubit.dart';
import '../bloc/locale_cubit.dart';
import '../bloc/theme_cubit.dart';
import 'auth_gate_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bodyWeightController = TextEditingController();
  UserProfile _profile = UserProfile.empty();
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    context.read<AnalyticsCubit>().load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bodyWeightController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final repository = context.read<WorkoutSessionRepository>();
    final profile = await repository.loadProfile();
    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profile;
      _nameController.text = profile.displayName;
      _bodyWeightController.text = profile.bodyWeightKg == null
          ? ''
          : profile.bodyWeightKg!.toStringAsFixed(
              profile.bodyWeightKg! % 1 == 0 ? 0 : 1,
            );
      _isLoading = false;
    });
  }

  UserProfile _readProfileFromForm() {
    final bodyWeight = double.tryParse(
      _bodyWeightController.text.replaceAll(',', '.'),
    );

    return UserProfile(
      displayName: _nameController.text,
      bodyWeightKg: bodyWeight,
      userId: _profile.userId,
      email: _profile.email,
      authToken: _profile.authToken,
      syncCode: _profile.syncCode,
      syncBaseUrl: _profile.syncBaseUrl.trim().isEmpty
          ? WorkoutSessionRepository.defaultSyncBaseUrl
          : _profile.syncBaseUrl,
    );
  }

  Future<void> _saveProfile() async {
    final labels = context.read<LocaleCubit>().labels;
    final profile = _readProfileFromForm();

    await context.read<WorkoutSessionRepository>().saveProfile(profile);

    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profile.copyWith(displayName: profile.displayName.trim());
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(labels.t('profileSaved'))));
  }

  Future<void> _logout() async {
    final labels = context.read<LocaleCubit>().labels;
    final repository = context.read<WorkoutSessionRepository>();
    final dashboardCubit = context.read<DashboardCubit>();
    final analyticsCubit = context.read<AnalyticsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final profile = await repository.logoutAccount(_readProfileFromForm());
    if (!mounted) {
      return;
    }
    _applyProfile(profile);
    await dashboardCubit.load();
    await analyticsCubit.load();
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(labels.t('authLoggedOut'))));
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthGateScreen()),
      (_) => false,
    );
  }

  void _applyProfile(UserProfile profile) {
    setState(() {
      _profile = profile;
      _nameController.text = profile.displayName;
      _bodyWeightController.text = profile.bodyWeightKg == null
          ? ''
          : profile.bodyWeightKg!.toStringAsFixed(
              profile.bodyWeightKg! % 1 == 0 ? 0 : 1,
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeCubit>();
    final labels = context.watch<LocaleCubit>().labels;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          Text(
            labels.t('profile'),
            style: TextStyle(
              color: AppColors.lime,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 8),
          Text(
            labels.t('profileTitle'),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 24),
          if (_isLoading)
            GymPanel(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.lime),
              ),
            )
          else
            _ProfileHero(labels: labels, profile: _profile),
          SizedBox(height: 16),
          _ProfileControls(labels: labels),
          SizedBox(height: 16),
          BlocBuilder<AnalyticsCubit, AnalyticsState>(
            builder: (context, state) {
              return _ProfileStats(labels: labels, snapshot: state.snapshot);
            },
          ),
          SizedBox(height: 16),
          _ProfileForm(
            labels: labels,
            nameController: _nameController,
            bodyWeightController: _bodyWeightController,
          ),
          SizedBox(height: 16),
          _AccountPanel(labels: labels, profile: _profile, onLogout: _logout),
          SizedBox(height: 18),
          BouncyGymButton(
            label: labels.t('saveProfile'),
            icon: Icons.save,
            onTap: _isLoading ? null : _saveProfile,
          ),
        ],
      ),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({
    required this.labels,
    required this.profile,
    required this.onLogout,
  });

  final GymLabels labels;
  final UserProfile profile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return GymPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.black,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.mail_outline, color: AppColors.lime, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      profile.email.trim().isEmpty
                          ? labels.t('email')
                          : profile.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          BouncyGymButton(
            label: labels.t('logout'),
            icon: Icons.logout,
            isOutlined: true,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _ProfileControls extends StatelessWidget {
  const _ProfileControls({required this.labels});

  final GymLabels labels;

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeCubit>().state;
    final isLight = themeMode == GymThemeMode.light;

    return GymPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              labels.t('settings'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.lime,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTight = constraints.maxWidth < 330;
              final cards = [
                _SettingsControlChip(
                  icon: Icons.language,
                  label: labels.language == GymLanguage.uk
                      ? 'Мова'
                      : 'Language',
                  child: GymLanguageToggle(compact: true),
                ),
                _SettingsControlChip(
                  icon: isLight ? Icons.light_mode : Icons.dark_mode,
                  label: labels.language == GymLanguage.uk ? 'Тема' : 'Theme',
                  child: _ThemeSwitchButton(
                    isLight: isLight,
                    onTap: () => context.read<ThemeCubit>().toggle(),
                    labels: labels,
                    compact: true,
                  ),
                ),
              ];

              if (isTight) {
                return Column(
                  children: [
                    for (final card in cards) ...[
                      SizedBox(width: double.infinity, child: card),
                      if (card != cards.last) SizedBox(height: 10),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (final card in cards) ...[
                    Expanded(child: card),
                    if (card != cards.last) SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsControlChip extends StatelessWidget {
  const _SettingsControlChip({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.lime, size: 18),
            SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 9),
            Center(child: child),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwitchButton extends StatelessWidget {
  const _ThemeSwitchButton({
    required this.isLight,
    required this.onTap,
    required this.labels,
    this.compact = false,
  });

  final bool isLight;
  final VoidCallback onTap;
  final GymLabels labels;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        width: compact ? 92 : null,
        height: compact ? 36 : 42,
        padding: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isLight ? AppColors.lime : AppColors.surface,
          border: Border.all(
            color: isLight ? AppColors.lime : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLight ? Icons.light_mode : Icons.dark_mode,
              color: isLight ? AppColors.ink : AppColors.lime,
              size: 18,
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                isLight
                    ? (labels.language == GymLanguage.uk ? 'Світла' : 'Light')
                    : (labels.language == GymLanguage.uk ? 'Темна' : 'Dark'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isLight ? AppColors.ink : AppColors.text,
                  fontSize: 11,
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.labels, required this.profile});

  final GymLabels labels;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName.trim().isEmpty
        ? labels.t('profileEmptyName')
        : profile.displayName.trim();
    final initial = name.characters.first.toUpperCase();
    final bodyWeight = profile.bodyWeightKg == null
        ? '--'
        : formatKg(profile.bodyWeightKg!, unit: labels.t('kg'));

    return GymPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lime.withValues(alpha: 0.32),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '${labels.t('bodyWeight')}: $bodyWeight',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.lime.withValues(alpha: 0.32)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: AppColors.lime),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      labels.language == GymLanguage.uk
                          ? 'Профіль тримає твої тренування, налаштування і прогрес.'
                          : 'Profile keeps your training, settings, and progress together.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats({required this.labels, required this.snapshot});

  final GymLabels labels;
  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return GymPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labels.t('trainingData'),
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _ProfileStatPill(
                      icon: Icons.calendar_month,
                      label: labels.t('trained'),
                      value: '${snapshot.trainingDates.length}',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ProfileStatPill(
                      icon: Icons.fitness_center,
                      label: labels.t('liftsTracked'),
                      value: '${snapshot.exerciseStats.length}',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ProfileStatPill(
                      icon: Icons.monitor_weight_outlined,
                      label: labels.t('bestWeight'),
                      value: formatKg(
                        snapshot.heaviestSetKg,
                        unit: labels.t('kg'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ProfileStatPill(
                      icon: Icons.local_fire_department_outlined,
                      label: labels.t('streak'),
                      value:
                          '${snapshot.currentStreakDays} ${labels.t('days')}',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileStatPill extends StatelessWidget {
  const _ProfileStatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
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
            Icon(icon, color: AppColors.lime, size: 18),
            SizedBox(height: 8),
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
            SizedBox(height: 6),
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

class _ProfileForm extends StatelessWidget {
  const _ProfileForm({
    required this.labels,
    required this.nameController,
    required this.bodyWeightController,
  });

  final GymLabels labels;
  final TextEditingController nameController;
  final TextEditingController bodyWeightController;

  @override
  Widget build(BuildContext context) {
    return GymPanel(
      child: Column(
        children: [
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: labels.t('profileName'),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.lime),
              ),
            ),
          ),
          SizedBox(height: 14),
          TextField(
            controller: bodyWeightController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            decoration: InputDecoration(
              labelText: '${labels.t('bodyWeight')} (${labels.t('kg')})',
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.lime),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
