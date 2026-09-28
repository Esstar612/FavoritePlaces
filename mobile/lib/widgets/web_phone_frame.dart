import 'package:flutter/material.dart';

class WebPhoneFrame extends StatelessWidget {
  const WebPhoneFrame({super.key, required this.child});

  final Widget child;

  static const double _breakpoint = 800;

  static const double _phoneWidth = 412;
  static const double _phoneHeight = 892;
  static const double _cornerRadius = 44;
  static const double _bezel = 10;

  static const _statusBar = EdgeInsets.only(top: 24);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    if (media.size.width < _breakpoint) return child;

    final scale = ((media.size.height - 48) / _phoneHeight).clamp(0.5, 1.0);

    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.06),
        scheme.brightness == Brightness.dark
            ? const Color(0xFF15121A)
            : const Color(0xFFECEAF0),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(_bezel),
          decoration: BoxDecoration(
            color: const Color(0xFF101014),
            borderRadius: BorderRadius.circular(_cornerRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 40,
                spreadRadius: 2,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_cornerRadius - _bezel),
            child: SizedBox(
              width: _phoneWidth * scale,
              height: _phoneHeight * scale,
              child: FittedBox(
                child: SizedBox(
                  width: _phoneWidth,
                  height: _phoneHeight,
                  child: MediaQuery(
                    data: media.copyWith(
                      size: const Size(_phoneWidth, _phoneHeight),
                      viewPadding: _statusBar,
                      padding: _statusBar,
                      viewInsets: EdgeInsets.zero,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
