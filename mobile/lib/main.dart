import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config.dart';
import 'firebase_options_web.dart';
import 'providers/user_settings.dart';
import 'screens/auth_gate.dart';
import 'utils/maps_loader.dart';
import 'widgets/web_phone_frame.dart';

const _seedColor = Color.fromARGB(255, 102, 6, 247);

final darkColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.dark,
  seedColor: _seedColor,
  surface: const Color(0xFF1D1A22),
  surfaceContainerLow: const Color(0xFF221F27),
  surfaceContainer: const Color(0xFF28242E),
  surfaceContainerHigh: const Color(0xFF322D39),
  surfaceContainerHighest: const Color(0xFF3D3745),
);

final lightColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.light,
  seedColor: _seedColor,
  primary: const Color(0xFF6B4FA3),
  onPrimary: const Color(0xFFFFFFFF),
  primaryContainer: const Color(0xFFEBDDFF),
  onPrimaryContainer: const Color(0xFF24104F),
  secondaryContainer: const Color(0xFFE8DEF8),
  onSecondaryContainer: const Color(0xFF1E192B),
  tertiary: const Color(0xFF7D5260),
  tertiaryContainer: const Color(0xFFFFD8E4),
  error: const Color(0xFFBA1A1A),
  surface: const Color(0xFFFEF7FF),
  onSurface: const Color(0xFF1D1B20),
  onSurfaceVariant: const Color(0xFF49454E),
  outline: const Color(0xFF7A757F),
  outlineVariant: const Color(0xFFCBC4CF),
  surfaceContainerLowest: const Color(0xFFFFFFFF),
  surfaceContainerLow: const Color(0xFFF7F2FA),
  surfaceContainer: const Color(0xFFF3EDF7),
  surfaceContainerHigh: const Color(0xFFEEE7F2),
  surfaceContainerHighest: const Color(0xFFE6E0E9),
);

/// Kept for backwards compatibility with existing references.
final colorScheme = darkColorScheme;

ThemeData _themeFor(ColorScheme scheme) {
  final base = ThemeData(
    useMaterial3: true,
    // Per-scheme, not shared — a dark surface on the light scheme would be
    // unreadable.
    scaffoldBackgroundColor: scheme.surface,
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(centerTitle: false),
    textTheme: const TextTheme(
      titleSmall: TextStyle(fontWeight: FontWeight.bold),
      titleMedium: TextStyle(fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontWeight: FontWeight.bold),
    ),
  );
  return base.copyWith(textTheme: _untracked(base.textTheme));
}

// The designs set no letter spacing; Material 3's default tracking makes lines wrap sooner.
TextTheme _untracked(TextTheme t) {
  TextStyle? zero(TextStyle? style) => style?.copyWith(letterSpacing: 0);
  return TextTheme(
    displayLarge: zero(t.displayLarge),
    displayMedium: zero(t.displayMedium),
    displaySmall: zero(t.displaySmall),
    headlineLarge: zero(t.headlineLarge),
    headlineMedium: zero(t.headlineMedium),
    headlineSmall: zero(t.headlineSmall),
    titleLarge: zero(t.titleLarge),
    titleMedium: zero(t.titleMedium),
    titleSmall: zero(t.titleSmall),
    bodyLarge: zero(t.bodyLarge),
    bodyMedium: zero(t.bodyMedium),
    bodySmall: zero(t.bodySmall),
    labelLarge: zero(t.labelLarge),
    labelMedium: zero(t.labelMedium),
    labelSmall: zero(t.labelSmall),
  );
}

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
      // Wraps the whole navigator, so dialogs and snackbars stay inside the
      // frame too. No-op on mobile and in narrow windows.
      builder: (context, child) => WebPhoneFrame(child: child ?? const SizedBox.shrink()),
      // AuthGate decides: login screens or main app
      home: const AuthGate(),
    );
  }
}
