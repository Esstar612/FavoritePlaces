import 'package:flutter_test/flutter_test.dart';

import 'package:favorite_places/models/place.dart';
import 'package:favorite_places/utils/evidence.dart';

Place _place({List<String> tags = const [], String notes = ''}) => Place(
      title: 't',
      tags: tags,
      notes: notes,
      location: const PlaceLocation(latitude: 0, longitude: 0, address: ''),
    );

void main() {
  test('a matching tag is the evidence', () {
    final evidence = evidenceFor(_place(tags: ['Family Friendly', 'Quiet']), 'somewhere quiet to work');

    expect((evidence as TagEvidence).tag, 'Quiet');
  });

  test('otherwise the clause of the note that matches', () {
    final evidence = evidenceFor(
      _place(
        tags: ['Hidden Gem'],
        notes: 'Amazing pour over, got there at 8am and it was quiet. Pricey but worth it.',
      ),
      'somewhere quiet to work',
    );

    expect((evidence as NoteEvidence).excerpt, 'got there at 8am and it was quiet');
  });

  test('plurals match their singular', () {
    final evidence = evidenceFor(_place(tags: ['Great Views']), 'a view');

    expect((evidence as TagEvidence).tag, 'Great Views');
  });

  test('filler words alone never match', () {
    expect(evidenceFor(_place(tags: ['Great Views'], notes: 'A great spot.'), 'somewhere great'), isNull);
  });

  test('no match gives no evidence', () {
    expect(evidenceFor(_place(tags: ['Loud'], notes: 'Busy all day.'), 'quiet'), isNull);
  });
}
