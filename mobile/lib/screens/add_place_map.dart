import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/providers/user_settings.dart';
import 'package:favorite_places/services/places_search_service.dart';
import 'package:favorite_places/utils/device_location.dart';
import 'package:favorite_places/utils/geo.dart';
import 'package:favorite_places/utils/map_markers.dart';
import 'package:favorite_places/utils/map_style.dart';
import 'package:favorite_places/widgets/add_place/place_sheet.dart';

const _fallbackCamera = CameraPosition(target: LatLng(39.83, -98.58), zoom: 3);
const _placeZoom = 16.0;

class PickedPlace {
  const PickedPlace({
    required this.position,
    this.name,
    this.details,
    this.pinPosition,
    this.lookingUp = false,
    this.declined = false,
  });

  final LatLng position;
  final String? name;
  final PlaceDetailsResult? details;
  final LatLng? pinPosition;
  final bool lookingUp;
  final bool declined;
}

class AddPlaceMapScreen extends ConsumerStatefulWidget {
  const AddPlaceMapScreen({super.key});

  @override
  ConsumerState<AddPlaceMapScreen> createState() => _AddPlaceMapScreenState();
}

class _AddPlaceMapScreenState extends ConsumerState<AddPlaceMapScreen> {
  final _query = TextEditingController();
  final _queryFocus = FocusNode();
  final _search = PlacesSearchService();

