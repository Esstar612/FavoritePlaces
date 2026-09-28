import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/providers/user_settings.dart';
import 'package:favorite_places/screens/auth/guest_loading.dart';
import 'package:favorite_places/screens/auth/login.dart';
import 'package:favorite_places/screens/home_shell.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, this.home = const HomeShell()});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    ref.listen(authStateProvider, (previous, next) {
      final before = previous?.value?.uid;
      final after = next.value?.uid;
      if (before == after) return;
      if (after != null) {
        ref.read(userPlacesProvider.notifier).startListening();
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

        ref.read(userPlacesProvider.notifier).startListening();
        ref.read(userSettingsProvider.notifier).load();
        return home;
      },
    );
  }
}
