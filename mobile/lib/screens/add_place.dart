import 'dart:io';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/providers/user_places.dart';
import 'package:favorite_places/widgets/image_input.dart';
import 'package:favorite_places/widgets/location_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddPlaceScreen extends ConsumerStatefulWidget {
  const AddPlaceScreen({super.key, this.placeToEdit});
  final Place? placeToEdit;

  @override
  ConsumerState<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends ConsumerState<AddPlaceScreen> {
  // ── controllers ──────────────────────────────────────────────────────────
  final _titleController    = TextEditingController();
  final _notesController    = TextEditingController();
  final _tagController      = TextEditingController();

  // ── local state ──────────────────────────────────────────────────────────
  List<File>      _newImages       = [];   // freshly-picked images (not yet uploaded)
  List<String>    _existingUrls    = [];   // cloud URLs from an existing place (edit mode)
  PlaceLocation?  _selectedLocation;
  PlaceCategory   _selectedCategory = PlaceCategory.other;
  List<String>    _tags            = [];
  int             _rating          = 0;
  DateTime        _visitDate       = DateTime.now();
  bool            _isSaving        = false;

  // ── tag suggestions ──────────────────────────────────────────────────────
  static const _suggestedTags = [
    'Must Visit', 'Hidden Gem', 'Family Friendly', 'Good Food',
    'Great Views', 'Budget Friendly', 'Romantic', 'Instagrammable',
    'Quiet', 'Crowded',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.placeToEdit;
    if (p != null) {
      _titleController.text     = p.title;
      _notesController.text     = p.notes;
      _existingUrls             = List.from(p.photoUrls);
      _selectedLocation         = p.location;
      _selectedCategory         = p.category;
      _tags                     = List.from(p.tags);
      _rating                   = p.rating;
      _visitDate                = p.visitDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // ── tag helpers ──────────────────────────────────────────────────────────
  void _addTag(String tag) {
    final t = tag.trim();
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() { _tags.add(t); });
      _tagController.clear();
    }
  }

  void _removeTag(String tag) => setState(() { _tags.remove(tag); });

  // ── does the user have at least one photo (new or existing)? ────────────
  bool get _hasPhoto => _newImages.isNotEmpty || _existingUrls.isNotEmpty;

  // ── save ─────────────────────────────────────────────────────────────────
  Future<void> _savePlace() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || !_hasPhoto || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in title, add at least one photo, and select a location'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.placeToEdit != null) {
        // ── EDIT: build an updated Place ─────────────────────────────────
        final updated = widget.placeToEdit!.copyWith(
          title:      title,
          images:     _newImages,          // provider uploads these if non-empty
          photoUrls:  _existingUrls,       // kept as fallback if no new images
          location:   _selectedLocation,
          category:   _selectedCategory,
          tags:       _tags,
          notes:      _notesController.text.trim(),
          rating:     _rating,
          visitDate:  _visitDate,
        );
        await ref.read(userPlacesProvider.notifier).updatePlace(updated);
      } else {
        // ── CREATE ─────────────────────────────────────────────────────
        final newPlace = Place(
          title:     title,
          images:    _newImages,
          location:  _selectedLocation!,
          category:  _selectedCategory,
          tags:      _tags,
          notes:     _notesController.text.trim(),
          rating:    _rating,
          visitDate: _visitDate,
        );
        await ref.read(userPlacesProvider.notifier).addPlace(newPlace);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  // ── date picker ──────────────────────────────────────────────────────────
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _visitDate = picked);
  }

  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.placeToEdit != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Place' : 'Add New Place')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──────────────────────────────────────────────────────
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Place Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // ── Category ───────────────────────────────────────────────────
            DropdownButtonFormField<PlaceCategory>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: PlaceCategory.values.map((cat) => DropdownMenuItem(
                value: cat,
                child: Row(children: [
                  Text(cat.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Text(cat.displayName),
                ]),
              )).toList(),
              onChanged: (v) { if (v != null) setState(() => _selectedCategory = v); },
            ),
            const SizedBox(height: 16),

            // ── Rating ─────────────────────────────────────────────────────
            Text('Rating', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) => IconButton(
                icon: Icon(
                  i < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber, size: 32,
                ),
                onPressed: () => setState(() => _rating = i + 1),
              )),
            ),
            const SizedBox(height: 16),

            // ── Visit Date ─────────────────────────────────────────────────
            ListTile(
              title: const Text('Visit Date'),
              subtitle: Text('${_visitDate.day}/${_visitDate.month}/${_visitDate.year}'),
              leading: const Icon(Icons.calendar_today),
              trailing: const Icon(Icons.edit),
              onTap: _selectDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            const SizedBox(height: 16),

            // ── Photo ──────────────────────────────────────────────────────
            Text('Photo *', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // If editing and we already have cloud URLs, show a placeholder note
            if (_existingUrls.isNotEmpty && _newImages.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.photo, size: 28),
                  const SizedBox(width: 12),
                  Text('${_existingUrls.length} photo(s) on file'),
                ]),
              ),
            ImageInput(
              onPickImage: (image) => setState(() => _newImages = [image]),
            ),
            const SizedBox(height: 16),

            // ── Location ───────────────────────────────────────────────────
            Text('Location *', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LocationInput(
              onSelectLocation: (loc) => setState(() => _selectedLocation = loc),
            ),
            const SizedBox(height: 16),

            // ── Tags ───────────────────────────────────────────────────────
            Text('Tags', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                ..._tags.map((tag) => Chip(
                  label: Text(tag),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeTag(tag),
                )),
                ..._suggestedTags
                    .where((t) => !_tags.contains(t))
                    .take(3)
                    .map((t) => ActionChip(label: Text(t), onPressed: () => _addTag(t))),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                hintText: 'Add custom tag...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addTag(_tagController.text),
                ),
              ),
              onSubmitted: _addTag,
            ),
            const SizedBox(height: 16),

            // ── Notes ──────────────────────────────────────────────────────
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes / Tips',
                hintText: 'Why did you like this place? Any tips?',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // ── Save button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _savePlace,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(isEditing ? Icons.save : Icons.add),
                label: Text(
                  _isSaving ? 'Saving…' : isEditing ? 'Save Changes' : 'Add Place',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
