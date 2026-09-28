import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/services/agent_service.dart';

const skipAnswer = 'Surprise me';

class PlanRequest {
  const PlanRequest({this.message, this.clarification, this.startPlaceId});

  final String? message;
  final Clarification? clarification;
  final String? startPlaceId;

  String? get askedText => clarification?.originalMessage ?? message;
}

sealed class PlanState {
  const PlanState();
}

class PlanIdle extends PlanState {
  const PlanIdle({this.startPlaceId, this.draft = ''});

  final String? startPlaceId;
  final String draft;
}

class PlanThinking extends PlanState {
  const PlanThinking(this.request);

  final PlanRequest request;
}

class PlanAsking extends PlanState {
  const PlanAsking(this.request, this.question);

  final PlanRequest request;
  final String question;
}

class PlanResults extends PlanState {
  const PlanResults(this.request, this.result);

  final PlanRequest request;
  final PlanResult result;
}

class PlanNothingFits extends PlanState {
  const PlanNothingFits(this.request, this.result);

  final PlanRequest request;
  final PlanResult result;
}

class PlanError extends PlanState {
  const PlanError(this.request, this.message);

  final PlanRequest request;
  final String message;
}

class PlanNotifier extends StateNotifier<PlanState> {
  PlanNotifier(this._agent) : super(const PlanIdle());

  final PlanAgent _agent;
  int _generation = 0;

  void compose(String draft, {String? startPlaceId}) {
    _generation++;
    state = PlanIdle(startPlaceId: startPlaceId, draft: clipForAgent(draft.trim()));
  }

  void startFrom(String? placeId) => compose('', startPlaceId: placeId);

  void reset() => startFrom(null);

  void edit() {
    final request = _request;
    _generation++;
    state = PlanIdle(startPlaceId: request?.startPlaceId, draft: request?.askedText ?? '');
  }

  Future<void> submit(String text) {
    final message = clipForAgent(text.trim());
    final current = state;
    final startPlaceId = current is PlanIdle ? current.startPlaceId : null;
    if (message.isEmpty && startPlaceId == null) return Future.value();
    return _run(PlanRequest(message: message.isEmpty ? null : message, startPlaceId: startPlaceId));
  }

  Future<void> answer(String text) {
    final current = state;
    if (current is! PlanAsking) return Future.value();
    final reply = text.trim();
    return _run(PlanRequest(
      clarification: Clarification(
        originalMessage: current.request.message!,
        question: current.question,
        answer: reply.isEmpty ? skipAnswer : reply,
      ),
      startPlaceId: current.request.startPlaceId,
    ));
  }

  Future<void> retry() {
    final request = _request;
    return request == null ? Future.value() : _run(request);
  }

  PlanRequest? get _request => switch (state) {
        PlanIdle() => null,
        PlanThinking(:final request) ||
        PlanAsking(:final request) ||
        PlanResults(:final request) ||
        PlanNothingFits(:final request) ||
        PlanError(:final request) =>
          request,
      };

  Future<void> _run(PlanRequest request) async {
    final generation = ++_generation;
    state = PlanThinking(request);
    try {
      final result = await _agent.recommend(
        message: request.message,
        clarification: request.clarification,
        startPlaceId: request.startPlaceId,
      );
      if (generation != _generation) return;
      if (result.needsClarification && request.clarification == null) {
        state = PlanAsking(request, result.clarifyingQuestion!);
      } else if (result.stops.isEmpty) {
        state = PlanNothingFits(request, result);
      } else {
        state = PlanResults(request, result);
      }
    } on AgentException catch (e) {
      if (generation == _generation) state = PlanError(request, e.message);
    }
  }
}

List<String> quickAnswers(List<Place> places, {int limit = 5}) {
  final counts = <String, int>{};
  for (final place in places) {
    counts.update(place.category.displayName, (n) => n + 1, ifAbsent: () => 1);
    for (final tag in place.tags) {
      counts.update(tag, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  final firstSeen = counts.keys.toList();
  final ranked = [...firstSeen]..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : firstSeen.indexOf(a).compareTo(firstSeen.indexOf(b));
    });
  return ranked.take(limit).toList();
}

final planAgentProvider = Provider<PlanAgent>((ref) => AgentService());

final planProvider = StateNotifierProvider<PlanNotifier, PlanState>(
  (ref) => PlanNotifier(ref.watch(planAgentProvider)),
);
