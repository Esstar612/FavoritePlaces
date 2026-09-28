import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:favorite_places/services/demo_service.dart';

void main() {
  test('a seed request that never answers times out and returns false', () async {
    final seeded = await DemoService.seed(
      client: MockClient((request) => Completer<http.Response>().future),
      idToken: () async => 'token',
      timeout: const Duration(milliseconds: 50),
    );
    expect(seeded, isFalse);
  });

  test('no token returns false without calling the backend', () async {
    var called = false;
    final seeded = await DemoService.seed(
      client: MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      }),
      idToken: () async => null,
    );
    expect(seeded, isFalse);
    expect(called, isFalse);
  });

  test('a 200 from the backend returns true', () async {
    final seeded = await DemoService.seed(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response('{}', 200);
      }),
      idToken: () async => 'token',
    );
    expect(seeded, isTrue);
  });
}
