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

1. **Node.js** 18+ ([download](https://nodejs.org/))
2. **Firebase Project** with:
   - Authentication enabled
   - Firestore database created
   - Storage bucket created
   - Service Account key downloaded
3. **Google Gemini API Key** ([get one here](https://aistudio.google.com/app/apikey)) - **FREE!**
4. **(Optional)** Google Cloud Vision API enabled for advanced image tagging

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

Edit `.env` and fill in your credentials:

```env
# Required
PORT=3000
GEMINI_API_KEY=your-gemini-api-key-here
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json

# Optional
GOOGLE_APPLICATION_CREDENTIALS=./google-cloud-key.json
CORS_ORIGIN=*
NODE_ENV=development
```

### Step 3: Get Google Gemini API Key (100% FREE!)

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Sign in with your Google account
3. Click **"Create API Key"**
4. Copy the key and add to `.env`:
   ```env
   GEMINI_API_KEY=your-key-here
   ```

**Free Tier Benefits:**
- ✅ 1.5 million requests per month
- ✅ No credit card required
- ✅ Rate limits: 15 requests/minute, 1,500/day
- ✅ Perfect for personal projects!

### Step 4: Add Firebase Service Account

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project → **Project Settings** → **Service Accounts**
3. Click **Generate new private key**
4. Save the JSON file as `serviceAccountKey.json` in the `backend/` directory

⚠️ **Important:** Never commit this file to git!

### Step 5: Start the Server

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

### Option 1: Google Cloud Run (Recommended)

Perfect for this backend - serverless, auto-scaling, and Firebase-native.

#### Prerequisites
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed
- Billing enabled on your GCP project (still uses free tier for low traffic)

#### Deploy Steps

1. **Create Dockerfile** (if not already present):

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["node", "server.js"]
```

2. **Build and deploy:**

```bash
# Build container
gcloud builds submit --tag gcr.io/YOUR-PROJECT-ID/favorite-places-backend

# Deploy to Cloud Run
gcloud run deploy favorite-places-backend \
  --image gcr.io/YOUR-PROJECT-ID/favorite-places-backend \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "NODE_ENV=production" \
  --set-secrets "GEMINI_API_KEY=gemini-key:latest,FIREBASE_CONFIG=firebase-config:latest"
```

3. **Create secrets:**

```bash
# Store Gemini API key as secret
echo -n "your-gemini-api-key" | gcloud secrets create gemini-key --data-file=-

# Store Firebase config as secret
cat serviceAccountKey.json | gcloud secrets create firebase-config --data-file=-
```

4. **Update Flutter app:**

```dart
// mobile/lib/config.dart
static const String backendUrl = 'https://your-service-xxxxx.a.run.app';
```

### Option 2: Heroku

```bash
# Install Heroku CLI and login
heroku login

# Create app
heroku create your-app-name

# Set environment variables
heroku config:set GEMINI_API_KEY=your-key
heroku config:set NODE_ENV=production
heroku config:set FIREBASE_CONFIG='paste-entire-service-account-json'

# Deploy
git push heroku main
```

### Option 3: VPS (DigitalOcean, AWS EC2, Linode)

1. SSH into your server
2. Install Node.js 18+:
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```
3. Clone repository
4. Copy `.env` and `serviceAccountKey.json`
5. Install PM2:
   ```bash
   sudo npm install -g pm2
   pm2 start server.js --name favorite-places-backend
   pm2 startup
   pm2 save
   ```
6. Configure Nginx reverse proxy:
   ```nginx
   server {
       listen 80;
       server_name yourdomain.com;
       
       location / {
           proxy_pass http://localhost:3000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
       }
   }
   ```
7. Install SSL with Let's Encrypt:
   ```bash
   sudo certbot --nginx -d yourdomain.com
   ```

---

## 🔒 Security Considerations

1. **Environment Variables**
   - Never commit `.env` or `serviceAccountKey.json`
   - Use `.env.example` as a template
   - Rotate API keys regularly

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

5. **API Key Security**
   - Gemini API key is free but should still be protected
   - Monitor usage at https://aistudio.google.com/

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

- **Request count**: Ensure within Gemini free tier (1.5M/month)
- **Latency**: Target < 2s for AI endpoints
- **Error rate**: Should be < 1%
- **Memory usage**: Monitor for leaks
- **API quota**: Check Gemini usage at https://aistudio.google.com/

### Set Up Alerts (Cloud Run)

1. Go to Cloud Monitoring
2. Create alerts for:
   - Error rate > 5%
   - Average latency > 3s
   - Memory usage > 80%
   - Request rate approaching Gemini limits

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

### "AI service error: 401"

**Symptom:** AI endpoints fail with authentication error

**Causes:**
- Invalid Gemini API key
- API key not set in environment

**Fixes:**
- Verify `GEMINI_API_KEY` in `.env`
- Regenerate key at https://aistudio.google.com/app/apikey
- Restart server after updating `.env`

### "AI service error: 429"

**Symptom:** Too many requests error

**Causes:**
- Exceeded Gemini rate limits (15/min or 1,500/day)

**Fixes:**
- Implement request caching
- Add user-side debouncing
- Consider upgrading to paid tier if needed (unlikely)

### "Failed to initialize Firebase Admin"

**Symptom:** Server crashes on startup

**Causes:**
- `serviceAccountKey.json` not found
- Invalid service account JSON
- Wrong path in `.env`

**Fixes:**
- Verify file exists: `ls serviceAccountKey.json`
- Check `FIREBASE_SERVICE_ACCOUNT_PATH` in `.env`
- Regenerate service account key from Firebase Console

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
- To enable: Set up `GOOGLE_APPLICATION_CREDENTIALS` in `.env`
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

When Google releases new models:

```javascript
// routes/ai.js - Update model version
const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

// Or use Pro for better quality (still free):
const model = genAI.getGenerativeModel({ model: 'gemini-1.5-pro' });
```

Available models:
- `gemini-1.5-flash` - Fastest (recommended)
- `gemini-1.5-pro` - Best quality
- `gemini-2.0-flash-exp` - Experimental

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

### Current Limits (Free Tier)

- **Gemini:** 1.5M requests/month (15/min, 1,500/day)
- **Firebase:** 50K reads/day, 20K writes/day
- **Cloud Run:** 2M requests/month, 360K GB-seconds

### When to Scale

Monitor and consider scaling when:
- Approaching 1M Gemini requests/month
- Consistent latency > 2s
- Error rate > 1%

### Scaling Options

1. **Caching** (Easy)
   - Cache AI responses for common queries
   - Use Redis or Firestore for cache storage

2. **Request Batching** (Medium)
   - Batch multiple AI requests together
   - Reduce per-request overhead

3. **Upgrade Gemini** (If needed)
   - Switch to paid tier only if needed
   - Monitor costs carefully

4. **Horizontal Scaling** (Advanced)
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
