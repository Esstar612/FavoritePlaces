import 'package:flutter_test/flutter_test.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/plan.dart';
import 'package:favorite_places/services/agent_service.dart';

typedef Call = ({String? message, Clarification? clarification, String? startPlaceId});

class FakeAgent implements PlanAgent {
  FakeAgent(this.responses);

  final List<Object> responses;
  final calls = <Call>[];

  @override
  Future<PlanResult> recommend({
    String? message,
    Clarification? clarification,
    String? startPlaceId,
  }) async {
    calls.add((message: message, clarification: clarification, startPlaceId: startPlaceId));
    final next = responses.removeAt(0);
    if (next is AgentException) throw next;
    return next as PlanResult;
  }
}

PlanResult _result({List<String> stops = const [], String? question}) => PlanResult(
      overview: stops.isEmpty ? '' : 'A plan.',
      stops: [
        for (final (i, id) in stops.indexed) Stop(placeId: id, order: i + 1, reason: 'r'),
      ],
      legs: const [],
      toolCalls: const [],
      clarifyingQuestion: question,
    );

void main() {
  test('a request goes from idle to thinking to results', () async {
    final agent = FakeAgent([_result(stops: ['a'])]);
    final notifier = PlanNotifier(agent);
    expect(notifier.state, isA<PlanIdle>());

    final pending = notifier.submit('  coffee  ');
    expect(notifier.state, isA<PlanThinking>());
    await pending;

    expect(notifier.state, isA<PlanResults>());
    expect(agent.calls.single.message, 'coffee');
  });

  test('an empty request with no start place sends nothing', () async {
    final agent = FakeAgent([]);
    final notifier = PlanNotifier(agent);

    await notifier.submit('   ');

    expect(agent.calls, isEmpty);
    expect(notifier.state, isA<PlanIdle>());
  });

  test('a question is answered once, as a clarification, then results', () async {
    final agent = FakeAgent([
      _result(question: 'What kind of place?'),
      _result(stops: ['a']),
    ]);
    final notifier = PlanNotifier(agent);

    await notifier.submit('Somewhere nice.');
    expect(notifier.state, isA<PlanAsking>());
    await notifier.answer('A view of the bay.');

    expect(notifier.state, isA<PlanResults>());
    final reply = agent.calls.last;
    expect(reply.message, isNull);
    expect(reply.clarification!.originalMessage, 'Somewhere nice.');
    expect(reply.clarification!.question, 'What kind of place?');
    expect(reply.clarification!.answer, 'A view of the bay.');
    expect((notifier.state as PlanResults).request.askedText, 'Somewhere nice.');
  });

  test('a second question after a clarification is never asked', () async {
    final agent = FakeAgent([
      _result(question: 'What kind of place?'),
      _result(question: 'And when?'),
    ]);
    final notifier = PlanNotifier(agent);

    await notifier.submit('Somewhere nice.');
    await notifier.answer('');

    expect(notifier.state, isA<PlanNothingFits>());
    expect(agent.calls.last.clarification!.answer, skipAnswer);
  });

  test('answer does nothing unless a question is showing', () async {
    final agent = FakeAgent([]);
    final notifier = PlanNotifier(agent);

    await notifier.answer('hello');

    expect(agent.calls, isEmpty);
  });

  test('nothing fits', () async {
    final notifier = PlanNotifier(FakeAgent([_result()]));

    await notifier.submit('late-night karaoke');

    expect(notifier.state, isA<PlanNothingFits>());
  });

  test('a start place is sent alone, and again with the clarification reply', () async {
    final agent = FakeAgent([
      _result(stops: ['p1', 'b']),
      _result(question: 'What kind of place?'),
      _result(stops: ['p1', 'c']),
    ]);
    final notifier = PlanNotifier(agent);

    notifier.startFrom('p1');
    await notifier.submit('');
    expect(agent.calls[0], (message: null, clarification: null, startPlaceId: 'p1'));

    notifier.startFrom('p1');
    await notifier.submit('somewhere nice');
    await notifier.answer('a park');
    expect(agent.calls[2].startPlaceId, 'p1');
    expect(agent.calls[2].clarification!.originalMessage, 'somewhere nice');
  });

  for (final (label, error) in [
    ('401', const AgentAuthException()),
    ('422', const AgentBadRequestException()),
    ('422 for a gone start place', const AgentBadRequestException.startPlaceGone()),
    ('429', AgentRateLimitException(const Duration(minutes: 30))),
  ]) {
    test('$label shows its message', () async {
      final notifier = PlanNotifier(FakeAgent([error]));

      await notifier.submit('coffee');

      expect(notifier.state, isA<PlanError>());
      expect((notifier.state as PlanError).message, error.message);
    });
  }

  test('retry resends the same request', () async {
    final agent = FakeAgent([const AgentUnavailableException(), _result(stops: ['a'])]);
    final notifier = PlanNotifier(agent);

    await notifier.submit('coffee');
    await notifier.retry();

    expect(notifier.state, isA<PlanResults>());
    expect(agent.calls.map((c) => c.message), ['coffee', 'coffee']);
  });

  test('a response that arrives after stop is dropped', () async {
    final notifier = PlanNotifier(FakeAgent([_result(stops: ['a'])]));

    final pending = notifier.submit('coffee');
    notifier.reset();
    await pending;

    expect(notifier.state, isA<PlanIdle>());
  });

  test('edit returns to idle with the original request and start place', () async {
    final notifier = PlanNotifier(FakeAgent([_result(stops: ['a'])]));
    notifier.startFrom('p1');

    await notifier.submit('coffee');
    notifier.edit();

    final idle = notifier.state as PlanIdle;
    expect(idle.draft, 'coffee');
    expect(idle.startPlaceId, 'p1');
  });

  test('quick answers are the most common categories and tags', () {
    Place place(PlaceCategory category, List<String> tags) =>
        Place(title: 't', category: category, tags: tags, location: const PlaceLocation(latitude: 0, longitude: 0, address: ''));

    final answers = quickAnswers([
      place(PlaceCategory.cafe, ['Quiet']),
      place(PlaceCategory.cafe, ['Quiet', 'Great Views']),
      place(PlaceCategory.park, []),
    ], limit: 2);

    expect(answers, ['Cafe', 'Quiet']);
  });
}
