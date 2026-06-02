import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';

class ThemeCubit extends Cubit<GymThemeMode> {
  ThemeCubit() : super(GymThemeMode.dark) {
    AppColors.mode = GymThemeMode.dark;
  }

  void setTheme(GymThemeMode mode) {
    AppColors.mode = mode;
    emit(mode);
  }

  void toggle() {
    setTheme(
      state == GymThemeMode.dark ? GymThemeMode.light : GymThemeMode.dark,
    );
  }
}
