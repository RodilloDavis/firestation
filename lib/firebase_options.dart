// lib/firebase_options.dart  (Dispatcher App)
//
// Same Firebase project as the LifeGuard360 user app (lifeguard-cefd9).
// Generated values are identical — both apps share the same RTDB and FCM project.
// DO NOT commit this file to public source control.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError('Linux not configured.');
      default:
        throw UnsupportedError('Unsupported platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCoBr-q1LF2dJhOAEhfP5GhpZKnhza-TgA',
    authDomain: 'lifeguard-cefd9.firebaseapp.com',
    databaseURL:
        'https://lifeguard-cefd9-default-rtdb.asia-southeast1.firebasedatabase.app',
    projectId: 'lifeguard-cefd9',
    storageBucket: 'lifeguard-cefd9.firebasestorage.app',
    messagingSenderId: '579792179500',
    appId: '1:579792179500:android:79a13340deae1512705c89',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCk9_Lc6Osz3Xs1WhYKzF3CfUpTImn1704',
    authDomain: 'lifeguard-cefd9.firebaseapp.com',
    databaseURL:
        'https://lifeguard-cefd9-default-rtdb.asia-southeast1.firebasedatabase.app',
    projectId: 'lifeguard-cefd9',
    storageBucket: 'lifeguard-cefd9.firebasestorage.app',
    messagingSenderId: '579792179500',
    appId: '1:579792179500:web:3bd106cbfd68d985705c89',
    measurementId: 'G-BK036BXCJ0',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCk9_Lc6Osz3Xs1WhYKzF3CfUpTImn1704',
    authDomain: 'lifeguard-cefd9.firebaseapp.com',
    databaseURL:
        'https://lifeguard-cefd9-default-rtdb.asia-southeast1.firebasedatabase.app',
    projectId: 'lifeguard-cefd9',
    storageBucket: 'lifeguard-cefd9.firebasestorage.app',
    messagingSenderId: '579792179500',
    appId: '1:579792179500:web:3bd106cbfd68d985705c89',
    iosClientId: '',
    iosBundleId: 'com.example.lifeguardDispatcher',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCk9_Lc6Osz3Xs1WhYKzF3CfUpTImn1704',
    authDomain: 'lifeguard-cefd9.firebaseapp.com',
    databaseURL:
        'https://lifeguard-cefd9-default-rtdb.asia-southeast1.firebasedatabase.app',
    projectId: 'lifeguard-cefd9',
    storageBucket: 'lifeguard-cefd9.firebasestorage.app',
    messagingSenderId: '579792179500',
    appId: '1:579792179500:web:3bd106cbfd68d985705c89',
    iosClientId: '',
    iosBundleId: 'com.example.lifeguardDispatcher',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCk9_Lc6Osz3Xs1WhYKzF3CfUpTImn1704',
    authDomain: 'lifeguard-cefd9.firebaseapp.com',
    databaseURL:
        'https://lifeguard-cefd9-default-rtdb.asia-southeast1.firebasedatabase.app',
    projectId: 'lifeguard-cefd9',
    storageBucket: 'lifeguard-cefd9.firebasestorage.app',
    messagingSenderId: '579792179500',
    appId: '1:579792179500:web:3bd106cbfd68d985705c89',
    measurementId: 'G-BK036BXCJ0',
  );
}
