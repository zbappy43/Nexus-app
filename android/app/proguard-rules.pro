# =============================================================================
# Nexus Consumers – R8 / ProGuard rules (release builds are minified + shrunk)
# Plugins ship their own consumer rules; these cover reflection-heavy cases.
# =============================================================================

# Keep line numbers for readable Play Console crash reports, hide source names.
-keepattributes SourceFile,LineNumberTable,Signature,*Annotation*,InnerClasses,EnclosingMethod
-renamesourcefileattribute SourceFile

# --- Flutter embedding --------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
# Deferred components reference Play Core classes that are not bundled.
-dontwarn com.google.android.play.core.**

# --- App ---------------------------------------------------------------------
-keep class com.nexus.consumers.MainActivity { *; }

# --- flutter_inappwebview: JavaScript interface methods are called by name ---
-keep class com.pichillilorenzo.flutter_inappwebview_android.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface

# --- flutter_local_notifications (Gson-serialised scheduled notifications) ---
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# --- Firebase ----------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --- OneSignal ---------------------------------------------------------------
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# --- flutter_downloader (WorkManager worker instantiated by class name) -------
-keep class vn.hunghd.flutterdownloader.** { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# --- Image cropper (uCrop) ---------------------------------------------------
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**
-dontwarn okhttp3.**
-dontwarn okio.**

# --- ML Kit (mobile_scanner) -------------------------------------------------
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# --- Biometric / secure storage ----------------------------------------------
-keep class androidx.biometric.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# --- Kotlin ------------------------------------------------------------------
-dontwarn kotlin.**
-dontwarn kotlinx.**
-keepclassmembers class **$WhenMappings { <fields>; }

# --- Strip verbose logging from release builds -------------------------------
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
