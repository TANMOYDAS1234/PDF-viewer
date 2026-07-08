import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';

/// Thin wrapper around google_mobile_ads for a home banner and an occasional
/// interstitial shown when opening documents.
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  bool _initialized = false;
  InterstitialAd? _interstitial;
  int _openCount = 0;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  bool get isInitialized => _initialized;

  /// Create a fresh adaptive banner. Caller owns disposal.
  BannerAd createBanner() {
    return BannerAd(
      size: AdSize.banner,
      adUnitId: AdsConfig.bannerUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdsConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Show an interstitial on every Nth document open. No-op when ads removed.
  void maybeShowInterstitialOnOpen({required bool adsRemoved}) {
    if (adsRemoved || !_initialized) return;
    _openCount++;
    if (_openCount % AdsConfig.interstitialEveryNOpens != 0) return;

    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitial = null;
        _loadInterstitial();
      },
    );
    ad.show();
    _interstitial = null;
  }
}
