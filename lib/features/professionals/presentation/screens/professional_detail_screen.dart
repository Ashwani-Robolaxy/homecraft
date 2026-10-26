import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../chat/presentation/professional_chat_args.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import '../../../favorites/presentation/widgets/save_to_collection_sheet.dart';
import '../../data/professionals_remote_datasource.dart';
import '../../domain/models/professional_listing.dart';
import '../../domain/models/professional_review.dart';

// ── Args passed via GoRouter extra ──────────────────────────────────────────

class ProfessionalDetailArgs {
  const ProfessionalDetailArgs(this.listing);
  final ProfessionalListing listing;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ProfessionalDetailScreen extends ConsumerStatefulWidget {
  const ProfessionalDetailScreen({super.key, required this.listing});
  final ProfessionalListing listing;

  @override
  ConsumerState<ProfessionalDetailScreen> createState() => _ProfessionalDetailScreenState();
}

class _ProfessionalDetailScreenState extends ConsumerState<ProfessionalDetailScreen> {
  final ApiClient _api = ApiClient();
  final SessionStorage _session = SessionStorage();
  final ProfessionalsRemoteDatasource _proDs = ProfessionalsRemoteDatasource();

  bool _loading = true;
  Map<String, dynamic> _detail = {};
  List<Map<String, dynamic>> _portfolio = [];

