# R8 / ProGuard keep rules for Flutter release builds.
#
# R8 is on (isMinifyEnabled = true in build.gradle.kts) for smaller APK/AAB sizes. The default Flutter rules cover
# most things, but we add explicit keeps for plugins that use reflection or platform channels at runtime —
# without these, R8 will strip "unused" classes that the Flutter engine actually needs.

# Flutter engine + plugin entry points
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.common.** { *; }

# json_serializable — generated *.g.dart classes do reflective access via toJson/fromJson; let R8 leave them alone
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# flutter_secure_storage uses platform channels + a small native bridge — keep it from being stripped
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# dio interceptors are reflectively instantiated in some debug paths
-keep class * implements dio.interceptor.Interceptor { *; }

# Strip noisy Java logging warnings about JSR-305 annotations the toolchain ships with
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**

# Keep generic signatures + annotations — required for json_serializable + Riverpod codegen reflection
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod
