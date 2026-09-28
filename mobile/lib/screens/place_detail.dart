import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/screens/add_place.dart';
import 'package:favorite_places/screens/home_shell.dart';
import 'package:favorite_places/screens/map.dart';
import 'package:favorite_places/services/ai_service.dart';
import 'package:favorite_places/utils/static_map.dart';
import 'package:favorite_places/widgets/place_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── date helper (no intl dep) ────────────────────────────────────────────────
const List<String> _months = [
  'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec',
];
String _formatDate(DateTime d) => '${_months[d.month-1]} ${d.day}, ${d.year}';

class PlaceDetailScreen extends ConsumerStatefulWidget {
  const PlaceDetailScreen({super.key, required this.place});
  final Place place;   // the version that was tapped — may go stale

  @override
  ConsumerState<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends ConsumerState<PlaceDetailScreen> {
  // ── AI summary state ─────────────────────────────────────────────────────
  // Freshly generated this session. A summary cached on the place itself takes
  // precedence, so revisiting never re-bills a model call.
  PlaceSummary? _summary;
  bool          _loadingSummary = false;
  String?       _summaryError;

  /// The summary to show: whatever we just generated, else the stored one —
  /// but only while it still matches the current notes.
  PlaceSummary? _effectiveSummary(Place p) {
    if (_summary != null) return _summary;
    final cached = p.summary;
    if (cached != null && cached.matches(p.notes)) return cached;
    return null;
  }

  Future<void> _generateSummary(Place p) async {
    setState(() => _summaryError = null);
    if (p.notes.trim().isEmpty) {
      setState(() => _summaryError = 'Add some notes first to generate a summary.');
      return;
    }
    setState(() { _loadingSummary = true; });
    try {
      final s = await AIService().summarizeNotes(
        title:    p.title,
        notes:    p.notes,
        category: p.category.name,
        address:  p.location.address,
      );
      final summary = PlaceSummary(
        whyILikedIt:  s.whyILikedIt,
        tips:         s.tips,
        bestTimeToGo: s.bestTimeToGo,
        sourceNotes:  p.notes,
      );
      if (!mounted) return;
      setState(() { _summary = summary; _loadingSummary = false; });

      // Cache it. A failure here only costs a regeneration later.
      try {
        await ref.read(userPlacesProvider.notifier).saveSummary(p.id, summary);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingSummary = false; _summaryError = "Couldn't reach the AI right now."; });
    }
  }

  Future<void> _toggleFavorite(String placeId) async {
    try {
      await ref.read(userPlacesProvider.notifier).toggleFavorite(placeId);
    } catch (e) {
      // The provider updates state optimistically, so a write failure would
      // otherwise leave the heart showing a value that never reached Firestore.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update favorite. Try again.")),
        );
      }
    }
  }

  final _scroll = ScrollController();
  bool _collapsed = false;

  static const _heroHeight = 300.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final collapsed = _scroll.offset > _heroHeight - kToolbarHeight - 28;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _edit(Place p) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AddPlaceScreen(placeToEdit: p)),
      );

  void _openMap(Place p) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MapScreen(location: p.location, isSelecting: false)),
      );

  Future<void> _delete(Place p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete place'),
        content: Text('Delete "${p.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(userPlacesProvider.notifier).deletePlace(p.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider so the UI stays in sync (e.g. favorite toggle)
    final places  = ref.watch(userPlacesProvider);
    final current = places.firstWhere((p) => p.id == widget.place.id, orElse: () => widget.place);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 14, color: scheme.onSurfaceVariant);

    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            expandedHeight: _heroHeight,
            pinned: true,
            backgroundColor: scheme.surfaceContainer,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _RoundButton(
                tooltip: 'Back',
                icon: Icons.arrow_back,
                filled: !_collapsed,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            leadingWidth: 64,
            title: AnimatedOpacity(
              opacity: _collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Text(current.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
            ),
            actions: [
              _RoundButton(
                tooltip: current.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                icon: current.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: current.isFavorite ? scheme.error : null,
                filled: !_collapsed,
                onPressed: () => _toggleFavorite(current.id),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'More options',
                position: PopupMenuPosition.under,
                onSelected: (value) => value == 'edit' ? _edit(current) : _delete(current),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit place')),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: scheme.error),
                      title: Text('Delete place', style: TextStyle(color: scheme.error)),
                    ),
                  ),
                ],
                child: IgnorePointer(
                  child: _RoundButton(icon: Icons.more_vert, filled: !_collapsed, onPressed: _noop),
                ),
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _heroImage(current),
                  if (!current.hasPhoto)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 44,
                      child: Center(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.surface.withValues(alpha: 0.82),
                            foregroundColor: scheme.onSurface,
                          ),
                          onPressed: () => _edit(current),
                          icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                          label: const Text('Add a photo'),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -1,
                    child: Container(
                      height: 29,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _categoryBadge(context, current.category),
                      const SizedBox(width: 12),
                      Icon(Icons.event_outlined, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text('Visited ${_formatDate(current.visitDate)}', style: muted),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    current.title,
                    style: const TextStyle(fontSize: 30, height: 38 / 30, fontWeight: FontWeight.w500),
                  ),
                  if (current.rating > 0) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      label: 'Rated ${current.rating} out of 5',
                      child: Row(
                        children: [
                          for (var i = 0; i < 5; i++)
                            Icon(
                              i < current.rating ? Icons.star : Icons.star_border,
                              size: 22,
                              color: const Color(0xFFF9C74F),
                            ),
                          const SizedBox(width: 8),
                          Text('Your rating', style: muted),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(child: Text(current.location.address, style: muted)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    onPressed: () => openPlan(context, ref, startPlaceId: current.id),
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: const Text('Plan an outing from here'),
                  ),
                  if (current.tags.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _heading('Tags'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final tag in current.tags) _Tag(label: tag)],
                    ),
                  ],
                  if (current.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _heading('Your notes'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(current.notes, style: const TextStyle(fontSize: 16, height: 24 / 16)),
                    ),
                    const SizedBox(height: 22),
                    _summaryCard(current),
                  ],
                  const SizedBox(height: 22),
                  _heading('Location'),
                  Material(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: () => _openMap(current),
                          child: Image.network(
                            staticMapUrlFor(current.location),
                            height: 170,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => SizedBox(
                              height: 170,
                              child: Icon(Icons.map_outlined, size: 48, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  current.location.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: muted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _openMap(current),
                                icon: const Icon(Icons.map_outlined, size: 18),
                                label: const Text('Open in Maps'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(Place current) {
    final scheme = Theme.of(context).colorScheme;
    final summary = _effectiveSummary(current);
    final muted = TextStyle(fontSize: 14, height: 20 / 14, color: scheme.onSurfaceVariant);
    return Semantics(
      container: true,
      label: 'AI summary',
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const Icon(Icons.auto_awesome, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      if (summary != null && !_loadingSummary)
                        Text('Made from your notes', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadingSummary) ...[
              Text('Reading your notes', style: muted),
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ] else if (summary != null) ...[
              _SummaryRow(
                icon: Icons.favorite,
                colors: (const Color(0xFF633B48), const Color(0xFFFFD9E3)),
                title: 'Why you liked it',
                body: summary.whyILikedIt,
              ),
              const SizedBox(height: 16),
              _SummaryRow(
                icon: Icons.lightbulb_outline,
                colors: (scheme.primaryContainer, scheme.primary),
                title: 'Tips',
                body: summary.tips,
              ),
              const SizedBox(height: 16),
              _SummaryRow(
                icon: Icons.schedule,
                colors: (const Color(0xFF4A3A10), const Color(0xFFF9C74F)),
                title: 'Best time to go',
                body: summary.bestTimeToGo,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _generateSummary(current),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Regenerate'),
                ),
              ),
            ] else ...[
              Text(
                'Turn your notes into three quick answers: why you liked it, tips, and the best time to go.',
                style: muted,
              ),
              if (_summaryError != null) ...[
                const SizedBox(height: 8),
                Text(_summaryError!, style: muted.copyWith(color: scheme.error)),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => _generateSummary(current),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_summaryError != null ? 'Try again' : 'Summarize my notes'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heading(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title, style: const TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w500)),
      );

  Widget _heroImage(Place p) {
    final tile = CategoryTile(category: p.category, iconSize: 96);
    if (p.photoUrls.isNotEmpty) {
      return Image.network(p.photoUrls.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => tile);
    }
    if (p.images.isNotEmpty) {
      return Image.file(p.images.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => tile);
    }
    return Image.network(
      staticMapUrlFor(p.location, width: 640, height: 640, zoom: 15),
      fit: BoxFit.cover,
      frameBuilder: (_, child, frame, __) => frame == null ? tile : child,
      errorBuilder: (_, __, ___) => tile,
    );
  }

  Widget _categoryBadge(BuildContext context, PlaceCategory cat) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 32,
      padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cat.icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text(
            cat.displayName,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

void _noop() {}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.filled = true,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: filled ? scheme.surface.withValues(alpha: 0.82) : Colors.transparent,
        foregroundColor: color ?? scheme.onSurface,
        fixedSize: const Size.square(48),
      ),
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.colors, required this.title, required this.body});

  final IconData icon;
  final (Color, Color) colors;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: background,
          foregroundColor: foreground,
          child: Icon(icon, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, color: foreground)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 15, height: 22 / 15)),
            ],
          ),
        ),
      ],
    );
  }
}
