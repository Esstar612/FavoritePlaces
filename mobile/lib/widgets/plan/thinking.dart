import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/providers/plan.dart';
import 'package:favorite_places/widgets/plan/common.dart';

class PlanThinkingView extends ConsumerStatefulWidget {
  const PlanThinkingView({super.key, required this.request});

  final PlanRequest request;

  @override
  ConsumerState<PlanThinkingView> createState() => _PlanThinkingViewState();
}

class _PlanThinkingViewState extends ConsumerState<PlanThinkingView> {
  static const _steps = [
    ('Searching your places', 'Looking for places that fit'),
    ('Reading details', 'Checking your notes'),
    ('Planning a route', 'Order, times and travel between stops'),
  ];

  late final Timer _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    // The API returns everything at once, so the steps advance on a timer and hold on the last.
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_step < _steps.length - 1) setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        PlanYouAsked(request: widget.request, editable: false),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Putting your outing together',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text('Usually a few seconds.', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    for (final (i, (title, detail)) in _steps.indexed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: i < _step
                            ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                            : i == _step
                                ? const SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(strokeWidth: 3),
                                  )
                                : const Icon(Icons.radio_button_unchecked),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(detail),
                      ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton(
                    onPressed: ref.read(planProvider.notifier).reset,
                    child: const Text('Stop'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
