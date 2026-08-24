import express from 'express';
import admin from 'firebase-admin';

const router = express.Router();
const db = admin.firestore();

// Upper bound on how many place documents a single stats/export request will
// read.  Without this each call is an unbounded collection scan.
const MAX_PLACES_SCAN = 1000;

// ═══════════════════════════════════════════════════════════════════════════
// USER PROFILE & SETTINGS ROUTES
// ═══════════════════════════════════════════════════════════════════════════

// ───────────────────────────────────────────────────────────────────────────
// GET /user/profile
// ───────────────────────────────────────────────────────────────────────────
/**
 * Get user profile data including settings
 */
router.get('/profile', async (req, res) => {
  try {
    const userId = req.user.uid;
    
    // Get user document from Firestore
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      // Create default profile if doesn't exist
      const defaultProfile = {
        userId,
        email: req.user.email,
        displayName: req.user.name || req.user.email?.split('@')[0],
        photoURL: req.user.picture || null,
        settings: {
          defaultRadius: 1000, // meters
          theme: 'dark',
          emailNotifications: true,
          pushNotifications: true,
          dataSharing: false,
        },
        stats: {
          totalPlaces: 0,
          favoriteCount: 0,
          categoriesUsed: 0,
          lastActive: new Date().toISOString(),
        },
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
      
      await db.collection('users').doc(userId).set(defaultProfile);
      return res.json(defaultProfile);
    }

    const profile = userDoc.data();
    res.json(profile);
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch profile' 
    });
  }
});

// ───────────────────────────────────────────────────────────────────────────
// PUT /user/profile
// ───────────────────────────────────────────────────────────────────────────
/**
 * Update user profile (display name, photo, etc.)
 */
router.put('/profile', async (req, res) => {
  try {
    const userId = req.user.uid;
    const { displayName, photoURL } = req.body;

    const updates = {
      updatedAt: new Date().toISOString(),
    };

    if (displayName !== undefined) updates.displayName = displayName;
    if (photoURL !== undefined) updates.photoURL = photoURL;

    // merge:true so a user who has never had a profile document created still
    // gets one — update() would throw NOT_FOUND instead.
    await db.collection('users').doc(userId).set(updates, { merge: true });

    console.log(`✅ Profile updated for user ${userId}`);
    res.json({ success: true, updates });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update profile' 
    });
  }
});

// ───────────────────────────────────────────────────────────────────────────
// GET /user/settings
// ───────────────────────────────────────────────────────────────────────────
/**
 * Get user settings
 */
router.get('/settings', async (req, res) => {
  try {
    const userId = req.user.uid;
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      return res.json({
        defaultRadius: 1000,
        theme: 'dark',
        emailNotifications: true,
        pushNotifications: true,
        dataSharing: false,
      });
    }

    const settings = userDoc.data().settings || {};
    res.json(settings);
  } catch (error) {
    console.error('Get settings error:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch settings' 
    });
  }
});

// ───────────────────────────────────────────────────────────────────────────
// PUT /user/settings
// ───────────────────────────────────────────────────────────────────────────
/**
 * Update user settings
 */
router.put('/settings', async (req, res) => {
  try {
    const userId = req.user.uid;
    const { defaultRadius, theme, emailNotifications, pushNotifications, dataSharing } = req.body;

    // Build settings object with only provided fields
    const settingsUpdate = {};
    if (defaultRadius !== undefined) settingsUpdate.defaultRadius = parseInt(defaultRadius);
    if (theme !== undefined) settingsUpdate.theme = theme;
    if (emailNotifications !== undefined) settingsUpdate.emailNotifications = emailNotifications;
    if (pushNotifications !== undefined) settingsUpdate.pushNotifications = pushNotifications;
    if (dataSharing !== undefined) settingsUpdate.dataSharing = dataSharing;

    // merge:true creates the document when it doesn't exist yet (update() throws
    // NOT_FOUND).  Note this needs a real nested object, not dotted `settings.x`
    // keys — those are an update()-only syntax.  Firestore merges nested maps
    // field-by-field, so settings the client didn't send survive.
    const updates = {
      settings: settingsUpdate,
      updatedAt: new Date().toISOString(),
    };

    await db.collection('users').doc(userId).set(updates, { merge: true });

    console.log(`✅ Settings updated for user ${userId}`);
    res.json({ success: true, settings: settingsUpdate });
  } catch (error) {
    console.error('Update settings error:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update settings' 
    });
  }
});

