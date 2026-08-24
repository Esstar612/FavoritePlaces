import 'dart:async';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/services/places_search_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

/// Last-resort camera target when we have neither a supplied location nor
/// permission to read the device's. Roughly centres the continental US rather
/// than dropping the user at a specific building.
const _fallbackTarget = LatLng(39.83, -98.58);
const _fallbackZoom = 3.0;
const _placeZoom = 16.0;

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.location,
    this.isSelecting = true,
  });

  /// Where to centre. When null (picking a brand-new place) the map opens on
  /// the user's current location instead of an arbitrary default.
  final PlaceLocation? location;
  final bool isSelecting;

  @override
  State<MapScreen> createState() {
    return _MapScreenState();
  }
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _pickedLocation;
  String? _pickedAddress;

  GoogleMapController? _controller;
  CameraPosition? _initialCamera;
  bool _locatedSelf = false;
  /// Set when the device reports in before the map controller exists; applied
  /// by onMapCreated. Without this the recentre is silently dropped whenever
  /// locating wins the race against map creation — which it usually does on
  /// web, where the position is already cached.
  LatLng? _pendingRecentre;

  // ── search ────────────────────────────────────────────────────────────────
  final _searchController = TextEditingController();
  final _search = PlacesSearchService();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _resolveInitialCamera();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  /// Show a map immediately, then re-centre on the device if it reports in.
  ///
  /// Locating is deliberately not awaited before the first frame: on the web
  /// the browser only prompts for permission when a position is actually
  /// requested, and the user may take seconds to answer — blocking on that
  /// would leave the screen on a spinner.
  Future<void> _resolveInitialCamera() async {
    final supplied = widget.location;
    setState(() {
      _initialCamera = supplied != null
          ? CameraPosition(
              target: LatLng(supplied.latitude, supplied.longitude),
              zoom: _placeZoom,
            )
          : const CameraPosition(target: _fallbackTarget, zoom: _fallbackZoom);
    });

    // An explicit location wins — don't override it with the device's.
    if (supplied != null) return;

    final here = await _currentLatLng();
    if (here == null || !mounted) return;

    // Don't yank the camera out from under someone who already acted.
    if (_pickedLocation != null || _searchController.text.isNotEmpty) return;

    setState(() => _locatedSelf = true);
    await _moveTo(here);
  }

  /// Move the camera, deferring until the controller exists.
  Future<void> _moveTo(LatLng target) async {
    final controller = _controller;
    if (controller == null) {
      _pendingRecentre = target;
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(target, _placeZoom),
    );
  }

  Future<LatLng?> _currentLatLng() async {
    try {
      final location = Location();

      // On web, requesting a position *is* the permission prompt — there is no
      // separate grant step, and asking permission first reports "denied"
      // while the browser is still only in the "prompt" state. Native does
      // need the explicit request.
      if (!kIsWeb) {
        var status = await location.hasPermission();
        if (status == PermissionStatus.denied) {
          status = await location.requestPermission();
        }
        final allowed = status == PermissionStatus.granted ||
            status == PermissionStatus.grantedLimited;
        if (!allowed || !await location.serviceEnabled()) return null;
      }

      final data = await location.getLocation().timeout(
            const Duration(seconds: 20),
          );
      final lat = data.latitude, lng = data.longitude;
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    } catch (_) {
      // Denied, unsupported, or timed out. The fallback map is already up and
      // search and pan both work, so this is a degraded start, not a failure.
      return null;
    }
  }

  // ── search handling ───────────────────────────────────────────────────────
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    // Debounced so a burst of keystrokes is one request, not one per letter.
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    setState(() => _searching = true);
    try {
      final results = await _search.autocomplete(value);
      if (!mounted) return;
      setState(() { _suggestions = results; _searching = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _suggestions = const []; _searching = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Place search unavailable right now.')),
      );
    }
  }

  Future<void> _choose(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    setState(() { _suggestions = const []; _searching = true; });

    try {
      final result = await _search.details(suggestion.placeId);
      if (!mounted) return;

      final target = LatLng(result.latitude, result.longitude);
      setState(() {
        _pickedLocation = target;
        _pickedAddress = result.address.isNotEmpty
            ? result.address
            : suggestion.primaryText;
        _searchController.text = suggestion.primaryText;
        _searching = false;
      });
      await _moveTo(target);
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open that place.")),
      );
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final camera = _initialCamera;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelecting ? 'Pick your location' : 'Your Location'),
        actions: [
          if (widget.isSelecting)
            IconButton(
              tooltip: 'Save location',
              onPressed: () {
                if (_pickedLocation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Search for a place or tap the map'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                // Return the address too when search already gave us one —
                // otherwise the caller pays for a redundant reverse geocode.
                Navigator.of(context).pop(PlaceLocation(
                  latitude:  _pickedLocation!.latitude,
                  longitude: _pickedLocation!.longitude,
                  address:   _pickedAddress ?? '',
                ));
              },
              icon: const Icon(Icons.save),
            ),
        ],
      ),
      body: camera == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: (c) {
                    _controller = c;
                    final pending = _pendingRecentre;
                    if (pending != null) {
                      _pendingRecentre = null;
                      c.animateCamera(
                        CameraUpdate.newLatLngZoom(pending, _placeZoom),
                      );
                    }
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onTap: !widget.isSelecting
                      ? null
                      : (position) {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _pickedLocation = position;
                            _pickedAddress = null;
                            _suggestions = const [];
                          });
                        },
                  initialCameraPosition: camera,
                  markers: _markers(),
                ),

                if (widget.isSelecting) _searchOverlay(context),

                // Brief confirmation that the map moved to the user, since it
                // happens after the first frame rather than before it.
                if (_locatedSelf && _pickedAddress == null)
                  Positioned(
                    left: 16, right: 16, bottom: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: const [
                          Icon(Icons.my_location, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('Centred on your location')),
                        ]),
                      ),
                    ),
                  ),

                if (_pickedAddress != null)
                  Positioned(
                    left: 16, right: 16, bottom: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          const Icon(Icons.location_on, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_pickedAddress!, maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Set<Marker> _markers() {
    final supplied = widget.location;
    final target = _pickedLocation ??
        (supplied != null && !widget.isSelecting
            ? LatLng(supplied.latitude, supplied.longitude)
            : null);
    if (target == null) return const {};
    return {Marker(markerId: const MarkerId('m1'), position: target)};
  }

  Widget _searchOverlay(BuildContext context) => Positioned(
        top: 12, left: 12, right: 12,
        child: Column(
          children: [
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search for a place or address',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _suggestions = const []);
                              },
                            )),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
              ),
            ),
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final s = _suggestions[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(s.primaryText, maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: s.secondaryText.isEmpty
                          ? null
                          : Text(s.secondaryText, maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      onTap: () => _choose(s),
                    );
                  },
                ),
              ),
          ],
        ),
      );
}
