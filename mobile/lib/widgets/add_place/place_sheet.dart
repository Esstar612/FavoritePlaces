import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/services/ai_service.dart';
import 'package:favorite_places/services/places_search_service.dart';
import 'package:favorite_places/utils/geo.dart';
import 'package:favorite_places/utils/place_types.dart';
import 'package:favorite_places/widgets/add_place/place_details_form.dart';
import 'package:favorite_places/widgets/place_visuals.dart';

class PlaceSheet extends ConsumerStatefulWidget {
  const PlaceSheet({
    super.key,
    required this.latitude,
    required this.longitude,
    this.name,
    this.details,
    this.lookingUp = false,
    this.declined = false,
    this.onNameItYourself,
    this.expanded = false,
    this.onExpand,
  });

  final double latitude;
  final double longitude;
  final String? name;
  final PlaceDetailsResult? details;
  final bool lookingUp;
  final bool declined;
  final VoidCallback? onNameItYourself;
  final bool expanded;
  final VoidCallback? onExpand;

  bool get isDroppedPin => details == null;

  @override
  ConsumerState<PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends ConsumerState<PlaceSheet> {
  final _name = TextEditingController();
  final _draft = PlaceDraft();
  late PlaceCategory _category = categoryForTypes(widget.details?.types ?? const []);
  String? _address;
  bool _locating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _address = widget.details?.address;
    _name.addListener(() => setState(() {}));
    if (widget.isDroppedPin && !widget.lookingUp) _lookUpAddress();
  }

  @override
  void dispose() {
    _name.dispose();
    _draft.dispose();
    super.dispose();
  }

  String get _fallbackAddress =>
      'Lat ${widget.latitude.toStringAsFixed(4)}, Lng ${widget.longitude.toStringAsFixed(4)}';

  Future<void> _lookUpAddress() async {
    setState(() => _locating = true);
    String? address;
    try {
      address = await AIService().reverseGeocode(latitude: widget.latitude, longitude: widget.longitude);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _address = address ?? _fallbackAddress;
      _locating = false;
    });
  }

  String get _title => widget.isDroppedPin ? _name.text.trim() : widget.name ?? '';

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(userPlacesProvider.notifier).addPlace(
            Place(
              title: _title,
              category: _category,
              images: [if (_draft.photo case final photo?) photo],
              rating: _draft.rating,
              visitDate: _draft.visited,
              tags: List.of(_draft.tags),
              notes: _draft.notes.text.trim(),
              location: PlaceLocation(
                latitude: widget.latitude,
                longitude: widget.longitude,
                address: _address ?? _fallbackAddress,
              ),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save the place. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final saved = savedPlaceNear(ref.watch(userPlacesProvider), widget.latitude, widget.longitude);
    final canSave = _title.isNotEmpty && !_saving && !_locating && !widget.lookingUp;
    final muted = TextStyle(fontSize: 14, height: 20 / 14, color: scheme.onSurfaceVariant);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isDroppedPin)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox.square(
                  dimension: 64,
                  child: ColoredBox(
                    color: scheme.primaryContainer,
                    child: Icon(Icons.push_pin_outlined, color: scheme.onPrimaryContainer),
                  ),
                ),
              )
            else
              _PreviewPhoto(photo: widget.details!.photo, category: _category),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isDroppedPin ? 'Dropped pin' : widget.name ?? '',
                    style: const TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.lookingUp
                        ? 'Looking for a place here…'
                        : _locating
                            ? 'Finding the address…'
                            : _address ?? '',
                    style: muted,
                  ),
                  if (!widget.isDroppedPin) ...[
                    const SizedBox(height: 8),
                    _CategoryMenu(value: _category, onChanged: (c) => setState(() => _category = c)),
                  ],
                  if (widget.onNameItYourself case final onTap?)
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      onPressed: onTap,
                      child: const Text('Not it? Name it yourself'),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (widget.isDroppedPin && !widget.lookingUp) ...[
          const SizedBox(height: 12),
          Text(
            widget.declined ? 'Give this spot your own name.' : 'No business here, so it needs a name from you.',
            style: muted,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Name this place',
              hintText: 'e.g. Sunset spot on Pier 14',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final category in PlaceCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${category.icon} ${category.displayName}'),
                      selected: _category == category,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (saved != null) ...[
          const SizedBox(height: 14),
          _SavedHereNote(title: saved.title),
        ],
        if (widget.expanded && !widget.lookingUp) ...[
          const SizedBox(height: 20),
          PlaceDetailsForm(draft: _draft, title: _title, category: _category.name),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          onPressed: canSave ? _save : null,
          icon: _saving
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check, size: 20),
          label: Text(widget.isDroppedPin && _title.isEmpty ? 'Add a name to save' : 'Save this place'),
        ),
        if (!widget.lookingUp) ...[
          const SizedBox(height: 6),
          if (widget.expanded)
            Text('Photo, rating and tags are optional', textAlign: TextAlign.center, style: muted.copyWith(fontSize: 12))
          else
            TextButton.icon(
              onPressed: widget.onExpand,
              icon: const Icon(Icons.keyboard_arrow_up, size: 18),
              label: const Text('Swipe up to add a photo, rating, tags or notes'),
            ),
        ],
      ],
    );
  }
}

class _PreviewPhoto extends StatelessWidget {
  const _PreviewPhoto({required this.photo, required this.category});

  final PlacePhoto? photo;
  final PlaceCategory category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tile = CategoryTile(category: category, iconSize: 36);
    final photo = this.photo;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox.square(
        dimension: 96,
        child: photo == null
            ? tile
            : Image.network(
                photoMediaUrl(photo.name, maxWidthPx: 288),
                fit: BoxFit.cover,
                frameBuilder: (_, child, frame, __) => frame == null ? tile : child,
                errorBuilder: (_, __, ___) => tile,
              ),
      ),
    );
    final author = photo?.author;
    if (author == null) return image;
    final uri = photo?.authorUri == null ? null : Uri.tryParse(photo!.authorUri!);
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          image,
          const SizedBox(height: 4),
          InkWell(
            onTap: uri == null ? null : () => launchUrl(uri),
            child: Text(
              'Photo: $author',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                decoration: uri == null ? null : TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryMenu extends StatelessWidget {
  const _CategoryMenu({required this.value, required this.onChanged});

  final PlaceCategory value;
  final ValueChanged<PlaceCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<PlaceCategory>(
      tooltip: 'Category',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final category in PlaceCategory.values)
          PopupMenuItem(value: category, child: Text('${category.icon} ${category.displayName}')),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.fromLTRB(8, 0, 6, 0),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${value.icon} ${value.displayName}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSecondaryContainer),
            ),
            Icon(Icons.arrow_drop_down, color: scheme.onSecondaryContainer),
          ],
        ),
      ),
    );
  }
}

class _SavedHereNote extends StatelessWidget {
  const _SavedHereNote({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    const foreground = Color(0xFFFFD9E3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF3E2B33), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.favorite, size: 16, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You've already saved $title here",
              style: const TextStyle(fontSize: 13, height: 18 / 13, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
