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

# Keep annotations and generic signatures
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