  ProfessionalReviewsSummary? _reviewsSummary;
  bool _reviewsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      final summary = await _proDs.fetchProfessionalReviewsById(widget.listing.id);
      if (!mounted) return;
      setState(() {
        _reviewsSummary = summary;
        _reviewsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _fetchDetail() async {
    try {
      final token = await _session.getToken();
      if (token == null) return;

      final data = await _api.get('/users/professionals/${widget.listing.id}', token: token);
      _logFullProfessionalProfile(data);

      final payload = data['data'] is Map<String, dynamic> ? Map<String, dynamic>.from(data['data'] as Map<String, dynamic>) : Map<String, dynamic>.from(data);
      final professionalNode = payload['professional'];
      final root = professionalNode is Map<String, dynamic>
          ? <String, dynamic>{
              ...Map<String, dynamic>.from(professionalNode),
              if (payload['portfolio'] != null) 'portfolio': payload['portfolio'],
              if (payload['portfolioItems'] != null) 'portfolioItems': payload['portfolioItems'],
              if (payload['reviews'] != null) 'reviews': payload['reviews'],
              if (payload['ratings'] != null) 'ratings': payload['ratings'],
              if (payload['feedback'] != null) 'feedback': payload['feedback'],
            }
          : payload;

      // Portfolio
      final rawPortfolio = root['portfolio'] ?? root['portfolioItems'] ?? [];
      final portfolio = (rawPortfolio is List) ? rawPortfolio.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _detail = root;
        _portfolio = portfolio;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _logFullProfessionalProfile(Map<String, dynamic> data) {
    try {
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      debugPrint('[ProfessionalDetail] Full profile payload start');
      for (final line in pretty.split('\n')) {
        debugPrint(line);
      }
      debugPrint('[ProfessionalDetail] Full profile payload end');
    } catch (_) {
      debugPrint('[ProfessionalDetail] Full profile payload: $data');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _bio() {
    String fromMap(Map<String, dynamic> m) {
      final s = _firstNonEmptyField(m, [
        'biography',
        'bio',
        'about',
        'description',
        'aboutMe',
        'profileDescription',
        'shortDescription',
        'personalDescription',
        'professionalBio',
        'summary',
        'overview',
      ]);
      return s ?? '';
    }

    if (_detail.isNotEmpty) {
      final direct = fromMap(_detail);
      if (direct.isNotEmpty) return direct;
      for (final key in ['professional', 'professionalProfile', 'profile', 'providerProfile', 'user']) {
        final node = _detail[key];
        if (node is Map) {
          final nested = fromMap(Map<String, dynamic>.from(node));
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return '';
  }

  String _siretNumber() {
    final raw =
        _detail['siretNumber'] ??
        _detail['siret'] ??
        (_detail['professional'] is Map ? (Map<String, dynamic>.from(_detail['professional'])['siretNumber'] ?? Map<String, dynamic>.from(_detail['professional'])['siret']) : null) ??
        '';
    return raw.toString().trim();
  }

  double? _performanceStarRating() {
    if (_reviewsSummary != null && _reviewsSummary!.averageRating > 0) {
      return _reviewsSummary!.averageRating;
    }
    if (widget.listing.rating != null && widget.listing.rating! > 0) {
      return widget.listing.rating;
    }
    final raw =
        _detail['performanceStarRating'] ??
        _detail['starRating'] ??
        _detail['averageRating'] ??
        _detail['rating'] ??
        (_detail['professional'] is Map ? (Map<String, dynamic>.from(_detail['professional'])['performanceStarRating'] ?? Map<String, dynamic>.from(_detail['professional'])['starRating']) : null);
    if (raw == null) return null;
    return double.tryParse(raw.toString());
  }

  int _totalReviewsCount() {
    if (_reviewsSummary != null) {
      return _reviewsSummary!.totalReviews;
    }
    final raw = _detail['totalReviews'] ?? _detail['reviewsCount'] ?? _detail['count'];
    if (raw != null) {
      return int.tryParse(raw.toString()) ?? 0;
    }
    return 0;
  }

  String _portfolioImage(Map<String, dynamic> item) {
    final photos = item['photos'] ?? item['images'] ?? item['photoUrls'] ?? item['pictures'];
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first;
      if (first is Map) {
        final url = first['url'] ?? first['photoUrl'] ?? first['imageUrl'] ?? first['fileUrl'] ?? '';
        return _abs(url.toString());
      }
      if (first is String) return _abs(first);
    }
    return _abs(item['coverPhotoUrl'] ?? item['imageUrl'] ?? item['photoUrl'] ?? item['photo'] ?? '');
  }

  String _abs(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    final base = ApiConfig.baseUrl.endsWith('/') ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) : ApiConfig.baseUrl;
    return '$base${raw.startsWith('/') ? raw : '/$raw'}';
  }

  /// App bar hero: first portfolio image when loaded and URL resolves; otherwise listing cover.
  String? _heroCoverUrl(ProfessionalListing p) {
    if (_portfolio.isNotEmpty) {
      final u = _portfolioImage(_portfolio.first);
      if (u.isNotEmpty) return u;
    }
    return p.coverPhotoUrl;
  }

  static String? _firstNonEmptyField(Map<String, dynamic> m, List<String> keys) {
    for (final key in keys) {
      final v = m[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static String? _nameFromMap(Map<String, dynamic> m) {
    final direct = _firstNonEmptyField(m, ['displayName', 'fullName', 'username', 'companyName', 'name', 'title']);
    if (direct != null) return direct;
    final first = (m['firstName'] ?? '').toString().trim();
    final last = (m['lastName'] ?? '').toString().trim();
    if (first.isEmpty && last.isEmpty) return null;
    return '$first $last'.trim();
  }

  /// Prefer live API payload (matches favorites `target` shape: username, companyName, …).
  String _resolvedDisplayName(ProfessionalListing p) {
    if (_detail.isNotEmpty) {
      final n = _nameFromMap(_detail);
      if (n != null) return n;
    }
    return p.displayName;
  }

  String _resolvedLocation(ProfessionalListing p) {
    final loc = p.location.trim();
    if (loc.isNotEmpty && loc != '—') return loc;
    if (_detail.isNotEmpty) {
      final text = _firstNonEmptyField(_detail, ['city', 'location', 'address', 'serviceArea', 'companyAddress']);
      if (text != null) return text;
      final nested = _detail['location'];
      if (nested is Map) {
        final m = Map<String, dynamic>.from(nested);
        final addr = _firstNonEmptyField(m, ['formattedAddress', 'formatted_address', 'address', 'label', 'name']);
        if (addr != null) return addr;
      }
      final lat = _detail['latitude'] ?? _detail['lat'];
      final lng = _detail['longitude'] ?? _detail['lng'];
      if (lat != null && lng != null) {
        return '${lat.toString()}, ${lng.toString()}';
      }
    }
    return loc.isNotEmpty ? loc : '—';
  }

  String _resolvedRoleLine(ProfessionalListing p) {
    if (_detail.isNotEmpty) {
      final s = _firstNonEmptyField(_detail, ['speciality', 'specialty', 'jobTitle', 'profession', 'role']);
      if (s != null) return s;
    }
    return p.roleLabel;
  }

  /// Portfolio image width:height = 16:9 (Flutter [AspectRatio] uses width / height).
  /// Wide card; if height would exceed [maxImageHeight], shrink width to preserve 16:9.
  ({double imageWidth, double rowHeight}) _portfolioLayout(BuildContext context) {
    const double metaBlockHeight = 76;
    final sw = MediaQuery.sizeOf(context).width;
    final sh = MediaQuery.sizeOf(context).height;
    final maxImageH = sh * 0.52;
    var imageW = (sw - 48) * 0.88;
    var imageH = imageW * _kPortfolioImageAspectH / _kPortfolioImageAspectW;
    if (imageH > maxImageH) {
      imageH = maxImageH;
      imageW = imageH * _kPortfolioImageAspectW / _kPortfolioImageAspectH;
    }
    return (imageWidth: imageW, rowHeight: imageH + metaBlockHeight);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = widget.listing;
    final heroCoverUrl = _heroCoverUrl(p);
    final profileUrl = p.profilePhotoUrl;
    final portfolioLayout = _portfolioLayout(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Cover image + back btn ────────────────────────────────────
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
                      ),
                      child: const Icon(LucideIcons.chevronLeft, color: AppColors.textMain, size: 22),
                    ),
                  ),
                ),
                actions: [
                  // ── Favourite heart ─────────────────────────────────────
                  _HeartButton(itemId: widget.listing.id, displayName: _resolvedDisplayName(widget.listing), subtitle: _resolvedRoleLine(widget.listing), imageUrl: widget.listing.profilePhotoUrl),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _CoverImage(url: heroCoverUrl, asset: p.backgroundAssetFallback),
                ),
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Name / rating / location ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _NetworkOrAsset(url: profileUrl, asset: p.profileAssetFallback, width: 72, height: 72, fit: BoxFit.cover, personImageFallback: true),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _resolvedDisplayName(p),
                                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textMain),
                                ),
                                if (_performanceStarRating() != null && _performanceStarRating()! > 0) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      ...List.generate(5, (index) {
                                        final rating = _performanceStarRating()!;
                                        IconData icon = Icons.star_border;
                                        if (rating >= index + 1) {
                                          icon = Icons.star;
                                        } else if (rating > index) {
                                          icon = Icons.star_half;
                                        }
                                        return Icon(icon, size: 14, color: Colors.amber);
                                      }),
                                      const SizedBox(width: 6),
                                      Text(
                                        _performanceStarRating()!.toStringAsFixed(1),
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain),
                                      ),
                                      if (_totalReviewsCount() > 0) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          '(${_totalReviewsCount()})',
                                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [Text(_resolvedRoleLine(p), style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary))],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(LucideIcons.mapPin, size: 13, color: AppColors.primaryRed),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _resolvedLocation(p),
                                        style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                    const SizedBox(height: 20),

                    // ── Biography ───────────────────────────────────────────
                    _sectionTitle('professional_detail.biography'.tr()),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: _loading
                          ? _shimmerLines(3)
                          : Text(_bio().isEmpty ? 'No biography provided yet.' : _bio(), style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
                    ),

                    // ── Siret Number ────────────────────────────────────────
                    if (!_loading) ...[
                      const SizedBox(height: 16),
                      _sectionTitle('professional_detail.siret_number'.tr()),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderLight),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.fileText, size: 20, color: AppColors.primaryRed),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _siretNumber().isNotEmpty ? _siretNumber() : '—',
                                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain, fontWeight: FontWeight.w500),
                                ),
                              ),
                              if (_siretNumber().isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: _siretNumber()));
                                    AppToast.success('professional_detail.siret_copied'.tr());
                                  },
                                  child: const Icon(LucideIcons.copy, size: 16, color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      _sectionTitle('professional_detail.siret_number'.tr()),
                      Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: _shimmerLines(1)),
                    ],

                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                    const SizedBox(height: 20),

                    // ── Portfolio ───────────────────────────────────────────
                    _sectionTitle('professional_detail.portfolio'.tr()),
                    const SizedBox(height: 12),
                    if (_loading)
                      SizedBox(
                        height: portfolioLayout.rowHeight,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: 3,
                          itemBuilder: (_, __) => _PortfolioShimmerCard(imageWidth: portfolioLayout.imageWidth),
                        ),
                      )
                    else if (_portfolio.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: Text('professional_detail.no_portfolio'.tr(), style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary)),
                      )
                    else
                      SizedBox(
                        height: portfolioLayout.rowHeight,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _portfolio.length,
                          itemBuilder: (ctx, i) => _PortfolioCard(item: _portfolio[i], imageUrl: _portfolioImage(_portfolio[i]), imageWidth: portfolioLayout.imageWidth),
                        ),
                      ),

                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                    const SizedBox(height: 20),

                    // ── Reviews & Rating ────────────────────────────────────
                    _sectionTitle('professional_detail.reviews'.tr()),
                    const SizedBox(height: 12),
                    _buildReviewsSection(),

                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                    const SizedBox(height: 20),

                    // Bottom padding for the fixed bar
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),

          // ── Fixed bottom action bar ────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(listing: widget.listing, onMessage: () => _openChat(context), onBook: () => _openBooking(context)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Text(
      title,
      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textMain),
    ),
  );

  Widget _shimmerLines(int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: List.generate(count, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          height: 14,
          width: i == count - 1 ? 160 : double.infinity,
          decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(4)),
        ),
      );
    }),
  );

  Widget _buildReviewsSection() {
    if (_reviewsLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ],
        ),
      );
    }

    final summary = _reviewsSummary;
    final reviews = summary?.reviews ?? [];

    if (summary == null || reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFEFEF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.star, size: 24, color: AppColors.primaryRed),
              ),
              const SizedBox(height: 10),
              Text(
                'professional_detail.no_reviews'.tr(),
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEFEFEF)),
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
                          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textMain),
                        ),
                        Text(
                          ' / 5.0',
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (i) {
                        final starIndex = i + 1;
                        return Icon(
                          LucideIcons.star,
                          size: 16,
                          color: starIndex <= summary.averageRating.round() ? const Color(0xFFFFB800) : const Color(0xFFE0E0E0),
                        );
                      }),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${summary.totalReviews} ${'professional_detail.reviews'.tr().toLowerCase()}',
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // List of Reviews
          for (int i = 0; i < reviews.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _DetailReviewCard(review: reviews[i]),
          ],
        ],
      ),
    );
  }

  void _openChat(BuildContext context) {
    if (widget.listing.id.isEmpty) {
      AppToast.error('professional_detail.cannot_chat'.tr());
      return;
    }
    context.push(
      '/chat',
      extra: ProfessionalChatArgs(
        clientUserId: widget.listing.id,
        clientDisplayName: _resolvedDisplayName(widget.listing),
        isCurrentUserProfessional: false,
        professionalId: widget.listing.id,
        clientImageUrl: widget.listing.profilePhotoUrl,
        clientProfession: _resolvedRoleLine(widget.listing),
      ),
    );
  }

  void _openBooking(BuildContext context) {
    if (widget.listing.id.isEmpty) {
      AppToast.error('professional_detail.cannot_book'.tr());
      return;
    }
    context.push(
      '/create-booking',
      extra: {
        'professionalId': widget.listing.id,
        'professionalName': _resolvedDisplayName(widget.listing),
        'professionalPhoto': widget.listing.profilePhotoUrl,
        'professionalProfession': _resolvedRoleLine(widget.listing),
      },
    );
  }
}

