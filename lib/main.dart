import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'routes/app_routes.dart';
import 'viewmodels/melody_viewmodel.dart';
import 'viewmodels/splash_viewmodel.dart';

void main() {
  runApp(const MagicSongApp());
}

class MagicSongApp extends StatelessWidget {
  const MagicSongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SplashViewModel()),
        ChangeNotifierProvider(create: (_) => MelodyViewModel()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Magic Song',
            theme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFF4C95D),
                secondary: Color(0xFFE5B94A),
                surface: Color(0xFF17191E),
                onPrimary: Color(0xFF141414),
                onSurface: Color(0xFFF2F3F5),
              ),
              scaffoldBackgroundColor: const Color(0xFF101217),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                foregroundColor: Color(0xFFF2F3F5),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF4C95D),
                  foregroundColor: const Color(0xFF141414),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF2F3F5),
                  side: const BorderSide(color: Color(0x33F4C95D)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              chipTheme: ThemeData.dark().chipTheme.copyWith(
                backgroundColor: const Color(0xFF1D2026),
                selectedColor: const Color(0xFFF4C95D).withValues(alpha: 0.18),
                side: const BorderSide(color: Color(0x33F4C95D)),
                labelStyle: const TextStyle(color: Color(0xFFE8EAED)),
              ),
              textTheme: GoogleFonts.outfitTextTheme(
                ThemeData.dark().textTheme,
              ),
              useMaterial3: true,
            ),
            initialRoute: AppRoutes.splash,
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}
