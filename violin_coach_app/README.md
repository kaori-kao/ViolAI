# Violin Coach App

A comprehensive AI-powered violin learning platform that uses computer vision to provide real-time feedback on posture, bowing technique, and musical performance.

## Features

- **Pose Detection**: Uses TCPformer for accurate 3D pose estimation
- **Bow Direction Analysis**: Real-time detection of bow movement direction
- **Posture Analysis**: Feedback on correct violin playing posture
- **Rhythm Training**: Guidance for maintaining proper rhythm
- **Song Recognition**: Identify the piece you're playing (like Shazam)
- **Teacher-Student System**: Share recordings with teachers and receive feedback
- **Classroom Management**: Organize students into virtual classrooms

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) (latest stable version)
- [Android Studio](https://developer.android.com/studio) (for Android development)
- [Xcode](https://developer.apple.com/xcode/) (for iOS development, Mac only)
- [Git](https://git-scm.com/)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/violin_coach_app.git
   cd violin_coach_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Set up ACRCloud API credentials (for song recognition):
   - Sign up for an account at [ACRCloud](https://www.acrcloud.com/)
   - Create a project and get your access key and access secret
   - Replace the placeholders in `lib/services/song_recognition_service.dart` with your credentials

### Running on Android

1. Connect an Android device or start an emulator

2. Run the app:
   ```bash
   flutter run
   ```

### Running on iOS

1. Install iOS dependencies:
   ```bash
   cd ios
   pod install
   cd ..
   ```

2. Connect an iOS device or start a simulator

3. Run the app:
   ```bash
   flutter run
   ```

### Building for Production

#### Android APK
```bash
flutter build apk
```

The APK file will be created at `build/app/outputs/flutter-apk/app-release.apk`

#### iOS IPA
```bash
flutter build ios
```

Then open the Xcode workspace:
```bash
open ios/Runner.xcworkspace
```

And archive the app from Xcode for distribution.

## Project Structure

- `lib/` - Contains all Dart code
  - `main.dart` - Entry point for the application
  - `models/` - Data models
  - `services/` - Services for API communication, database, etc.
  - `screens/` - UI screens
  - `widgets/` - Reusable UI components
  - `utils/` - Utility classes and functions

- `assets/` - Contains static assets
  - `images/` - Image files
  - `models/` - ML model files (TCPformer)

## Demo Accounts

For testing purposes, the following demo accounts are available:

- **Teacher**: Username: `teacher`, Password: `password`
- **Student**: Username: `student`, Password: `password`

## Technical Implementation

- **Computer Vision**: Using TCPformer for 3D pose estimation
- **Audio Analysis**: Fast Fourier Transform for pitch detection
- **Database**: SQLite with structured tables for users, sessions, events, etc.
- **State Management**: Provider pattern
- **Audio Recording**: Flutter Sound library

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- TCPformer for the state-of-the-art pose estimation models
- Flutter and the Flutter community for the amazing framework