// ── Cover image ───────────────────────────────────────────────────────────────

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url, required this.asset});
  final String? url;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final showNetworkImage = url != null && url!.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showNetworkImage) Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder()) else _placeholder(),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.25), Colors.transparent, Colors.black.withOpacity(0.15)]),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF2F2F2),
      alignment: Alignment.center,
      child: const Icon(LucideIcons.image, color: Colors.black26, size: 48),
    );
  }
}

// ── Reusable network/asset image ──────────────────────────────────────────────

class _NetworkOrAsset extends StatelessWidget {
  const _NetworkOrAsset({required this.url, required this.asset, this.width, this.height, this.fit = BoxFit.cover, this.personImageFallback = false});
  final String? url;
  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool personImageFallback;

  Widget _assetLoadError() {
    if (personImageFallback) {
      return Image.asset(AppAssets.profilePlaceholder, width: width, height: height, fit: fit);
    }
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      alignment: Alignment.center,
      child: const Icon(LucideIcons.image, color: Colors.white54, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return Image.network(
        url!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Image.asset(asset, width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => _assetLoadError()),
      );
    }
    return Image.asset(asset, width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => _assetLoadError());
  }
}

// ── Portfolio card ────────────────────────────────────────────────────────────
// Image crop: width : height = 16 : 9 (landscape).
const double _kPortfolioImageAspectW = 16;
const double _kPortfolioImageAspectH = 9;

