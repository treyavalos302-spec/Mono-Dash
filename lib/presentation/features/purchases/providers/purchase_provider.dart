import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/utils/app_logger.dart';

final purchaseControllerProvider =
    AsyncNotifierProvider<PurchaseController, PurchaseState>(
      PurchaseController.new,
    );

class RevenueCatConfig {
  const RevenueCatConfig._();

  static const iosApiKey = 'appl_uQclCTdAgutFrwPUlmIzMxhagIe';
  static const androidApiKey = '';
  static const webApiKey = '';
  static const entitlementId = 'Mono Dash Unlimited';
  static const offeringId = 'default';
  static const freeServerLimit = 1;

  static String? get apiKey {
    if (kIsWeb) return webApiKey.isEmpty ? null : webApiKey;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _usableApiKey(iosApiKey);
      case TargetPlatform.android:
        return _usableApiKey(androidApiKey);
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return null;
    }
  }

  static String? _usableApiKey(String key) {
    if (key.isEmpty || key.startsWith('REPLACE_WITH_')) return null;
    return key;
  }
}

class PurchaseState {
  const PurchaseState({
    required this.isConfigured,
    required this.isUnlocked,
    required this.freeServerLimit,
    required this.entitlementId,
    this.priceText,
    this.hasPackage = false,
    this.message,
  });

  final bool isConfigured;
  final bool isUnlocked;
  final int freeServerLimit;
  final String entitlementId;
  final String? priceText;
  final bool hasPackage;
  final String? message;

  bool canAddServer(int serverCount) {
    return isUnlocked || serverCount < freeServerLimit;
  }

  PurchaseState copyWith({
    bool? isConfigured,
    bool? isUnlocked,
    int? freeServerLimit,
    String? entitlementId,
    String? priceText,
    bool? hasPackage,
    String? message,
  }) {
    return PurchaseState(
      isConfigured: isConfigured ?? this.isConfigured,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      freeServerLimit: freeServerLimit ?? this.freeServerLimit,
      entitlementId: entitlementId ?? this.entitlementId,
      priceText: priceText ?? this.priceText,
      hasPackage: hasPackage ?? this.hasPackage,
      message: message ?? this.message,
    );
  }
}

class ServerLimitReachedException implements Exception {
  const ServerLimitReachedException({
    required this.serverCount,
    required this.freeServerLimit,
    required this.message,
  });

  final int serverCount;
  final int freeServerLimit;
  final String message;

  @override
  String toString() => message;
}

