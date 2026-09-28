import 'package:flutter_riverpod/legacy.dart';

enum HomeTab { places, plan, favorites }

final homeTabProvider = StateProvider<HomeTab>((ref) => HomeTab.places);
