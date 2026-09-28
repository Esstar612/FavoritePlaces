import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:favorite_places/config.dart';

const maxRequestChars = 500;
const startPlaceGoneDetail = 'start_place_id is not one of your places';

// Clips by code point, which is how the API counts its 500-character limit.
String clipForAgent(String text) => String.fromCharCodes(text.runes.take(maxRequestChars));

class Stop {
  const Stop({
    required this.placeId,
    required this.order,
    required this.reason,
    this.suggestedTime,
  });

  final String placeId;
  final int order;
  final String reason;
  final String? suggestedTime;

  factory Stop.fromJson(Map<String, dynamic> json) => Stop(
        placeId: json['place_id'] as String,
        order: json['order'] as int,
        reason: json['reason'] as String? ?? '',
        suggestedTime: json['suggested_time'] as String?,
      );
}

class Leg {
  const Leg({required this.fromPlaceId, required this.toPlaceId, this.walkMinutes});

  final String fromPlaceId;
  final String toPlaceId;
  final int? walkMinutes;

  factory Leg.fromJson(Map<String, dynamic> json) => Leg(
        fromPlaceId: json['from_place_id'] as String,
        toPlaceId: json['to_place_id'] as String,
        walkMinutes: json['walk_minutes'] as int?,
      );
}

class ToolCallInfo {
  const ToolCallInfo({
    required this.name,
    required this.args,
    required this.resultPlaceIds,
    this.matched,
  });

  final String name;
  final Map<String, dynamic> args;
  final List<String> resultPlaceIds;
  final int? matched;

  factory ToolCallInfo.fromJson(Map<String, dynamic> json) => ToolCallInfo(
        name: json['name'] as String,
        args: (json['args'] as Map?)?.cast<String, dynamic>() ?? const {},
        resultPlaceIds: ((json['result_place_ids'] as List?) ?? const []).cast<String>(),
        matched: json['matched'] as int?,
      );
}

class PlanResult {
  const PlanResult({
    required this.overview,
    required this.stops,
    required this.legs,
    required this.toolCalls,
    this.clarifyingQuestion,
  });

  final String overview;
  final List<Stop> stops;
  final List<Leg> legs;
  final List<ToolCallInfo> toolCalls;
  final String? clarifyingQuestion;

  bool get needsClarification => clarifyingQuestion != null;
  bool get nothingFits => !needsClarification && stops.isEmpty;

  factory PlanResult.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        ((json[key] as List?) ?? const [])
            .map((e) => parse(e as Map<String, dynamic>))
            .toList();
    return PlanResult(
      overview: json['overview'] as String? ?? '',
      stops: list('recommendations', Stop.fromJson)..sort((a, b) => a.order.compareTo(b.order)),
      legs: list('legs', Leg.fromJson),
      toolCalls: list('tool_calls', ToolCallInfo.fromJson),
      clarifyingQuestion: json['clarifying_question'] as String?,
    );
  }
}

class Clarification {
  const Clarification({
    required this.originalMessage,
    required this.question,
    required this.answer,
  });

  final String originalMessage;
  final String question;
  final String answer;

  Map<String, String> toJson() => {
        'original_message': clipForAgent(originalMessage),
        'question': clipForAgent(question),
        'answer': clipForAgent(answer),
      };
}

sealed class AgentException implements Exception {
  const AgentException(this.message);

  final String message;
}

class AgentAuthException extends AgentException {
  const AgentAuthException() : super('Your session expired. Sign in again to plan.');
}

class AgentBadRequestException extends AgentException {
  const AgentBadRequestException()
      : super("The planner couldn't read that request. Try a shorter one.");

  const AgentBadRequestException.startPlaceGone() : super('That place is no longer saved.');
}

class AgentRateLimitException extends AgentException {
  AgentRateLimitException(this.retryAfter)
      : super(retryAfter == null
            ? "You've planned a lot this hour. Try again later."
            : "You've planned a lot this hour. "
                'Try again in ${(retryAfter.inSeconds / 60).ceil()} min.');

  final Duration? retryAfter;
}

class AgentUnavailableException extends AgentException {
  const AgentUnavailableException() : super("The planner isn't reachable right now. Try again.");
}

abstract interface class PlanAgent {
  Future<PlanResult> recommend({
    String? message,
    Clarification? clarification,
    String? startPlaceId,
  });
}

class AgentService implements PlanAgent {
  AgentService({http.Client? client, Future<String?> Function()? idToken})
      : _client = client ?? http.Client(),
        _idToken = idToken ?? (() async => FirebaseAuth.instance.currentUser?.getIdToken());

  final http.Client _client;
  final Future<String?> Function() _idToken;

  @override
  Future<PlanResult> recommend({
    String? message,
    Clarification? clarification,
    String? startPlaceId,
  }) async {
    assert(message == null || clarification == null);
    assert(message != null || clarification != null || startPlaceId != null);
    final token = await _idToken();
    if (token == null) throw const AgentAuthException();

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${AppConfig.agentUrl}/recommend'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({
              if (message != null) 'message': clipForAgent(message),
              if (clarification != null) 'clarification': clarification.toJson(),
              'start_place_id': ?startPlaceId,
            }),
          )
          .timeout(const Duration(seconds: 120));
    } catch (_) {
      throw const AgentUnavailableException();
    }

    return switch (response.statusCode) {
      200 => _parse(response.body),
      401 => throw const AgentAuthException(),
      422 => throw _badRequest(response.body),
      429 => throw AgentRateLimitException(_retryAfter(response)),
      _ => throw const AgentUnavailableException(),
    };
  }

  PlanResult _parse(String body) {
    try {
      return PlanResult.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } on FormatException {
      throw const AgentUnavailableException();
    } on TypeError {
      throw const AgentUnavailableException();
    }
  }

  AgentBadRequestException _badRequest(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      return const AgentBadRequestException();
    }
    return json is Map && json['detail'] == startPlaceGoneDetail
        ? const AgentBadRequestException.startPlaceGone()
        : const AgentBadRequestException();
  }

  Duration? _retryAfter(http.Response response) {
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
