/// A single plan option shown in the UI (from `purchaseOptions` array).
class PurchaseOption {
  const PurchaseOption({
    required this.planKey,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.priceEuros,
    required this.eligible,
    this.durationDays,
    this.appliesAfterTrial = false,
  });

  final String planKey;
  final String kind; // "trial" | "month" | "year"
  final String title;
  final String subtitle;
  final String priceEuros;
  final bool eligible;
  final int? durationDays;
  final bool appliesAfterTrial;

  bool get isTrial => kind == 'trial';

  factory PurchaseOption.fromMap(Map<String, dynamic> m) => PurchaseOption(
        planKey: m['planKey']?.toString() ?? '',
        kind: m['kind']?.toString() ?? '',
        title: m['title']?.toString() ?? '',
        subtitle: m['subtitle']?.toString() ?? '',
        priceEuros: m['priceEuros']?.toString() ?? '0.00',
        eligible: m['eligible'] == true,
        durationDays: m['durationDays'] is int ? m['durationDays'] as int : null,
        appliesAfterTrial: m['appliesAfterTrial'] == true,
      );
}

/// Subscription state for the current professional.
class SubscriptionState {
  const SubscriptionState({
    required this.status,
    required this.promoEligible,
    required this.verificationStatus,
    this.trialActive = false,
    this.trialDaysRemaining = 0,
    this.trialEndsAt,
    this.trialStartsAfterVerification = false,
  });

  final String status; // "none" | "trial" | "active" | "lapsed"
  final bool promoEligible;
  final String verificationStatus;
  final bool trialActive;
  final int trialDaysRemaining;
  final DateTime? trialEndsAt;
  final bool trialStartsAfterVerification;

  bool get isActive => status == 'active';
  bool get isOnTrial => status == 'trial' && trialActive;
  bool get needsSubscription => status == 'none' || status == 'lapsed';

  factory SubscriptionState.fromMap(Map<String, dynamic> m) {
    final trial = m['trial'] is Map ? m['trial'] as Map : {};
    DateTime? trialEndsAt;
    final endsRaw = trial['endsAt'] ?? m['trialEndsAt'];
    if (endsRaw is String && endsRaw.isNotEmpty) {
      trialEndsAt = DateTime.tryParse(endsRaw);
    }
    return SubscriptionState(
      status: m['status']?.toString() ?? 'none',
      promoEligible: m['promoEligible'] == true,
      verificationStatus: m['verificationStatus']?.toString() ?? '',
      trialActive: trial['active'] == true,
      trialDaysRemaining: trial['daysRemaining'] is int ? trial['daysRemaining'] as int : 0,
      trialEndsAt: trialEndsAt,
      trialStartsAfterVerification: m['trialStartsAfterVerification'] == true,
    );
  }
}

/// Pricing numbers from the admin settings.
class SubscriptionPricing {
  const SubscriptionPricing({
    required this.trialDays,
    required this.monthlyReducedEuros,
    required this.monthlyStandardEuros,
    required this.annualEuros,
    required this.reducedPeriodMonths,
    required this.currency,
    required this.vatNote,
  });

  final int trialDays;
  final String monthlyReducedEuros;
  final String monthlyStandardEuros;
  final String annualEuros;
  final int reducedPeriodMonths;
  final String currency;
  final String vatNote;

  factory SubscriptionPricing.fromMaps(
      Map<String, dynamic> pricing, Map<String, dynamic> catalog) {
    return SubscriptionPricing(
      trialDays: pricing['trialDays'] is int ? pricing['trialDays'] as int : 45,
      monthlyReducedEuros: pricing['monthlyReducedEuros']?.toString() ?? '99.00',
      monthlyStandardEuros: pricing['monthlyStandardEuros']?.toString() ?? '140.00',
      annualEuros: pricing['annualEuros']?.toString() ?? '1300.00',
      reducedPeriodMonths: pricing['reducedPeriodMonths'] is int ? pricing['reducedPeriodMonths'] as int : 6,
      currency: catalog['currency']?.toString() ?? 'EUR',
      vatNote: catalog['vatNote']?.toString() ?? 'All amounts exclude VAT.',
    );
  }

  String get currencySymbol {
    switch (currency) {
      case 'EUR': return '€';
      case 'USD': return '\$';
      case 'GBP': return '£';
      default: return currency;
    }
  }
}

/// Full subscription context returned by GET /professionals/me/subscription.
class SubscriptionContext {
  const SubscriptionContext({
    required this.pricing,
    required this.purchaseOptions,
    required this.subscriptionState,
    required this.showPaywall,
    required this.showSubscribeDuringTrial,
    this.subscriptionEndsAt,
    this.cancelAtPeriodEnd = false,
    this.canceledAt,
  });

