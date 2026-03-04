# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Pigeon and Standard Plugins
-keep class dev.flutter.pigeon.** { *; }
-keep class com.llfbandit.record.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }

# FFmpegKit
-keep class com.arthenica.ffmpegkit.** { *; }

# Google Play Core / SplitInstall (Flutter Deferred Components)
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
