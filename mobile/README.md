# Favorite Places - Mobile App

Flutter mobile application for iOS and Android.

## 🚀 Features

- 📱 Cross-platform (iOS & Android)
- 🔐 User authentication (Email/Password, Google Sign-In)
- 📸 Photo capture and upload
- 🗺️ Google Maps location picker
- 🤖 AI-powered tag suggestions (via backend)
- 📝 Smart note summarization (via backend)
- 🔍 Search and filter places
- ⭐ Favorite places
- 🏷️ Custom tags and categories
- 📊 User profile and statistics
- 🌙 Dark mode support
- 🔄 Real-time sync with Firestore

## 📋 Prerequisites

- Flutter 3.7+ ([install](https://docs.flutter.dev/get-started/install))
- Xcode (for iOS development)
- Android Studio (for Android development)
- Firebase project ([create one](https://console.firebase.google.com/))
- Google Maps API key ([get one](https://console.cloud.google.com/))

## 🛠️ Installation

### Step 1: Install Flutter Dependencies

```bash
cd mobile
flutter pub get
```

### Step 2: Configure API Keys

#### 2a. Create Config File

```bash
cp lib/config.example.dart lib/config.dart
```

#### 2b. Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable **Maps SDK for Android**
4. Enable **Maps SDK for iOS**
5. Go to **Credentials** → **Create Credentials** → **API Key**
6. Copy the API key

#### 2c. Edit Config File

Open `lib/config.dart` and add your keys:

```dart
import 'dart:io';

class AppConfig {
  // Google Maps API Key
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY_HERE';
  
  // Backend URL
  static const String backendUrl = Platform.isAndroid 
      ? 'http://10.0.2.2:3000'      // Android emulator
      : 'http://localhost:3000';     // iOS simulator
  
  // For physical devices on same WiFi:
  // static const String backendUrl = 'http://192.168.1.XXX:3000';
  
  // For production (after deploying backend):
  // static const String backendUrl = 'https://your-backend.run.app';
}
```

### Step 3: Setup Firebase

#### 3a. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add Project**
3. Follow the setup wizard

#### 3b. Add Android App

1. In Firebase Console, click **Add app** → **Android**
2. Package name: `com.star.favorite_places`
3. Download `google-services.json`
4. Place in `android/app/`

#### 3c. Add iOS App

1. In Firebase Console, click **Add app** → **iOS**
2. Bundle ID: `com.star.favorite-places`
3. Download `GoogleService-Info.plist`
4. Open `ios/Runner.xcworkspace` in Xcode
5. Drag `GoogleService-Info.plist` into Runner folder

#### 3d. Enable Firebase Services

In Firebase Console:

1. **Authentication**
   - Go to **Authentication** → **Sign-in method**
   - Enable **Email/Password**
   - Enable **Google** (download and configure OAuth)

2. **Firestore Database**
   - Go to **Firestore Database** → **Create database**
   - Start in **test mode** (we'll add security rules later)
   - Choose a location

3. **Storage**
   - Go to **Storage** → **Get started**
   - Start in **test mode**

4. **Security Rules** (Important!)

   Update Firestore rules:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /places/{placeId} {
         allow read, write: if request.auth != null && 
                              resource.data.userId == request.auth.uid;
         allow create: if request.auth != null;
       }
       match /users/{userId} {
         allow read, write: if request.auth != null && 
                              userId == request.auth.uid;
       }
     }
   }
   ```

   Update Storage rules:
   ```javascript
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /users/{userId}/{allPaths=**} {
         allow read, write: if request.auth != null && 
                              request.auth.uid == userId;
       }
     }
   }
   ```

### Step 4: Generate Firebase Options (Optional)

If you need to regenerate `firebase_options.dart`:

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

### Step 5: Run the App

#### Android Emulator

```bash
# Start emulator, then:
flutter run
```

#### iOS Simulator

```bash
# Open simulator, then:
flutter run -d ios
```

#### Physical Device

```bash
# Connect device via USB, enable developer mode
flutter devices  # List available devices
flutter run -d <device-id>
```

## 📁 Project Structure

```
lib/
├── config.dart              # API keys and configuration
├── main.dart                # App entry point
├── models/                  # Data models
│   └── place.dart
├── providers/               # Riverpod state management
│   ├── auth_provider.dart
│   └── user_places.dart
├── screens/                 # UI screens
│   ├── auth/
│   │   ├── login.dart
│   │   └── signup.dart
│   ├── add_place.dart
│   ├── place_detail.dart
│   ├── places.dart
│   ├── profile.dart
│   └── settings.dart
├── services/                # API services
│   ├── ai_service.dart
│   └── firestore_service.dart
└── widgets/                 # Reusable widgets
    ├── image_input.dart
    ├── location_input.dart
    └── places_list.dart
```

## 🔑 Required API Keys

### 1. Google Maps API Key

**Where to get it:**
- [Google Cloud Console](https://console.cloud.google.com/)
- Enable Maps SDK for Android and iOS
- Create API key

**Where to put it:**
- `lib/config.dart` → `googleMapsApiKey`

### 2. Firebase Configuration

**Where to get it:**
- [Firebase Console](https://console.firebase.google.com/)
- Download `google-services.json` (Android)
- Download `GoogleService-Info.plist` (iOS)

**Where to put it:**
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### 3. Backend URL

**Local Development:**
- Android emulator: `http://10.0.2.2:3000`
- iOS simulator: `http://localhost:3000`
- Physical device: `http://YOUR_COMPUTER_IP:3000`

**Production:**
- Your deployed backend URL (e.g., Cloud Run URL)

## 🧪 Testing

### Run Tests

```bash
flutter test
```

### Integration Tests

```bash
flutter test integration_test
```

## 🐛 Troubleshooting

### "Google Maps API key not found"

**Fix:**
- Ensure `lib/config.dart` exists (copy from `config.example.dart`)
- Add your Google Maps API key
- Restart the app (`R` in terminal)

### Firebase Auth not working

**Fix:**
- Check `google-services.json` and `GoogleService-Info.plist` are in place
- Verify package name/bundle ID matches Firebase project
- Ensure Authentication is enabled in Firebase Console

### Images not uploading

**Fix:**
- Check Firebase Storage rules allow authenticated writes
- Verify Storage is enabled in Firebase Console
- Check network connection

### Backend connection fails

**Fix:**
- Ensure backend server is running (`npm run dev`)
- Check `backendUrl` in `lib/config.dart`
- For Android emulator, use `10.0.2.2` not `localhost`
- For iOS simulator, use `localhost`
- For physical device, use your computer's IP address

### "Permission denied" on Firestore

**Fix:**
- Update Firestore security rules (see Step 3d above)
- Ensure user is authenticated
- Check that `userId` matches in documents

### Location picker not working

**Fix:**
- **Android:** Check permissions in `AndroidManifest.xml`
- **iOS:** Check permissions in `Info.plist`
- Enable location services on device
- Grant location permission when prompted

### iOS build fails

**Fix:**
- Open `ios/Runner.xcworkspace` in Xcode
- Select correct Team in Signing & Capabilities
- Change Bundle Identifier if needed
- Run `pod install` in `ios/` directory

## 📱 Building for Release

### Android

```bash
# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

Output: `build/app/outputs/`

### iOS

```bash
# Build for iOS
flutter build ios --release

# Open in Xcode to archive and upload
open ios/Runner.xcworkspace
```

Then in Xcode:
1. Product → Archive
2. Distribute App → App Store Connect

## 🔒 Security Best Practices

1. **Never commit secrets**
   - `lib/config.dart` is in `.gitignore`
   - Use `config.example.dart` as template

2. **Firebase Security Rules**
   - Never use test mode in production
   - Users should only access their own data

3. **API Keys**
   - Restrict Google Maps API key to your app
   - Add app restrictions in Cloud Console

4. **Authentication**
   - Use Firebase Authentication
   - Never store passwords in app

## 📦 Dependencies

Main dependencies in `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.6.1
  
  # Firebase
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.0
  cloud_firestore: ^5.5.0
  firebase_storage: ^12.3.0
  
  # Google
  google_sign_in: ^6.2.1
  google_maps_flutter: ^2.9.0
  
  # Location
  location: ^7.0.0
  geocoding: ^3.0.0
  
  # Images
  image_picker: ^1.1.2
  
  # UI
  flutter_rating_bar: ^4.0.1
  
  # HTTP
  http: ^1.2.2
  
  # Storage
  path_provider: ^2.1.4
  path: ^1.9.0
```

## 🎨 Features in Detail

### Authentication
- Email/Password signup and login
- Google Sign-In
- Password reset
- Persistent login sessions

### Places Management
- Add places with photos, location, tags, notes
- Edit existing places
- Delete places (with confirmation)
- Mark favorites
- Rate places (1-5 stars)

### Search & Filter
- Search by title, tags, notes, location
- Filter by category
- Sort by: recent, alphabetical, rating, category
- Show favorites only

### AI Features (via Backend)
- AI-powered tag suggestions based on photo
- Smart note summarization
- Natural language search (optional)

### Profile
- View statistics (total places, favorites, categories)
- Export data as JSON
- Delete account

## 🚀 Performance Tips

1. **Images**
   - Compress images before upload
   - Use thumbnail URLs for lists

2. **Firestore**
   - Implement pagination for large datasets
   - Use indexes for complex queries

3. **Caching**
   - Images cached automatically
   - Implement offline mode with local storage

## 📝 License

MIT License

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing`)
5. Open a Pull Request

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/Esstar612/FavoritePlaces/issues)
- **Firebase:** [Firebase Documentation](https://firebase.google.com/docs)
- **Flutter:** [Flutter Documentation](https://docs.flutter.dev/)

---

**Built with ❤️ using Flutter and Firebase**
