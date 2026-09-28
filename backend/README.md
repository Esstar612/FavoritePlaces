# Favorite Places Backend API

Full-featured Node.js + Express backend for the Favorite Places Flutter app with Firebase Authentication, Firestore integration, and AI-powered features using Google Gemini.

## 🚀 Features

### Authentication
- ✅ Firebase ID token verification
- ✅ Secure user authentication middleware
- ✅ Per-user data isolation

### AI Features (Powered by Google Gemini)
- ✅ **Smart Notes Summarization** - Transform raw notes into structured summaries
- ✅ **Intelligent Tag Suggestions** - AI analyzes photos and context to suggest relevant tags
- ✅ **Natural Language Search** - Ask questions like "where did I eat pasta?" (optional)

### User Management
- ✅ User profile management
- ✅ Settings (default radius, theme, notifications)
- ✅ Statistics dashboard
- ✅ Data export (JSON)
- ✅ Account deletion

### Infrastructure
- ✅ Rate limiting (prevents abuse)
- ✅ CORS configuration
- ✅ Security headers (Helmet)
- ✅ Response compression
- ✅ Structured error handling
- ✅ Health check endpoints

---

## 📋 Prerequisites

1. **Node.js** 20+ ([download](https://nodejs.org/))
2. **Firebase Project** with:
   - Authentication enabled
   - Firestore database created
   - Storage bucket created
3. **Google Cloud SDK** ([install](https://cloud.google.com/sdk/docs/install)), signed in to the project
4. **Vertex AI API** enabled on the project: `gcloud services enable aiplatform.googleapis.com`
5. **(Optional)** Google Cloud Vision API enabled for advanced image tagging

---

## 🛠️ Installation

### Step 1: Install Dependencies

```bash
cd backend
npm install
```

### Step 2: Configure Environment Variables

```bash
cp .env.example .env
```

Edit `.env`:

```env
# Required
PORT=3000
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_MAPS_SERVER_KEY=your-geocoding-key-here

# Optional
GOOGLE_CLOUD_LOCATION=us-central1
CORS_ORIGIN=http://localhost:5050
NODE_ENV=development
```

### Step 3: Sign In with Application Default Credentials

There are no key files. Gemini (through Vertex AI) and Firebase Admin both use
Application Default Credentials: your own gcloud login locally, and the Cloud Run
service account in production.

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project your-project-id
```

Your account needs the same access as the production service account (see
Deployment). A project Owner already has it.

### Step 4: Start the Server

**Development mode** (with auto-reload):
```bash
npm run dev
```

**Production mode**:
```bash
npm start
```

✅ Success! The server will start on `http://localhost:3000`

You should see:
```
✅ Firebase Admin initialized
✅ Google Cloud Vision API initialized (or warning if not configured)

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🚀 Favorite Places Backend Server                          ║
║                                                               ║
║   Status:  ✅ Running                                        ║
║   Port:    3000                                              ║
║   Env:     development                                       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 📡 API Endpoints

### Health Check

```http
GET /
GET /health
```

Returns server status and uptime.

**Response:**
```json
{
  "status": "healthy",
  "uptime": 12345.67,
  "timestamp": "2026-02-04T12:00:00.000Z"
}
```

### AI Features

All AI routes require authentication (Bearer token in Authorization header).

#### 1. Summarize Notes

Transforms raw, unstructured notes into a clean, organized summary.

```http
POST /ai/summarize-notes
Authorization: Bearer <firebase-id-token>
Content-Type: application/json

{
  "title": "Central Park",
  "notes": "Beautiful park in Manhattan. Lots of people jogging. Great for picnics. Best in spring when flowers bloom.",
  "category": "park",
  "address": "New York, NY"
}
```

**Response:**
```json
{
  "whyILikedIt": "A sprawling urban oasis perfect for outdoor activities and relaxation in the heart of Manhattan.",
  "tips": "Visit during spring for the best flower displays. Arrive early morning on weekends to avoid crowds. Bring a blanket for picnics.",
  "bestTimeToGo": "Spring mornings or early fall afternoons"
}
```

#### 2. Suggest Tags

AI analyzes photo and context to suggest relevant, useful tags.

```http
POST /ai/suggest-tags
Authorization: Bearer <firebase-id-token>
Content-Type: application/json

{
  "photoUrl": "https://storage.googleapis.com/your-bucket/photos/abc123.jpg",
  "title": "Cozy Italian Restaurant",
  "category": "restaurant"
}
```

**Response:**
```json
{
  "tags": [
    "Romantic",
    "Italian Cuisine",
    "Date Night",
    "Warm Ambiance",
    "Intimate",
    "Urban",
    "Indoor"
  ]
}
```

**Note:** If Google Cloud Vision is configured, it will analyze the image first for better tag suggestions.

#### 3. Smart Search (Optional Feature)

Natural language search across your places.

```http
POST /ai/smart-search
Authorization: Bearer <firebase-id-token>
Content-Type: application/json

{
  "query": "where did I have amazing pasta?",
  "places": [
    {
      "id": "place-1",
      "title": "Mario's Trattoria",
      "category": "restaurant",
      "tags": ["Italian", "Pasta"],
      "notes": "Best carbonara ever!"
    },
    {
      "id": "place-2",
      "title": "Central Park",
      "category": "park",
      "tags": ["Outdoor"],
      "notes": "Nice walk"
    }
  ]
}
```

**Response:**
```json
{
  "matchingIds": ["place-1"],
  "explanation": "Mario's Trattoria matches because it's an Italian restaurant where you specifically mentioned having great pasta (carbonara)."
}
```

### User Management

#### Get Profile

```http
GET /user/profile
Authorization: Bearer <firebase-id-token>
```

**Response:**
```json
{
  "uid": "user123",
  "displayName": "John Doe",
  "email": "john@example.com",
  "photoURL": "https://example.com/photo.jpg",
  "createdAt": "2026-01-01T00:00:00.000Z"
}
```

#### Update Profile

```http
PUT /user/profile
Authorization: Bearer <firebase-id-token>
Content-Type: application/json

{
  "displayName": "John Doe",
  "photoURL": "https://example.com/photo.jpg"
}
```

#### Get Settings

```http
GET /user/settings
Authorization: Bearer <firebase-id-token>
```

**Response:**
```json
{
  "defaultRadius": 5000,
  "theme": "dark",
  "emailNotifications": true,
  "pushNotifications": true,
  "shareData": false
}
```

#### Update Settings

```http
PUT /user/settings
Authorization: Bearer <firebase-id-token>
Content-Type: application/json

{
  "defaultRadius": 2000,
  "theme": "light",
  "emailNotifications": false
}
```

#### Get Statistics

```http
GET /user/stats
Authorization: Bearer <firebase-id-token>
```

**Response:**
```json
{
  "totalPlaces": 42,
  "favoriteCount": 15,
  "categoriesUsed": 8,
  "totalTags": 67,
  "averageRating": 4.2,
  "placesWithNotes": 38,
  "oldestPlace": "2024-01-15T10:30:00.000Z",
  "newestPlace": "2026-02-03T15:45:00.000Z"
}
```

#### Export Data

```http
POST /user/export
Authorization: Bearer <firebase-id-token>
```

Returns complete user data as JSON (profile, places, settings).

#### Delete Account

```http
DELETE /user/account
Authorization: Bearer <firebase-id-token>
Content-Type: application/json

{
  "confirmEmail": "user@example.com"
}
```

⚠️ **Warning:** This permanently deletes the user account and all associated data (places, photos, settings).

---

## 🚢 Deployment

### Google Cloud Run

The service runs as its own service account and holds no API keys or service
account keys. Access to Vertex AI, Firestore and Firebase Auth comes from IAM
roles on that account.

#### One-time setup

```bash
PROJECT=your-project-id
SA=places-backend-runtime@$PROJECT.iam.gserviceaccount.com

gcloud services enable aiplatform.googleapis.com
gcloud iam service-accounts create places-backend-runtime --display-name "Places backend runtime"
for role in roles/aiplatform.user roles/datastore.user roles/firebaseauth.admin; do
  gcloud projects add-iam-policy-binding $PROJECT --member serviceAccount:$SA --role $role --condition None
done
```

| Role | Used for |
|---|---|
| `roles/aiplatform.user` | Gemini calls through Vertex AI |
| `roles/datastore.user` | Firestore reads and writes |
| `roles/firebaseauth.admin` | Deleting the Firebase Auth user on account deletion |

Verifying ID tokens needs no role.

#### Deploy

From `backend/`:

```bash
gcloud run deploy favorite-places-backend --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --service-account $SA \
  --update-env-vars NODE_ENV=production,GOOGLE_CLOUD_PROJECT=$PROJECT,GOOGLE_CLOUD_LOCATION=us-central1,GOOGLE_MAPS_SERVER_KEY=...
```

Then point the app at the service URL in `mobile/lib/config.dart` (`backendUrl`).

---

## 🔒 Security Considerations

1. **Credentials**
   - No service account keys or Gemini API keys. Locally the server uses your gcloud login, and on Cloud Run its own service account
   - Never commit `.env`
   - Use `.env.example` as a template

2. **HTTPS in Production**
   - Required for secure token transmission
   - Use Cloud Run (auto HTTPS) or Let's Encrypt

3. **CORS Configuration**
   - Development: `CORS_ORIGIN=*`
   - Production: `CORS_ORIGIN=https://your-app.web.app`

4. **Rate Limiting**
   - Already configured: 100 requests per 15 minutes
   - Adjust in `.env` if needed:
     ```env
     RATE_LIMIT_WINDOW_MS=900000
     RATE_LIMIT_MAX_REQUESTS=100
     ```

5. **IAM**
   - The runtime service account has only the three roles listed under Deployment
   - Review Vertex AI usage in the Cloud Console under Vertex AI

6. **Firebase Rules**
   - Ensure Firestore security rules are properly configured
   - Users should only access their own data

---

## 🧪 Testing

### Manual Testing with cURL

```bash
# 1. Get a Firebase ID token
# (In your Flutter app, print: await user.getIdToken())
export TOKEN="eyJhbGciOiJSUzI1NiIsImtp..."

# 2. Test health check
curl http://localhost:3000/health

# 3. Test summarize notes
curl -X POST http://localhost:3000/ai/summarize-notes \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Awesome Restaurant",
    "notes": "Great food, friendly staff, cozy atmosphere",
    "category": "restaurant",
    "address": "123 Main St"
  }'

# 4. Test tag suggestions
curl -X POST http://localhost:3000/ai/suggest-tags \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "photoUrl": "https://example.com/photo.jpg",
    "title": "Central Park",
    "category": "park"
  }'

# 5. Test user stats
curl -X GET http://localhost:3000/user/stats \
  -H "Authorization: Bearer $TOKEN"
```

### Automated Testing

Create `tests/` directory with Jest:

```bash
npm install --save-dev jest supertest
```

Example test file (`tests/health.test.js`):

```javascript
const request = require('supertest');
const app = require('../server');

describe('Health Endpoints', () => {
  it('should return healthy status', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
  });
});
```

---

## 📊 Monitoring

### Local Development

Logs print to console with color coding:
- ✅ Green: Success messages
- ⚠️ Yellow: Warnings
- ❌ Red: Errors

### Production (Cloud Run)

View logs:
```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=favorite-places-backend" \
  --limit 50
```

Stream live logs:
```bash
gcloud run services logs tail favorite-places-backend
```

### Metrics to Monitor

- **Latency**: Target < 2s for AI endpoints
- **Error rate**: Should be < 1%
- **Memory usage**: Monitor for leaks
- **Vertex AI quota**: Check usage under Vertex AI in the Cloud Console

### Set Up Alerts (Cloud Run)

1. Go to Cloud Monitoring
2. Create alerts for:
   - Error rate > 5%
   - Average latency > 3s
   - Memory usage > 80%

---

## 🐛 Troubleshooting

### "Unauthorized" errors

**Symptom:** 401 Unauthorized on all protected routes

**Causes:**
- Invalid or expired Firebase ID token
- Missing `Authorization` header
- Token not prefixed with `Bearer `

**Fixes:**
- Ensure Flutter app calls `await user.getIdToken()` before each request
- Check header format: `Authorization: Bearer <token>`
- Verify Firebase project ID matches in both app and backend

### "AI service error: 403" or permission denied

**Symptom:** AI endpoints fail with a permission error

**Causes:**
- Vertex AI API not enabled on the project
- The caller lacks `roles/aiplatform.user` (your account locally, the runtime service account on Cloud Run)

**Fixes:**
- `gcloud services enable aiplatform.googleapis.com`
- Grant `roles/aiplatform.user` to the account
- Locally, rerun `gcloud auth application-default login`

### "AI service error: 429"

**Symptom:** Too many requests error

**Causes:**
- Vertex AI quota for the model exceeded

**Fixes:**
- Check quotas under Vertex AI in the Cloud Console
- Add user-side debouncing

### "GOOGLE_CLOUD_PROJECT is not set"

**Symptom:** Server exits on startup

**Fix:** Set `GOOGLE_CLOUD_PROJECT` in `.env` locally, or with `--update-env-vars` on Cloud Run.

### CORS errors from Flutter app

**Symptom:** Browser console shows CORS errors

**Causes:**
- Origin not allowed
- Missing CORS headers

**Fixes:**
- Development: `CORS_ORIGIN=*`
- Production: `CORS_ORIGIN=https://your-app.web.app`
- Restart server after changing `.env`

### Google Cloud Vision errors (Optional)

**Symptom:** Warning on startup or tag suggestions fail

**Causes:**
- Vision API not enabled
- Credentials not configured

**Fixes:**
- This is optional! App works without it
- To enable: `gcloud services enable vision.googleapis.com`
- Or ignore - Gemini still generates tags without Vision API

---

## 🔄 Maintenance & Updates

### Update Dependencies

```bash
# Check for outdated packages
npm outdated

# Update all dependencies
npm update

# Update specific package
npm update express

# Check for security vulnerabilities
npm audit
npm audit fix
```

### Update Gemini Model

The model name is set in `callGemini` in `routes/ai.js`. Check that a new model
is available on Vertex AI in `GOOGLE_CLOUD_LOCATION` before switching.

### Add New Routes

1. Create new file in `routes/`:
   ```javascript
   // routes/newFeature.js
   import express from 'express';
   const router = express.Router();
   
   router.get('/endpoint', async (req, res) => {
     // Your code here
   });
   
   export default router;
   ```

2. Import and use in `server.js`:
   ```javascript
   import newFeatureRoutes from './routes/newFeature.js';
   app.use('/new-feature', authenticateUser, newFeatureRoutes);
   ```

### Database Migrations

If Firestore schema changes:

1. Create migration script
2. Run against production with caution
3. Test thoroughly in development first

---

## 📈 Scaling Considerations

### When to Scale

Monitor and consider scaling when:
- Consistent latency > 2s
- Error rate > 1%

### Scaling Options

1. **Caching** (Easy)
   - Cache AI responses for common queries
   - Use Redis or Firestore for cache storage

2. **Request Batching** (Medium)
   - Batch multiple AI requests together
   - Reduce per-request overhead

3. **Horizontal Scaling** (Advanced)
   - Cloud Run auto-scales automatically
   - No code changes needed

---

## 📝 License

MIT License

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Follow existing code style
4. Add tests for new features
5. Update documentation
6. Commit changes (`git commit -m 'Add amazing feature'`)
7. Push to branch (`git push origin feature/amazing`)
8. Open Pull Request

---

## 📞 Support

- **Issues:** Open an issue on GitHub
- **Questions:** Check existing issues or documentation
- **Gemini API:** https://ai.google.dev/docs
- **Firebase:** https://firebase.google.com/docs

---

**Built with ❤️ using Node.js, Express, Firebase, and Google Gemini AI**

**Total Cost: $0/month** 🎉