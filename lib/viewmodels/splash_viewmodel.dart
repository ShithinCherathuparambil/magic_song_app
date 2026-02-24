import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

class SplashViewModel extends ChangeNotifier {
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  void initializeApp(BuildContext context) async {
    // Artificial delay for splash screen or any future initialization logic (e.g., config fetching)
    await Future.delayed(const Duration(seconds: 2));

    _isInitialized = true;
    notifyListeners();

    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }
}
