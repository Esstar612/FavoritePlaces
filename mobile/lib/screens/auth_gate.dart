import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/screens/auth/login.dart';
import 'package:favorite_places/screens/places.dart';

/// Root widget that watches the Firebase auth stream and:
///   • starts the Firestore places listener when a user signs in
///   • stops it and clears state when they sign out
///   • routes to LoginScreen or PlacesScreen accordingly
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // Side-effect: start/stop the Firestore stream when auth changes
    ref.listen(authStateProvider, (previous, next) {
      next.whenOrNull(data: (user) {
        if (user != null) {
          ref.read(userPlacesProvider.notifier).startListening();
        } else {
          ref.read(userPlacesProvider.notifier).stopListening();
        }
      });
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
        if (user == null) return const LoginScreen();

        // Ensure listener is running (handles cold-start where listen hasn't fired yet)
        ref.read(userPlacesProvider.notifier).startListening();
        return const PlacesScreen();
      },
    );
  }
}
