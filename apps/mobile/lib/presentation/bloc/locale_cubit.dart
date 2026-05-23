import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/gym_labels.dart';

class LocaleCubit extends Cubit<GymLanguage> {
  LocaleCubit() : super(GymLanguage.uk);

  void setLanguage(GymLanguage language) => emit(language);

  GymLabels get labels => GymLabels(state);
}
