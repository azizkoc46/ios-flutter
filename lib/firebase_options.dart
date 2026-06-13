// File generated from the registered Pazarcik Portal Firebase apps.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase bu platform icin yapilandirilmadi.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCtpHn1bsvLL0qa5yINP2Iqs63_cFcvGXo',
    appId: '1:615903758381:web:45f43002331febe9b610a4',
    messagingSenderId: '615903758381',
    projectId: 'pazarcik-portal-7faf2',
    authDomain: 'pazarcik-portal-7faf2.firebaseapp.com',
    storageBucket: 'pazarcik-portal-7faf2.firebasestorage.app',
    measurementId: 'G-QSL6V7W48R',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBfEjiOOnRjnv7GtHZJ7oz46ScuLpRZZDg',
    appId: '1:615903758381:android:f4d24ce9835910e9b610a4',
    messagingSenderId: '615903758381',
    projectId: 'pazarcik-portal-7faf2',
    storageBucket: 'pazarcik-portal-7faf2.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBx25XwRSYovdN0dSqUcpwn3zDv354CtA0',
    appId: '1:615903758381:ios:a322c27d2aa31b3ab610a4',
    messagingSenderId: '615903758381',
    projectId: 'pazarcik-portal-7faf2',
    storageBucket: 'pazarcik-portal-7faf2.firebasestorage.app',
    iosClientId:
        '615903758381-dnk37omn3qbqf1mbg0jr83o22013imqk.apps.googleusercontent.com',
    iosBundleId: 'com.pp.pazarckportal.pazarckportal',
  );
}
