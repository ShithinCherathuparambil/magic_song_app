import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../viewmodels/splash_viewmodel.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SplashViewModel>().initializeApp(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFF003C72)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/app_icon.png', width: 128.w, height: 128.w),
              SizedBox(height: 28.h),
              Text(
                'Magic Song Studio',
                style: TextStyle(
                  fontSize: 30.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Shape your voice with cinematic control',
                style: TextStyle(
                  color: const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                ),
              ),
              SizedBox(height: 24.h),
              const CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4C95D)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
