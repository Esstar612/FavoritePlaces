import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class GuestLoadingScreen extends StatefulWidget {
  const GuestLoadingScreen({super.key});

  @override
  State<GuestLoadingScreen> createState() => _GuestLoadingScreenState();
}

class _GuestLoadingScreenState extends State<GuestLoadingScreen> with SingleTickerProviderStateMixin {
  static const _samples = [('Blue Bottle Coffee', 'Cafe'), ('Golden Gate Park', 'Park'), ('SFMOMA', 'Museum')];

  late final _drop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  Timer? _ticker;
  var _ticked = 0;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _drop.value = 1;
      _ticked = _samples.length;
      return;
    }
    _drop.forward();
    _ticker = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      setState(() => _ticked++);
      if (_ticked >= _samples.length) timer.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;

    Widget row(Widget lead, String name, {String? category, bool done = true}) => SizedBox(
          height: 44,
          child: Row(
            children: [
              SizedBox.square(dimension: 24, child: Center(child: lead)),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: TextStyle(fontSize: 16, color: done ? null : muted))),
              if (category != null) Text(category, style: TextStyle(fontSize: 13, color: muted)),
            ],
          ),
        );
    final spinner = SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 3, color: scheme.surfaceContainerHighest),
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 96, 32, 40),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: max(0, constraints.maxHeight - 136)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      AnimatedBuilder(
                        animation: _drop,
                        builder: (context, _) => CustomPaint(
                          size: const Size(220, 150),
                          painter: _MapCardPainter(_drop.value, scheme.surfaceContainer),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Setting up your sample places',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '5 favorite spots around San Francisco, with notes and ratings to play with.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, height: 20 / 14, color: muted),
                      ),
                      const SizedBox(height: 28),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          backgroundColor: scheme.surfaceContainerHighest,
                          semanticsLabel: 'Loading sample places',
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (final (i, (name, category)) in _samples.indexed)
                        i < _ticked
                            ? row(
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: scheme.primary,
                                  child: Icon(Icons.check, size: 16, color: scheme.onPrimary),
                                ),
                                name,
                                category: category,
                              )
                            : row(spinner, name, done: false),
                      row(spinner, '2 more', done: false),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Text(
                      'You can create an account any time from your profile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 18 / 13, color: scheme.outline),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapCardPainter extends CustomPainter {
  _MapCardPainter(this.progress, this.card);

  final double progress;
  final Color card;

  static const _pins = [
    (Offset(150, 42), Color(0xFFF0B8C9), Color(0xFF492532)),
    (Offset(118, 74), Color(0xFFD3BBFF), Color(0xFF3E1A7A)),
    (Offset(44, 100), Color(0xFF9AD1A8), Color(0xFF1F4A2C)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28));
    canvas.clipRRect(bounds);
    canvas.drawRRect(bounds, Paint()..color = card);
    canvas.drawPath(
      Path()
        ..moveTo(150, 0)
        ..lineTo(220, 0)
        ..lineTo(220, 150)
        ..lineTo(180, 150)
        ..cubicTo(170, 110, 160, 70, 150, 0)
        ..close(),
      Paint()..color = const Color(0xFF253547),
    );
    final grid = Paint()
      ..color = const Color(0xFF35303D)
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(0, 50), const Offset(160, 50), grid);
    canvas.drawLine(const Offset(0, 100), const Offset(175, 100), grid);
    canvas.drawLine(const Offset(50, 0), const Offset(50, 150), grid);
    canvas.drawLine(const Offset(105, 0), const Offset(105, 150), grid);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(12, 108, 70, 18), const Radius.circular(4)),
      Paint()..color = const Color(0xFF2C4034),
    );

    for (final (i, (c, fill, dot)) in _pins.indexed) {
      final t = ((progress * 1.1 - i * 0.25) / 0.6).clamp(0.0, 1.0);
      if (t == 0) continue;
      final dy = t < 0.6 ? -14 + 16 * Curves.easeOut.transform(t / 0.6) : 2 - 2 * ((t - 0.6) / 0.4);
      final opacity = (t / 0.6).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(0, dy);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 12)
          ..cubicTo(c.dx - 7, c.dy - 12, c.dx - 12, c.dy - 7, c.dx - 12, c.dy)
          ..cubicTo(c.dx - 12, c.dy + 9, c.dx, c.dy + 21, c.dx, c.dy + 21)
          ..cubicTo(c.dx, c.dy + 21, c.dx + 12, c.dy + 9, c.dx + 12, c.dy)
          ..cubicTo(c.dx + 12, c.dy - 7, c.dx + 7, c.dy - 12, c.dx, c.dy - 12)
          ..close(),
        Paint()..color = fill.withValues(alpha: opacity),
      );
      canvas.drawCircle(c, 4, Paint()..color = dot.withValues(alpha: opacity));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MapCardPainter old) => old.progress != progress || old.card != card;
}
