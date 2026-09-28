import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/plan.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/services/agent_service.dart';
import 'package:favorite_places/widgets/plan/common.dart';

class PlanAskingView extends ConsumerStatefulWidget {
  const PlanAskingView({super.key, required this.state});

  final PlanAsking state;

  @override
  ConsumerState<PlanAskingView> createState() => _PlanAskingViewState();
}

class _PlanAskingViewState extends ConsumerState<PlanAskingView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(planProvider.notifier);
    final answers = quickAnswers(ref.watch(userPlacesProvider));

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
        PlanYouAsked(request: widget.state.request),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      'One quick question',
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(widget.state.question, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(
                  "Your places could fit this a few ways, so I'd rather ask than guess.",
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final answer in answers)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface,
                          side: BorderSide(color: theme.colorScheme.outline),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                          minimumSize: const Size(0, 36),
                        ),
                        icon: Icon(_answerIcon(answer), size: 18, color: theme.colorScheme.primary),
                        label: Text(answer, style: const TextStyle(fontWeight: FontWeight.w500)),
                        onPressed: () => notifier.answer(answer),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  maxLength: maxRequestChars,
                  decoration: InputDecoration(
                    hintText: 'Or say it your way',
                    counterText: '',
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    contentPadding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton.filled(
                        icon: Icon(Icons.arrow_upward, size: 20, color: theme.colorScheme.onPrimary),
                        tooltip: 'Send answer',
                        onPressed: () => notifier.answer(_controller.text),
                      ),
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: notifier.answer,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Just this one question, then straight to your plan.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: TextButton(
                    onPressed: () => notifier.answer(skipAnswer),
                    child: const Text('Skip and surprise me'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _answerIcon(String answer) {
  for (final category in PlaceCategory.values) {
    if (category.displayName == answer) return categoryIcon(category);
  }
  final text = answer.toLowerCase();
  for (final (word, icon) in _tagIcons) {
    if (text.contains(word)) return icon;
  }
  return Icons.sell_outlined;
}

const _tagIcons = [
  ('view', Icons.landscape),
  ('gem', Icons.diamond_outlined),
  ('must', Icons.star),
  ('quiet', Icons.self_improvement),
  ('calm', Icons.self_improvement),
  ('family', Icons.family_restroom),
  ('food', Icons.restaurant),
  ('coffee', Icons.local_cafe),
  ('instagram', Icons.photo_camera),
];
