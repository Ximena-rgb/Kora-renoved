import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS:     return ios;
      default: throw UnsupportedError('Plataforma no soportada');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyC5W6euy7eKc_a_HCA-UJvWbKV1P5WDRiM',
    appId:             '1:695071672432:web:3c6dfbf0f5968b42654cb5',
    messagingSenderId: '695071672432',
    projectId:         'kora-defd6',
    authDomain:        'kora-defd6.firebaseapp.com',
    storageBucket:     'kora-defd6.firebasestorage.app',
    measurementId:     'G-15ZGYLXWZQ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyBMcwLsSTXH73WVhqPMtpfOniPHSZDl61Q',
    appId:             '1:695071672432:android:e0064ec8fb940f40654cb5',
    messagingSenderId: '695071672432',
    projectId:         'kora-defd6',
    storageBucket:     'kora-defd6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyBMcwLsSTXH73WVhqPMtpfOniPHSZDl61Q',
    appId:             '1:695071672432:ios:e0064ec8fb940f40654cb5',
    messagingSenderId: '695071672432',
    projectId:         'kora-defd6',
    storageBucket:     'kora-defd6.firebasestorage.app',
    iosClientId:       '695071672432-5ol425us56ibi85tfmhjkavouc5cm3us.apps.googleusercontent.com',
    iosBundleId:       'com.kora.app',
  );
}