  GoogleMapController? _controller;
  CameraUpdate? _pendingCamera;
  LatLng? _self;
  PickedPlace? _picked;
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _pinHint = false;
  int _lookup = 0;
  BitmapDescriptor? _savedIcon;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_savedIcon != null) return;
    final scheme = Theme.of(context).colorScheme;
    savedPlaceMarker(fill: scheme.primaryContainer, ring: scheme.primary, heart: scheme.onPrimaryContainer)
        .then((icon) {
      if (mounted) setState(() => _savedIcon = icon);
    });
  }

  @override
  void initState() {
    super.initState();
    _queryFocus.addListener(() => setState(() {}));
    currentLatLng().then((here) {
      if (!mounted || here == null) return;
      setState(() => _self = here);
      if (_picked == null && _query.text.isEmpty) _moveTo(here, zoom: 14);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  CameraPosition _initialCamera() {
    final places = ref.read(userPlacesProvider);
    if (places.isEmpty) return _fallbackCamera;
    // The median lands among most of the saved places, even when one is in another city.
    double median(Iterable<double> values) => (values.toList()..sort())[values.length ~/ 2];
    final target = LatLng(
      median(places.map((p) => p.location.latitude)),
      median(places.map((p) => p.location.longitude)),
    );
    return CameraPosition(target: target, zoom: 12);
  }

  void _moveTo(LatLng target, {double zoom = _placeZoom}) {
    final update = CameraUpdate.newLatLngZoom(target, zoom);
    final controller = _controller;
    if (controller == null) {
      _pendingCamera = update;
    } else {
      controller.animateCamera(update);
    }
  }

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(text));
  }

  Future<void> _runSearch(String text) async {
    setState(() => _searching = true);
    try {
      final origin = _self;
      final results = await _search.autocomplete(
        text,
        origin: origin == null ? null : (latitude: origin.latitude, longitude: origin.longitude),
        radiusMeters: ref.read(userSettingsProvider).defaultRadius.toDouble(),
      );
      if (mounted && _query.text == text) setState(() => _suggestions = results);
    } catch (_) {
      if (mounted) _snack('Place search unavailable right now.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _choose(PlaceSuggestion suggestion) async {
    _queryFocus.unfocus();
    _query.text = suggestion.primaryText;
    setState(() => _suggestions = const []);
    try {
      final details = await _search.details(suggestion.placeId);
      if (!mounted) return;
      final position = LatLng(details.latitude, details.longitude);
      _lookup++;
      setState(() => _picked = PickedPlace(position: position, name: suggestion.primaryText, details: details));
      _moveTo(position);
    } catch (_) {
      if (mounted) _snack("Couldn't open that place.");
    }
  }

  Future<void> _dropPin(LatLng position) async {
    _queryFocus.unfocus();
    final lookup = ++_lookup;
    setState(() {
      _picked = PickedPlace(position: position, lookingUp: true);
      _pinHint = false;
      _suggestions = const [];
    });
    ({String name, PlaceDetailsResult details})? found;
    try {
      found = await _search.nearby(position.latitude, position.longitude);
    } catch (_) {}
    if (!mounted || lookup != _lookup) return;
    setState(() {
      _picked = found == null
          ? PickedPlace(position: position)
          : PickedPlace(
              position: LatLng(found.details.latitude, found.details.longitude),
              name: found.name,
              details: found.details,
              pinPosition: position,
            );
    });
  }

  void _nameItYourself() {
    final pin = _picked?.pinPosition;
    if (pin == null) return;
    _lookup++;
    setState(() => _picked = PickedPlace(position: pin, declined: true));
  }

  Future<void> _useMyLocation() async {
    _queryFocus.unfocus();
    final here = _self ?? await currentLatLng();
    if (!mounted) return;
    if (here == null) {
      _snack("Couldn't find your location.");
      return;
    }
    setState(() => _self = here);
    _moveTo(here);
    await _dropPin(here);
  }

  void _clear() {
    _lookup++;
    _query.clear();
    setState(() {
      _picked = null;
      _suggestions = const [];
    });
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Set<Marker> _markers(List<Place> saved) => {
        if (_savedIcon case final icon?)
          for (final place in saved)
            Marker(
              markerId: MarkerId('saved-${place.id}'),
              position: LatLng(place.location.latitude, place.location.longitude),
              icon: icon,
              anchor: const Offset(0.5, 0.5),
              infoWindow: InfoWindow(title: place.title),
            ),
        if (_picked case final picked?)
          Marker(markerId: const MarkerId('picked'), position: picked.position, zIndexInt: 1),
      };

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(userPlacesProvider);
    final scheme = Theme.of(context).colorScheme;
    final searching = _queryFocus.hasFocus;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: _initialCamera(),
                  style: darkMapStyle,
                  markers: _markers(saved),
                  circles: selfLocationCircles(_self),
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onTap: _dropPin,
                  onMapCreated: (controller) {
                    _controller = controller;
                    if (_pendingCamera case final update?) controller.animateCamera(update);
                    _pendingCamera = null;
                  },
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !searching,
                    child: GestureDetector(
                      onTap: _queryFocus.unfocus,
                      child: AnimatedOpacity(
                        opacity: searching ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: const ColoredBox(color: Color(0x8C0C0A10)),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _SearchPanel(
                          controller: _query,
                          focusNode: _queryFocus,
                          open: searching,
                          loading: _searching,
                          suggestions: _suggestions,
                          onChanged: _onQueryChanged,
                          onClear: _clear,
                          onChoose: _choose,
                          onUseMyLocation: _useMyLocation,
                          onDropPin: () {
                            _queryFocus.unfocus();
                            setState(() => _pinHint = true);
                          },
                        ),
                      ),
                      if (!searching && _picked == null) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: _Hint(
                            text: _pinHint ? 'Tap the map to drop a pin' : 'Or tap the map to drop a pin',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!searching && saved.isNotEmpty && _picked == null)
                  Positioned(left: 16, bottom: 40, child: _Legend(color: scheme.primary)),
                if (!searching)
                  Positioned(
                    right: 16,
                    bottom: _picked == null ? 32 : 16,
                    child: _picked == null
                        ? FloatingActionButton.extended(
                            heroTag: null,
                            backgroundColor: scheme.secondaryContainer,
                            foregroundColor: scheme.onSecondaryContainer,
                            onPressed: _useMyLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Use my location'),
                          )
                        : FloatingActionButton(
                            heroTag: null,
                            tooltip: 'Use my location',
                            backgroundColor: scheme.secondaryContainer,
                            foregroundColor: scheme.onSecondaryContainer,
                            onPressed: _useMyLocation,
                            child: const Icon(Icons.my_location),
                          ),
                  ),
              ],
            ),
          ),
          // Below the map rather than over it: Google's logo and terms must stay
          // visible, and the web map can't move them out from under an overlay.
          if (_picked case final picked? when !searching) _SheetPanel(picked: picked, onNameItYourself: _nameItYourself),
        ],
      ),
    );
  }
}

