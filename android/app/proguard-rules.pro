# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core / deferred components are referenced by the Flutter embedding but
# are not bundled — silence the missing-class warnings.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Google Play Billing (in_app_purchase)
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Syncfusion PDF viewer / document library
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# Printing plugin uses the Android print framework via reflection
-keep class net.nfet.** { *; }
-dontwarn net.nfet.**

# ML Kit document scanner pulls in optional Huawei HMS / Cronet / Conscrypt /
# BouncyCastle network classes (only used on Huawei devices). Ignore them.
-dontwarn com.huawei.**
-dontwarn org.chromium.net.**
-dontwarn org.conscrypt.**
-dontwarn com.android.org.conscrypt.**
-dontwarn org.bouncycastle.**
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep annotations and generic signatures
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
