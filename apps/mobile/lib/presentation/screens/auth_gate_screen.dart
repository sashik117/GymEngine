import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/gym_labels.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bouncy_gym_button.dart';
import '../../core/widgets/gym_language_toggle.dart';
import '../../core/widgets/gym_panel.dart';
import '../../data/repos/workout_session_repository.dart';
import '../../domain/models/user_profile.dart';
import '../bloc/analytics_cubit.dart';
import '../bloc/dashboard_cubit.dart';
import '../bloc/locale_cubit.dart';
import 'app_shell_screen.dart';

enum _AuthGatePhase { checking, auth, app }

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  var _phase = _AuthGatePhase.checking;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final repository = context.read<WorkoutSessionRepository>();
    final dashboardCubit = context.read<DashboardCubit>();
    final analyticsCubit = context.read<AnalyticsCubit>();
    final profile = await repository.loadProfile();

    if (!profile.isAuthenticated) {
      if (mounted) {
        setState(() => _phase = _AuthGatePhase.auth);
      }
      return;
    }

    unawaited(
      repository
          .syncToServer(profile: profile, baseUrl: profile.syncBaseUrl)
          .catchError(
            (_) => SyncRunResult(
              message: 'offline',
              syncCode: profile.userId,
              setCount: 0,
              sessionCount: 0,
              trainingDayCount: 0,
            ),
          ),
    );

    if (!mounted) {
      return;
    }
    await dashboardCubit.load();
    await analyticsCubit.load();

    if (mounted) {
      setState(() => _phase = _AuthGatePhase.app);
    }
  }

  Future<void> _enterApp() async {
    setState(() => _phase = _AuthGatePhase.checking);
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _AuthGatePhase.app => AppShellScreen(),
      _AuthGatePhase.auth => _AuthScreen(onAuthenticated: _enterApp),
      _AuthGatePhase.checking => const _AuthLoadingScreen(),
    };
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final labels = context.watch<LocaleCubit>().labels;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  color: AppColors.lime,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 18),
              Text(
                labels.t('loading'),
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthScreen extends StatefulWidget {
  const _AuthScreen({required this.onAuthenticated});

  final Future<void> Function() onAuthenticated;

  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

enum _AuthMode {
  login,
  register,
  verifyRegistration,
  resetRequest,
  resetConfirm,
}

class _AuthScreenState extends State<_AuthScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();
  var _mode = _AuthMode.login;
  var _isSubmitting = false;
  var _isPasswordVisible = false;
  var _isConfirmPasswordVisible = false;
  var _pendingRegistrationEmail = '';
  var _pendingRegistrationName = '';

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    switch (_mode) {
      case _AuthMode.login:
        await _login();
      case _AuthMode.register:
        await _requestRegistrationCode();
      case _AuthMode.verifyRegistration:
        await _verifyRegistrationCode();
      case _AuthMode.resetRequest:
        await _requestPasswordResetCode();
      case _AuthMode.resetConfirm:
        await _confirmPasswordReset();
    }
  }

  Future<void> _login() async {
    final labels = context.read<LocaleCubit>().labels;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.length < 6) {
      _showAuthError(labels);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repository = context.read<WorkoutSessionRepository>();
      final profile = UserProfile.empty().copyWith(
        displayName: _nameController.text.trim(),
        email: email,
        syncBaseUrl: WorkoutSessionRepository.defaultSyncBaseUrl,
      );

      await repository.loginAccount(
        profile: profile,
        baseUrl: WorkoutSessionRepository.defaultSyncBaseUrl,
        email: email,
        password: password,
      );

      if (mounted) {
        await widget.onAuthenticated();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showAuthError(labels);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _requestRegistrationCode() async {
    final labels = context.read<LocaleCubit>().labels;
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty ||
        name.isEmpty ||
        password.length < 6 ||
        password != confirmPassword) {
      _showAuthError(labels);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await context.read<WorkoutSessionRepository>().requestRegistrationCode(
        baseUrl: WorkoutSessionRepository.defaultSyncBaseUrl,
        email: email,
        password: password,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingRegistrationEmail = email;
        _pendingRegistrationName = name;
        _codeController.clear();
        _mode = _AuthMode.verifyRegistration;
      });
      _showSnack(labels.t('codeSent'));
    } catch (_) {
      if (mounted) {
        _showAuthError(labels);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _verifyRegistrationCode() async {
    final labels = context.read<LocaleCubit>().labels;
    final code = _codeController.text.trim();
    final email = _pendingRegistrationEmail.isNotEmpty
        ? _pendingRegistrationEmail
        : _emailController.text.trim();

    if (email.isEmpty || code.length < 6) {
      _showAuthError(labels);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final profile = UserProfile.empty().copyWith(
        displayName: _pendingRegistrationName,
        email: email,
        syncBaseUrl: WorkoutSessionRepository.defaultSyncBaseUrl,
      );
      await context.read<WorkoutSessionRepository>().verifyRegistrationCode(
        profile: profile,
        baseUrl: WorkoutSessionRepository.defaultSyncBaseUrl,
        email: email,
        code: code,
      );
      if (mounted) {
        await widget.onAuthenticated();
      }
    } catch (_) {
      if (mounted) {
        _showAuthError(labels);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _requestPasswordResetCode() async {
    final labels = context.read<LocaleCubit>().labels;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showAuthError(labels);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await context.read<WorkoutSessionRepository>().requestPasswordResetCode(
        baseUrl: WorkoutSessionRepository.defaultSyncBaseUrl,
        email: email,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _codeController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _mode = _AuthMode.resetConfirm;
      });
      _showSnack(labels.t('resetCodeSent'));
    } catch (_) {
      if (mounted) {
        _showAuthError(labels);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _confirmPasswordReset() async {
    final labels = context.read<LocaleCubit>().labels;
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty ||
        code.length < 6 ||
        password.length < 6 ||
        password != confirmPassword) {
      _showAuthError(labels);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final profile = UserProfile.empty().copyWith(
        displayName: _nameController.text.trim(),
        email: email,
        syncBaseUrl: WorkoutSessionRepository.defaultSyncBaseUrl,
      );
      await context.read<WorkoutSessionRepository>().confirmPasswordReset(
        profile: profile,
        baseUrl: WorkoutSessionRepository.defaultSyncBaseUrl,
        email: email,
        code: code,
        password: password,
      );
      if (mounted) {
        await widget.onAuthenticated();
      }
    } catch (_) {
      if (mounted) {
        _showAuthError(labels);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showAuthError(GymLabels labels) {
    _showSnack(labels.t('authFailed'));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _codeController.clear();
      if (mode == _AuthMode.login || mode == _AuthMode.register) {
        _pendingRegistrationEmail = '';
        _pendingRegistrationName = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels = context.watch<LocaleCubit>().labels;
    final isRegisterMode = _mode == _AuthMode.register;
    final isCodeMode =
        _mode == _AuthMode.verifyRegistration ||
        _mode == _AuthMode.resetConfirm;
    final title = switch (_mode) {
      _AuthMode.login => labels.t('login'),
      _AuthMode.register => labels.t('register'),
      _AuthMode.verifyRegistration => labels.t('verifyEmail'),
      _AuthMode.resetRequest => labels.t('resetPassword'),
      _AuthMode.resetConfirm => labels.t('newPassword'),
    };
    final primaryLabel = switch (_mode) {
      _AuthMode.login => labels.t('login'),
      _AuthMode.register => labels.t('sendCode'),
      _AuthMode.verifyRegistration => labels.t('confirmEmail'),
      _AuthMode.resetRequest => labels.t('sendCode'),
      _AuthMode.resetConfirm => labels.t('resetPassword'),
    };

    return Scaffold(
      floatingActionButton: GymLanguageToggle(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: SafeArea(
        child: CustomPaint(
          painter: const _AuthBackgroundPainter(),
          child: Center(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(20, 48, 20, 28),
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.94, end: 1),
                  duration: Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.lime,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.lime.withValues(alpha: 0.28),
                                  blurRadius: 22,
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: 42,
                              height: 42,
                              child: Icon(
                                Icons.fitness_center,
                                color: AppColors.ink,
                                size: 22,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'GYMENGINE',
                            style: TextStyle(
                              color: AppColors.lime,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset(0, 0.08),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          title,
                          key: ValueKey(title),
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18),
                GymPanel(
                  padding: EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_mode == _AuthMode.login ||
                          _mode == _AuthMode.register)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _AuthModeButton(
                                  label: labels.t('login'),
                                  isSelected: _mode == _AuthMode.login,
                                  onTap: () => _switchMode(_AuthMode.login),
                                ),
                              ),
                              Expanded(
                                child: _AuthModeButton(
                                  label: labels.t('register'),
                                  isSelected: _mode == _AuthMode.register,
                                  onTap: () => _switchMode(_AuthMode.register),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        _AuthBackButton(
                          label: labels.t('backToLogin'),
                          onTap: () => _switchMode(_AuthMode.login),
                        ),
                      SizedBox(height: 14),
                      _AuthTextField(
                        controller: _emailController,
                        label: labels.t('email'),
                        icon: Icons.alternate_email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                      ),
                      AnimatedSize(
                        duration: Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: 180),
                          child: isCodeMode
                              ? Padding(
                                  key: ValueKey('code-field'),
                                  padding: EdgeInsets.only(top: 12),
                                  child: _AuthTextField(
                                    controller: _codeController,
                                    label: labels.t('emailCode'),
                                    icon: Icons.pin,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                  ),
                                )
                              : SizedBox.shrink(key: ValueKey('no-code-field')),
                        ),
                      ),
                      AnimatedSize(
                        duration: Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: 180),
                          child: isRegisterMode
                              ? Padding(
                                  key: ValueKey('name-field'),
                                  padding: EdgeInsets.only(top: 12),
                                  child: _AuthTextField(
                                    controller: _nameController,
                                    label: labels.t('profileName'),
                                    icon: Icons.person,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    autofillHints: const [AutofillHints.name],
                                  ),
                                )
                              : SizedBox.shrink(key: ValueKey('no-name-field')),
                        ),
                      ),
                      if (_mode != _AuthMode.resetRequest) ...[
                        SizedBox(height: 12),
                        _AuthTextField(
                          controller: _passwordController,
                          label: _mode == _AuthMode.resetConfirm
                              ? labels.t('newPassword')
                              : labels.t('password'),
                          icon: Icons.lock,
                          obscureText: !_isPasswordVisible,
                          autofillHints: const [AutofillHints.password],
                          textInputAction:
                              isRegisterMode || _mode == _AuthMode.resetConfirm
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onSubmitted: (_) => _isSubmitting ? null : _submit(),
                          suffix: _PasswordEyeButton(
                            isVisible: _isPasswordVisible,
                            onTap: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: AnimatedSwitcher(
                            duration: Duration(milliseconds: 180),
                            child:
                                (isRegisterMode ||
                                    _mode == _AuthMode.resetConfirm)
                                ? Padding(
                                    key: ValueKey('confirm-field'),
                                    padding: EdgeInsets.only(top: 12),
                                    child: _AuthTextField(
                                      controller: _confirmPasswordController,
                                      label: labels.t('repeatPassword'),
                                      icon: Icons.lock_reset,
                                      obscureText: !_isConfirmPasswordVisible,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) =>
                                          _isSubmitting ? null : _submit(),
                                      suffix: _PasswordEyeButton(
                                        isVisible: _isConfirmPasswordVisible,
                                        onTap: () => setState(
                                          () => _isConfirmPasswordVisible =
                                              !_isConfirmPasswordVisible,
                                        ),
                                      ),
                                    ),
                                  )
                                : SizedBox.shrink(
                                    key: ValueKey('no-confirm-field'),
                                  ),
                          ),
                        ),
                      ],
                      if (_mode == _AuthMode.login)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _switchMode(_AuthMode.resetRequest),
                            child: Text(labels.t('forgotPassword')),
                          ),
                        ),
                      SizedBox(height: 16),
                      BouncyGymButton(
                        height: 50,
                        label: _isSubmitting
                            ? labels.t('loading')
                            : primaryLabel,
                        icon: switch (_mode) {
                          _AuthMode.login => Icons.login,
                          _AuthMode.register => Icons.mark_email_unread,
                          _AuthMode.verifyRegistration => Icons.verified,
                          _AuthMode.resetRequest => Icons.mark_email_unread,
                          _AuthMode.resetConfirm => Icons.lock_reset,
                        },
                        onTap: _isSubmitting ? null : _submit,
                      ),
                    ],
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

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      cursorColor: AppColors.lime,
      style: TextStyle(
        color: AppColors.text,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.black.withValues(alpha: 0.72),
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
        suffixIcon: suffix,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.lime, width: 1.3),
        ),
      ),
    );
  }
}

class _PasswordEyeButton extends StatelessWidget {
  const _PasswordEyeButton({required this.isVisible, required this.onTap});

  final bool isVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isVisible ? 'Hide password' : 'Show password',
      onPressed: onTap,
      icon: AnimatedSwitcher(
        duration: Duration(milliseconds: 140),
        child: Icon(
          isVisible ? Icons.visibility_off : Icons.visibility,
          key: ValueKey(isVisible),
          color: AppColors.lime,
          size: 20,
        ),
      ),
    );
  }
}

class _AuthBackgroundPainter extends CustomPainter {
  const _AuthBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.lime.withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.18, size.height * 0.12),
              radius: size.width * 0.9,
            ),
          );
    canvas.drawRect(Offset.zero & size, glowPaint);

    final linePaint = Paint()
      ..color = AppColors.lime.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 160),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? AppColors.ink : AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _AuthBackButton extends StatelessWidget {
  const _AuthBackButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.arrow_back, size: 18, color: AppColors.lime),
        label: Text(
          label,
          style: TextStyle(
            color: AppColors.lime,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
