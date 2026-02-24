import 'package:flutter/material.dart';

import '../views/melody_recorder_view.dart';
import '../views/saved_voices_view.dart';
import '../views/splash_view.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String savedVoices = '/saved-voices';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashView(),
    home: (context) => const MelodyRecorderView(),
    savedVoices: (context) => const SavedVoicesView(),
  };
}
