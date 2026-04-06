import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
  String? _error;
  String? _payingPlanKey; // tracks which plan button shows a spinner

  static const List<String> _introPoints = [
    'Choose your plans',
    'Showcase your skills',
    'Let start work and get more.',
  ];

  static const List<String> _premiumFeatures = [
    'Full profile & portfolio',
    'Online appointment booking',
    'Client messaging access',
    'Accept up to 3 projects/week',
    'Local visibility',
    'No commission on services',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ctx = await _ds.fetchContext();
      if (!mounted) return;
      setState(() { _ctx = ctx; _loading = false; });
    } catch (e) {
      // If authenticated call fails (e.g. professional not yet verified), fall back to public pricing
      try {
        final ctx = await _ds.fetchPublicPricing();
        if (!mounted) return;
        setState(() { _ctx = ctx; _loading = false; });
      } catch (e2) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e2.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient + waves
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  AppColors.primaryRed.withOpacity(0.2),
                  AppColors.primaryRed.withOpacity(0.15),
                ],
              ),
            ),
            child: CustomPaint(painter: _RedWavesPainter(), size: Size.infinite),
          ),
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
              'Subscription Plans',
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

    // Show trial banner if currently on trial
    final trialBannerText = sub.isOnTrial
        ? 'Trial active — ${sub.trialDaysRemaining} day${sub.trialDaysRemaining == 1 ? '' : 's'} remaining'
        : sub.trialStartsAfterVerification
            ? 'Trial starts after account verification'
            : null;

    // Trial button label
    final trialLabel = sub.promoEligible && !sub.isOnTrial && !sub.isActive
        ? 'TEST — ${pricing.trialDays} DAYS FREE'
        : sub.isOnTrial
            ? '${sub.trialDaysRemaining} DAYS LEFT IN TRIAL'
            : sub.isActive
                ? 'SUBSCRIPTION ACTIVE'
                : 'START FREE TRIAL';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intro checkmarks
          ..._introPoints.map((pt) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(LucideIcons.check, color: AppColors.primaryRed, size: 22),
                const SizedBox(width: 12),
                Text(pt, style: GoogleFonts.outfit(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500)),
              ],
            ),
          )),

          const SizedBox(height: 8),

          // Trial/status banner
          if (trialBannerText != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(trialBannerText,
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

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
              child: Text(trialLabel,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
          ),

          const SizedBox(height: 24),

          // Plan cards from purchaseOptions, or static premium card
          if (ctx.purchaseOptions.isNotEmpty)
            ...ctx.purchaseOptions
                .where((o) => !o.isTrial) // trial shown as banner above
                .map((opt) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PlanCard(
                        option: opt,
                        pricing: pricing,
                        features: _premiumFeatures,
                        isPaying: _payingPlanKey == opt.planKey,
                        anyPaying: _payingPlanKey != null,
                        onTap: () => _onPlanTap(opt, ctx),
                      ),
                    ))
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
      title: 'Premium subscription plan',
      price: '${pricing.currencySymbol} ${pricing.monthlyStandardEuros}/Month',
      features: _premiumFeatures,
      buttonLabel: '${pricing.trialDays} Day for free Premium',
      onTap: () => AppToast.info('Please log in as a professional to subscribe.'),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required List<String> features,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primaryRed)),
          const SizedBox(height: 4),
          Text(price, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryRed)),
          const SizedBox(height: 18),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(LucideIcons.check, color: Color(0xFF4CAF50), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(f, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain))),
              ],
            ),
          )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
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
      AppToast.info('You are already on a free trial.');
    } else if (ctx.subscriptionState.trialStartsAfterVerification) {
      AppToast.info('Your trial will start once your account is verified.');
    } else {
      AppToast.info('Contact support to activate your free trial.');
    }
  }

  Future<void> _onPlanTap(PurchaseOption opt, SubscriptionContext ctx) async {
    if (!opt.eligible) {
      AppToast.error('This plan is not available for your account.');
      return;
    }
    if (_payingPlanKey != null) return; // already processing another plan

    setState(() => _payingPlanKey = opt.planKey);
    try {
      final result = await StripePaymentService.instance.pay(opt);
      if (!mounted) return;
      switch (result) {
        case PaymentSuccess():
          AppToast.success('Payment successful! Welcome to ${opt.title}.');
          // Refresh subscription state so UI reflects new status
          _load();
        case PaymentCancelled():
          AppToast.info('Payment cancelled.');
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
            Text(_error ?? 'Could not load plans.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70, height: 1.5)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(LucideIcons.refreshCw, size: 16, color: Colors.white),
              label: Text('Retry', style: GoogleFonts.outfit(color: Colors.white)),
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
  const _PlanCard({
    required this.option,
    required this.pricing,
    required this.features,
    required this.onTap,
    this.isPaying = false,
    this.anyPaying = false,
  });

  final PurchaseOption option;
  final SubscriptionPricing pricing;
  final List<String> features;
  final VoidCallback onTap;
  final bool isPaying;
  final bool anyPaying;

  String get _priceLabel {
    final sym = pricing.currencySymbol;
    if (option.kind == 'year') return '$sym ${option.priceEuros}/Year';
    if (option.kind == 'month') return '$sym ${option.priceEuros}/Month';
    return '$sym ${option.priceEuros}';
  }

  @override
  Widget build(BuildContext context) {
    final dimmed = !option.eligible;
    final blocked = anyPaying && !isPaying;

    return Opacity(
      opacity: dimmed ? 0.5 : 1.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
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
                  child: Text(option.title,
                      style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primaryRed)),
                ),
                if (option.appliesAfterTrial)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('After trial',
                        style: GoogleFonts.outfit(fontSize: 10, color: AppColors.primaryRed, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_priceLabel,
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryRed)),
            if (option.subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(option.subtitle,
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.black45)),
            ],
            const SizedBox(height: 18),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(LucideIcons.check, color: Color(0xFF4CAF50), size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(f, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain))),
                ],
              ),
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (dimmed || blocked) ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: isPaying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        option.durationDays != null
                            ? '${option.durationDays} Days free — ${option.title}'
                            : 'Subscribe — ${option.title}',
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

// ── Background wave painter (unchanged) ───────────────────────────────────────

class _RedWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryRed.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.3, size.height * 0.3, size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.7, size.height * 0.7, size.width, size.height * 0.4);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
