import express from 'express';
import { GoogleGenerativeAI } from '@google/generative-ai';
import vision from '@google-cloud/vision';

const router = express.Router();

// ═══════════════════════════════════════════════════════════════════════════
// GOOGLE GEMINI CLIENT
// ═══════════════════════════════════════════════════════════════════════════
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash-lite' });

// ═══════════════════════════════════════════════════════════════════════════
// GOOGLE CLOUD VISION CLIENT (optional, for advanced image analysis)
// ═══════════════════════════════════════════════════════════════════════════
let visionClient;
try {
  visionClient = new vision.ImageAnnotatorClient();
  console.log('✅ Google Cloud Vision API initialized');
} catch (error) {
  console.warn('⚠️  Google Cloud Vision API not configured (optional feature)');
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Call Gemini API with error handling
 */
async function callGemini(prompt) {
  try {
    const result = await model.generateContent(prompt);
    const response = await result.response;
    return response.text();
  } catch (error) {
    console.error('Gemini API error:', error);
    throw new Error(`AI service error: ${error.message}`);
  }
}

/**
 * Extract JSON from Gemini's response (handles markdown code blocks)
 */
function parseJSON(text) {
  // Remove markdown code blocks if present
  const jsonMatch = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/) || text.match(/{[\s\S]*}/);
  
  if (jsonMatch) {
    const jsonStr = jsonMatch[1] || jsonMatch[0];
    return JSON.parse(jsonStr);
  }
  
  // Try parsing as-is
  return JSON.parse(text);
}

// ═══════════════════════════════════════════════════════════════════════════
// AI ROUTES
// ═══════════════════════════════════════════════════════════════════════════

// ───────────────────────────────────────────────────────────────────────────
// POST /ai/summarize-notes
// ───────────────────────────────────────────────────────────────────────────
/**
 * Takes raw notes about a place and generates a structured summary with:
 * - Why I liked it
 * - Tips for visitors
 * - Best time to go
 */
router.post('/summarize-notes', async (req, res) => {
  try {
    const { title, notes, category, address } = req.body;

    // Validation
    if (!notes || notes.trim().length === 0) {
      return res.status(400).json({ 
        error: 'Bad Request', 
        message: 'Notes field is required' 
      });
    }

    const prompt = `You are an expert at analyzing travel notes and creating structured summaries. 
Your job is to take raw, unstructured notes about a place and organize them into three clear sections.

Return ONLY valid JSON in this exact format (no other text, no markdown):
{
  "whyILikedIt": "A concise 1-2 sentence explanation of what made this place special",
  "tips": "Practical advice for future visitors (2-3 sentences)",
  "bestTimeToGo": "When to visit (time of day, season, or conditions)"
}

Keep each field brief and actionable. If the notes don't contain info for a field, use your best judgment based on the place type.

Place: ${title}
Category: ${category}
Location: ${address}

Raw notes:
${notes}

Create a structured summary following the JSON format specified.`;

    const response = await callGemini(prompt);
    const summary = parseJSON(response);

    // Log for monitoring
    console.log(`✅ Notes summarized for user ${req.user.uid}: ${title}`);

    res.json(summary);
  } catch (error) {
    console.error('Summarize notes error:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to generate summary',
      ...(process.env.NODE_ENV === 'development' && { details: error.message })
    });
  }
});

// ───────────────────────────────────────────────────────────────────────────
// POST /ai/suggest-tags
// ───────────────────────────────────────────────────────────────────────────
/**
 * Analyzes a photo URL and suggests relevant tags.
 * Uses Google Cloud Vision for image analysis + Gemini for intelligent tag generation.
 */