class _PortfolioCard extends StatefulWidget {
  const _PortfolioCard({required this.item, required this.imageUrl, required this.imageWidth});

  final Map<String, dynamic> item;
  final String imageUrl;
  final double imageWidth;

  @override
  State<_PortfolioCard> createState() => _PortfolioCardState();
}

class _PortfolioCardState extends State<_PortfolioCard> {
  int _currentIndex = 0;
  late final PageController _pageController;
  Timer? _autoSlideTimer;

  // Pointer drag tracking
  double _startX = 0;
  double _startPixels = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      final photos = _extractAllPhotos();
      if (photos.length > 1 && _pageController.hasClients && !_isDragging) {
        final next = (_currentIndex + 1) % photos.length;
        _pageController.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      }
    });
  }

  void _stopAutoSlide() {
    _autoSlideTimer?.cancel();
  }

  @override
  void dispose() {
    _stopAutoSlide();
    _pageController.dispose();
    super.dispose();
  }

  String _str(String key) => (widget.item[key] ?? '').toString().trim();

  String _abs(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    final base = ApiConfig.baseUrl.endsWith('/') ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) : ApiConfig.baseUrl;
    return '$base${raw.startsWith('/') ? raw : '/$raw'}';
  }

  List<String> _extractAllPhotos() {
    final photos = widget.item['photos'] ?? widget.item['images'] ?? widget.item['photoUrls'] ?? widget.item['pictures'];
    final urls = <String>[];
    if (photos is List && photos.isNotEmpty) {
      for (final p in photos) {
        if (p is Map) {
          final url = p['url'] ?? p['photoUrl'] ?? p['imageUrl'] ?? p['fileUrl'] ?? '';
          if (url.toString().isNotEmpty) {
            urls.add(_abs(url.toString()));
          }
        } else if (p is String && p.isNotEmpty) {
          urls.add(_abs(p));
        }
      }
    }
    if (urls.isEmpty && widget.imageUrl.isNotEmpty) {
      urls.add(widget.imageUrl);
    }
    return urls;
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day.toString().padLeft(2, '0')} ${_months[dt.month - 1]} ${dt.year}';
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final title = _str('title').isEmpty ? _str('projectTitle') : _str('title');
    final place = _str('completedPlace').isEmpty ? _str('location') : _str('completedPlace');
    final cost = _str('amount').isEmpty ? _str('price') : _str('amount');
    final rawDate = _str('completedAt').isEmpty ? _str('date') : _str('completedAt');
    final date = _formatDate(rawDate);

    final photos = _extractAllPhotos();
    debugPrint('=== [PORTFOLIO CAROUSEL DEBUG] ===');
    debugPrint('Title: $title');
    debugPrint('Photos: $photos');
    debugPrint('=== ========================== ===');

    return Container(
      width: widget.imageWidth,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.grey[100],
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: _kPortfolioImageAspectW / _kPortfolioImageAspectH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photos.isEmpty)
                  _placeholder()
                else if (photos.length == 1)
                  Image.network(photos.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                else
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      _stopAutoSlide();
                      if (photos.length > 1 && _pageController.hasClients) {
                        _startX = event.position.dx;
                        _startPixels = _pageController.position.pixels;
                        _isDragging = true;
                      }
                    },
                    onPointerMove: (event) {
                      if (_isDragging && _pageController.hasClients) {
                        final dx = event.position.dx - _startX;
                        _pageController.position.jumpTo((_startPixels - dx).clamp(0.0, _pageController.position.maxScrollExtent));
                      }
                    },
                    onPointerUp: (event) {
                      if (_isDragging && _pageController.hasClients) {
                        _isDragging = false;
                        final page = (_pageController.position.pixels / widget.imageWidth).round();
                        _pageController.animateToPage(page.clamp(0, photos.length - 1), duration: const Duration(milliseconds: 250), curve: Curves.easeOut).then((_) {
                          _startAutoSlide();
                        });
                      } else {
                        _startAutoSlide();
                      }
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: photos.length,
                      onPageChanged: (idx) => setState(() => _currentIndex = idx),
                      itemBuilder: (context, idx) => Image.network(photos[idx], fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder()),
                    ),
                  ),

                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)]),
                  ),
                ),

                // Left Arrow Chevron overlay
                if (photos.length > 1 && _currentIndex > 0)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          _stopAutoSlide();
                          if (_pageController.hasClients) {
                            _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut).then((_) => _startAutoSlide());
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                          child: const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),

                // Right Arrow Chevron overlay
                if (photos.length > 1 && _currentIndex < photos.length - 1)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          _stopAutoSlide();
                          if (_pageController.hasClients) {
                            _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut).then((_) => _startAutoSlide());
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                          child: const Icon(LucideIcons.chevronRight, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),

                // Indicator overlay badge at top right
                if (photos.length > 1)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        '${_currentIndex + 1}/${photos.length}',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),

                // Pagination dot indicators at bottom right
                if (photos.length > 1)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        photos.length,
                        (idx) => Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _currentIndex == idx ? AppColors.primaryRed : Colors.white.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),

                if (title.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: photos.length > 1 ? 50 : 8,
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Meta info
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (place.isNotEmpty) _metaRow(LucideIcons.mapPin, place),
                if (date.isNotEmpty) _metaRow(LucideIcons.calendar, date),
                if (cost.isNotEmpty) _metaRow(LucideIcons.banknote, cost.contains('€') ? cost : '$cost€'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        Icon(icon, size: 11, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _placeholder() => Container(
    color: const Color(0xFFE8E8E8),
    child: const Center(child: Icon(LucideIcons.image, color: Colors.white54, size: 28)),
  );
}

// ── Portfolio shimmer card ────────────────────────────────────────────────────

class _PortfolioShimmerCard extends StatelessWidget {
  const _PortfolioShimmerCard({required this.imageWidth});

  final double imageWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: imageWidth,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: _kPortfolioImageAspectW / _kPortfolioImageAspectH,
            child: Container(color: const Color(0xFFEEEEEE)),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 8,
                  width: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFFE0E0E0), borderRadius: BorderRadius.all(Radius.circular(4))),
                  ),
                ),
                SizedBox(height: 6),
                SizedBox(
                  height: 8,
                  width: 90,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFFE8E8E8), borderRadius: BorderRadius.all(Radius.circular(4))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Heart / favourite button ──────────────────────────────────────────────────

