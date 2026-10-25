# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Mobile Scanner (ML Kit barcode)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Play Core 
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Google Play Services ML Kit (Unbundled barcode)
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.android.gms.internal.mlkit_vision_barcode.**
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.android.gms.vision.**