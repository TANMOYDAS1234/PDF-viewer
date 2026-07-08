# Monetization (disabled)

Ads and the "Remove Ads" in-app purchase are **turned off** so you can use the
app personally with no ads and the smallest possible size. Everything needed to
turn them back on for a Play Store release is preserved in this folder.

Files here:
- `ads_config.dart` – ad unit IDs + IAP product id (has test IDs; add real ones)
- `ad_manager.dart` – banner + interstitial helper
- `purchase_manager.dart` – "Remove Ads" one-time purchase
- `banner_ad_widget.dart` – self-managing banner widget

## Re-enable before publishing

1. **Move the files back:**
   ```
   move ad_manager.dart ads_config.dart purchase_manager.dart ..\lib\services\
   move banner_ad_widget.dart ..\lib\widgets\
   ```

2. **Add the dependencies** (in `pubspec.yaml`, under dependencies):
   ```yaml
   google_mobile_ads: ^9.0.0
   in_app_purchase: ^3.3.0
   ```
   then run `flutter pub get`.

3. **Add your AdMob App ID** to `android/app/src/main/AndroidManifest.xml`
   inside `<application>` (replace the test id with your real one):
   ```xml
   <meta-data
       android:name="com.google.android.gms.ads.APPLICATION_ID"
       android:value="ca-app-pub-3940256099942544~3347511713" />
   ```

4. **Initialise in `lib/main.dart`** (`main()`):
   ```dart
   import 'services/ad_manager.dart';
   import 'services/purchase_manager.dart';
   final purchaseManager = PurchaseManager();
   // inside main(), before runApp:
   purchaseManager.init();
   AdManager.instance.init();
   ```

5. **Home screen** (`lib/screens/home_screen.dart`): wrap the `Scaffold` in
   `AnimatedBuilder(animation: purchaseManager, …)`, add
   `bottomNavigationBar: purchaseManager.adsRemoved ? null : const SafeArea(child: BannerAdWidget())`,
   and re-add the "Remove Ads" header button + bottom sheet.

6. **Viewer** (`lib/screens/viewer_screen.dart`): re-add `initState` that calls
   `AdManager.instance.maybeShowInterstitialOnOpen(adsRemoved: purchaseManager.adsRemoved)`.

7. In `ads_config.dart` set `useTestAds = false` and paste your real ad unit IDs,
   and create a non-consumable product `remove_ads` in the Play Console.

> Tip: the full wired-up version was working before removal — these steps just
> reverse the "disable" edit.
