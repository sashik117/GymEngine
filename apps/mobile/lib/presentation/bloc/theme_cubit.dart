import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';

class ThemeCubit extends Cubit<GymThemeMode> {
  ThemeCubit() : super(GymThemeMode.dark);

  void setTheme(GymThemeMode mode) => emit(mode);

  void toggle() {
    emit(state == GymThemeMode.dark ? GymThemeMode.light : GymThemeMode.dark);
  }
}