class _HeartButton extends ConsumerWidget {
  const _HeartButton({required this.itemId, this.displayName, this.subtitle, this.imageUrl});

  final String itemId;
  final String? displayName;
  final String? subtitle;
  final String? imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider.select((s) => s.isFavorited(itemId)));
    final isToggling = ref.watch(favoritesProvider.select((s) => s.togglingIds.contains(itemId)));

    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: isToggling
            ? null
            : () async {
                final notifier = ref.read(favoritesProvider.notifier);
                final wasFav = ref.read(favoritesProvider).isFavorited(itemId);
                final nowFav = await notifier.toggleProfessional(itemId, displayName: displayName, subtitle: subtitle, imageUrl: imageUrl);
                if (!context.mounted) return;
                final err = notifier.consumeError();
                if (err != null) {
                  AppToast.error(err);
                } else if (!wasFav && nowFav) {
                  // Just added — offer to save to a collection
                  final item = ref.read(favoritesProvider).items.where((f) => f.itemId == itemId).firstOrNull;
                  if (item != null) {
                    await showSaveToCollectionSheet(context, item: item);
                  }
                } else {
                  AppToast.info('Removed from favorites');
                }
              },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
          ),
          padding: const EdgeInsets.all(8),
          child: isToggling
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed))
              : Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? AppColors.primaryRed : AppColors.textMain, size: 20),
        ),
      ),
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.listing, required this.onMessage, required this.onBook});
  final ProfessionalListing listing;
  final VoidCallback onMessage;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(
          children: [
            // Messages — white filled pill for better contrast
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: OutlinedButton(
                  onPressed: onMessage,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.94),
                    foregroundColor: AppColors.primaryRed,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    elevation: 1,
                  ),
                  child: Text(
                    'Messages',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryRed),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Book Now — translucent gradient so content shows through slightly
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onBook,
                  borderRadius: BorderRadius.circular(30),
                  child: Ink(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.buttonGradientTop, AppColors.buttonGradientBottom]),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Center(
                      child: Text(
                        'Book Now',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailReviewCard extends StatelessWidget {
  const _DetailReviewCard({required this.review});
  final ProfessionalReview review;

  @override
  Widget build(BuildContext context) {
    final name = review.reviewerName != null && review.reviewerName!.isNotEmpty
        ? review.reviewerName!
        : 'Anonymous';
    final dateStr = review.createdAt != null
        ? DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(review.createdAt!)
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryRed.withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
                    ),
                    if (dateStr != null)
                      Text(
                        dateStr,
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    LucideIcons.star,
                    size: 14,
                    color: (i + 1) <= review.rating ? const Color(0xFFFFB800) : const Color(0xFFE0E0E0),
                  );
                }),
              ),
            ],
          ),
          if (review.bookingDescription != null && review.bookingDescription!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                review.bookingDescription!,
                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMain, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
