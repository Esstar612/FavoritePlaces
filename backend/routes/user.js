import express from 'express';
import admin from 'firebase-admin';

const router = express.Router();
const db = admin.firestore();

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

    await db.collection('users').doc(userId).update(updates);

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

    const updates = {
      updatedAt: new Date().toISOString(),
    };

    // Build settings object with only provided fields
    const settingsUpdate = {};
    if (defaultRadius !== undefined) settingsUpdate.defaultRadius = parseInt(defaultRadius);
    if (theme !== undefined) settingsUpdate.theme = theme;
    if (emailNotifications !== undefined) settingsUpdate.emailNotifications = emailNotifications;
    if (pushNotifications !== undefined) settingsUpdate.pushNotifications = pushNotifications;
    if (dataSharing !== undefined) settingsUpdate.dataSharing = dataSharing;

    // Update nested settings fields
    Object.keys(settingsUpdate).forEach(key => {
      updates[`settings.${key}`] = settingsUpdate[key];
    });

    await db.collection('users').doc(userId).update(updates);

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
      .get();

    const places = placesSnapshot.docs.map(doc => doc.data());

    const stats = {
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

    // Delete all places
    const placesSnapshot = await db.collection('places')
      .where('userId', '==', userId)
      .get();
    
    const batch = db.batch();
    placesSnapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    // Delete user profile
    await db.collection('users').doc(userId).delete();

    // Delete Firebase Auth account
    await admin.auth().deleteUser(userId);

    console.log(`✅ Account deleted for user ${userId}`);
    
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
