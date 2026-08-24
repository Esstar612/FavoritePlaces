import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config.dart';
import 'firebase_options_web.dart';
import 'providers/user_settings.dart';
import 'screens/auth_gate.dart';
import 'utils/maps_loader.dart';

const _seedColor = Color.fromARGB(255, 102, 6, 247);

final darkColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.dark,
  seedColor: _seedColor,
  surface: const Color.fromARGB(255, 56, 49, 66),
);

final lightColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.light,
  seedColor: _seedColor,
);

/// Kept for backwards compatibility with existing references.
final colorScheme = darkColorScheme;

ThemeData _themeFor(ColorScheme scheme) => ThemeData(
      useMaterial3: true,
      // Per-scheme, not shared — a dark surface on the light scheme would be
      // unreadable.
      scaffoldBackgroundColor: scheme.surface,
      colorScheme: scheme,
      textTheme: const TextTheme(
        titleSmall: TextStyle(fontWeight: FontWeight.bold),
        titleMedium: TextStyle(fontWeight: FontWeight.bold),
        titleLarge: TextStyle(fontWeight: FontWeight.bold),
      ),
    );

void main() async {
  // Flutter + Firebase both need this before runApp
  WidgetsFlutterBinding.ensureInitialized();
  // Web has no google-services.json / plist to read config from, so it must be
  // passed explicitly; native platforms pick theirs up at build time.
  await Firebase.initializeApp(
    options: kIsWeb ? FirebaseWebOptions.current : null,
  );

  // On web the Maps JavaScript API has to be present before any GoogleMap
  // widget builds; native platforms ship the SDK and this is a no-op.
  if (kIsWeb) {
    await loadGoogleMapsJs(AppConfig.googleMapsApiKey);
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hydrated from the backend at sign-in by AuthGate.
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Favorite Places',
      theme: _themeFor(lightColorScheme),
      darkTheme: _themeFor(darkColorScheme),
      themeMode: themeMode,
      // AuthGate decides: login screens or main app
      home: const AuthGate(),
    );
  }
}