router.post('/suggest-tags', async (req, res) => {
  try {
    const { photoUrl, title, category } = req.body;

    if (!photoUrl) {
      return res.status(400).json({ 
        error: 'Bad Request', 
        message: 'photoUrl is required' 
      });
    }

    let imageDescription = '';

    // Try Google Cloud Vision first (if available)
    if (visionClient) {
      try {
        const [result] = await visionClient.annotateImage({
          image: { source: { imageUri: photoUrl } },
          features: [
            { type: 'LABEL_DETECTION', maxResults: 10 },
            { type: 'LANDMARK_DETECTION', maxResults: 5 },
            { type: 'IMAGE_PROPERTIES' },
          ],
        });

        const labels = result.labelAnnotations?.map(l => l.description) || [];
        const landmarks = result.landmarkAnnotations?.map(l => l.description) || [];
        const colors = result.imagePropertiesAnnotation?.dominantColors?.colors
          ?.slice(0, 3)
          .map(c => {
            const rgb = `rgb(${c.color.red},${c.color.green},${c.color.blue})`;
            return `${(c.score * 100).toFixed(0)}%`;
          }) || [];

        imageDescription = `
Labels detected: ${labels.join(', ')}
Landmarks: ${landmarks.length > 0 ? landmarks.join(', ') : 'none'}
Dominant colors: ${colors.join(', ')}`;
      } catch (visionError) {
        console.warn('Vision API failed, falling back to Gemini-only:', visionError.message);
      }
    }

    // Use Gemini to generate smart tags
    const prompt = `You are an expert at analyzing images and generating relevant, useful tags for a places app.
Based on the image analysis data and place context, suggest 5-8 relevant tags that would help users categorize and search for this place.

Focus on:
- Atmosphere (cozy, modern, rustic, vibrant, etc.)
- Activities (dining, photography, relaxation, etc.)
- Audience (family-friendly, romantic, group-friendly, solo-friendly, etc.)
- Characteristics (indoor/outdoor, quiet/lively, budget-friendly/upscale, etc.)

Return ONLY valid JSON in this format (no other text, no markdown):
{
  "tags": ["tag1", "tag2", "tag3", ...]
}

Keep tags short (1-2 words each) and practical.

Place: ${title || 'Unknown'}
Category: ${category || 'General'}
${imageDescription ? `\nImage analysis:\n${imageDescription}` : ''}

Suggest relevant tags for this place.`;

    const response = await callGemini(prompt);
    const result = parseJSON(response);

    // Ensure we return an array
    const tags = Array.isArray(result.tags) ? result.tags : [];

    console.log(`✅ Tags suggested for user ${req.user.uid}: ${title} (${tags.length} tags)`);

    res.json({ tags });
  } catch (error) {
    console.error('Suggest tags error:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to generate tags',
      ...(process.env.NODE_ENV === 'development' && { details: error.message })
    });
  }
});

// ───────────────────────────────────────────────────────────────────────────
// POST /ai/smart-search
// ───────────────────────────────────────────────────────────────────────────
/**
 * Natural language search - user asks questions like "where did I eat pasta?"
 * Gemini interprets the query and returns matching place IDs from Firestore.
 */
router.post('/smart-search', async (req, res) => {
  try {
    const { query, places } = req.body;

    if (!query || !places || !Array.isArray(places)) {
      return res.status(400).json({ 
        error: 'Bad Request', 
        message: 'query and places array are required' 
      });
    }

    const prompt = `You are a smart search assistant for a places app.
Given a natural language query and a list of places, identify which places best match the user's intent.

Return ONLY valid JSON in this format (no other text, no markdown):
{
  "matchingIds": ["place-id-1", "place-id-2", ...],
  "explanation": "Brief explanation of why these places match"
}

If no places match, return empty array with explanation.

User query: "${query}"

Available places:
${places.map(p => `ID: ${p.id} | Title: ${p.title} | Category: ${p.category} | Tags: ${p.tags?.join(', ') || 'none'} | Notes: ${p.notes?.substring(0, 100) || 'none'}`).join('\n')}

Which places match the query?`;

    const response = await callGemini(prompt);
    const result = parseJSON(response);

    console.log(`✅ Smart search for user ${req.user.uid}: "${query}" (${result.matchingIds?.length || 0} matches)`);

    res.json(result);
  } catch (error) {
    console.error('Smart search error:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to process search',
      ...(process.env.NODE_ENV === 'development' && { details: error.message })
    });
  }
});

export default router;