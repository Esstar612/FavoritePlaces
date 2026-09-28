import 'dart:math';

import 'package:flutter/material.dart';

class WelcomeHeader extends StatefulWidget {
  const WelcomeHeader({super.key});

  static const height = 404.0;

  @override
  State<WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<WelcomeHeader> with SingleTickerProviderStateMixin {
  late final _bob = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _bob.stop();
    } else if (!_bob.isAnimating) {
      _bob.repeat();
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: SizedBox(
        height: WelcomeHeader.height,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapPainter(scheme.primary, scheme.onPrimary))),
            Positioned(
              left: 24,
              top: 24,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.place, size: 22, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 10),
                  const Text('Favorite Places', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            _Bobbing(
              animation: _bob,
              phase: 0,
              left: 28,
              top: 92,
              angle: -4,
              child: const _PlaceCard(),
            ),
            _Bobbing(
              animation: _bob,
              phase: 0.5,
              right: 24,
              top: 268,
              angle: 3,
              child: const _PlanCard(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bobbing extends StatelessWidget {
  const _Bobbing({
    required this.animation,
    required this.phase,
    required this.top,
    required this.angle,
    required this.child,
    this.left,
    this.right,
  });

  final Animation<double> animation;
  final double phase;
  final double top;
  final double? left;
  final double? right;
  final double angle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -2 - 2 * cos(2 * pi * (animation.value + phase))),
            child: child,
          ),
          child: Transform.rotate(angle: angle * pi / 180, child: child),
        ),
      ),
    );
  }
}

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _FloatingCard(
      width: 196 + 24,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: const Color(0xFF4A3040), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.local_cafe, size: 22, color: Color(0xFFFFD9E3)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Blue Bottle Coffee',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: Color(0xFFF9C74F)),
                    const SizedBox(width: 3),
                    Text('5 · Cafe', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.favorite, size: 18, color: scheme.error),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget stop(String number, String time, String what) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 9,
                backgroundColor: scheme.primary,
                child: Text(
                  number,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: scheme.onPrimary),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: Text(time, softWrap: false, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(what, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
            ],
          ),
        );
    return _FloatingCard(
      width: 212 + 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: scheme.tertiary),
              const SizedBox(width: 6),
              Text(
                'Your Saturday',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: scheme.primary),
              ),
            ],
          ),
          stop('1', '8:00 AM', 'Coffee by the bay'),
          stop('2', '10:00 AM', 'One floor of art'),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.route, this.onRoute);

  final Color route;
  final Color onRoute;

  static const _ground = Color(0xFF231F29);
  static const _grid = Color(0xFF2E2A35);
  static const _water = Color(0xFF1E2C3B);
  static const _park = Color(0xFF243A2C);
  static const _road = Color(0xFF35303D);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 412, size.height / 404);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 412, 404), Paint()..color = _ground);
    final grid = Paint()
      ..color = _grid
      ..strokeWidth = 2;
    for (double x = 0; x <= 412; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, 404), grid);
    }
    for (double y = 0; y <= 404; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(412, y), grid);
    }
    final water = Path()
      ..moveTo(300, 0)
      ..lineTo(412, 0)
      ..lineTo(412, 404)
      ..lineTo(360, 404)
      ..cubicTo(340, 330, 318, 260, 322, 190)
      ..cubicTo(326, 120, 312, 60, 300, 0)
      ..close();
    canvas.drawPath(water, Paint()..color = _water);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(30, 250, 120, 34), const Radius.circular(8)),
      Paint()..color = _park,
    );
    canvas.drawLine(
      const Offset(300, 170),
      const Offset(40, 404),
      Paint()
        ..color = _road
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    final path = Path()
      ..moveTo(300, 150)
      ..cubicTo(260, 200, 230, 196, 206, 232)
      ..cubicTo(182, 268, 130, 262, 92, 270);
    final dash = Paint()
      ..color = route
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 13) {
        canvas.drawPath(metric.extractPath(d, min(d + 7, metric.length)), dash);
      }
    }

    for (final (i, point) in const [Offset(300, 150), Offset(206, 232), Offset(92, 270)].indexed) {
      canvas.drawCircle(point, 17.5, Paint()..color = _ground);
      canvas.drawCircle(point, 16, Paint()..color = route);
      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onRoute),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, point - Offset(label.width / 2, label.height / 2));
    }

    _sparkle(canvas, const Offset(360, 70), 10, const Color(0xFFF0B8C9));
    _sparkle(canvas, const Offset(44, 337), 7, const Color(0xFFF9C74F));
  }

  void _sparkle(Canvas canvas, Offset center, double r, Color color) {
    final inner = r * 0.3;
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + inner, center.dy - inner)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx + inner, center.dy + inner)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - inner, center.dy + inner)
      ..lineTo(center.dx - r, center.dy)
      ..lineTo(center.dx - inner, center.dy - inner)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => oldDelegate.route != route || oldDelegate.onRoute != onRoute;
}
