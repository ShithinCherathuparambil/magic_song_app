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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F1218), Color(0xFF141922), Color(0xFF181D27)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 128.w,
                height: 128.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE5B94A), Color(0xFFFFE4A3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF4C95D).withValues(alpha: 0.22),
                      blurRadius: 45.r,
                      spreadRadius: 10.r,
                    ),
                  ],
                ),
                child: Container(
                  margin: EdgeInsets.all(8.w),
                  decoration: const BoxDecoration(
                    color: Color(0xFF12161D),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mic_external_on_rounded,
                    size: 56.sp,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
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
