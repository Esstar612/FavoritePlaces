import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/providers/user_settings.dart';
import 'package:favorite_places/screens/auth/guest_loading.dart';
import 'package:favorite_places/screens/auth_gate.dart';

class _FakeUser extends Fake implements User {}

class _FakePlaces extends UserPlacesNotifier {
  @override
  void startListening() {}

  @override
  void stopListening() {}
}

class _FakeSettings extends UserSettingsNotifier {
  @override
  Future<String?> load() async => null;

  @override
  void reset() {}
}

const _home = Text('home');

Future<ProviderContainer> _pumpGate(WidgetTester tester, {required bool seeding}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_FakeUser())),
        guestSeedingProvider.overrideWith((ref) => seeding),
        userPlacesProvider.overrideWith((ref) => _FakePlaces()),
        userSettingsProvider.overrideWith((ref) => _FakeSettings()),
      ],
      child: const MaterialApp(home: AuthGate(home: _home)),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(AuthGate)));
}

void main() {
  testWidgets('the loading screen while seeding is true', (tester) async {
    await _pumpGate(tester, seeding: true);
    expect(find.byType(GuestLoadingScreen), findsOneWidget);
    expect(find.text('home'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('HomeShell once seeding goes false', (tester) async {
    final container = await _pumpGate(tester, seeding: true);
    container.read(guestSeedingProvider.notifier).state = false;
    await tester.pump();
    expect(find.byType(GuestLoadingScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('HomeShell when seeding is false and the account has no places', (tester) async {
    final container = await _pumpGate(tester, seeding: false);
    expect(container.read(userPlacesProvider), isEmpty);
    expect(find.byType(GuestLoadingScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
