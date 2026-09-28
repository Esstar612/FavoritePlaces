import express from 'express';

const router = express.Router();

/**
 * Reverse geocoding proxy.
 *
 * The Geocoding web service refuses HTTP-referrer-restricted keys ("API keys
 * with referer restrictions cannot be used with this API"), so a browser
 * cannot call it with the referrer-locked web key. Rather than ship a second,
 * unrestricted key to the client for this one call, it runs here — the key
 * stays server-side and neither client carries a geocoding-capable key.
 */
router.get('/reverse-geocode', async (req, res) => {
  try {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);

    if (!Number.isFinite(lat) || !Number.isFinite(lng) ||
        lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'lat and lng must be valid coordinates',
      });
    }

    const key = process.env.GOOGLE_MAPS_SERVER_KEY;
    if (!key) {
      console.error('GOOGLE_MAPS_SERVER_KEY is not set');
      return res.status(503).json({
        error: 'Service Unavailable',
        message: 'Geocoding is not configured',
      });
    }

    const geocode = async (resultType) => {
      const filter = resultType ? `&result_type=${encodeURIComponent(resultType)}` : '';
      const response = await fetch(
        `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}${filter}&key=${key}`,
      );
      return response.json();
    };

    // Google's first unfiltered result can be a nearby park or landmark rather
    // than the street the pin is on. A pin inside a park or on a beach has no
    // street-level result, so it falls back to the unfiltered lookup.
    let body = await geocode('street_address|premise|route');
    if (body.status === 'ZERO_RESULTS') body = await geocode();

    if (body.status !== 'OK' || !body.results?.length) {
      // Caller falls back to showing coordinates; this isn't an error state.
      return res.json({ address: null, status: body.status });
    }

    res.json({
      address: body.results[0].formatted_address,
      status: 'OK',
    });
  } catch (error) {
    console.error('Reverse geocode error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to look up address',
    });
  }
});

export default router;
