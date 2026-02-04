# Favorite Places

A full-stack Flutter app for saving and organizing your favorite places with AI-powered features.

## 🚀 Features

- 📱 Cross-platform mobile app (iOS & Android)
- 🔐 Firebase Authentication (Email/Password + Google Sign-In)
- 📸 Photo upload with Firebase Storage
- 🗺️ Google Maps integration
- 🤖 AI-powered tag suggestions (Google Gemini)
- 📝 Smart note summarization
- 🔍 Search, filter, and sort places
- ⭐ Favorite places
- 🏷️ Custom tags and categories
- 📊 User statistics and profile

## 📂 Project Structure

- `/mobile` - Flutter mobile app
- `/backend` - Node.js Express backend with AI features

## 🛠️ Tech Stack

**Mobile:**
- Flutter 3.7+
- Firebase (Auth, Firestore, Storage)
- Riverpod (State Management)
- Google Maps Flutter

**Backend:**
- Node.js + Express
- Firebase Admin SDK
- Google Gemini AI API
- Google Cloud Vision (optional)

## 📖 Documentation

See detailed setup instructions in:
- [Mobile App Setup](./mobile/README.md)
- [Backend Setup](./backend/README.md)

## 🚀 Quick Start

### Prerequisites
- Flutter 3.7+
- Node.js 18+
- Firebase project
- Google Maps API key
- Google Gemini API key

### Setup

1. **Clone the repository**
```bash
   git clone https://github.com/yourusername/FavoritePlaces.git
   cd FavoritePlaces
```

2. **Setup Backend**
```bash
   cd backend
   npm install
   cp .env.example .env
   # Edit .env with your keys
   npm run dev
```

3. **Setup Mobile**
```bash
   cd mobile
   flutter pub get
   flutter run
```

See individual README files for detailed instructions.

## 📝 License

MIT License (or your choice)

## 👤 Author

Star Olaojo
