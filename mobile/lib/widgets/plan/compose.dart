import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/plan.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/services/agent_service.dart';
import 'package:favorite_places/widgets/plan/common.dart';

const _afterIdeas = [
  (Icons.directions_walk, 'Something within walking distance'),
  (Icons.museum, 'Add some art'),
  (Icons.restaurant, 'End with lunch'),
  (Icons.park, 'A calm afternoon'),
];

class PlanCompose extends ConsumerStatefulWidget {
  const PlanCompose({super.key, required this.state});

  final PlanIdle state;

  @override
  ConsumerState<PlanCompose> createState() => _PlanComposeState();
}

class _PlanComposeState extends ConsumerState<PlanCompose> {
  late final _controller = TextEditingController(text: widget.state.draft);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? text]) {
    if (text != null) _controller.text = text;
    ref.read(planProvider.notifier).submit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startId = widget.state.startPlaceId;
    final places = ref.watch(userPlacesProvider);
    final start = startId == null ? null : places.where((p) => p.id == startId).firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (start != null)
                  _StartCard(
                    place: start,
                    onRemove: () => ref.read(planProvider.notifier).startFrom(null),
                  )
                else
                  Row(
                    children: [
                      const _RouteBadge(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Where to today?',
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Describe a mood, a time or who's coming. "
                              "I'll pick from your places and put them in order.",
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                _InputCard(
                  controller: _controller,
                  hint: start == null ? 'What are you in the mood for?' : 'What happens after?',
                  helper: start == null
                      ? 'A time, a vibe, a neighborhood'
                      : 'Optional. I can plan from here on my own.',
                  sendWhenEmpty: start != null,
                  onSend: _submit,
                ),
                const SizedBox(height: 20),
                Text(
                  start == null ? 'Or try one' : 'Ideas for after',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                PlanIdeaChips(
                    ideas: start == null ? planExamples : _afterIdeas, onSelected: _submit),
              ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _OnlyYourPlaces(places: places),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteBadge extends StatelessWidget {
  const _RouteBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: const Size.square(72),
      painter: _RoutePainter(
        background: scheme.surfaceContainerHighest,
        line: scheme.outline,
        stops: [scheme.tertiary, scheme.primary, const Color(0xFFF9C74F)],
        labels: [scheme.onTertiary, scheme.onPrimary, const Color(0xFF4A3500)],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.background,
    required this.line,
    required this.stops,
    required this.labels,
  });

  final Color background;
  final Color line;
  final List<Color> stops;
  final List<Color> labels;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 72;
    canvas.drawCircle(Offset(36 * s, 36 * s), 36 * s, Paint()..color = background);
    final points = [Offset(18 * s, 50 * s), Offset(38 * s, 30 * s), Offset(54 * s, 18 * s)];
    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..quadraticBezierTo(28 * s, 30 * s, points[1].dx, points[1].dy)
      ..quadraticBezierTo(48 * s, 26 * s, points[2].dx, points[2].dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s,
    );
    for (final (i, point) in points.indexed) {
      canvas.drawCircle(point, 7 * s, Paint()..color = stops[i]);
      final number = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(color: labels[i], fontSize: 9 * s, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      number.paint(canvas, point - Offset(number.width / 2, number.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.background != background ||
      old.line != line ||
      old.stops != stops ||
      old.labels != labels;
}

class _OnlyYourPlaces extends StatelessWidget {
  const _OnlyYourPlaces({required this.places});

  final List<Place> places;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categories = places.map((p) => p.category).toSet().take(3).toList();
    final more = places.length - categories.length;
    final bubbles = <Widget>[
      for (final category in categories)
        Icon(categoryIcon(category), size: 16, color: scheme.onSecondaryContainer),
      if (more > 0) Text('+$more', style: theme.textTheme.labelSmall),
    ];
    const size = 32.0;
    const step = 22.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (bubbles.isNotEmpty) ...[
            SizedBox(
            width: size + step * (bubbles.length - 1),
            height: size,
            child: Stack(
              children: [
                for (final (i, child) in bubbles.indexed)
                  Positioned(
                    left: step * i,
                    child: Container(
                      width: size,
                      height: size,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surfaceContainer, width: 2),
                      ),
                      child: child,
                    ),
                  ),
              ],
            ),
          ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              "I only suggest places you've saved, so every stop is one you already love.",
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.place, required this.onRemove});

  final Place place;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Starting from', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.primary),
          ),
          child: ListTile(
            leading: CircleAvatar(child: Icon(categoryIcon(place.category))),
            title: Text(place.title),
            subtitle: Text(
              '${place.category.displayName} · ${place.location.address}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove starting point',
              onPressed: onRemove,
            ),
          ),
        ),
      ],
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.controller,
    required this.hint,
    required this.helper,
    required this.sendWhenEmpty,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final String helper;
  final bool sendWhenEmpty;
  final VoidCallback onSend;

  bool get _canSend => sendWhenEmpty || controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            maxLength: maxRequestChars,
            style: const TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w400),
            decoration: InputDecoration.collapsed(hintText: hint).copyWith(counterText: ''),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) {
              if (_canSend) onSend();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(helper, style: theme.textTheme.bodySmall)),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => FilledButton.icon(
                  onPressed: _canSend ? onSend : null,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Plan it'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
