import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:favorite_places/services/agent_service.dart';

Map<String, dynamic> _response({
  List<Map<String, dynamic>> recommendations = const [],
  List<Map<String, dynamic>> legs = const [],
  List<Map<String, dynamic>> toolCalls = const [],
  String? clarifyingQuestion,
}) =>
    {
      'run_id': 'r1',
      'provider': 'anthropic',
      'model': 'm',
      'overview': recommendations.isEmpty ? '' : 'A slow morning.',
      'recommendations': recommendations,
      'legs': legs,
      'tool_calls': toolCalls,
      'confidence': 0.9,
      'clarifying_question': clarifyingQuestion,
    };

Map<String, dynamic> _rec(String id, int order) => {
      'place_id': id,
      'title': id,
      'category': 'cafe',
      'order': order,
      'reason': 'because',
      'suggested_time': '8:00 AM',
    };

AgentService _service(http.Response Function(http.Request) handler) => AgentService(
      client: MockClient((request) async => handler(request)),
      idToken: () async => 'token',
    );

void main() {
  group('PlanResult.fromJson', () {
    test('itinerary keeps stop order, legs and tool results', () {
      final result = PlanResult.fromJson(_response(
        recommendations: [_rec('b', 2), _rec('a', 1)],
        legs: [
          {'from_place_id': 'a', 'to_place_id': 'b', 'walk_minutes': 18},
        ],
        toolCalls: [
          {
            'name': 'search_places',
            'args': {'query': 'coffee'},
            'source': 'model',
            'result_place_ids': ['a', 'b'],
            'matched': 4,
          },
        ],
      ));

      expect(result.stops.map((s) => s.placeId), ['a', 'b']);
      expect(result.legs.single.walkMinutes, 18);
      expect(result.toolCalls.single.resultPlaceIds, ['a', 'b']);
      expect(result.toolCalls.single.matched, 4);
      expect(result.needsClarification, isFalse);
      expect(result.nothingFits, isFalse);
    });

    test('a leg too far to walk has no minutes', () {
      final result = PlanResult.fromJson(_response(
        recommendations: [_rec('a', 1), _rec('b', 2)],
        legs: [
          {'from_place_id': 'a', 'to_place_id': 'b', 'walk_minutes': null},
        ],
      ));

      expect(result.legs.single.walkMinutes, isNull);
    });

    test('options have no legs', () {
      final result = PlanResult.fromJson(_response(recommendations: [_rec('a', 1), _rec('b', 2)]));

      expect(result.legs, isEmpty);
    });

    test('escalated asks and has no stops', () {
      final result = PlanResult.fromJson(_response(clarifyingQuestion: 'Morning or evening?'));

      expect(result.needsClarification, isTrue);
      expect(result.nothingFits, isFalse);
      expect(result.stops, isEmpty);
    });

    test('nothing fits has no stops and no question', () {
      final result = PlanResult.fromJson(_response());

      expect(result.nothingFits, isTrue);
    });

    test('older responses without the new fields still parse', () {
      final json = _response(
        recommendations: [_rec('a', 1)],
        toolCalls: [
          {'name': 'search_places', 'args': {}, 'source': 'model'},
        ],
      )..remove('legs');

      final result = PlanResult.fromJson(json);

      expect(result.legs, isEmpty);
      expect(result.toolCalls.single.resultPlaceIds, isEmpty);
    });
  });

  group('clipping', () {
    test('clips by code point without splitting an emoji', () {
      final clipped = clipForAgent('😀' * 600);

      expect(clipped.runes.length, maxRequestChars);
      expect(clipped, '😀' * maxRequestChars);
    });

    test('a clarification clips every field', () {
      final json = Clarification(
        originalMessage: 'Somewhere nice.',
        question: 'q' * 600,
        answer: 'a' * 600,
      ).toJson();

      expect(json['question']!.length, maxRequestChars);
      expect(json['answer']!.length, maxRequestChars);
      expect(json['original_message'], 'Somewhere nice.');
    });
  });

  group('AgentService.recommend', () {
    test('sends a message with the bearer token and parses the result', () async {
      late http.Request sent;
      final service = _service((request) {
        sent = request;
        return http.Response(jsonEncode(_response(recommendations: [_rec('a', 1)])), 200);
      });

      final result = await service.recommend(message: 'coffee');

      expect(sent.url.path, '/recommend');
      expect(sent.headers['Authorization'], 'Bearer token');
      expect(jsonDecode(sent.body), {'message': 'coffee'});
      expect(result.stops.single.placeId, 'a');
    });

    test('sends a clarification as its own object', () async {
      late http.Request sent;
      final service = _service((request) {
        sent = request;
        return http.Response(jsonEncode(_response(recommendations: [_rec('a', 1)])), 200);
      });

      await service.recommend(
        clarification: const Clarification(
          originalMessage: 'Somewhere nice.',
          question: 'What kind of place?',
          answer: 'A view of the bay.',
        ),
      );

      expect(jsonDecode(sent.body), {
        'clarification': {
          'original_message': 'Somewhere nice.',
          'question': 'What kind of place?',
          'answer': 'A view of the bay.',
        },
      });
    });

    test('no signed-in user is an auth error before any request', () async {
      var called = false;
      final service = AgentService(
        client: MockClient((_) async {
          called = true;
          return http.Response('', 200);
        }),
        idToken: () async => null,
      );

      await expectLater(service.recommend(message: 'coffee'), throwsA(isA<AgentAuthException>()));
      expect(called, isFalse);
    });

    for (final (status, matcher) in [
      (401, isA<AgentAuthException>()),
      (422, isA<AgentBadRequestException>()),
      (500, isA<AgentUnavailableException>()),
    ]) {
      test('$status maps to its error', () async {
        final service = _service((_) => http.Response('', status));

        await expectLater(service.recommend(message: 'coffee'), throwsA(matcher));
      });
    }

    test('429 reads Retry-After into the message', () async {
      final service = _service((_) => http.Response('', 429, headers: {'retry-after': '1800'}));

      await expectLater(
        service.recommend(message: 'coffee'),
        throwsA(isA<AgentRateLimitException>()
            .having((e) => e.retryAfter, 'retryAfter', const Duration(minutes: 30))
            .having((e) => e.message, 'message', contains('30 min'))),
      );
    });

    test('a 200 whose body is not JSON is unavailable', () async {
      final service = _service((_) => http.Response('<html>proxy error</html>', 200));

      await expectLater(
        service.recommend(message: 'coffee'),
        throwsA(isA<AgentUnavailableException>()),
      );
    });

    test('a 200 with the wrong shape is unavailable', () async {
      final service = _service((_) => http.Response(jsonEncode(['not', 'an', 'object']), 200));

      await expectLater(
        service.recommend(message: 'coffee'),
        throwsA(isA<AgentUnavailableException>()),
      );
    });

    test('a network failure is unavailable', () async {
      final service = AgentService(
        client: MockClient((_) async => throw http.ClientException('offline')),
        idToken: () async => 'token',
      );

      await expectLater(
        service.recommend(message: 'coffee'),
        throwsA(isA<AgentUnavailableException>()),
      );
    });
  });
}
