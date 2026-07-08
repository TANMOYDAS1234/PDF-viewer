import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads_config.dart';

/// Manages the one-time "Remove Ads" in-app purchase and exposes whether ads
/// should currently be shown.
class PurchaseManager extends ChangeNotifier {
  static const _prefKey = 'ads_removed';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _adsRemoved = false;
  bool get adsRemoved => _adsRemoved;

  bool _storeAvailable = false;
  bool get storeAvailable => _storeAvailable;

  ProductDetails? _removeAdsProduct;
  ProductDetails? get removeAdsProduct => _removeAdsProduct;

  /// Localised price string (e.g. "$1.99") when the product is available.
  String get priceLabel => _removeAdsProduct?.price ?? '';

  String? lastError;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool(_prefKey) ?? false;
    notifyListeners();

    try {
      _storeAvailable = await _iap.isAvailable();
    } catch (_) {
      _storeAvailable = false;
    }
    if (!_storeAvailable) return;

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) {
        lastError = '$e';
        notifyListeners();
      },
    );

    await _loadProducts();
    // Silently restore so re-installs / new devices regain the purchase.
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    try {
      final resp =
          await _iap.queryProductDetails({AdsConfig.removeAdsProductId});
      if (resp.productDetails.isNotEmpty) {
        _removeAdsProduct = resp.productDetails.first;
        notifyListeners();
      }
    } catch (e) {
      lastError = '$e';
    }
  }

  /// Start the purchase flow. Returns false if it couldn't be started.
  Future<bool> buyRemoveAds() async {
    lastError = null;
    if (!_storeAvailable) {
      lastError = 'In-app billing is not available on this device.';
      notifyListeners();
      return false;
    }
    final product = _removeAdsProduct;
    if (product == null) {
      lastError =
          'The "Remove Ads" product isn\'t set up in the store yet.';
      notifyListeners();
      return false;
    }
    return _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  Future<void> restore() async {
    if (!_storeAvailable) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      lastError = '$e';
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        if (p.productID == AdsConfig.removeAdsProductId) {
          await _setRemoved(true);
        }
      } else if (p.status == PurchaseStatus.error) {
        lastError = p.error?.message ?? 'Purchase failed.';
        notifyListeners();
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  Future<void> _setRemoved(bool value) async {
    _adsRemoved = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
