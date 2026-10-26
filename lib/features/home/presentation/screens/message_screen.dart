import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../chat/data/chat_remote_datasource.dart';
import '../../../chat/presentation/professional_chat_args.dart';
import '../../../../core/storage/session_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class MessageScreen extends ConsumerStatefulWidget {
  const MessageScreen({super.key});

  @override
  ConsumerState<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends ConsumerState<MessageScreen> {
  final _ds = ChatRemoteDatasource();
  final _session = SessionStorage();
  List<_ConvItem> _conversations = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  bool get _isPro =>
      ref.read(authStateNotifierProvider).currentUser?.isProvider ?? false;

  Future<void> _loadConversations() async {
    setState(() { _loading = true; _hasError = false; });
    try {
      final raw =
          await _ds.listConversations(isCurrentUserProfessional: _isPro);
      if (!mounted) return;
      
      final parsed = raw.map((m) => _ConvItem.fromMap(m, isPro: _isPro)).toList();
      
      final List<_ConvItem> filtered = [];
      for (final item in parsed) {
        final deleteTime = await _session.getConversationDeleteTimeByUserId(item.otherUserId);
        if (deleteTime != null) {
          if (item.lastMessageTime == null || item.lastMessageTime!.isBefore(deleteTime)) {
            continue;
          }
        }
        filtered.add(item);
      }

      setState(() {
        _conversations = filtered;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _hasError = true; });
    }
  }

  void _openChat(_ConvItem item) {
    context.push(
      '/chat',
      extra: ProfessionalChatArgs(
        clientUserId: item.otherUserId,
        clientDisplayName: item.otherName,
        isCurrentUserProfessional: _isPro,
        clientImageUrl: item.otherPhoto,
        clientProfession: item.otherRole,
      ),
    ).then((_) {
      if (mounted) {
        _loadConversations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadAsync = ref.watch(unreadNotificationCountProvider);
    final unread = unreadAsync.when<int>(data: (c) => c, loading: () => 0, error: (_, __) => 0);
    return Scaffold(
      backgroundColor: const Color(0xFFFDF9F9),
      appBar: CommonAppBar(
        title: 'provider.nav.message'.tr(),
        showBackButton: false,
        showLogo: true,
        showNotification: true,
        notificationCount: unread,
        onNotificationTap: () {
          context.push('/notifications').then((_) {
            ref.invalidate(unreadNotificationCountProvider);
          });
        },
      ),
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: () async {
          await _loadConversations();
          ref.invalidate(unreadNotificationCountProvider);
        },
        child: _loading
            ? _MessageShimmer()
            : _hasError
                ? _ErrorState(onRetry: _loadConversations)
                : _conversations.isEmpty
                    ? _EmptyState(isPro: _isPro)
                    : Stack(
                    children: [
                      Positioned(
                        left: 31,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 2, color: AppColors.primaryRed),
                      ),
                      ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        itemCount: _conversations.length,
                        itemBuilder: (context, i) => _MessageCard(
                          item: _conversations[i],
                          isPro: _isPro,
                          onTap: () => _openChat(_conversations[i]),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversation data model (parsed from API response)
// ─────────────────────────────────────────────────────────────────────────────

class _ConvItem {
  const _ConvItem({
    required this.conversationId,
    required this.otherUserId,
    required this.otherName,
    required this.otherPhoto,
    required this.otherRole,
    required this.lastMessageText,
    required this.lastMessageTime,
  });

  final int conversationId;
  final String otherUserId;
  final String otherName;
  final String? otherPhoto;
  final String otherRole;
  final String lastMessageText;
  final DateTime? lastMessageTime;

  factory _ConvItem.fromMap(Map<String, dynamic> m, {required bool isPro}) {
    // ── Identify the other party ─────────────────────────────────────────
    // Try every known key that various API response shapes use.
    final Map<String, dynamic> other = _firstNonNull([
      m['otherParty'],          // primary key from /users/chat/conversations
      if (isPro) ...[
        m['client'],
        m['clientUser'],
        m['userData'],
        m['clientData'],
        m['clientInfo'],
        m['user'],              // /professionals/chat/conversations may use 'user'
        m['userInfo'],
      ] else ...[
        m['professional'],
        m['professionalUser'],
        m['provider'],
        m['professionalInfo'],
        m['providerData'],
      ],
    ]) ?? _tryExtractOtherFromRoot(m, isPro: isPro);

    // ── User ID ──────────────────────────────────────────────────────────
    final userId = (other['id'] ?? other['_id'] ?? other['userId'] ??
            m['userId'] ?? m['clientId'] ?? m['professionalId'] ?? '')
        .toString();

    // ── Build display name ───────────────────────────────────────────────
    final firstName = (other['firstName'] ?? m['firstName'] ?? '').toString().trim();
    final lastName  = (other['lastName']  ?? m['lastName']  ?? '').toString().trim();
    final combinedName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final name = (other['displayName'] ?? other['fullName'] ?? other['name'] ??
            other['username'] ?? m['displayName'] ?? m['name'] ?? combinedName)
        .toString()
        .trim();

    final photoRaw = (other['imageUrl'] ??
            other['profilePhoto'] ??
            other['profilePhotoUrl'] ??
            other['avatar'] ??
            other['photo'] ??
            other['image'] ??
            m['imageUrl'] ??
            m['profilePhoto'] ??
            m['profilePhotoUrl'] ??
            '')
        .toString()
        .trim();
    final photo = _abs(photoRaw);

    final profession = (other['speciality'] ??
            other['specialty'] ??
            other['profession'] ??
            other['companyName'] ??
            other['category'] ??
            other['role'] ??
            other['jobTitle'] ??
            m['speciality'] ??
            m['specialty'] ??
            m['profession'] ??
            (isPro ? 'Client' : 'Professional'))
        .toString()
        .trim();

    // ── Last message ──────────────────────────────────────────────────────
    final Map<String, dynamic> lastMsg = _firstNonNull([
      m['lastMessage'],
      m['latestMessage'],
    ]) ?? {};

    final body =
        (lastMsg['body'] ?? lastMsg['content'] ?? lastMsg['text'] ?? lastMsg['message'] ?? '').toString().trim();
    final rawTime = lastMsg['createdAt'] ?? lastMsg['sentAt'] ?? lastMsg['timestamp'] ?? m['updatedAt'] ?? m['lastActivity'];
    DateTime? time;
    if (rawTime is String && rawTime.isNotEmpty) {
      time = DateTime.tryParse(rawTime);
    } else if (rawTime is int) {
      time = DateTime.fromMillisecondsSinceEpoch(rawTime);
    }

    // ── Conversation ID ───────────────────────────────────────────────────
    final convId = (() {
      final raw = m['id'] ?? m['conversationId'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? 0;
      return 0;
    })();

    return _ConvItem(
      conversationId: convId,
      otherUserId: userId,
      otherName: name.isEmpty ? 'Unknown' : name,
      otherPhoto: photo.isEmpty ? null : photo,
      otherRole: profession,
      lastMessageText: body,
      lastMessageTime: time,
    );
  }

  /// Returns the first non-null, non-empty Map from [candidates].
  static Map<String, dynamic>? _firstNonNull(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c is Map && c.isNotEmpty) return Map<String, dynamic>.from(c);
    }
    return null;
  }

  /// Last-resort: if no dedicated sub-object is found, check whether the
  /// conversation root itself carries first/lastName/displayName directly
  /// (some APIs inline the user fields at the top level).
  static Map<String, dynamic> _tryExtractOtherFromRoot(
    Map<String, dynamic> m, {
    required bool isPro,
  }) {
    // Scan ALL values in the map for any nested Map that looks like a user
    for (final value in m.values) {
      if (value is! Map) continue;
      final v = Map<String, dynamic>.from(value);
      // A "user-like" map has at least an id and some name field
      final hasId   = v.containsKey('id') || v.containsKey('_id') || v.containsKey('userId');
      final hasName = v.containsKey('firstName') || v.containsKey('displayName') ||
          v.containsKey('fullName') || v.containsKey('name');
      if (hasId && hasName) return v;
    }
    // If nothing matched, return root itself so firstName/lastName are picked up
    return m;
  }

  static String _abs(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    return '$base${raw.startsWith('/') ? raw : '/$raw'}';
  }

  String get relativeTime {
    if (lastMessageTime == null) return '';
    final diff = DateTime.now().difference(lastMessageTime!);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(lastMessageTime!);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversation card
// ─────────────────────────────────────────────────────────────────────────────

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.item,
    required this.isPro,
    required this.onTap,
  });

  final _ConvItem item;
  final bool isPro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Timeline dot ───────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(left: 24, top: 22),
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: AppColors.primaryRed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),

        // ── Card column ────────────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main tap card
              GestureDetector(
                onTap: onTap,
                child: Container(
                  margin: const EdgeInsets.only(right: 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Name + Profession ────────────────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // "Name: John Smith"
                            RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'provider.messages.name_prefix'.tr(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  TextSpan(
                                    text: item.otherName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isPro && item.otherRole.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              // "Profession: Plumber"
                              RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'provider.messages.profession_prefix'.tr(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryRed,
                                      ),
                                    ),
                                    TextSpan(
                                      text: item.otherRole,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.primaryRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // ── Rectangular thumbnail ────────────────────────────
                      _Thumbnail(url: item.otherPhoto),

                      const SizedBox(width: 10),

                      // ── Time ─────────────────────────────────────────────
                      Text(
                        item.relativeTime,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rectangular thumbnail widget
// ─────────────────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 72,
        height: 56,
        child: (url != null && url!.trim().isNotEmpty)
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Image.asset(
        AppAssets.profilePlaceholder,
        fit: BoxFit.cover,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isPro});
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline,
                size: 64, color: AppColors.primaryRed),
            const SizedBox(height: 16),
            Text(
              isPro
                  ? 'provider.messages.empty_pro'.tr()
                  : 'provider.messages.empty_client'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 14, color: Colors.black54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: Colors.black26),
            const SizedBox(height: 16),
            Text(
              'provider.messages.load_error'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('common.retry'.tr()),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer loading skeleton
// ─────────────────────────────────────────────────────────────────────────────

class _MessageShimmer extends StatefulWidget {
  @override
  State<_MessageShimmer> createState() => _MessageShimmerState();
}

class _MessageShimmerState extends State<_MessageShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: -1, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Stack(
        children: [
          Positioned(
            left: 31,
            top: 0,
            bottom: 0,
            child: Container(width: 2, color: AppColors.primaryRed),
          ),
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 20),
            itemCount: 4,
            itemBuilder: (_, __) => _ShimmerCard(offset: _anim.value),
          ),
        ],
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard({required this.offset});
  final double offset;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // dot
        _box(width: 16, height: 16, radius: 8,
            margin: const EdgeInsets.only(left: 24, top: 18)),
        const SizedBox(width: 16),
        // card body
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 20, bottom: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(height: 14, radius: 4),
                      const SizedBox(height: 8),
                      _box(width: 100, height: 12, radius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _box(width: 68, height: 52, radius: 6),
                const SizedBox(width: 8),
                _box(width: 48, height: 12, radius: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _box({
    double? width,
    double? height,
    double radius = 4,
    EdgeInsets? margin,
  }) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: LayoutBuilder(builder: (ctx, c) {
          final w = c.maxWidth.isFinite ? c.maxWidth : 200.0;
          final h = c.maxHeight.isFinite ? c.maxHeight : 20.0;
          return CustomPaint(
            size: Size(w, h),
            painter: _ShimmerPainter(offset: offset),
          );
        }),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  const _ShimmerPainter({required this.offset});
  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = LinearGradient(
      begin: Alignment(offset - 1, 0),
      end: Alignment(offset + 1, 0),
      colors: const [Color(0xFFEDEDED), Color(0xFFF5F5F5), Color(0xFFEDEDED)],
    );
    final paint = Paint()
      ..shader =
          gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.offset != offset;
}