  final SubscriptionPricing pricing;
  final List<PurchaseOption> purchaseOptions;
  final SubscriptionState subscriptionState;
  final bool showPaywall;
  final bool showSubscribeDuringTrial;

  /// End date of the currently active Stripe subscription period.
  /// Parsed from `stripe.currentPeriodEnd` in the API response.
  final DateTime? subscriptionEndsAt;

  /// Whether auto-renewal is disabled and the subscription will cancel at current period end.
  final bool cancelAtPeriodEnd;

  /// When the subscription cancellation was scheduled/executed.
  final DateTime? canceledAt;

  factory SubscriptionContext.fromMap(Map<String, dynamic> m) {
    final pricingRaw = m['pricing'] is Map ? Map<String, dynamic>.from(m['pricing'] as Map) : <String, dynamic>{};
    final catalogRaw = m['catalog'] is Map ? Map<String, dynamic>.from(m['catalog'] as Map) : <String, dynamic>{};
    final optionsRaw = m['purchaseOptions'] is List ? m['purchaseOptions'] as List : [];
    final subRaw = m['subscription'] is Map ? Map<String, dynamic>.from(m['subscription'] as Map) : <String, dynamic>{};
    final hintsRaw = m['hints'] is Map ? Map<String, dynamic>.from(m['hints'] as Map) : <String, dynamic>{};
    final stripeRaw = m['stripe'] is Map ? Map<String, dynamic>.from(m['stripe'] as Map) : <String, dynamic>{};

    // Parse Stripe subscription end date
    DateTime? subscriptionEndsAt;
    final periodEndRaw = stripeRaw['currentPeriodEnd'] ??
        stripeRaw['current_period_end'] ??
        subRaw['currentPeriodEnd'] ??
        subRaw['current_period_end'] ??
        subRaw['endsAt'] ??
        subRaw['ends_at'];
    if (periodEndRaw is String && periodEndRaw.isNotEmpty) {
      subscriptionEndsAt = DateTime.tryParse(periodEndRaw);
    } else if (periodEndRaw is int) {
      final sec = periodEndRaw;
      subscriptionEndsAt = sec > 10000000000
          ? DateTime.fromMillisecondsSinceEpoch(sec)
          : DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    }

    DateTime? canceledAt;
    final canceledAtRaw = stripeRaw['canceledAt'] ??
        stripeRaw['canceled_at'] ??
        subRaw['canceledAt'] ??
        subRaw['canceled_at'];
    if (canceledAtRaw is String && canceledAtRaw.isNotEmpty) {
      canceledAt = DateTime.tryParse(canceledAtRaw);
    }

    final cancelAtPeriodEnd = stripeRaw['cancelAtPeriodEnd'] == true ||
        stripeRaw['cancel_at_period_end'] == true ||
        stripeRaw['autoRenew'] == false ||
        stripeRaw['auto_renew'] == false ||
        stripeRaw['autoRenewing'] == false ||
        stripeRaw['auto_renewing'] == false ||
        stripeRaw['status'] == 'canceled' ||
        stripeRaw['status'] == 'cancelled' ||
        subRaw['cancelAtPeriodEnd'] == true ||
        subRaw['cancel_at_period_end'] == true ||
        subRaw['autoRenew'] == false ||
        subRaw['auto_renew'] == false ||
        subRaw['autoRenewing'] == false ||
        subRaw['auto_renewing'] == false ||
        subRaw['isCancelled'] == true ||
        subRaw['is_cancelled'] == true ||
        subRaw['status'] == 'canceled' ||
        subRaw['status'] == 'cancelled' ||
        m['cancelAtPeriodEnd'] == true ||
        m['cancel_at_period_end'] == true ||
        m['autoRenew'] == false ||
        m['auto_renew'] == false ||
        m['autoRenewing'] == false ||
        m['auto_renewing'] == false ||
        (canceledAt != null && subscriptionEndsAt != null && subscriptionEndsAt.isAfter(DateTime.now()));

    return SubscriptionContext(
      pricing: SubscriptionPricing.fromMaps(pricingRaw, catalogRaw),
      purchaseOptions: optionsRaw
          .whereType<Map>()
          .map((e) => PurchaseOption.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      subscriptionState: SubscriptionState.fromMap(subRaw),
      showPaywall: hintsRaw['showPaywall'] == true,
      showSubscribeDuringTrial: hintsRaw['showSubscribeDuringTrial'] == true,
      subscriptionEndsAt: subscriptionEndsAt,
      cancelAtPeriodEnd: cancelAtPeriodEnd,
      canceledAt: canceledAt,
    );
  }
}
