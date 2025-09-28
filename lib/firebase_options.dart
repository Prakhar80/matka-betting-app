import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Default Firebase configuration used by the app.
class DefaultFirebaseOptions {
  /// Returns the [FirebaseOptions] for the current platform if available,
  /// otherwise `null`.
  static FirebaseOptions? get currentPlatformOrNull {
    if (!supportsCurrentPlatform) {
      return null;
    }

    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return null;
    }
  }

  static FirebaseOptions get currentPlatform {
    final options = currentPlatformOrNull;
    if (options != null) {
      return options;
    }

    throw UnsupportedError(
      'Firebase options have not been configured for $platformLabel.'
      ' Run `flutterfire configure` to add support.',
    );
  }

  /// Whether Firebase has configuration for the current platform.
  static bool get supportsCurrentPlatform {
    if (kIsWeb) {
      return true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return true;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  /// Human readable name of the active platform for logging/debugging.
  static String get platformLabel {
    if (kIsWeb) {
      return 'web';
    }
    return defaultTargetPlatform.name;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDMkYPCKKjmBcGc9YsC5yO8vTUdsTmbf9w',
    appId: '1:221882838219:android:493ef1073e8f6857403f4e',
    messagingSenderId: '221882838219',
    projectId: 'matka-betting-app',
    storageBucket: 'matka-betting-app.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDMkYPCKKjmBcGc9YsC5yO8vTUdsTmbf9w',
    appId: '1:221882838219:web:f8b2e4b7c3d6a5e9403f4e',
    messagingSenderId: '221882838219',
    projectId: 'matka-betting-app',
    authDomain: 'matka-betting-app.firebaseapp.com',
    storageBucket: 'matka-betting-app.firebasestorage.app',
    measurementId: 'G-XXXXXXXXXX',
  );
}
