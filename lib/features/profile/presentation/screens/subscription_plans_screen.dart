import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../subscription/data/subscription_remote_datasource.dart';
import '../../../subscription/domain/subscription_data.dart';
import '../../../subscription/services/stripe_payment_service.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  final _ds = SubscriptionRemoteDatasource();

  SubscriptionContext? _ctx;
  bool _loading = true;
  bool _cancelling = false;
  String? _error;
  String? _payingPlanKey; // tracks which plan button shows a spinner

  List<String> get _introPoints => [
    'provider.profile.choose_plans'.tr(),
    'provider.profile.showcase_skills'.tr(),
    'provider.profile.let_start_work'.tr(),
  ];

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = await _ds.fetchContext();
      if (!mounted) return;
      setState(() {
        _ctx = ctx;
        _loading = false;
      });
    } catch (e) {
      // If authenticated call fails (e.g. professional not yet verified), fall back to public pricing
      try {
        final ctx = await _ds.fetchPublicPricing();
        if (!mounted) return;
        setState(() {
          _ctx = ctx;
          _loading = false;
        });
      } catch (e2) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e2.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
        });
      }
    }
  }

  Future<void> _confirmCancelSubscription(SubscriptionContext ctx) async {
    final dateStr = ctx.subscriptionEndsAt != null ? _fmt(ctx.subscriptionEndsAt!) : null;
    final message = dateStr != null
        ? 'provider.profile.cancel_subscription_confirm_with_date'.tr(namedArgs: {'date': dateStr})
        : 'provider.profile.cancel_subscription_confirm'.tr();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.alertTriangle, color: AppColors.primaryRed, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'provider.profile.cancel_subscription_title'.tr(),
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54, height: 1.5),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'provider.profile.keep_subscription'.tr(),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'provider.profile.confirm_cancellation'.tr(),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final res = await _ds.cancelSubscription(immediately: false);
      if (!mounted) return;
      final serverMsg = res['message']?.toString();
      final msg = (serverMsg != null && serverMsg.trim().isNotEmpty)
          ? AppToast.localizeBackendMessage(serverMsg, context)
          : 'provider.profile.subscription_cancelled_success'.tr();
      AppToast.success(msg);
      await _load();
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      AppToast.error(AppToast.localizeBackendMessage(raw, context));
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Background image + readability overlays
            Positioned.fill(child: Image.asset(AppAssets.subscriptionBackground, fit: BoxFit.cover)),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.62),
                      Colors.black.withValues(alpha: 0.35),
                      AppColors.primaryRed.withValues(alpha: 0.22),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.18))),
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(context),
                  Expanded(
                    child: _loading
                        ? _buildShimmer()
                        : _error != null
                        ? _buildError()
                        : _buildContent(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 24),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              'provider.profile.subscription_plans'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final ctx = _ctx!;
    final pricing = ctx.pricing;
    final sub = ctx.subscriptionState;

    // Trial button label
    final trialLabel = sub.promoEligible && !sub.isOnTrial && !sub.isActive
        ? 'provider.profile.test_days_free'.tr(args: ['${pricing.trialDays}'])
        : sub.isOnTrial
        ? 'provider.profile.days_left_in_trial'.tr(args: ['${sub.trialDaysRemaining}'])
        : sub.isActive
        ? (ctx.cancelAtPeriodEnd
            ? 'provider.profile.subscription_cancelled_status'.tr()
            : 'provider.profile.subscription_active'.tr())
        : 'provider.profile.start_free_trial'.tr();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notice banner
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.info, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'provider.profile.notice_cancellation'.tr(),
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.white, height: 1.4, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // Intro checkmarks
          ..._introPoints.map(
            (pt) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(LucideIcons.check, color: AppColors.primaryRed, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    pt,
                    style: GoogleFonts.outfit(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Trial / main CTA button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: sub.isActive ? null : () => _onTrialTap(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: sub.isActive ? Colors.white24 : AppColors.primaryRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white60,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(trialLabel, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
          ),

          // Cancel subscription / auto-renewal status when active
          if (sub.isActive) ...[
            const SizedBox(height: 12),
            if (ctx.cancelAtPeriodEnd)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.calendarX, color: Colors.amber, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ctx.subscriptionEndsAt != null
                            ? 'provider.profile.auto_renewal_off'.tr(args: [_fmt(ctx.subscriptionEndsAt!)])
                            : 'provider.profile.cancellation_scheduled'.tr(),
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelling ? null : () => _confirmCancelSubscription(ctx),
                  icon: _cancelling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                        )
                      : const Icon(LucideIcons.xCircle, size: 18, color: Colors.white70),
                  label: Text(
                    _cancelling
                        ? 'provider.profile.cancelling'.tr()
                        : 'provider.profile.cancel_subscription'.tr(),
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
          ],

          const SizedBox(height: 24),

          // Plan cards from purchaseOptions, or static premium card
          if (ctx.purchaseOptions.isNotEmpty)
            ...ctx.purchaseOptions
                .where((o) => !o.isTrial) // trial shown as banner above
                .map(
                  (opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlanCard(
                      option: opt,
                      pricing: pricing,
                      isPaying: _payingPlanKey == opt.planKey,
                      anyPaying: _payingPlanKey != null,
                      hasActiveSubscription: sub.isActive || sub.isOnTrial,
                      onTap: () => _onPlanTap(opt, ctx),
                    ),
                  ),
                )
          else
            _buildStaticPremiumCard(pricing),

          const SizedBox(height: 8),
          Text(
            pricing.vatNote,
            style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Fallback when purchaseOptions is empty (public pricing fetch).
  Widget _buildStaticPremiumCard(SubscriptionPricing pricing) {
    return _buildPlanCard(
      title: 'provider.profile.premium_plan'.tr(),
      price: '${pricing.currencySymbol} ${pricing.monthlyStandardEuros}/${'provider.profile.month'.tr()}',
      buttonLabel: 'provider.profile.day_free_premium'.tr(args: ['${pricing.trialDays}']),
      onTap: () => AppToast.info('provider.profile.login_pro_to_subscribe'.tr()),
    );
  }

  Widget _buildPlanCard({required String title, required String price, required String buttonLabel, required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primaryRed),
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryRed),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(buttonLabel, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _onTrialTap(SubscriptionContext ctx) {
    if (ctx.subscriptionState.isOnTrial) {
      AppToast.info('provider.profile.already_on_trial'.tr());
    } else if (ctx.subscriptionState.trialStartsAfterVerification) {
      AppToast.info('provider.profile.trial_starts_verification'.tr());
    } else {
      AppToast.info('provider.profile.contact_support_trial'.tr());
    }
  }

  Future<void> _onPlanTap(PurchaseOption opt, SubscriptionContext ctx) async {
    if (ctx.subscriptionState.isOnTrial) {
      AppToast.info('provider.profile.already_on_trial'.tr());
      return;
    }
    if (ctx.subscriptionState.isActive) {
      AppToast.info('provider.profile.already_active_subscription'.tr());
      return;
    }
    if (!opt.eligible) {
      AppToast.error('provider.profile.plan_not_available'.tr());
      return;
    }
    if (_payingPlanKey != null) return; // already processing another plan

    setState(() => _payingPlanKey = opt.planKey);
    try {
      final result = await StripePaymentService.instance.pay(opt);
      if (!mounted) return;
      switch (result) {
        case PaymentSuccess():
          AppToast.success('provider.profile.payment_successful'.tr(args: [opt.title]));
          // Refresh subscription state so UI reflects new status
          _load();
        case PaymentQueuedChange(:final pendingPlanKey, :final effectiveAt, :final message):
          final when = effectiveAt != null ? ' It will take effect on ${effectiveAt.toLocal().toString().split(' ').first}.' : '';
          final fallback = 'Plan change queued for $pendingPlanKey.$when';
          AppToast.info((message != null && message.trim().isNotEmpty) ? message : fallback);
          _load();
        case PaymentCancelled():
          AppToast.info('provider.profile.payment_cancelled'.tr());
        case PaymentError(:final message):
          AppToast.error(message);
      }
    } finally {
      if (mounted) setState(() => _payingPlanKey = null);
    }
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.wifiOff, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              _error != null ? AppToast.localizeBackendMessage(_error!, context) : 'provider.profile.could_not_load_plans'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(LucideIcons.refreshCw, size: 16, color: Colors.white),
              label: Text('common.retry'.tr(), style: GoogleFonts.outfit(color: Colors.white)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 220, height: 18, radius: 6),
            const SizedBox(height: 14),
            ShimmerBox(width: 180, height: 18, radius: 6),
            const SizedBox(height: 14),
            ShimmerBox(width: 200, height: 18, radius: 6),
            const SizedBox(height: 28),
            ShimmerBox(width: double.infinity, height: 52, radius: 12),
            const SizedBox(height: 24),
            ShimmerBox(width: double.infinity, height: 280, radius: 16),
          ],
        ),
      ),
    );
  }
}

// ── Dynamic plan card built from API PurchaseOption ───────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.option, required this.pricing, required this.onTap, this.isPaying = false, this.anyPaying = false, this.hasActiveSubscription = false});

  final PurchaseOption option;
  final SubscriptionPricing pricing;
  final VoidCallback onTap;
  final bool isPaying;
  final bool anyPaying;
  final bool hasActiveSubscription;

  String get _priceLabel {
    final sym = pricing.currencySymbol;
    if (option.kind == 'year') return '$sym ${option.priceEuros}/${'provider.profile.year'.tr()}';
    if (option.kind == 'month') return '$sym ${option.priceEuros}/${'provider.profile.month'.tr()}';
    return '$sym ${option.priceEuros}';
  }

  @override
  Widget build(BuildContext context) {
    final dimmed = !option.eligible || hasActiveSubscription;
    final blocked = (anyPaying && !isPaying) || hasActiveSubscription;

    return Opacity(
      opacity: dimmed ? 0.5 : 1.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    option.title,
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primaryRed),
                  ),
                ),
                if (option.appliesAfterTrial)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      'provider.profile.after_trial'.tr(),
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primaryRed, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _priceLabel,
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryRed),
            ),
            if (option.subtitle.isNotEmpty) ...[const SizedBox(height: 6), Text(option.subtitle, style: GoogleFonts.outfit(fontSize: 15, color: Colors.black54))],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (dimmed || blocked) ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: isPaying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        option.durationDays != null
                            ? 'provider.profile.days_free_plan'.tr(args: ['${option.durationDays}', option.title])
                            : 'provider.profile.subscribe_plan'.tr(args: [option.title]),
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
