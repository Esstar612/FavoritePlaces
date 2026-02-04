# Favorite Places Backend API

Full-featured Node.js + Express backend for the Favorite Places Flutter app with Firebase Authentication, Firestore integration, and AI-powered features using Claude API.

## 🚀 Features

### Authentication
- ✅ Firebase ID token verification
- ✅ Secure user authentication middleware
- ✅ Per-user data isolation

### AI Features (Powered by Claude)
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
3. **Anthropic API Key** ([get one here](https://console.anthropic.com/))
4. **(Optional)** Google Cloud Vision API enabled for advanced image tagging

---

## 🛠️ Installation

### Step 1: Clone & Install Dependencies

```bash
cd backend_server
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
ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json

# Optional
GOOGLE_APPLICATION_CREDENTIALS=./google-cloud-key.json
CORS_ORIGIN=*
```

### Step 3: Add Firebase Service Account

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project → **Project Settings** → **Service Accounts**
3. Click **Generate new private key**
4. Save the JSON file as `serviceAccountKey.json` in the `backend_server/` directory

### Step 4: Start the Server

**Development mode** (with auto-reload):
```bash
npm run dev
```

**Production mode**:
```bash
npm start
```

The server will start on `http://localhost:3000`

---

## 📡 API Endpoints

### Health Check

```
GET /
GET /health
```

Returns server status and uptime.

### AI Features

All AI routes require authentication (Bearer token in Authorization header).

#### 1. Summarize Notes

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

#### 3. Smart Search (Optional)

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

Returns complete user data as JSON.

#### Delete Account

```http
DELETE /user/account
Authorization: Bearer <firebase-id-token>
Content-Type: application/json

{
  "confirmEmail": "user@example.com"
}
```

⚠️ **Warning:** This permanently deletes the user account and all associated data.

---

## 🚢 Deployment

### Option 1: Google Cloud Run (Recommended)

Cloud Run is perfect for this backend - serverless, auto-scaling, and Firebase-native.

#### Prerequisites
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed
- Billing enabled on your GCP project

#### Steps

1. **Build the container:**

```bash
# In backend_server directory
gcloud builds submit --tag gcr.io/YOUR-PROJECT-ID/favorite-places-backend
```

2. **Deploy to Cloud Run:**

```bash
gcloud run deploy favorite-places-backend \
  --image gcr.io/YOUR-PROJECT-ID/favorite-places-backend \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "NODE_ENV=production" \
  --set-secrets "ANTHROPIC_API_KEY=anthropic-key:latest,FIREBASE_CONFIG=firebase-config:latest"
```

3. **Set environment variables as secrets:**

```bash
# Create secrets in Secret Manager
echo -n "sk-ant-api03-your-key" | gcloud secrets create anthropic-key --data-file=-

# For Firebase config, paste entire service account JSON
cat serviceAccountKey.json | gcloud secrets create firebase-config --data-file=-
```

4. **Update Flutter app config:**

```dart
// lib/config.dart
static const String backendUrl = 'https://your-cloud-run-url.a.run.app';
```

#### Dockerfile

Create `Dockerfile` in `backend_server/`:

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["node", "server.js"]
```

### Option 2: Heroku

```bash
# Install Heroku CLI and login
heroku login

# Create app
heroku create your-app-name

# Set environment variables
heroku config:set ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
heroku config:set NODE_ENV=production
heroku config:set FIREBASE_CONFIG='{"type":"service_account",...}'

# Deploy
git push heroku main
```

### Option 3: VPS (DigitalOcean, AWS EC2, etc.)

1. SSH into your server
2. Install Node.js 18+
3. Clone repository
4. Copy `.env` and `serviceAccountKey.json`
5. Install PM2: `npm install -g pm2`
6. Start server: `pm2 start server.js --name favorite-places-backend`
7. Configure Nginx reverse proxy

---

## 🔒 Security Considerations

1. **Never commit `.env` or `serviceAccountKey.json`** - these are in `.gitignore`
2. **Use HTTPS in production** - required for secure token transmission
3. **Set CORS_ORIGIN** to your app's domain in production (not `*`)
4. **Enable rate limiting** - already configured, adjust limits in `.env` if needed
5. **Monitor API usage** - Set up alerts for unusual activity
6. **Rotate API keys regularly** - especially after team member changes

---

## 🧪 Testing

### Manual Testing with cURL

```bash
# Get a Firebase ID token from your app (print it in debug mode)
export TOKEN="eyJhbGciOiJSUzI1NiIsImtp..."

# Test summarize notes
curl -X POST http://localhost:3000/ai/summarize-notes \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Place",
    "notes": "This is a test note with some interesting details.",
    "category": "restaurant",
    "address": "123 Main St"
  }'
```

### Automated Testing

Create `test/` directory with Jest or Mocha tests (TODO).

---

## 📊 Monitoring

### Logs

**Local development:**
```bash
# Logs print to console
```

**Production (Cloud Run):**
```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=favorite-places-backend" --limit 50
```

### Metrics

Monitor in Google Cloud Console:
- Request count
- Latency (p50, p95, p99)
- Error rate
- Memory usage
- CPU utilization

Set up alerts for:
- Error rate > 5%
- Average latency > 2s
- Memory usage > 80%

---

## 🐛 Troubleshooting

### "Unauthorized" errors

**Cause:** Invalid or expired Firebase ID token

**Fix:**
- Ensure Flutter app is calling `user.getIdToken()` before each request
- Check that token is included in `Authorization: Bearer <token>` header
- Verify Firebase project ID matches in both app and backend

### "AI service error"

**Cause:** Anthropic API key invalid or rate limited

**Fix:**
- Check `ANTHROPIC_API_KEY` in `.env`
- Verify API key at https://console.anthropic.com/
- Check Anthropic usage limits

### "Failed to initialize Firebase Admin"

**Cause:** Service account JSON not found or invalid

**Fix:**
- Ensure `serviceAccountKey.json` exists in backend_server/
- Verify file path in `FIREBASE_SERVICE_ACCOUNT_PATH`
- Regenerate service account key if corrupted

### CORS errors from Flutter app

**Cause:** Origin not allowed

**Fix:**
- Set `CORS_ORIGIN` in `.env` to your app's origin
- For development: `CORS_ORIGIN=*`
- For production: `CORS_ORIGIN=https://your-app.web.app`

---

## 🔄 Update Guide

### Update Dependencies

```bash
npm update
npm audit fix
```

### Update Claude Model

Edit `.env`:
```env
CLAUDE_MODEL=claude-3-5-sonnet-20241022
# Or newer version when available
```

### Add New Routes

1. Create new file in `routes/`
2. Export Express router
3. Import and use in `server.js`:
```javascript
import newRoutes from './routes/new.js';
app.use('/new-prefix', authenticateUser, newRoutes);
```

---

## 📝 License

MIT

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open Pull Request

---

## 📞 Support

Issues? Questions? Open an issue on GitHub or reach out to the development team.

---

**Built with ❤️ using Node.js, Express, Firebase, and Claude AI**
