# 🗺️ Favorite Places

A full-stack Flutter mobile application for saving and organizing favorite places with AI-powered features using Google Gemini.

## 🎮 Live Demo

**[🚀 Try the App in Your Browser →](https://appetize.io/app/YOUR-APPETIZE-URL)**

*No download required! Runs in a simulated Android device via Appetize.io*

---

## ✨ Features

### Core Functionality
- 📸 **Photo Management** - Upload and store multiple photos per place using Firebase Storage
- 🗺️ **Location Integration** - Google Maps picker with address geocoding
- ⭐ **Favorites System** - Mark and filter favorite places
- 🏷️ **Custom Categories** - Park, Restaurant, Entertainment, Shopping, etc.
- 📝 **Notes & Ratings** - Add detailed notes and 5-star ratings

### AI-Powered Features
- 🤖 **Smart Tag Suggestions** - Google Gemini analyzes photos and suggests relevant tags
- 📊 **Note Summarization** - AI-powered summaries with tips and best times to visit
- 🔍 **Smart Search** - Natural language search across all place data

### User Experience
- 🔐 **Authentication** - Email/Password and Google Sign-In via Firebase Auth
- 🔄 **Real-time Sync** - Firestore database with real-time updates
- 📱 **Responsive UI** - Material Design 3 with dark mode support
- 📈 **Statistics Dashboard** - Track total places, favorites, and categories

---

## 🏗️ Architecture

### Frontend (Mobile App)
- **Framework:** Flutter 3.7+
- **State Management:** Riverpod
- **Authentication:** Firebase Auth
- **Database:** Cloud Firestore
- **Storage:** Firebase Storage
- **Maps:** Google Maps Flutter

### Backend (REST API)
- **Runtime:** Node.js 20
- **Framework:** Express.js
- **AI:** Google Gemini 1.5 Flash (1.5M requests/month FREE)
- **Deployment:** Google Cloud Run (serverless, auto-scaling)
- **Security:** Firebase Admin SDK for token verification

### Infrastructure
- **Hosting:** Firebase Hosting (web) + GitHub Actions (CI/CD)
- **Backend:** Google Cloud Run (auto-deploy from GitHub)
- **Secrets:** Google Secret Manager
- **APIs:** Google Maps API, Google Gemini API

---

## 🛠️ Tech Stack

| Layer | Technologies |
|-------|-------------|
| **Mobile** | Flutter, Dart, Riverpod |
| **Backend** | Node.js, Express, Firebase Admin |
| **AI** | Google Gemini 1.5 Flash |
| **Database** | Cloud Firestore (NoSQL) |
| **Storage** | Firebase Storage |
| **Auth** | Firebase Authentication |
| **Cloud** | Google Cloud Run, Secret Manager |
| **CI/CD** | GitHub Actions |
| **APIs** | Google Maps, Gemini AI |

---

## 📸 Screenshots

<div align="center">
  <img src="screenshots/places-list.png" width="250" />
  <img src="screenshots/add-place.png" width="250" />
  <img src="screenshots/place-detail.png" width="250" />
</div>

*Add screenshots to a `/screenshots` folder in your repo*

---

## 🚀 Getting Started

### Prerequisites
- Flutter 3.7+
- Node.js 18+
- Firebase project
- Google Cloud account
- Google Gemini API key (free)

### Backend Setup

1. **Clone the repository**
```bash
   git clone https://github.com/Esstar612/FavoritePlaces.git
   cd FavoritePlaces/backend
```

2. **Install dependencies**
```bash
   npm install
```

3. **Configure environment**
```bash
   cp .env.example .env
   # Add your Gemini API key and Firebase credentials
```

4. **Run locally**
```bash
   npm run dev
```

5. **Deploy to Cloud Run**
```bash
   gcloud builds submit --tag gcr.io/YOUR-PROJECT-ID/favorite-places-backend
   gcloud run deploy favorite-places-backend --image gcr.io/YOUR-PROJECT-ID/favorite-places-backend
```

### Mobile App Setup

1. **Navigate to mobile directory**
```bash
   cd mobile
```

2. **Install dependencies**
```bash
   flutter pub get
```

3. **Configure API keys**
```bash
   cp lib/config.example.dart lib/config.dart
   # Add your Google Maps API key and backend URL
```

4. **Add Firebase configuration**
   - Download `google-services.json` → `android/app/`
   - Download `GoogleService-Info.plist` → `ios/Runner/`

5. **Run the app**
```bash
   flutter run
```

---

## 📦 Project Structure
```
FavoritePlaces/
├── backend/                 # Node.js Express API
│   ├── routes/
│   │   ├── ai.js           # AI endpoints (Gemini)
│   │   └── user.js         # User management
│   ├── server.js           # Main server
│   └── Dockerfile          # Cloud Run deployment
│
├── mobile/                  # Flutter mobile app
│   ├── lib/
│   │   ├── models/         # Data models
│   │   ├── providers/      # Riverpod state management
│   │   ├── screens/        # UI screens
│   │   ├── services/       # API & Firebase services
│   │   └── widgets/        # Reusable components
│   └── pubspec.yaml
│
└── .github/workflows/       # CI/CD pipelines
```

---

## 🔐 Security Features

- ✅ Firebase ID token verification on all protected endpoints
- ✅ Rate limiting on AI endpoints (100 requests per 15 minutes)
- ✅ CORS configuration for production
- ✅ Secrets stored in Google Secret Manager
- ✅ Firestore security rules (user data isolation)
- ✅ HTTPS only (enforced by Cloud Run)

---

## 💰 Cost Estimate

**Monthly costs for personal use:**

- Google Gemini API: **FREE** (1.5M requests/month)
- Firebase (Auth, Firestore, Storage): **FREE** (generous free tier)
- Google Maps API: **FREE** ($200 monthly credit)
- Cloud Run: **FREE** (2M requests/month)

**Total: $0/month** for personal use! 🎉

---

## 📝 API Documentation

See [Backend README](./backend/README.md) for complete API documentation.

**Key Endpoints:**

- `POST /ai/summarize-notes` - Generate smart summaries
- `POST /ai/suggest-tags` - AI-powered tag suggestions
- `GET /user/profile` - User profile
- `GET /user/stats` - User statistics

---

## 🎯 Future Enhancements

- [ ] Social features (share places with friends)
- [ ] Offline mode with local caching
- [ ] Trip planning with multiple places
- [ ] Place recommendations based on preferences
- [ ] Import/export to Google Maps
- [ ] Multi-language support

---

## 📄 License

MIT License - feel free to use this project for learning!

---

## 👤 Author

**Your Name**
- GitHub: [@Esstar612](https://github.com/Esstar612)
- LinkedIn: [Your LinkedIn]
- Portfolio: [Your Website]

---

## 🙏 Acknowledgments

- Google Gemini AI for smart features
- Firebase for backend infrastructure
- Flutter team for the amazing framework

---

**Built with ❤️ using Flutter, Firebase, and Google Cloud**