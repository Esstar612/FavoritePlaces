import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/screens/profile.dart';

class _FakeUser extends Fake implements User {
  _FakeUser({required this.isAnonymous, this.email});

  @override
  final bool isAnonymous;

  @override
  final String? email;

  @override
  String get uid => 'same-uid';

  @override
  String? get displayName => email == null ? null : 'Alex';
}

class _FakePlaces extends UserPlacesNotifier {
  @override
  void startListening() {}

  @override
  void stopListening() {}
}

void main() {
  testWidgets('a linked guest leaves guest mode on the same uid', (tester) async {
    final users = StreamController<User?>();
    addTearDown(users.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => users.stream),
          userPlacesProvider.overrideWith((ref) => _FakePlaces()),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    users.add(_FakeUser(isAnonymous: true));
    await tester.pump();
    expect(find.text('Create account'), findsOneWidget);

    users.add(_FakeUser(isAnonymous: false, email: 'alex@example.com'));
    await tester.pump();
    expect(find.text('Create account'), findsNothing);
    expect(find.text('alex@example.com'), findsOneWidget);
  });
}
