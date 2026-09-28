import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/providers/user_settings.dart';
import 'package:favorite_places/screens/auth/guest_loading.dart';
import 'package:favorite_places/screens/auth/login.dart';
import 'package:favorite_places/screens/home_shell.dart';

/// Root widget that watches the Firebase auth stream and:
///   • starts the Firestore places listener when a user signs in
///   • loads saved user settings so the chosen theme applies at launch
///   • stops both and clears state when they sign out
///   • routes to LoginScreen or HomeShell accordingly
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, this.home = const HomeShell()});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // userChanges also fires on profile updates (display name), so the places stream
    // and settings only restart when the uid actually changes.
    ref.listen(authStateProvider, (previous, next) {
      final before = previous?.valueOrNull?.uid;
      final after = next.valueOrNull?.uid;
      if (before == after) return;
      if (after != null) {
        ref.read(userPlacesProvider.notifier).startListening();
        // Fire-and-forget: the theme swaps in when it arrives. load() is
        // guarded against overlapping calls.
        ref.read(userSettingsProvider.notifier).load();
      } else {
        ref.read(userPlacesProvider.notifier).stopListening();
        ref.read(userSettingsProvider.notifier).reset();
      }
    });

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Auth error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(authStateProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        if (ref.watch(guestSeedingProvider)) return const GuestLoadingScreen();
        if (user == null) return const LoginScreen();

        // Cold start: ref.listen above doesn't fire for the stream's initial
        // value, so kick both off here too. Each is idempotent.
        ref.read(userPlacesProvider.notifier).startListening();
        ref.read(userSettingsProvider.notifier).load();
        return home;
      },
    );
  }
}
