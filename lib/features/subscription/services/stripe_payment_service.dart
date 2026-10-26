import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../data/subscription_remote_datasource.dart';
import '../domain/subscription_data.dart';

// ── Result types ──────────────────────────────────────────────────────────────

sealed class PaymentResult {}

class PaymentSuccess extends PaymentResult {
  PaymentSuccess({required this.planKey, required this.amountEuros});
  final String planKey;
  final String amountEuros;
}

class PaymentQueuedChange extends PaymentResult {
  PaymentQueuedChange({
    required this.pendingPlanKey,
    this.effectiveAt,
    this.message,
  });
  final String pendingPlanKey;
  final DateTime? effectiveAt;
  final String? message;
}

class PaymentCancelled extends PaymentResult {}

class PaymentError extends PaymentResult {
  PaymentError(this.message);
  final String message;
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Handles the full Stripe Payment Sheet flow:
///   1. Request secrets from backend (POST /professionals/subscription/payment-sheet)
///   2. Initialise the Stripe Payment Sheet
///   3. Present the sheet to the user
///   4. Return a typed [PaymentResult]
class StripePaymentService {
  StripePaymentService._();
  static final instance = StripePaymentService._();

  final _ds = SubscriptionRemoteDatasource();

  Future<PaymentResult> pay(PurchaseOption option) async {
    try {
      // ── 1. Get Payment Sheet secrets from server ──────────────────────────
      final secrets = await _ds.requestPaymentSheet(
        planKey: option.planKey,
        amountEuros: option.priceEuros,
      );

      // Backend can queue a plan change for period-end without immediate charge.
      if (secrets.queuedPlanChange) {
        return PaymentQueuedChange(
          pendingPlanKey: secrets.pendingPlanKey?.isNotEmpty == true
              ? secrets.pendingPlanKey!
              : option.planKey,
          effectiveAt: secrets.effectiveAt,
          message: secrets.message,
        );
      }

      if (secrets.publishableKey.isEmpty ||
          secrets.paymentIntentClientSecret.isEmpty) {
        return PaymentError(
          'Invalid payment configuration received from server.',
        );
      }

      // ── 2. Set Stripe publishable key (provided by server) ────────────────
      Stripe.publishableKey = secrets.publishableKey;
      await Stripe.instance.applySettings();

      // ── 3. Initialise Payment Sheet ───────────────────────────────────────
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'HomeCraft',
          customerId: secrets.customerId.isNotEmpty ? secrets.customerId : null,
          customerEphemeralKeySecret: secrets.ephemeralKeySecret.isNotEmpty
              ? secrets.ephemeralKeySecret
              : null,
          paymentIntentClientSecret: secrets.paymentIntentClientSecret,
          style: ThemeMode.light,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: const Color(0xFF8B0000),
            ),
            shapes: PaymentSheetShape(borderRadius: 12),
          ),
        ),
      );

      // ── 4. Present sheet to user ──────────────────────────────────────────
      await Stripe.instance.presentPaymentSheet();

      debugPrint(
        '[Stripe] Payment succeeded: ${secrets.planKey} €${secrets.amountEurosCharged}',
      );
      return PaymentSuccess(
        planKey: secrets.planKey,
        amountEuros: secrets.amountEurosCharged,
      );
    } on StripeException catch (e) {
      debugPrint('[Stripe] StripeException: ${e.error}');
      if (e.error.code == FailureCode.Canceled) return PaymentCancelled();
      final msg =
          e.error.localizedMessage ??
          e.error.message ??
          'Payment failed. Please try again.';
      return PaymentError(msg);
    } on Exception catch (e) {
      debugPrint('[Stripe] Exception: $e');
      final msg = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('ApiException: ', '');
      return PaymentError(
        msg.isNotEmpty ? msg : 'Payment could not be completed.',
      );
    }
  }
}
