import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeTab { places, plan, favorites }

final homeTabProvider = StateProvider<HomeTab>((ref) => HomeTab.places);
