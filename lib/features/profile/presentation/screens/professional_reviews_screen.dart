import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../booking/data/booking_remote_datasource.dart';
import '../../../professionals/domain/models/professional_review.dart';

class ProfessionalReviewsScreen extends StatefulWidget {
  const ProfessionalReviewsScreen({super.key});

  @override
  State<ProfessionalReviewsScreen> createState() => _ProfessionalReviewsScreenState();
}

class _ProfessionalReviewsScreenState extends State<ProfessionalReviewsScreen> {
  final _ds = BookingRemoteDatasource();
  ProfessionalReviewsSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _ds.fetchProfessionalReviews();
      if (!mounted) return;
      setState(() {
        _summary = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CommonAppBar(title: 'provider.profile.my_reviews'.tr(), showNotification: false),
      body: RefreshIndicator(onRefresh: _loadReviews, color: AppColors.primaryRed, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _ReviewsShimmer();
    if (_error != null) return _buildError();

    final summary = _summary;
    final reviews = summary?.reviews ?? [];

    if (reviews.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 40),
          if (summary != null) _buildSummaryHeader(summary),
          const SizedBox(height: 60),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: AppColors.primaryRed.withValues(alpha: 0.08), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.star, size: 36, color: AppColors.primaryRed),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'provider.profile.no_reviews_title'.tr(),
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'provider.profile.no_reviews_desc'.tr(),
                    style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: reviews.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(padding: const EdgeInsets.only(bottom: 20), child: _buildSummaryHeader(summary!));
        }
        final item = reviews[index - 1];
        return _ReviewItemCard(review: item);
      },
    );
  }

  Widget _buildSummaryHeader(ProfessionalReviewsSummary summary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    summary.averageRating.toStringAsFixed(1),
                    style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                  Text(
                    ' / 5.0',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return Icon(LucideIcons.star, size: 18, color: starIndex <= summary.averageRating.round() ? const Color(0xFFFFB800) : const Color(0xFFE0E0E0));
                }),
              ),
              const SizedBox(height: 6),
              Text(
                '${summary.totalReviews} ${'provider.profile.reviews_total'.tr()}',
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 14),
                Text(
                  _error ?? 'Failed to load reviews.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadReviews,
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: Text('common.retry'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({required this.review});
  final ProfessionalReview review;

  @override
  Widget build(BuildContext context) {
    final name = review.reviewerName ?? 'Anonymous';
    final dateStr = review.createdAt != null ? DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(review.createdAt!) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryRed.withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMain),
                    ),
                    if (dateStr != null) Text(dateStr, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              // Stars
              Row(
                children: List.generate(5, (i) {
                  return Icon(LucideIcons.star, size: 15, color: (i + 1) <= review.rating ? const Color(0xFFFFB800) : const Color(0xFFE0E0E0));
                }),
              ),
            ],
          ),
          if (review.bookingDescription != null && review.bookingDescription!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
              child: Text(
                review.bookingDescription!,
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(review.comment!, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain, height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class _ReviewsShimmer extends StatelessWidget {
  const _ReviewsShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ShimmerBox(width: double.infinity, height: 110, radius: 20),
            const SizedBox(height: 20),
            ...List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ShimmerBox(width: double.infinity, height: 100, radius: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
