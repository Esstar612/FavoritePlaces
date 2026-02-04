import 'package:favorite_places/config.dart';
import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/screens/add_place.dart';
import 'package:favorite_places/screens/map.dart';
import 'package:favorite_places/services/ai_service.dart';
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
  NoteSummary?  _summary;
  bool          _loadingSummary = false;
  String?       _summaryError;

  Future<void> _generateSummary(Place p) async {
    if (p.notes.trim().isEmpty) {
      setState(() => _summaryError = 'Add some notes first to generate a summary.');
      return;
    }
    setState(() { _loadingSummary = true; _summaryError = null; });
    try {
      final s = await AIService().summarizeNotes(
        title:    p.title,
        notes:    p.notes,
        category: p.category.name,
        address:  p.location.address,
      );
      setState(() { _summary = s; _loadingSummary = false; });
    } catch (e) {
      setState(() { _loadingSummary = false; _summaryError = 'AI unavailable – make sure the backend is running.'; });
    }
  }

  // ── static map URL ───────────────────────────────────────────────────────
  String _mapUrl(Place p) {
    final lat = p.location.latitude, lng = p.location.longitude;
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$lat,$lng&zoom=16&size=600x300&maptype=roadmap'
        '&markers=color:red%7Clabel:A%7C$lat,$lng'
        '&key=${AppConfig.googleMapsApiKey}';
  }

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
                onPressed: () => ref.read(userPlacesProvider.notifier).toggleFavorite(current.id),
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
                    if (ok == true && context.mounted) {
                      await ref.read(userPlacesProvider.notifier).deletePlace(current.id);
                      Navigator.of(context).pop();
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
                    if (_loadingSummary)
                      const Center(child: CircularProgressIndicator()),
                    if (_summaryError != null)
                      Text(_summaryError!, style: const TextStyle(color: Colors.grey)),
                    if (_summary != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _summaryRow(context, '💡 Why I Liked It', _summary!.whyILikedIt),
                            const SizedBox(height: 10),
                            _summaryRow(context, '📝 Tips',            _summary!.tips),
                            const SizedBox(height: 10),
                            _summaryRow(context, '🕐 Best Time',       _summary!.bestTimeToGo),
                          ],
                        ),
                      ),
                    if (_summary == null && !_loadingSummary && _summaryError == null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _generateSummary(current),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Generate Smart Summary'),
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
    return Container(
      color: Colors.grey.shade800,
      child: const Center(child: Icon(Icons.landscape, size: 80, color: Colors.grey)),
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

  Widget _summaryRow(BuildContext context, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(value, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}