// ───────────────────────────────────────────────────────────────────────────
// POST /user/seed-demo
// ───────────────────────────────────────────────────────────────────────────
/**
 * Give a brand-new (typically anonymous) account something to look at.
 *
 * Deliberately photoless: the app renders a map of each place when it has no
 * photo, which looks better than stock imagery and keeps this endpoint free of
 * any Storage dependency. A visitor who wants to see the photo flow can add
 * their own place.
 */
const DEMO_PLACES = [
  {
    title: 'Blue Bottle Coffee', category: 'cafe', rating: 5, isFavorite: true,
    lat: 37.7955, lng: -122.3937, address: '1 Ferry Building, San Francisco, CA',
    tags: ['Hidden Gem', 'Great Views'],
    notes: 'Amazing pour over, got there at 8am and it was quiet. Pricey but worth it. The window seats look out over the bay. Gets packed by 10.',
  },
  {
    title: 'Golden Gate Park', category: 'park', rating: 4, isFavorite: false,
    lat: 37.7694, lng: -122.4862, address: '501 Stanyan St, San Francisco, CA',
    tags: ['Family Friendly', 'Quiet'],
    notes: 'Huge. Rent a bike near the entrance, walking the whole thing takes hours. The Japanese Tea Garden is worth the entry fee. Go on a weekday, weekends are packed.',
  },
  {
    title: 'Tartine Bakery', category: 'restaurant', rating: 5, isFavorite: true,
    lat: 37.7614, lng: -122.4241, address: '600 Guerrero St, San Francisco, CA',
    tags: ['Must Visit', 'Good Food'],
    notes: 'The morning bun is the thing to get. Line is long but moves fast. Cash only used to be true, not anymore. Get there before 9 or after 2.',
  },
  {
    title: 'SFMOMA', category: 'museum', rating: 4, isFavorite: false,
    lat: 37.7857, lng: -122.4011, address: '151 3rd St, San Francisco, CA',
    tags: ['Instagrammable'],
    notes: 'Seven floors, do not try to do it all in one visit. The living wall on floor 3 is the best photo spot. Free for under 18.',
  },
  {
    title: 'Alcatraz Island', category: 'other', rating: 5, isFavorite: false,
    lat: 37.8267, lng: -122.4230, address: 'Alcatraz Island, San Francisco, CA, USA',
    tags: ['Must Visit'],
    notes: 'Book the night tour, it sells out weeks ahead. The audio guide is genuinely good. Bring a jacket, the crossing is cold even in summer.',
  },
];

router.post('/seed-demo', async (req, res) => {
  try {
    const userId = req.user.uid;

    // Idempotent: never overwrite an account that already has content.
    const existing = await db.collection('places')
      .where('userId', '==', userId).limit(1).get();
    if (!existing.empty) {
      return res.json({ seeded: false, reason: 'account already has places' });
    }

    const now = Date.now();
    const batch = db.batch();
    DEMO_PLACES.forEach((p, i) => {
      const ref = db.collection('places').doc();
      batch.set(ref, {
        userId,
        title: p.title,
        photoUrls: [],
        lat: p.lat,
        lng: p.lng,
        address: p.address,
        category: p.category,
        tags: p.tags,
        notes: p.notes,
        rating: p.rating,
        isFavorite: p.isFavorite,
        visitDate: new Date(now - (i + 1) * 86400000).toISOString(),
        // Descending so the list order is stable and matches this array.
        createdAt: new Date(now - i * 1000).toISOString(),
      });
    });
    await batch.commit();

    console.log(`\u2705 Demo data seeded for user ${userId} (${DEMO_PLACES.length} places)`);
    res.json({ seeded: true, count: DEMO_PLACES.length });
  } catch (error) {
    console.error('Seed demo error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to seed demo data',
    });
  }
});