class PurchaseUnavailableException implements Exception {
  const PurchaseUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PurchaseController extends AsyncNotifier<PurchaseState> {
  static const _tag = 'purchase';
  static const _localUnlockKey = 'purchase.unlimited_servers.unlocked';
  static bool _configured = false;

  @override
  Future<PurchaseState> build() async {
    final l10n = ref.read(appLocalizationsProvider);
    final apiKey = RevenueCatConfig.apiKey;
    if (apiKey == null) {
      final localUnlocked = _isLocallyUnlocked();
      return PurchaseState(
        isConfigured: false,
        isUnlocked: localUnlocked,
        freeServerLimit: RevenueCatConfig.freeServerLimit,
        entitlementId: RevenueCatConfig.entitlementId,
        message: localUnlocked
            ? l10n.purchases_offlineUnlocked
            : l10n.purchases_apiKeyMissing,
      );
    }

    try {
      await _configure(apiKey);
      return await _loadState();
    } catch (error) {
      AppLogger.w(_tag, 'Purchase service initialization failed: $error');
      final localUnlocked = _isLocallyUnlocked();
      return PurchaseState(
        isConfigured: false,
        isUnlocked: localUnlocked,
        freeServerLimit: RevenueCatConfig.freeServerLimit,
        entitlementId: RevenueCatConfig.entitlementId,
        message: localUnlocked
            ? l10n.purchases_serviceUnavailableOfflineUnlocked
            : l10n.purchases_serviceUnavailableNetwork,
      );
    }
  }

  Future<PurchaseState> refresh() async {
    final current = state.valueOrNull;
    if (current != null && !current.isConfigured) return current;

    state = const AsyncValue.loading();
    final next = await AsyncValue.guard(_loadState);
    state = next;
    return next.requireValue;
  }

  Future<PurchaseState> restorePurchases() async {
    _ensureConfigured();
    final customerInfo = await rc.Purchases.restorePurchases();
    final next = await _stateFromCustomerInfo(customerInfo);
    state = AsyncValue.data(next);
    return next;
  }

  Future<PurchaseState> purchaseUnlimitedServers() async {
    _ensureConfigured();
    final package = await _loadPurchasePackage();
    if (package == null) {
      throw PurchaseUnavailableException(
        ref.read(appLocalizationsProvider).purchases_noPackageAvailable,
      );
    }

    try {
      final result = await rc.Purchases.purchase(
        rc.PurchaseParams.package(package),
      );
      final next = await _stateFromCustomerInfo(result.customerInfo);
      state = AsyncValue.data(next);
      return next;
    } on PlatformException catch (error) {
      final code = rc.PurchasesErrorHelper.getErrorCode(error);
      if (code == rc.PurchasesErrorCode.purchaseCancelledError) {
        return state.requireValue;
      }
      rethrow;
    }
  }

  Future<void> _configure(String apiKey) async {
    if (_configured) return;
    await rc.Purchases.configure(rc.PurchasesConfiguration(apiKey));
    _configured = true;
  }

  Future<PurchaseState> _loadState() async {
    try {
      final customerInfo = await rc.Purchases.getCustomerInfo();
      return _stateFromCustomerInfo(customerInfo);
    } catch (error) {
      AppLogger.w(_tag, 'Purchase status refresh failed: $error');
      final localUnlocked = _isLocallyUnlocked();
      if (!localUnlocked) rethrow;
      return PurchaseState(
        isConfigured: true,
        isUnlocked: true,
        freeServerLimit: RevenueCatConfig.freeServerLimit,
        entitlementId: RevenueCatConfig.entitlementId,
        message: ref
            .read(appLocalizationsProvider)
            .purchases_serviceUnavailableOfflineUnlocked,
      );
    }
  }

  Future<PurchaseState> _stateFromCustomerInfo(
    rc.CustomerInfo customerInfo,
  ) async {
    String? priceText;
    var hasPackage = false;
    String? message;

    try {
      final package = await _loadPurchasePackage();
      priceText = package?.storeProduct.priceString;
      hasPackage = package != null;
    } catch (error) {
      AppLogger.w(_tag, 'Purchase package loading failed: $error');
      message = ref.read(appLocalizationsProvider).purchases_packageLoadFailed;
    }

    final unlocked = _hasUnlimitedServers(customerInfo);
    await _setLocallyUnlocked(unlocked);

    return PurchaseState(
      isConfigured: true,
      isUnlocked: unlocked,
      freeServerLimit: RevenueCatConfig.freeServerLimit,
      entitlementId: RevenueCatConfig.entitlementId,
      priceText: priceText,
      hasPackage: hasPackage,
      message: message,
    );
  }

  bool _hasUnlimitedServers(rc.CustomerInfo customerInfo) {
    return customerInfo
            .entitlements
            .all[RevenueCatConfig.entitlementId]
            ?.isActive ??
        false;
  }

  Future<rc.Package?> _loadPurchasePackage() async {
    final offerings = await rc.Purchases.getOfferings();
    final offering = RevenueCatConfig.offeringId.isEmpty
        ? offerings.current
        : offerings.all[RevenueCatConfig.offeringId];
    final packages = offering?.availablePackages ?? const <rc.Package>[];
    return packages.isEmpty ? null : packages.first;
  }

  void _ensureConfigured() {
    final current = state.valueOrNull;
    if (current == null || !current.isConfigured) {
      throw PurchaseUnavailableException(
        current?.message ??
            ref.read(appLocalizationsProvider).purchases_serviceNotInitialized,
      );
    }
  }

  bool _isLocallyUnlocked() {
    return ref.read(storageServiceProvider).getString(_localUnlockKey) ==
        'true';
  }

  Future<void> _setLocallyUnlocked(bool value) {
    return ref
        .read(storageServiceProvider)
        .setString(_localUnlockKey, value ? 'true' : 'false');
  }
}
