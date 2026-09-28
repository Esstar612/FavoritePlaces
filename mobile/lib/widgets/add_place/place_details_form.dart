import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/services/ai_service.dart';
import 'package:favorite_places/widgets/local_photo.dart';

const suggestedTags = [
  'Must Visit', 'Hidden Gem', 'Family Friendly', 'Good Food', 'Great Views',
  'Budget Friendly', 'Romantic', 'Instagrammable', 'Quiet', 'Crowded',
];

class PlaceDraft extends ChangeNotifier {
  PlaceDraft();

  PlaceDraft.from(Place place)
      : rating = place.rating,
        visited = place.visitDate,
        savedPhotoUrls = List.of(place.photoUrls) {
    tags.addAll(place.tags);
    notes.text = place.notes;
  }

  XFile? photo;
  int rating = 0;
  DateTime visited = DateTime.now();
  List<String> savedPhotoUrls = const [];
  final List<String> tags = [];
  final notes = TextEditingController();

  void removeSavedPhoto() {
    savedPhotoUrls = const [];
    notifyListeners();
  }

  void setPhoto(XFile? value) {
    photo = value;
    notifyListeners();
  }

  void setRating(int value) {
    rating = value == rating ? 0 : value;
    notifyListeners();
  }

  void setVisited(DateTime value) {
    visited = value;
    notifyListeners();
  }

  void toggleTag(String tag) {
    tags.contains(tag) ? tags.remove(tag) : tags.add(tag);
    notifyListeners();
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }
}

class PlaceDetailsForm extends StatefulWidget {
  const PlaceDetailsForm({super.key, required this.draft, required this.title, required this.category});

  final PlaceDraft draft;
  final String title;
  final String category;

  @override
  State<PlaceDetailsForm> createState() => _PlaceDetailsFormState();
}

class _PlaceDetailsFormState extends State<PlaceDetailsForm> {
  final _customTag = TextEditingController();
  List<String> _aiTags = const [];
  bool _suggesting = false;

  PlaceDraft get _draft => widget.draft;

  @override
  void dispose() {
    _customTag.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (picked != null) _draft.setPhoto(picked);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(source == ImageSource.camera ? "Couldn't open the camera." : "Couldn't open your photos.")),
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.visited,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) _draft.setVisited(picked);
  }

  Future<void> _suggest() async {
    if (widget.title.isEmpty) return;
    setState(() => _suggesting = true);
    try {
      final tags = await AIService().suggestTags(title: widget.title, category: widget.category);
      if (mounted) setState(() => _aiTags = tags);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't suggest tags right now.")),
        );
      }
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  void _addCustomTag() {
    final tag = _customTag.text.trim();
    if (tag.isEmpty) return;
    if (!_draft.tags.contains(tag)) _draft.toggleTag(tag);
    _customTag.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) {
        final choices = <String>{..._draft.tags, ..._aiTags, ...suggestedTags}.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading(
              'Photo',
              trailing: _draft.photo != null
                  ? 'Your photo'
                  : _draft.savedPhotoUrls.isNotEmpty
                      ? 'Current photo'
                      : null,
            ),
            if (_draft.photo case final photo?)
              _Preview(image: LocalPhoto(file: photo), onRemove: () => _draft.setPhoto(null))
            else if (_draft.savedPhotoUrls.firstOrNull case final url?)
              _Preview(
                image: Image.network(url, fit: BoxFit.cover, width: double.infinity),
                onRemove: _draft.removeSavedPhoto,
              )
            else
              Row(
                children: [
                  Expanded(child: _PickTile(icon: Icons.photo_camera_outlined, label: 'Camera', onTap: () => _pick(ImageSource.camera))),
                  const SizedBox(width: 12),
                  Expanded(child: _PickTile(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: () => _pick(ImageSource.gallery))),
                ],
              ),
            const SizedBox(height: 20),
            const _Heading('Your rating'),
            Semantics(
              label: 'Your rating',
              value: '${_draft.rating} out of 5',
              child: Row(
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      tooltip: '$star ${star == 1 ? 'star' : 'stars'}',
                      onPressed: () => _draft.setRating(star),
                      icon: Icon(
                        star <= _draft.rating ? Icons.star : Icons.star_border,
                        size: 32,
                        color: const Color(0xFFF9C74F),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _Heading('Visited'),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: scheme.outlineVariant),
                  foregroundColor: scheme.onSurface,
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                onPressed: _pickDate,
                icon: Icon(Icons.calendar_today_outlined, size: 18, color: scheme.primary),
                label: Text(_visitedLabel(_draft.visited)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: _Heading('Tags')),
                TextButton.icon(
                  onPressed: _suggesting || widget.title.isEmpty ? null : _suggest,
                  icon: _suggesting
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Suggest'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in choices)
                  FilterChip(
                    label: Text(tag),
                    selected: _draft.tags.contains(tag),
                    onSelected: (_) => _draft.toggleTag(tag),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _customTag,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addCustomTag(),
              decoration: InputDecoration(
                hintText: 'Add your own tag',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(tooltip: 'Add tag', icon: const Icon(Icons.add), onPressed: _addCustomTag),
              ),
            ),
            const SizedBox(height: 20),
            const _Heading('Notes'),
            TextField(
              controller: _draft.notes,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What did you like? When is it best?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );
      },
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _visitedLabel(DateTime date) {
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Today';
  return '${_months[date.month - 1]} ${date.day}, ${date.year}';
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          if (trailing case final trailing?) ...[
            const Spacer(),
            Text(trailing, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 88,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.image, required this.onRemove});

  final Widget image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                tooltip: 'Remove photo',
                style: IconButton.styleFrom(backgroundColor: scheme.surface.withValues(alpha: 0.82)),
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
