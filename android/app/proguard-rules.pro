# Flutter Kuralları
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Uygulama Paketi Kuralları
-keep class com.aladin.iptv.player.pro.** { *; }

# Isar Veritabanı Kuralları (Kritik: arm64 cihazlarda çökme sebebi budur)
-keep class io.isar.** { *; }
-keepclassmembers class io.isar.** { *; }
-dontwarn io.isar.**

# MediaKit / Video Player Kuralları
-keep class com.alexmercerind.mediakit.** { *; }
-dontwarn com.alexmercerind.mediakit.**

# AndroidX ve Support Kütüphaneleri
-keep class androidx.core.app.CoreComponentFactory
-dontwarn androidx.**
-dontwarn com.google.android.material.**

# --- Google Play Core (Flutter deferred components için gerekli, kullanılmasa bile) ---
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Genel olarak tüm play.core uyarılarını bastır
-dontwarn com.google.android.play.**
