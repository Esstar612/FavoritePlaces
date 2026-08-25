import 'package:flutter/material.dart';

/// Presents the app as a phone on wide screens.
///
/// This is a mobile UI. Stretched across a desktop window it reads as broken:
/// cards run the full width, the static map images crop to letterbox strips,
/// and the category chips truncate. Rather than build a second responsive
/// layout for a demo, the app is rendered at phone dimensions inside a device
/// frame and centred on the page.
///
/// Below [_breakpoint] — real phones, and a narrow browser window — the child
/// is returned untouched, so nothing changes on the platforms that matter.
class WebPhoneFrame extends StatelessWidget {
  const WebPhoneFrame({super.key, required this.child});

  final Widget child;

  /// Under this width there's no room for a frame, and none needed.
  static const double _breakpoint = 800;

  /// Roughly a modern handset: 9:19.5, capped so it doesn't dominate a large
  /// monitor.
  static const double _maxWidth = 412;
  static const double _maxHeight = 892;
  static const double _aspect = 19.5 / 9;
  static const double _cornerRadius = 44;
  static const double _bezel = 10;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    if (media.size.width < _breakpoint) return child;

    // Fit the tallest phone the window allows, then derive width from it.
    final available = media.size.height - 48;
    final height = available.clamp(480.0, _maxHeight);
    final width = (height / _aspect).clamp(320.0, _maxWidth);

    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      // A neutral backdrop so the frame reads as a device on a surface rather
      // than the app failing to fill the page.
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
              width: width,
              height: height,
              // The app must believe it is phone-sized, or it lays out against
              // the full window and the frame just crops it.
              child: MediaQuery(
                data: media.copyWith(
                  size: Size(width, height),
                  viewPadding: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  viewInsets: EdgeInsets.zero,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