// ───────────────────────────────────────────────────────────────────────────
// GET /user/stats
// ───────────────────────────────────────────────────────────────────────────
/**
 * Get user statistics (computed from places)
 */
router.get('/stats', async (req, res) => {
  try {
    const userId = req.user.uid;
    
    // Query all places for this user
    const placesSnapshot = await db.collection('places')
      .where('userId', '==', userId)
      .limit(MAX_PLACES_SCAN)
      .get();

    const places = placesSnapshot.docs.map(doc => doc.data());

    const stats = {
      truncated: places.length === MAX_PLACES_SCAN,
      totalPlaces: places.length,
      favoriteCount: places.filter(p => p.isFavorite).length,
      categoriesUsed: new Set(places.map(p => p.category)).size,
      totalTags: new Set(places.flatMap(p => p.tags || [])).size,
      averageRating: places.length > 0 
        ? (places.reduce((sum, p) => sum + (p.rating || 0), 0) / places.length).toFixed(1)
        : 0,
      placesWithNotes: places.filter(p => p.notes && p.notes.trim().length > 0).length,
      oldestPlace: places.length > 0 
        ? places.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt))[0].createdAt
        : null,
      newestPlace: places.length > 0 
        ? places.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))[0].createdAt
        : null,
    };

    res.json(stats);
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to compute stats' 
    });
  }
});

// ───────────────────────────────────────────────────────────────────────────
// POST /user/export
// ───────────────────────────────────────────────────────────────────────────
/**
 * Export all user data as JSON
 */
router.post('/export', async (req, res) => {
  try {
    const userId = req.user.uid;
    
    // Get user profile
    const userDoc = await db.collection('users').doc(userId).get();
    const profile = userDoc.exists ? userDoc.data() : null;

    // Get all places
    const placesSnapshot = await db.collection('places')
      .where('userId', '==', userId)
      .limit(MAX_PLACES_SCAN)
      .get();

    const places = placesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    const exportData = {
      exportedAt: new Date().toISOString(),
      exportVersion: '1.0',
      user: {
        uid: userId,
        email: req.user.email,
        profile,
      },
      places,
      metadata: {
        totalPlaces: places.length,
        truncated: places.length === MAX_PLACES_SCAN,
        dataSize: JSON.stringify(places).length,
      }
    };

    console.log(`✅ Data exported for user ${userId} (${places.length} places)`);
    
    res.json(exportData);
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to export data' 
    });
  }
});

// ───────────────────────────────────────────────────────────────────────────
// DELETE /user/account
// ───────────────────────────────────────────────────────────────────────────
/**
 * Delete user account and all associated data
 */
router.delete('/account', async (req, res) => {
  try {
    const userId = req.user.uid;
    const { confirmEmail } = req.body;

    // Require email confirmation for safety
    if (confirmEmail !== req.user.email) {
      return res.status(400).json({ 
        error: 'Bad Request',
        message: 'Email confirmation does not match' 
      });
    }

    // Delete all places.  A Firestore batch caps at 500 writes, so page through
    // the collection in chunks rather than building one oversized batch.
    const BATCH_LIMIT = 500;
    let deleted = 0;
    for (;;) {
      const placesSnapshot = await db.collection('places')
        .where('userId', '==', userId)
        .limit(BATCH_LIMIT)
        .get();

      if (placesSnapshot.empty) break;

      const batch = db.batch();
      placesSnapshot.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
      deleted += placesSnapshot.size;

      if (placesSnapshot.size < BATCH_LIMIT) break;
    }

    // Delete user profile
    await db.collection('users').doc(userId).delete();

    // Delete Firebase Auth account
    await admin.auth().deleteUser(userId);

    console.log(`✅ Account deleted for user ${userId} (${deleted} places)`);
    
    res.json({ 
      success: true, 
      message: 'Account and all data deleted successfully' 
    });
  } catch (error) {
    console.error('Delete account error:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to delete account' 
    });
  }
});

export default router;
