# ──────────────────────────────────────────────────────────────────────────────
# aladinIPTV Player Pro — ProGuard / R8 Rules
# ──────────────────────────────────────────────────────────────────────────────

# Flutter — genel
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# AndroidX / AppCompat
-keep class androidx.appcompat.** { *; }
-dontwarn androidx.**

# ── Media3 / ExoPlayer ────────────────────────────────────────────────────────
-keep class androidx.media3.** { *; }
-keep interface androidx.media3.** { *; }
-dontwarn androidx.media3.**

# ExoPlayer decoder extension (HLS, DASH, RTMP vb.) — dinamik yükleme için
-keepclassmembers class * implements androidx.media3.exoplayer.mediacodec.MediaCodecRenderer {
    *;
}

# ── Isar ──────────────────────────────────────────────────────────────────────
# Isar native kütüphanelerini küçültme; generate edilmiş .g.dart kodları native
# tarafta referans aldığından class isimlerini koru.
-keep class isar.** { *; }
-keep class dev.isar.** { *; }
-dontwarn isar.**

# ── OkHttp / HTTP ─────────────────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ── Uygulama sınıfları ────────────────────────────────────────────────────────
-keep class com.aladin.iptv.player.pro.** { *; }
-keep class com.aladin.iptv.pro.tv.** { *; }

# ── Genel kurallar ────────────────────────────────────────────────────────────
# Serialization / reflection ile kullanılan sınıfları koru
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Enum'ları koru (valueOf / values() çağrıları için)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Native method bildirimlerini koru
-keepclasseswithmembernames class * {
    native <methods>;
}

# Parcelable implementasyonlarını koru
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