class _SheetPanel extends StatelessWidget {
  const _SheetPanel({required this.picked, required this.onNameItYourself});

  final PickedPlace picked;
  final VoidCallback onNameItYourself;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      elevation: 8,
      shadowColor: Colors.black,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: scheme.outline, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              PlaceSheet(
                key: ValueKey(picked),
                latitude: picked.position.latitude,
                longitude: picked.position.longitude,
                name: picked.name,
                details: picked.details,
                lookingUp: picked.lookingUp,
                declined: picked.declined,
                onNameItYourself: picked.pinPosition == null ? null : onNameItYourself,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchPanel extends ConsumerWidget {
  const _SearchPanel({
    required this.controller,
    required this.focusNode,
    required this.open,
    required this.loading,
    required this.suggestions,
    required this.onChanged,
    required this.onClear,
    required this.onChoose,
    required this.onUseMyLocation,
    required this.onDropPin,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool open;
  final bool loading;
  final List<PlaceSuggestion> suggestions;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<PlaceSuggestion> onChoose;
  final VoidCallback onUseMyLocation;
  final VoidCallback onDropPin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final unit = ref.watch(distanceUnitProvider);
    final primary = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: scheme.primary);
    // One tap region for the whole panel, so pressing a suggestion doesn't count
    // as a tap outside the field, which would close the panel before the tap lands.
    return TextFieldTapRegion(
      child: Material(
        color: scheme.surfaceContainerHigh,
        elevation: 4,
        shadowColor: Colors.black,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: open ? 'Close search' : 'Back to places',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: open ? focusNode.unfocus : () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Search for a place or address',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (controller.text.isNotEmpty)
                    IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close), onPressed: onClear)
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.search, color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            if (open) ...[
              const Divider(height: 1),
              for (final suggestion in suggestions)
                _SuggestionRow(
                  suggestion: suggestion,
                  distance: suggestion.distanceMeters == null ? null : formatDistance(suggestion.distanceMeters!, unit),
                  onTap: () => onChoose(suggestion),
                ),
              if (suggestions.isNotEmpty) const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                minTileHeight: 56,
                leading: Icon(Icons.my_location, color: scheme.primary),
                title: Text('Use my location', style: primary),
                onTap: onUseMyLocation,
              ),
              ListTile(
                minTileHeight: 56,
                leading: Icon(Icons.touch_app_outlined, color: scheme.primary),
                title: Text('Drop a pin on the map instead', style: primary),
                onTap: onDropPin,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'powered by Google',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: scheme.outline),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion, required this.distance, required this.onTap});

  final PlaceSuggestion suggestion;
  final String? distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = [
      if (suggestion.secondaryText.isNotEmpty) suggestion.secondaryText,
      if (distance != null) distance,
    ].join(' · ');
    return ListTile(
      minTileHeight: 64,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurfaceVariant,
        child: const Icon(Icons.place, size: 20),
      ),
      title: Text.rich(_highlighted(suggestion.primaryText, suggestion.matches, scheme)),
      subtitle: secondary.isEmpty ? null : Text(secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

TextSpan _highlighted(String text, List<(int, int)> matches, ColorScheme scheme) {
  final bold = TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface);
  final spans = <TextSpan>[];
  var at = 0;
  for (final (start, end) in matches) {
    if (start < at || end > text.length || start >= end) continue;
    if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
    spans.add(TextSpan(text: text.substring(start, end), style: bold));
    at = end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return TextSpan(children: spans, style: const TextStyle(fontSize: 16));
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place, size: 16, color: color),
          const SizedBox(width: 6),
          Text('Already saved', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
