import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../support/data/support_remote_datasource.dart';
import '../../../support/domain/support_message.dart';
import '../../../support/services/support_socket.dart';

class ContactSupportScreen extends ConsumerStatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  ConsumerState<ContactSupportScreen> createState() =>
      _ContactSupportScreenState();
}

class _ContactSupportScreenState extends ConsumerState<ContactSupportScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _ds = SupportRemoteDatasource();
  final _session = SessionStorage();

  List<SupportMessage> _messages = [];
  SupportSocket? _socket;
  int? _threadId;
  String? _token;
  bool _loading = true;
  String? _error;
  bool _sendBusy = false;
  bool _isProfessional = false;
  String _threadStatus = 'open';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _session.getUser();
      _isProfessional = user?.isProvider ?? false;

      _token = await _session.getToken();
      if (_token == null || _token!.isEmpty) {
        throw ApiException('Please login again.');
      }

      // Step 1: Find an existing thread (don't create yet — API requires a body)
      final threadId = await _ds.findExistingThread(
        isProfessional: _isProfessional,
      );
      _threadId = threadId;

      if (threadId != null) {
        // Step 2: Load message history
        final history = await _ds.fetchMessages(
          threadId,
          isProfessional: _isProfessional,
        );
        if (!mounted) return;
        setState(() {
          _messages = history;
          _loading = false;
        });
        // Step 3: Connect socket
        _connectSocket(_token!, threadId);
        if (history.isNotEmpty) _scrollToBottom();
      } else {
        // No thread yet — show empty state; thread created on first send
        if (!mounted) return;
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Something went wrong.';
      });
    }
  }

  void _connectSocket(String token, int threadId) {
    _socket?.close();
    _socket = SupportSocket(
      serverUrl: ApiConfig.baseUrl,
      token: token,
      threadId: threadId,
      onIncomingMessage: _onIncoming,
      onStatusChanged: (status) {
        if (!mounted) return;
        setState(() => _threadStatus = status);
        if (status == 'closed') {
          AppToast.info('This support thread has been closed by admin.');
        }
      },
      onJoinFailed: (msg) {
        if (!mounted) return;
        AppToast.error(msg);
      },
      onConnectError: (_) {
        if (!mounted) return;
        AppToast.error('Support connection failed. Messages may be delayed.');
      },
    );
    _socket!.connect();
  }

  void _onIncoming(SupportMessage msg) {
    if (!mounted || msg.body.trim().isEmpty) return;
    setState(() => _appendDeduped(msg));
    _scrollToBottom();
  }

  void _appendDeduped(SupportMessage msg) {
    if (_messages.any((m) => m.id == msg.id && msg.id != 0)) return;
    _messages = [..._messages, msg];
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sendBusy) return;

    if (_threadStatus == 'closed') {
      AppToast.error('This thread is closed. Waiting for admin to reopen.');
      return;
    }

    setState(() => _sendBusy = true);
    _messageController.clear();

    // ── First message: create the thread lazily ────────────────────────────
    if (_threadId == null) {
      try {
        final result = await _ds.createThreadWithMessage(
          isProfessional: _isProfessional,
          body: text,
        );
        if (!mounted) return;
        setState(() {
          _threadId = result.threadId;
          _sendBusy = false;
          _appendDeduped(result.message);
        });
        _scrollToBottom();
        // Now connect the socket for subsequent real-time messages
        if (_token != null) _connectSocket(_token!, result.threadId);
      } catch (e) {
        if (!mounted) return;
        setState(() => _sendBusy = false);
        AppToast.error(e is ApiException ? e.message : 'Failed to send message.');
      }
      return;
    }

    // ── Subsequent messages ────────────────────────────────────────────────
    final socket = _socket;
    if (socket != null && socket.isConnected) {
      socket.sendMessage(text, onAck: (saved) {
        if (!mounted) return;
        setState(() => _sendBusy = false);
        if (saved != null) {
          setState(() => _appendDeduped(saved));
          _scrollToBottom();
        }
      });
    } else {
      // Fallback: send via REST
      try {
        final saved = await _ds.sendMessage(
          _threadId!,
          text,
          isProfessional: _isProfessional,
        );
        if (!mounted) return;
        setState(() {
          _sendBusy = false;
          if (saved != null) _appendDeduped(saved);
        });
        _scrollToBottom();
      } catch (e) {
        if (!mounted) return;
        setState(() => _sendBusy = false);
        AppToast.error(e is ApiException ? e.message : 'Failed to send message.');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            if (_threadStatus == 'closed') _buildClosedBanner(),
            Expanded(child: _buildBody()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return CommonAppBar(
      title: 'provider.profile.contact_support_title'.tr(),
      showNotification: false,
    );
  }

  Widget _buildClosedBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(LucideIcons.alertCircle, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'support.thread_closed_banner'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();
    if (_messages.isEmpty) return _buildEmpty();
    return _buildMessageList();
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primaryRed,
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.wifiOff, size: 48, color: Colors.black26),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 14, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _bootstrap,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: Text('common.retry'.tr()),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryRed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.headphones,
                size: 32, color: AppColors.primaryRed),
          ),
          const SizedBox(height: 16),
          Text(
            'support.how_can_help'.tr(),
            maxLines: 1,
            style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'support.send_msg_hint'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 13, color: Colors.black45, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final prev = index > 0 ? _messages[index - 1] : null;
        final showDate = prev == null ||
            !_isSameDay(prev.createdAt, msg.createdAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate) _buildDateSeparator(msg.createdAt),
            _buildBubble(msg),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;

    String label;
    if (diff == 0) {
      label = 'chat.today'.tr();
    } else if (diff == 1) {
      label = 'chat.yesterday'.tr();
    } else {
      label = DateFormat('MMM d, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(SupportMessage msg) {
    final isMe = msg.isMine;
    final timeStr = DateFormat('HH:mm').format(msg.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 4),
              child: Text(
                'support.support_label'.tr(),
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500),
              ),
            ),
          Container(
            margin: EdgeInsets.only(
              left: isMe ? 60 : 0,
              right: isMe ? 0 : 60,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primaryRed : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft:
                    isMe ? const Radius.circular(16) : Radius.zero,
                bottomRight:
                    isMe ? Radius.zero : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              msg.body,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: isMe ? Colors.white : Colors.black87,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 3,
              bottom: 6,
              left: isMe ? 0 : 4,
              right: isMe ? 4 : 0,
            ),
            child: Text(
              timeStr,
              style: GoogleFonts.outfit(fontSize: 10, color: Colors.black38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final isClosed = _threadStatus == 'closed';
    final enabled = !_loading && !isClosed && !_sendBusy;
    // Inset only inside the bar so the composer stays white edge-to-edge (no gray gap below).
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 4 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
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
                border: Border.all(
                  color: enabled
                      ? AppColors.primaryRed.withOpacity(0.35)
                      : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _messageController,
                enabled: enabled,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => _send(),
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: isClosed
                      ? 'support.thread_closed_hint'.tr()
                      : 'chat.type_message'.tr(),
                  hintStyle:
                      GoogleFonts.outfit(color: Colors.black38, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? _send : null,
              customBorder: const CircleBorder(),
              child: Ink(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: enabled ? AppColors.primaryRed : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _sendBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          LucideIcons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
