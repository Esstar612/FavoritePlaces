# Favorite Places

A full-stack Flutter app for saving and organizing your favorite places with AI-powered features.

## 🚀 Features

- 📱 Cross-platform mobile app (iOS & Android)
- 🔐 Firebase Authentication (Email/Password + Google Sign-In)
- 📸 Photo upload with Firebase Storage
- 🗺️ Google Maps integration
- 🤖 AI-powered tag suggestions (Google Gemini) - **FREE!**
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
- **Google Gemini AI API (FREE - 1.5M requests/month)**
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
- **Google Gemini API key** (FREE from https://aistudio.google.com/app/apikey)

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
   # Edit .env with your Gemini API key and Firebase credentials
   npm run dev
   ```

3. **Setup Mobile**
   ```bash
   cd mobile
   flutter pub get
   # Configure lib/config.dart with your API keys
   flutter run
   ```

See individual README files for detailed instructions.

## 💰 Cost Estimate

- **Firebase:** FREE (generous free tier for personal use)
- **Google Maps:** FREE ($200 monthly credit)
- **Google Gemini AI:** FREE (1.5M requests/month)
- **Total:** $0/month for personal use! 🎉

For production with 1,000+ users, expect ~$30-90/month.

## 🎯 Use Cases

- Track favorite restaurants, cafes, parks
- Save travel destinations with photos and notes
- Organize places by custom categories
- Get AI-powered tag suggestions
- Search places naturally ("where did I have great pizza?")
- Export all your data as JSON

## 📱 Screenshots

(Add screenshots here)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open Pull Request

## 📝 License

MIT License

## 👤 Author

Star Olaojo
---

**Built with ❤️ using Flutter, Firebase, and Google Gemini AI**