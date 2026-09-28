import 'package:favorite_places/models/place.dart';

const _ignored = {
  'a', 'an', 'and', 'the', 'to', 'for', 'of', 'in', 'on', 'at', 'with', 'or', 'is', 'it',
  'somewhere', 'place', 'places', 'spot', 'spots', 'something', 'some', 'where', 'that',
  'this', 'good', 'nice', 'great', 'best', 'like', 'want', 'from', 'your', 'my', 'me',
};

sealed class Evidence {
  const Evidence();
}

class TagEvidence extends Evidence {
  const TagEvidence(this.tag);

  final String tag;
}

class NoteEvidence extends Evidence {
  const NoteEvidence(this.excerpt);

  final String excerpt;
}

Set<String> _words(String text) => {
      for (final word in text.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
        if (word.isNotEmpty) _singular(word),
    };

String _singular(String word) =>
    word.length > 3 && word.endsWith('s') ? word.substring(0, word.length - 1) : word;

final _ignoredWords = _words(_ignored.join(' '));

Evidence? evidenceFor(Place place, String query) {
  final wanted = _words(query).difference(_ignoredWords);
  if (wanted.isEmpty) return null;
  for (final tag in place.tags) {
    if (_words(tag).intersection(wanted).isNotEmpty) return TagEvidence(tag);
  }
  for (final clause in place.notes.split(RegExp(r'[.,;!?\n]'))) {
    final text = clause.trim();
    if (text.isNotEmpty && _words(text).intersection(wanted).isNotEmpty) return NoteEvidence(text);
  }
  return null;
}
