import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Patched build: all paid features are unlocked by default.
//
// The original implementation gated "Mono Dash Unlimited" behind a RevenueCat
// in-app purchase and limited the free tier to a single server. This patched
// version removes every purchase requirement: the app always reports a fully
// unlocked, verified entitlement and never contacts RevenueCat or any store.
// ---------------------------------------------------------------------------

final purchaseControllerProvider =
    AsyncNotifierProvider<PurchaseController, PurchaseState>(
      PurchaseController.new,
    );

class RevenueCatConfig {
  const RevenueCatConfig._();

  static const entitlementId = 'Mono Dash Unlimited';
  static const offeringId = 'default';

  // Patched: effectively unlimited free servers.
  static const freeServerLimit = 1 << 30;

  // Patched: always bypass the paid server-limit check.
  static const bypassServerLimitCheck = true;

  // Kept for API compatibility; no key is ever used in the patched build.
  static String? get apiKey => null;
}

enum PurchaseVerificationStatus { localOnly, verified, unverified, unavailable }

class PurchaseState {
  const PurchaseState({
    required this.isConfigured,
    required this.isUnlocked,
    required this.freeServerLimit,
    required this.entitlementId,
    required this.verificationStatus,
    this.priceText,
    this.hasPackage = false,
    this.message,
    this.lastVerifiedAt,
  });

  final bool isConfigured;
  final bool isUnlocked;
  final int freeServerLimit;
  final String entitlementId;
  final PurchaseVerificationStatus verificationStatus;
  final String? priceText;
  final bool hasPackage;
  final String? message;
  final DateTime? lastVerifiedAt;

  bool canAddServer(int serverCount) {
    // Patched: every feature is unlocked, so adding servers is always allowed.
    return true;
  }

  PurchaseState copyWith({
    bool? isConfigured,
    bool? isUnlocked,
    int? freeServerLimit,
    String? entitlementId,
    PurchaseVerificationStatus? verificationStatus,
    String? priceText,
    bool? hasPackage,
    String? message,
    DateTime? lastVerifiedAt,
    bool clearPriceText = false,
    bool clearMessage = false,
  }) {
    return PurchaseState(
      isConfigured: isConfigured ?? this.isConfigured,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      freeServerLimit: freeServerLimit ?? this.freeServerLimit,
      entitlementId: entitlementId ?? this.entitlementId,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      priceText: clearPriceText ? null : priceText ?? this.priceText,
      hasPackage: hasPackage ?? this.hasPackage,
      message: clearMessage ? null : message ?? this.message,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
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
  @override
  Future<PurchaseState> build() => _loadLocalState();

  static Future<bool> isLocallyUnlocked(WidgetRef ref) async {
    return (await ref.read(purchaseControllerProvider.future)).isUnlocked;
  }

  // Always return a fully unlocked, verified state.
  Future<PurchaseState> _loadLocalState() async {
    return PurchaseState(
      isConfigured: true,
      isUnlocked: true,
      freeServerLimit: RevenueCatConfig.freeServerLimit,
      entitlementId: RevenueCatConfig.entitlementId,
      verificationStatus: PurchaseVerificationStatus.verified,
      lastVerifiedAt: DateTime.now().toUtc(),
    );
  }

  Future<PurchaseState> maybeRefreshEntitlementAfterFirstFrame() async {
    final current = state.valueOrNull ?? await _loadLocalState();
    if (state.valueOrNull == null) {
      state = AsyncValue.data(current);
    }
    return current;
  }

  Future<PurchaseState> refresh() => refreshEntitlement();

  Future<PurchaseState> refreshEntitlement({bool force = true}) async {
    final next = await _loadLocalState();
    state = AsyncValue.data(next);
    return next;
  }

  Future<PurchaseState> loadOfferings({bool force = false}) async {
    final next = await _loadLocalState();
    state = AsyncValue.data(next);
    return next;
  }

  Future<PurchaseState> restorePurchases() async {
    final next = await _loadLocalState();
    state = AsyncValue.data(next);
    return next;
  }

  Future<PurchaseState> purchaseUnlimitedServers() async {
    final next = await _loadLocalState();
    state = AsyncValue.data(next);
    return next;
  }
}
