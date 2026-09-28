import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/services/agent_service.dart';

class PlanTrace extends ConsumerStatefulWidget {
  const PlanTrace({super.key, required this.calls});

  final List<ToolCallInfo> calls;

  @override
  ConsumerState<PlanTrace> createState() => _PlanTraceState();
}

class _PlanTraceState extends ConsumerState<PlanTrace> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titles = {for (final p in ref.watch(userPlacesProvider)) p.id: p.title};
    final calls = widget.calls;
    final read = {
      for (final call in calls)
        if (call.name == 'get_place_details') ...call.resultPlaceIds,
    }.length;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _open ? scheme.surfaceContainer : null,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _open ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                    child: Icon(Icons.code, size: 20, color: _open ? scheme.onPrimaryContainer : scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How I got this',
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${calls.length} ${calls.length == 1 ? 'step' : 'steps'} · '
                          'read $read of your places',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            ),
          ),
          if (_open) ...[
            Divider(height: 1, indent: 16, endIndent: 16, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Every tool call, in order. I can only read your saved places; '
                    'nothing here came from the wider web.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  for (final (i, call) in calls.indexed)
                    _Step(number: i + 1, call: call, titles: titles, last: i == calls.length - 1),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.call, required this.titles, required this.last});

  final int number;
  final ToolCallInfo call;
  final Map<String, String> titles;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Text(
                    '$number',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 18 / 13),
                        children: [
                          TextSpan(
                            text: call.name,
                            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w500),
                          ),
                          const TextSpan(text: '('),
                          TextSpan(text: _args(call, titles), style: TextStyle(color: scheme.tertiary)),
                          const TextSpan(text: ')'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _result(call, titles),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _args(ToolCallInfo call, Map<String, String> titles) {
  final parts = <String>[];
  for (final MapEntry(:key, :value) in call.args.entries) {
    if (key == 'limit' || value == null || value == false) continue;
    parts.add(switch ((key, value)) {
      ('place_ids', final List ids) => ids.map((id) => titles[id] ?? id).join(', '),
      ('query', final String query) => '"$query"',
      (_, final List items) => '$key: ${items.join(', ')}',
      (_, true) => key,
      _ => '$key: $value',
    });
  }
  return parts.join(', ');
}

String _result(ToolCallInfo call, Map<String, String> titles) {
  final names = [for (final id in call.resultPlaceIds) titles[id] ?? id];
  switch (call.name) {
    case 'search_places':
      final matched = call.matched ?? names.length;
      if (matched == 0) return 'No matches';
      final shown = names.take(3).join(', ');
      final more = names.length > 3 ? ' and ${names.length - 3} more' : '';
      return '$matched ${matched == 1 ? 'match' : 'matches'}: $shown$more';
    case 'get_place_details':
      return names.isEmpty ? 'Nothing to read' : 'Read your notes on ${names.join(', ')}';
    case 'plan_route':
      return names.isEmpty ? 'No route' : 'Put ${names.length} stops in order';
    default:
      return names.join(', ');
  }
}
