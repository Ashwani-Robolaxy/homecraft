import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/subscription_data.dart';

/// Secrets returned by POST /professionals/subscription/payment-sheet.
class PaymentSheetSecrets {
  const PaymentSheetSecrets({
    required this.paymentIntentClientSecret,
    required this.ephemeralKeySecret,
    required this.customerId,
    required this.publishableKey,
    required this.planKey,
    required this.amountEurosCharged,
    required this.queuedPlanChange,
    this.pendingPlanKey,
    this.message,
    this.effectiveAt,
  });

  final String paymentIntentClientSecret;
  final String ephemeralKeySecret;
  final String customerId;
  final String publishableKey;
  final String planKey;
  final String amountEurosCharged;
  final bool queuedPlanChange;
  final String? pendingPlanKey;
  final String? message;
  final DateTime? effectiveAt;

  factory PaymentSheetSecrets.fromMap(Map<String, dynamic> m) {
    final root = _extractRootMap(m);
    final effectiveAtRaw = _readAny(root, const [
      'effectiveAt',
      'effective_at',
    ])?.toString();
    return PaymentSheetSecrets(
      paymentIntentClientSecret:
          _readAny(root, const [
            'paymentIntentClientSecret',
            'payment_intent_client_secret',
          ])?.toString() ??
          '',
      ephemeralKeySecret:
          _readAny(root, const [
            'ephemeralKeySecret',
            'ephemeral_key_secret',
          ])?.toString() ??
          '',
      customerId:
          _readAny(root, const ['customerId', 'customer_id'])?.toString() ?? '',
      publishableKey:
          _readAny(root, const [
            'publishableKey',
            'publishable_key',
          ])?.toString() ??
          '',
      planKey: _readAny(root, const ['planKey', 'plan_key'])?.toString() ?? '',
      amountEurosCharged:
          _readAny(root, const [
            'amountEurosCharged',
            'amount_euros_charged',
          ])?.toString() ??
          '',
      queuedPlanChange:
          _readAny(root, const ['queuedPlanChange', 'queued_plan_change']) ==
          true,
      pendingPlanKey: _readAny(root, const [
        'pendingPlanKey',
        'pending_plan_key',
      ])?.toString(),
      message: _readAny(root, const ['message'])?.toString(),
      effectiveAt: (effectiveAtRaw != null && effectiveAtRaw.isNotEmpty)
          ? DateTime.tryParse(effectiveAtRaw)
          : null,
    );
  }

  static Map<String, dynamic> _extractRootMap(Map<String, dynamic> map) {
    for (final key in ['data', 'result', 'payload']) {
      final v = map[key];
      if (v is Map) return Map<String, dynamic>.from(v);
    }
    return map;
  }

  static Object? _readAny(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) return value;
    }
    return null;
  }
}

class SubscriptionRemoteDatasource {
  final ApiClient _api = ApiClient();
  final SessionStorage _session = SessionStorage();

  Future<String?> _getToken() => _session.getToken();

  /// GET /professionals/me/subscription (JWT required)
  /// Returns full paywall context: pricing, catalog, purchase options, subscription state.
  Future<SubscriptionContext> fetchContext() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please log in again.');
    }

    debugPrint('[Subscription] GET /professionals/me/subscription');
    final res = await _api.get('/professionals/me/subscription', token: token);
    debugPrint('[Subscription] response keys: ${res.keys.toList()}');
    return SubscriptionContext.fromMap(res);
  }

  /// POST /professionals/subscription/payment-sheet
  /// Returns Stripe Payment Sheet secrets for the given plan.
  /// [amountEuros] must match exactly what the server has for [planKey].
  Future<PaymentSheetSecrets> requestPaymentSheet({
    required String planKey,
    required String amountEuros,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please log in again.');
    }

    debugPrint(
      '[Subscription] POST /professionals/subscription/payment-sheet planKey=$planKey amount=$amountEuros',
    );
    final res = await _api.post(
      '/professionals/subscription/payment-sheet',
      body: {'planKey': planKey, 'amountEuros': amountEuros},
      token: token,
    );
    debugPrint('[Subscription] payment-sheet keys: ${res.keys.toList()}');
    return PaymentSheetSecrets.fromMap(res);
  }

  /// POST /professionals/me/subscription/cancel (JWT required)
  /// Cancels the professional's active Stripe subscription or turns off auto-renewal (cancel_at_period_end: true).
  /// Pass [immediately] = true in JSON body to cancel immediately instead of waiting for period end.
  Future<Map<String, dynamic>> cancelSubscription({bool immediately = false}) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please log in again.');
    }

    debugPrint('[Subscription] POST /professionals/me/subscription/cancel (immediately: $immediately)');
    final res = await _api.post(
      '/professionals/me/subscription/cancel',
      body: {'immediately': immediately},
      token: token,
    );
    debugPrint('[Subscription] cancel response: $res');
    return res;
  }

  /// GET /professionals/subscription-pricing (public — no token needed)
  /// Returns pricing + catalog only (no subscription state).
  Future<SubscriptionContext> fetchPublicPricing() async {
    debugPrint('[Subscription] GET /professionals/subscription-pricing');
    final res = await _api.get('/professionals/subscription-pricing');
    // Public endpoint has no purchaseOptions / subscription / hints — build a minimal context.
    final pricingRaw = res['pricing'] is Map
        ? Map<String, dynamic>.from(res['pricing'] as Map)
        : <String, dynamic>{};
    final catalogRaw = res['catalog'] is Map
        ? Map<String, dynamic>.from(res['catalog'] as Map)
        : <String, dynamic>{};
    return SubscriptionContext(
      pricing: SubscriptionPricing.fromMaps(pricingRaw, catalogRaw),
      purchaseOptions: const [],
      subscriptionState: const SubscriptionState(
        status: 'none',
        promoEligible: true,
        verificationStatus: '',
      ),
      showPaywall: false,
      showSubscribeDuringTrial: false,
      cancelAtPeriodEnd: false,
    );
  }
}
