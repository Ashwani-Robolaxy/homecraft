import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../booking/data/booking_remote_datasource.dart';
import '../../../booking/domain/models/booking.dart';
import '../../../chat/presentation/professional_chat_args.dart';
import '../../../projects/domain/models/project.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {
  final _bookingDs = BookingRemoteDatasource();

  bool _isSearchActive = false;
  late ScrollController _dateScrollController;
  late ScrollController _mainScrollController;
  double _scrollProgress = 0.0;
  double _headerCollapse = 0.0;

  List<Booking> _bookings = [];
  bool _bookingsLoading = true;
  String? _bookingsError;

  @override
  void initState() {
    super.initState();
    _dateScrollController = ScrollController();
    _mainScrollController = ScrollController();
    _mainScrollController.addListener(() {
      const maxCollapseDistance = 180.0;
      final value =
          (_mainScrollController.offset / maxCollapseDistance).clamp(0.0, 1.0);
      if (value != _headerCollapse) setState(() => _headerCollapse = value);
    });
    _dateScrollController.addListener(() {
      if (_dateScrollController.hasClients &&
          _dateScrollController.position.maxScrollExtent > 0) {
        setState(() {
          _scrollProgress = (_dateScrollController.offset /
                  _dateScrollController.position.maxScrollExtent)
              .clamp(0.0, 1.0);
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPendingBookings());
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingBookings() async {
    setState(() { _bookingsLoading = true; _bookingsError = null; });
    try {
      final bookings = await _bookingDs.fetchProfessionalBookings(status: 'pending');
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _bookingsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('ApiException: ', '');
      setState(() {
        _bookingsLoading = false;
        _bookingsError = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _mainScrollController,
            slivers: [
              SliverAppBar(
                pinned: true,
                stretch: true,
                expandedHeight: 380,
                backgroundColor: Colors.white,
                toolbarHeight: 72,
                titleSpacing: 0,
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _headerCollapse > 0.5 ? 1 : 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildSearchField(compact: true),
                  ),
                ),
                flexibleSpace:
                    FlexibleSpaceBar(background: _buildSliverHeader(context)),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Section header ───────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pending Requests',
                                style: GoogleFonts.outfit(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              if (!_bookingsLoading && _bookings.isNotEmpty)
                                Text(
                                  '${_bookings.length} awaiting your response',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: AppColors.primaryRed,
                                      fontWeight: FontWeight.w500),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Content ──────────────────────────────────────────
                      if (_bookingsLoading)
                        _buildShimmer()
                      else if (_bookingsError != null)
                        _buildError()
                      else if (_bookings.isEmpty)
                        _buildEmpty()
                      else
                        ..._bookings.map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _BookingRequestCard(
                                booking: b,
                                onDismiss: () => setState(() => _bookings.remove(b)),
                              ),
                            )),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          if (_isSearchActive) _buildSearchOverlay(context),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return AppShimmer(
      child: Column(
        children: List.generate(
          2,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: double.infinity, height: 200, radius: 16),
                const SizedBox(height: 10),
                ShimmerBox(width: 200, height: 16, radius: 6),
                const SizedBox(height: 6),
                ShimmerBox(width: 140, height: 12, radius: 6),
                const SizedBox(height: 8),
                ShimmerBox(width: double.infinity, height: 12, radius: 6),
                const SizedBox(height: 4),
                ShimmerBox(width: double.infinity, height: 12, radius: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.wifiOff, size: 40, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              _bookingsError ?? 'Could not load booking requests.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.black45, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadPendingBookings,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.clipboardList, size: 48, color: Colors.black12),
            const SizedBox(height: 12),
            Text(
              'No pending booking requests.\nCheck back later!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.black45, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header / search (unchanged) ────────────────────────────────────────────

  Widget _buildSliverHeader(BuildContext context) {
    final expandedSearchOpacity =
        (1 - (_headerCollapse * 1.4)).clamp(0.0, 1.0);
    final logoScale = (1 - (_headerCollapse * 0.2)).clamp(0.86, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage('assets/images/house_interior.png'),
                fit: BoxFit.cover),
          ),
        ),
        Container(color: Colors.black.withOpacity(0.22)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: logoScale,
                  child: Image.asset(
                    'assets/images/logo_white.png',
                    height: 56,
                    errorBuilder: (context, error, stackTrace) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('H/',
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 44, color: Colors.white)),
                        Text('omeCraft',
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 38),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: expandedSearchOpacity,
                  child: _buildSearchField(compact: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField({required bool compact}) {
    final hintColor = compact ? AppColors.textSecondary : Colors.white;
    final iconColor = compact ? AppColors.textSecondary : Colors.white;
    final fillColor =
        compact ? Colors.white : Colors.white.withOpacity(0.12);
    final borderColor = compact
        ? AppColors.borderLight
        : Colors.white.withOpacity(compact ? 0.9 : 1);
    return TextField(
      readOnly: true,
      onTap: () => setState(() => _isSearchActive = true),
      decoration: InputDecoration(
        hintText: 'provider.home.search_hint'.tr(),
        hintStyle: GoogleFonts.outfit(
            color: hintColor,
            fontWeight: FontWeight.w300,
            fontSize: compact ? 15 : 18),
        prefixIcon: Icon(LucideIcons.search, color: iconColor, size: 22),
        suffixIcon: Icon(LucideIcons.x, color: iconColor, size: 22),
        filled: true,
        fillColor: fillColor,
        contentPadding: EdgeInsets.symmetric(vertical: compact ? 10 : 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: BorderSide(color: borderColor, width: compact ? 1.2 : 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: BorderSide(
              color: compact
                  ? AppColors.primaryRed.withOpacity(0.45)
                  : Colors.white,
              width: compact ? 1.4 : 2),
        ),
      ),
    );
  }

  Widget _buildSearchOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.1),
      child: Stack(
        children: [
          Positioned(
            top: 180,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1), blurRadius: 20)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('provider.home.location'.tr(),
                      style: GoogleFonts.outfit(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'provider.home.search_hint'.tr(),
                      hintStyle:
                          GoogleFonts.outfit(color: Colors.black26),
                      prefixIcon: const Icon(LucideIcons.search,
                          color: Colors.black26, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(LucideIcons.x,
                            color: Colors.black, size: 20),
                        onPressed: () =>
                            setState(() => _isSearchActive = false),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(
                            color: Color(0xFF7A0000), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(
                            color: Color(0xFF7A0000), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                            color: Color(0xFF7A0000),
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Text('Paris',
                          style: GoogleFonts.outfit(
                              fontSize: 16, color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text('provider.home.date_of_intervention'.tr(),
                      style: GoogleFonts.outfit(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    controller: _dateScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        10,
                        (index) => Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF8EDED),
                              borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: [
                              Text('Fri',
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF7A0000))),
                              Text('30',
                                  style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF7A0000))),
                              Text('May',
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF7A0000))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(LucideIcons.chevronLeft,
                          color: Colors.black87, size: 20),
                      Expanded(
                        child: Container(
                          height: 8,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE5B9B9),
                              borderRadius: BorderRadius.circular(4)),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const double barWidth = 80;
                              final double maxScrollableWidth =
                                  constraints.maxWidth - barWidth;
                              return Stack(
                                children: [
                                  Positioned(
                                    left: _scrollProgress *
                                        maxScrollableWidth,
                                    child: Container(
                                      width: barWidth,
                                      height: 8,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF7A0000),
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight,
                          color: Colors.black87, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isSearchActive = false),
            child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent),
          ),
        ],
      ),
    );
  }
}

// ── Booking request card ──────────────────────────────────────────────────────

class _BookingRequestCard extends StatefulWidget {
  const _BookingRequestCard({required this.booking, required this.onDismiss});
  final Booking booking;
  final VoidCallback onDismiss;

  @override
  State<_BookingRequestCard> createState() => _BookingRequestCardState();
}

class _BookingRequestCardState extends State<_BookingRequestCard> {
  final _ds = BookingRemoteDatasource();
  bool _accepting = false;
  bool _rejecting = false;

  bool get _busy => _accepting || _rejecting;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await _ds.updateBookingStatus(widget.booking.id, 'accepted');
      if (!mounted) return;
      AppToast.success('Booking accepted!');
      widget.onDismiss();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString()
          .replaceFirst('ApiException: ', '')
          .replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _reject() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reject this booking?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Text(
          'The client will be notified that you are unavailable.',
          style: GoogleFonts.outfit(color: Colors.black54, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Reject', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _rejecting = true);
    try {
      await _ds.updateBookingStatus(widget.booking.id, 'rejected');
      if (!mounted) return;
      AppToast.success('Booking rejected.');
      widget.onDismiss();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString()
          .replaceFirst('ApiException: ', '')
          .replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  /// Build a lightweight Project so we can reuse the details screen UI.
  Project _bookingAsProject(Booking b) => Project(
        id: b.projectId ?? b.id.toString(),
        title: b.clientName ?? 'Booking #${b.id}',
        description: b.notes ?? '',
        location: b.location ?? '',
        date: b.scheduledDate != null ? _fmtDate(b.scheduledDate!) : '',
        clientUserId: b.clientId,
        clientDisplayName: b.clientName,
      );

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final clientPhoto = b.clientPhoto;
    final hasPhoto =
        clientPhoto != null && clientPhoto.startsWith('http');

    return GestureDetector(
      onTap: () => context.push(
        '/project-details',
        extra: (project: _bookingAsProject(b), bookingId: b.id),
      ),
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: client info ────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFFDF3F3),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Avatar
                ClipOval(
                  child: hasPhoto
                      ? Image.network(clientPhoto,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _avatarFallback(b.clientName))
                      : _avatarFallback(b.clientName),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.clientName ?? 'Client',
                        style: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Booking #${b.id}',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: Colors.black38),
                      ),
                    ],
                  ),
                ),
                // PENDING chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFFC107), width: 1),
                  ),
                  child: Text(
                    'PENDING',
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF856404)),
                  ),
                ),
              ],
            ),
          ),

          // ── Details ───────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (b.scheduledDate != null)
                  _infoRow(LucideIcons.calendar,
                      _fmtDate(b.scheduledDate!), AppColors.primaryRed),
                if (b.slotStart != null || b.slotEnd != null)
                  _infoRow(
                    LucideIcons.clock,
                    [b.slotStart, b.slotEnd]
                        .whereType<String>()
                        .join(' – '),
                    Colors.black54,
                  ),
                if (b.location != null && b.location!.isNotEmpty)
                  _infoRow(
                      LucideIcons.mapPin, b.location!, Colors.black54),
                if (b.notes != null && b.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    b.notes!,
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.45),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),

                // ── Chat + Accept / Reject buttons ────────────────
                Row(
                  children: [
                    // Message icon button
                    GestureDetector(
                      onTap: _busy
                          ? null
                          : () => context.push(
                                '/chat',
                                extra: ProfessionalChatArgs(
                                  clientUserId: b.clientId ?? '',
                                  clientDisplayName:
                                      b.clientName ?? 'Client',
                                  isCurrentUserProfessional: true,
                                  projectId: b.projectId,
                                ),
                              ),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.messageCircle,
                            size: 20, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Reject
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _reject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryRed,
                          side: const BorderSide(
                              color: AppColors.primaryRed, width: 1.5),
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _rejecting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryRed))
                            : Text('Reject',
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Accept
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy ? null : _accept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF238E10),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _accepting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : Text('Accept',
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),  // Container
    );  // GestureDetector
  }

  Widget _infoRow(IconData icon, String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: Colors.black54)),
            ),
          ],
        ),
      );

  Widget _avatarFallback(String? name) => Container(
        width: 46,
        height: 46,
        color: AppColors.primaryRed.withOpacity(0.12),
        child: Center(
          child: Text(
            (name?.isNotEmpty == true ? name![0] : 'C').toUpperCase(),
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryRed),
          ),
        ),
      );

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
