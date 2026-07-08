import 'dart:io';

/// Central place for ad unit IDs and the in-app-purchase product id.
///
/// While [useTestAds] is true the app shows Google's official *test* ads, which
/// are safe to click and won't get your AdMob account flagged. Before
/// publishing: create your own ad units at https://apps.admob.com, paste the
/// real IDs below, and set [useTestAds] to false (and update the AdMob App ID
/// in AndroidManifest.xml).
class AdsConfig {
  AdsConfig._();

  static const bool useTestAds = true;

  // --- Google official TEST ad unit IDs -------------------------------------
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';

  // --- Your REAL ad unit IDs (replace before release) -----------------------
  static const String _prodBannerAndroid = 'REPLACE_WITH_YOUR_BANNER_ID';
  static const String _prodInterstitialAndroid =
      'REPLACE_WITH_YOUR_INTERSTITIAL_ID';

  static String get bannerUnitId {
    if (Platform.isAndroid) {
      return useTestAds ? _testBannerAndroid : _prodBannerAndroid;
    }
    return _testBannerAndroid;
  }

  static String get interstitialUnitId {
    if (Platform.isAndroid) {
      return useTestAds ? _testInterstitialAndroid : _prodInterstitialAndroid;
    }
    return _testInterstitialAndroid;
  }

  /// In-app product id for the one-time "Remove Ads" upgrade.
  /// Create this as a non-consumable managed product in the Play Console with
  /// the SAME id.
  static const String removeAdsProductId = 'remove_ads';

  /// Show an interstitial every N document opens (when ads are enabled).
  static const int interstitialEveryNOpens = 3;
}
