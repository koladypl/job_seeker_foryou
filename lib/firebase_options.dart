import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS:     return ios;
      case TargetPlatform.macOS:   return macos;
      default: throw UnsupportedError('Unsupported platform');
    }
  }

  static const web = FirebaseOptions(
    apiKey: 'WEB_API_KEY',
    authDomain: 'proj.firebaseapp.com',
    projectId: 'proj-id',
    storageBucket: 'proj.appspot.com',
    messagingSenderId: '1234567890',
    appId: '1:1234567890:web:abcdef',
    measurementId: 'G-XXXXXX',
  );

  static const android = FirebaseOptions(
    apiKey: 'ANDROID_KEY',
    appId: '1:1234567890:android:abcdef',
    messagingSenderId: '1234567890',
    projectId: 'proj-id',
    storageBucket: 'proj.appspot.com',
  );

  static const ios = FirebaseOptions(
    apiKey: 'IOS_KEY',
    appId: '1:1234567890:ios:abcdef',
    messagingSenderId: '1234567890',
    projectId: 'proj-id',
    storageBucket: 'proj.appspot.com',
    iosClientId: '1234567890-abcdef.apps.googleusercontent.com',
    iosBundleId: 'com.your.bundle',
  );

  static const macos = FirebaseOptions(
    apiKey: 'MACOS_KEY',
    appId: '1:1234567890:macos:abcdef',
    messagingSenderId: '1234567890',
    projectId: 'proj-id',
    storageBucket: 'proj.appspot.com',
  );
}
