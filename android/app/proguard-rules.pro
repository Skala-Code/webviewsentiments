# Facebook SDK ProGuard rules
-keep class com.facebook.** { *; }
-dontwarn com.facebook.**

# Keep native methods
-keepclassmembers class * {
    native <methods>;
}