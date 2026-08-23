import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/screens/add_place.dart';
import 'package:favorite_places/screens/map.dart';
import 'package:favorite_places/services/ai_service.dart';
import 'package:favorite_places/utils/static_map.dart';
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
      setState(() { _loadingSummary = false; _summaryError = 'AI unavailable – make sure the backend is running.'; });
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

  // ── static map URL ───────────────────────────────────────────────────────
  String _mapUrl(Place p) => staticMapUrlFor(p.location);

  @override
  Widget build(BuildContext context) {
    // Watch the provider so the UI stays in sync (e.g. favorite toggle)
    final places  = ref.watch(userPlacesProvider);
    final current = places.firstWhere((p) => p.id == widget.place.id, orElse: () => widget.place);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── expandable image header ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _heroImage(current),
                  // gradient so title is readable
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // favorite toggle
              IconButton(
                icon: Icon(
                  current.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: current.isFavorite ? Colors.red : null,
                ),
                onPressed: () => _toggleFavorite(current.id),
              ),
              // edit
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AddPlaceScreen(placeToEdit: current)),
                  );
                },
              ),
              // 3-dot menu → delete
              PopupMenuButton(
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
                onSelected: (v) async {
                  if (v == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Place'),
                        content: Text('Delete "${current.title}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref.read(userPlacesProvider.notifier).deletePlace(current.id);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  }
                },
              ),
            ],
          ),

          // ── body content ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title + category badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          current.title,
                          style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      _categoryBadge(context, current.category),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // rating
                  if (current.rating > 0) ...[
                    Row(children: List.generate(5, (i) => Icon(
                      i < current.rating ? Icons.star : Icons.star_border,
                      color: Colors.amber, size: 28,
                    ))),
                    const SizedBox(height: 16),
                  ],

                  // visit date
                  Row(children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Visited: ${_formatDate(current.visitDate)}',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // tags
                  if (current.tags.isNotEmpty) ...[
                    _sectionTitle(context, 'Tags'),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: current.tags.map((t) => Chip(
                        label: Text(t),
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // notes
                  if (current.notes.isNotEmpty) ...[
                    _sectionTitle(context, 'Notes'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(current.notes, style: Theme.of(context).textTheme.bodyLarge),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── AI Smart Summary ─────────────────────────────────────
                  if (current.notes.isNotEmpty) ...[
                    _sectionTitle(context, 'Smart Summary'),
                    if (_effectiveSummary(current) case final s?) ...[
                      _summaryCard(context, s),
                      const SizedBox(height: 8),
                    ],
                    if (_loadingSummary)
                      const Center(child: CircularProgressIndicator()),
                    if (_summaryError != null) ...[
                      Text(_summaryError!, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                    ],
                    // Stays visible after a failure — the error text renders
                    // above it, so a transient backend outage is retryable
                    // without leaving the screen. Also offers a refresh once a
                    // cached summary is showing.
                    if (!_loadingSummary)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _generateSummary(current),
                          icon: Icon(_effectiveSummary(current) != null
                              ? Icons.refresh
                              : Icons.auto_awesome),
                          label: Text(
                            _summaryError != null
                                ? 'Try Again'
                                : _effectiveSummary(current) != null
                                    ? 'Regenerate'
                                    : 'Generate Smart Summary',
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],

                  // location section
                  _sectionTitle(context, 'Location'),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => MapScreen(location: current.location, isSelecting: false)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Image.network(
                            _mapUrl(current),
                            height: 200, width: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 200,
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              child: const Center(child: Icon(Icons.map, size: 48)),
                            ),
                          ),
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                                ),
                              ),
                              child: Row(children: [
                                const Icon(Icons.location_on, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    current.location.address,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => MapScreen(location: current.location, isSelecting: false)),
                      ),
                      icon: const Icon(Icons.map),
                      label: const Text('Open in Maps'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  Widget _heroImage(Place p) {
    if (p.photoUrls.isNotEmpty) {
      return Image.network(p.photoUrls.first, fit: BoxFit.cover);
    }
    if (p.images.isNotEmpty) {
      return Image.file(p.images.first, fit: BoxFit.cover);
    }
    // No photo — the map of where it is beats an empty grey header.
    return Image.network(
      staticMapUrlFor(p.location, width: 640, height: 640, zoom: 15),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade800,
        child: const Center(child: Icon(Icons.landscape, size: 80, color: Colors.grey)),
      ),
    );
  }

  Widget _categoryBadge(BuildContext context, PlaceCategory cat) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(cat.icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(
          cat.displayName,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
  );

  Widget _summaryCard(BuildContext context, PlaceSummary s) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.25),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryRow(context, '💡 Why I Liked It', s.whyILikedIt),
        const SizedBox(height: 10),
        _summaryRow(context, '📝 Tips',            s.tips),
        const SizedBox(height: 10),
        _summaryRow(context, '🕐 Best Time',       s.bestTimeToGo),
      ],
    ),
  );

  Widget _summaryRow(BuildContext context, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(value, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}
