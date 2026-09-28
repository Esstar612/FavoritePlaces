import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/services/firestore_service.dart';

void main() {
  test("deleting samples removes only this user's sample places", () async {
    final db = FakeFirebaseFirestore();
    final places = db.collection('places');
    await places.doc('sample-1').set({'userId': 'me', 'isSample': true});
    await places.doc('sample-2').set({'userId': 'me', 'isSample': true});
    await places.doc('mine').set({'userId': 'me', 'title': 'Added as a guest'});
    await places.doc('theirs').set({'userId': 'someone-else', 'isSample': true});

    final removed = await FirestoreService.deleteSamplePlaces(db: db, uid: 'me');

    expect(removed, 2);
    final left = (await places.get()).docs.map((d) => d.id);
    expect(left, unorderedEquals(['mine', 'theirs']));
  });

  test('both account-exists codes are recognised, other errors are not', () {
    expect(isAccountExistsError(FirebaseAuthException(code: 'email-already-in-use')), isTrue);
    expect(isAccountExistsError(FirebaseAuthException(code: 'credential-already-in-use')), isTrue);
    expect(isAccountExistsError(FirebaseAuthException(code: 'wrong-password')), isFalse);
    expect(isAccountExistsError(Exception('offline')), isFalse);
  });
}
