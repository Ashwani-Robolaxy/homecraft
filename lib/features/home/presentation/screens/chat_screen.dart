import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../chat/data/chat_remote_datasource.dart';
import '../../../chat/domain/chat_message.dart';
import '../../../chat/presentation/professional_chat_args.dart';
import '../../../chat/services/professional_chat_socket.dart';
import '../../../report/domain/report_args.dart';
import '../../../professionals/domain/models/professional_listing.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.args});
  final ProfessionalChatArgs? args;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatRemoteDatasource _chatApi = ChatRemoteDatasource();
  final SessionStorage _session = SessionStorage();

  List<ChatMessage> _messages = [];
  ProfessionalChatSocket? _socket;
  bool _loading = true;
  String? _error;
  bool _sendBusy = false;
  int? _conversationId;

  bool get _isPro => widget.args?.isCurrentUserProfessional ?? true;

  String get _titleName {
    final n = widget.args?.clientDisplayName?.trim() ?? '';
    return n.isNotEmpty ? n : (_isPro ? 'common.client'.tr() : 'common.professional'.tr());
  }

  String get _subtitleText {
    final prof = widget.args?.clientProfession?.trim() ?? '';
    if (prof.isNotEmpty) return prof;
    return _isPro ? 'common.client'.tr() : 'common.professional'.tr();
  }

  String get _emptyStateText => _isPro ? '${'chat.no_messages_yet'.tr()}\n${'chat.say_hello_client'.tr()}' : '${'chat.no_messages_yet'.tr()}\n${'chat.say_hello_professional'.tr()}';

  @override
  void initState() {
    super.initState();
    if (widget.args == null || widget.args!.clientUserId.trim().isEmpty) {
      _loading = false;
      return;
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _session.getToken();
      if (token == null || token.isEmpty) {
        throw ApiException('chat.login_again'.tr());
      }

      // ── Step 1: Get or create conversation (role-aware) ──────────────────
      final int convId;
      if (_isPro) {
        convId = await _chatApi.createOrGetProfessionalConversation(widget.args!.clientUserId);
      } else {
        convId = await _chatApi.createOrGetUserConversation(widget.args!.clientUserId);
      }

      if (!mounted) return;
      setState(() {
        _conversationId = convId;
      });

      // ── Step 2: Load message history ─────────────────────────────────────
      final history = await _chatApi.fetchMessages(convId, isCurrentUserProfessional: _isPro);

      final deleteTime = await _session.getConversationDeleteTimeByUserId(widget.args!.clientUserId);
      if (deleteTime != null) {
        history.removeWhere((m) => m.createdAt == null || m.createdAt!.isBefore(deleteTime));
      }

      if (!mounted) return;
      setState(() {
        _messages = history;
        _loading = false;
      });

      // ── Step 3: Connect socket for real-time messages ─────────────────────
      _connectSocket(token, convId);
      if (history.isNotEmpty) _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : e.toString();
      });
    }
  }

  void _connectSocket(String token, int conversationId) {
    _socket?.close();
    _socket = ProfessionalChatSocket(
      serverUrl: ApiConfig.baseUrl,
      token: token,
      conversationId: conversationId,
      isCurrentUserProfessional: _isPro,
      onIncomingMessage: _onIncoming,
      onJoinFailed: (msg) {
        if (!mounted) return;
        AppToast.error(msg);
      },
      onConnectError: (err) {
        if (!mounted) return;
        AppToast.error('chat.connection_failed'.tr());
      },
    );
    _socket!.connect();
  }

  void _onIncoming(ChatMessage message) {
    if (!mounted || message.body.trim().isEmpty) return;
    setState(() => _appendDeduped(message));
    _scrollToBottom();
  }

  void _appendDeduped(ChatMessage message) {
    final id = message.id;
    if (id != null && _messages.any((m) => m.id == id)) return;
    _messages = [..._messages, message];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(_scrollController.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _messageController.text;
    if (text.trim().isEmpty || _socket == null || _sendBusy) return;
    setState(() => _sendBusy = true);
    _messageController.clear();
    _socket!.sendMessage(
      text,
      onAck: (saved) {
        if (!mounted) return;
        setState(() => _sendBusy = false);
        if (saved != null && saved.body.trim().isNotEmpty) {
          setState(() => _appendDeduped(saved));
          _scrollToBottom();
        }
      },
    );
  }

  @override
  void dispose() {
    _socket?.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.args == null || widget.args!.clientUserId.trim().isEmpty) {
      return _buildNoArgs();
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(child: _buildBody()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── No-args placeholder ───────────────────────────────────────────────────

  Widget _buildNoArgs() => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(LucideIcons.chevronLeft, color: Colors.black),
        onPressed: () => context.pop(),
      ),
      title: Text('chat.title'.tr(), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'chat.open_to_chat'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 15, color: Colors.black54, height: 1.4),
        ),
      ),
    ),
  );

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(LucideIcons.chevronLeft, color: Colors.black),
        onPressed: () => context.pop(),
      ),
      title: GestureDetector(
        onTap: () {
          if (!_isPro && widget.args != null) {
            final prof = widget.args?.clientProfession?.trim() ?? '';
            final fallbackProf = prof.isNotEmpty ? prof : 'Professional';
            context.push(
              '/professional-detail',
              extra: ProfessionalListing(
                id: widget.args!.clientUserId,
                displayName: _titleName,
                specialty: fallbackProf,
                roleLabel: fallbackProf,
                location: '—',
                costDisplay: '—',
                dateDisplay: '—',
                profilePhotoUrl: widget.args?.clientImageUrl,
                profileAssetFallback: AppAssets.profilePlaceholder,
                backgroundAssetFallback: AppAssets.homeHeaderBg,
              ),
            );
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 36,
                height: 36,
                child: (widget.args?.clientImageUrl != null && widget.args!.clientImageUrl!.trim().isNotEmpty)
                    ? Image.network(
                        widget.args!.clientImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          AppAssets.profilePlaceholder,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        AppAssets.profilePlaceholder,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleName,
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _subtitleText,
                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.black45),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.moreVertical, color: Colors.black),
          onPressed: () => _showMenu(context),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFEEEEEE), height: 1),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const _ChatShimmer();
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.wifiOff, size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                AppToast.localizeBackendMessage(_error!, context),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _bootstrap,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primaryRed),
                child: Text('common.retry'.tr(), style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.messageCircle, size: 48, color: AppColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              _emptyStateText,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.black45, height: 1.5),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final m = _messages[index];
        final showDate = index == 0 || _isDifferentDay(_messages[index - 1].createdAt, m.createdAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate && m.createdAt != null) _DateChip(date: m.createdAt!),
            _ChatBubble(message: m, showTail: index == _messages.length - 1 || _messages[index + 1 < _messages.length ? index + 1 : index].isMine != m.isMine),
          ],
        );
      },
    );
  }

  bool _isDifferentDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    final enabled = _error == null && !_loading && _socket != null;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomSafe),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: enabled ? AppColors.primaryRed.withOpacity(0.35) : Colors.grey.shade300, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _messageController,
                enabled: enabled && !_sendBusy,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (enabled) _send();
                },
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'chat.type_message'.tr(),
                  hintStyle: GoogleFonts.outfit(color: Colors.black38, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: enabled && !_sendBusy ? _send : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: enabled && !_sendBusy ? AppColors.primaryRed : Colors.grey.shade300, shape: BoxShape.circle),
              child: _sendBusy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.send, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ── Menu ─────────────────────────────────────────────────────────────────

  void _showMenu(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) => Stack(
        children: [
          Positioned(
            top: 60,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 240,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isPro) ...[
                      _menuItem('chat.media'.tr(), () {
                        Navigator.pop(context);
                        final proId = widget.args?.resolvedProfessionalId ?? widget.args?.professionalId ?? (!_isPro ? widget.args?.clientUserId : null);
                        context.push('/media', extra: proId);
                      }),
                      const Divider(height: 1),
                    ],
                    _menuItem('chat.report'.tr(), () {
                      Navigator.pop(context);
                      final proId = widget.args?.clientUserId ?? '';
                      final proName = widget.args?.clientDisplayName ?? 'User';
                      context.push(
                        '/take-action',
                        extra: ReportArgs(professionalId: proId, professionalName: proName, isCurrentUserProfessional: _isPro),
                      );
                    }),
                    const Divider(height: 1),
                    _menuItem('chat.delete_conversation'.tr(), () {
                      Navigator.pop(context);
                      _confirmDeleteConversation();
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteConversation() {
    final int? cid = _conversationId;
    if (cid == null) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'chat.delete_confirm_title'.tr(),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.black),
        ),
        content: Text('chat.delete_confirm_body'.tr(), style: GoogleFonts.outfit(fontSize: 15, color: Colors.black87, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'common.cancel'.tr(),
              style: GoogleFonts.outfit(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await _chatApi.deleteConversation(cid, isCurrentUserProfessional: _isPro);
                await _session.setConversationDeleteTimeByUserId(widget.args!.clientUserId, DateTime.now());
                AppToast.success('chat.deleted_success'.tr());
                if (mounted) {
                  context.pop(); // Close ChatScreen and go back
                }
              } catch (e) {
                final msg = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
                AppToast.error(msg.isNotEmpty ? msg : 'Could not delete conversation.');
              }
            },
            child: Text(
              'common.delete'.tr(),
              style: GoogleFonts.outfit(color: AppColors.primaryRed, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(String title, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      width: double.infinity,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          title,
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
        ),
      ),
    ),
  );
}

// ── Chat bubble ────────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, this.showTail = true});
  final ChatMessage message;
  final bool showTail;

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMine;
    final time = message.createdAt != null ? _fmt(message.createdAt!) : null;

    return Padding(
      padding: EdgeInsets.only(bottom: 4, left: isMe ? 60 : 0, right: isMe ? 0 : 60),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primaryRed : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe || !showTail ? 18 : 4),
                bottomRight: Radius.circular(!isMe || !showTail ? 18 : 4),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Text(message.body, style: GoogleFonts.outfit(fontSize: 14, color: isMe ? Colors.white : Colors.black87, height: 1.4)),
          ),
          if (time != null || message.pending)
            Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 6),
              child: Text(message.pending ? 'chat.sending'.tr() : time!, style: GoogleFonts.outfit(fontSize: 10, color: Colors.black38)),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }

  String _fmt(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ── Date chip ─────────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final String label;
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      label = 'chat.today'.tr();
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      label = 'chat.yesterday'.tr();
    } else {
      label = DateFormat.yMMMd(context.locale.languageCode).format(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.07), borderRadius: BorderRadius.circular(12)),
          child: Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.black54)),
        ),
      ),
    );
  }
}

// ── Chat loading shimmer ──────────────────────────────────────────────────────

class _ChatShimmer extends StatelessWidget {
  const _ChatShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bubble(isMe: false, width: 180),
            _bubble(isMe: true, width: 120),
            _bubble(isMe: false, width: 220),
            _bubble(isMe: true, width: 160),
            _bubble(isMe: false, width: 140),
            _bubble(isMe: true, width: 200),
          ],
        ),
      ),
    );
  }

  Widget _bubble({required bool isMe, required double width}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12, left: isMe ? 80 : 0, right: isMe ? 0 : 80),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              width: width,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEDEDED),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
            ),
            const SizedBox(height: 4),
            ShimmerBox(width: 36, height: 8, radius: 4),
          ],
        ),
      ),
    );
  }
}
