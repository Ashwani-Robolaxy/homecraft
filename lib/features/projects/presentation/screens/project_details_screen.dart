import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/token_utils.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/project_image_placeholder.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../booking/data/booking_remote_datasource.dart';
import '../../../chat/presentation/professional_chat_args.dart';
import '../../../professionals/data/professionals_remote_datasource.dart';
import '../../../professionals/domain/models/professional_listing.dart';
import '../../data/repositories/project_repository_impl.dart';
import '../../domain/models/project.dart';
import '../../../subscription/data/subscription_remote_datasource.dart';
import '../../../../core/utils/category_localizer.dart';

class ProjectDetailsScreen extends StatefulWidget {
  const ProjectDetailsScreen({
    super.key,
    required this.project,
    this.bookingId,
    this.openAsClientOwner = false,
  });

  final Project project;

  /// When non-null the screen is in "professional review" mode and shows
  /// Accept / Reject / Chat action buttons that operate on this booking.
  final int? bookingId;

  /// When true (e.g. opened from **My projects**), hide comment + "interested" — only visitors/pros engage.
  final bool openAsClientOwner;

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  final _ds = BookingRemoteDatasource();
  final _projectRepo = ProjectRepositoryImpl();
  final _professionalsDs = ProfessionalsRemoteDatasource();
  final _commentController = TextEditingController();
  final _proCommentController = TextEditingController();
  bool _accepting = false;
  bool _rejecting = false;
  bool _interested = false;
  bool _submittingInterest = false;
  bool _loadingInterests = false;
  int? _interestedCountOverride;
  List<ProjectComment> _interestComments = const [];
  List<ProjectInterest> _interestProfiles = const [];
  String? _myComment;

  bool _isProvider = false;
  bool _isVerifiedProvider = false;
  bool _loadingVerification = false;

  bool get _busy => _accepting || _rejecting;
  bool get _hasProfessionalActions => widget.bookingId != null;

  /// True when the signed-in **client** is the project owner (async when not [openAsClientOwner]).
  bool _asyncDetectedClientOwnsProject = false;

  bool get _isClientViewingOwnProject =>
      widget.openAsClientOwner || _asyncDetectedClientOwnsProject;

  /// Comment thread + "Mark as interested" — not for owners; pros use [bookingId] flow instead.
  bool get _showVisitorInterestAndComments =>
      !_hasProfessionalActions && !_isClientViewingOwnProject;

  /// Clients should still see professionals' engagement on their own projects.
  bool get _showCommentsSection =>
      !_hasProfessionalActions && _isClientViewingOwnProject;

  late Project _project;
  bool _loadingInterestStatus = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _initializeView();
  }

  Future<void> _initializeView() async {
    await _resolveClientOwnership();
    if (_isClientViewingOwnProject) {
      await _loadProjectInterests();
    } else {
      await _checkProviderVerification();
      if (_isProvider && _isVerifiedProvider) {
        await _loadProfessionalInterestStatus();
      }
    }
  }

  Future<void> _loadProfessionalInterestStatus() async {
    if (_loadingInterestStatus) return;
    setState(() => _loadingInterestStatus = true);

    try {
      final list = await _projectRepo.getProfessionalInterestedProjects();
      final myInterest = list.firstWhere(
        (p) => p.project.id == _project.id,
        orElse: () => ProfessionalInterestedProject(project: _project),
      );
      if (!mounted) return;
      if (myInterest.interestCreatedAt != null) {
        setState(() {
          _interested = true;
          _myComment = myInterest.professionalComment;
          _proCommentController.text = myInterest.professionalComment ?? '';
          if (_project.imageUrl == null && myInterest.project.imageUrl != null) {
            _project = myInterest.project;
          }
        });
      }
    } catch (_) {
      // Fail silently
    } finally {
      if (mounted) {
        setState(() => _loadingInterestStatus = false);
      }
    }
  }

  Future<void> _checkProviderVerification() async {
    final me = await SessionStorage().getUser();
    if (me == null) return;
    if (!me.isProvider) {
      setState(() {
        _isProvider = false;
      });
      return;
    }

    setState(() {
      _isProvider = true;
      _loadingVerification = true;
    });

    try {
      final subDs = SubscriptionRemoteDatasource();
      final ctx = await subDs.fetchContext();
      final status = ctx.subscriptionState.verificationStatus;
      if (!mounted) return;
      setState(() {
        _isVerifiedProvider = status == 'verified';
        _loadingVerification = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingVerification = false;
      });
    }
  }

  Future<void> _resolveClientOwnership() async {
    if (widget.openAsClientOwner || widget.bookingId != null) return;
    final me = await SessionStorage().getUser();
    if (me == null || !me.isClient || !mounted) return;
    final cid = widget.project.clientUserId?.trim() ?? '';
    if (cid.isEmpty) return;
    final token = await SessionStorage().getToken();
    final sub = token != null ? TokenUtils.readSubject(token) : null;
    final uid = me.uid.trim();
    final owns = cid == uid || (sub != null && sub == cid);
    if (!mounted) return;
    setState(() => _asyncDetectedClientOwnsProject = owns);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _proCommentController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await _ds.updateBookingStatus(widget.bookingId!, 'accepted');
      if (!mounted) return;
      AppToast.success('booking.accepted_toast'.tr());
      context.pop();
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
        title: Text('booking.reject_title'.tr(),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Text(
          'booking.reject_body'.tr(),
          style: GoogleFonts.outfit(color: Colors.black54, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr(),
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
            child: Text('common.reject'.tr(), style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _rejecting = true);
    try {
      await _ds.updateBookingStatus(widget.bookingId!, 'rejected');
      if (!mounted) return;
      AppToast.success('booking.rejected_toast'.tr());
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString()
          .replaceFirst('ApiException: ', '')
          .replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  void _openChat() {
    final uid = widget.project.clientUserId?.trim() ?? '';
    if (uid.isEmpty) {
      AppToast.info('booking.no_client_info'.tr());
      return;
    }
    context.push('/chat',
        extra: ProfessionalChatArgs(
          clientUserId: uid,
          clientDisplayName: widget.project.clientDisplayName,
          isCurrentUserProfessional: true,
          projectId: widget.project.id,
        ));
  }

  Future<void> _submitInterestAndComment() async {
    if (_interested || _submittingInterest) return;
    final comment = _commentController.text.trim();
    setState(() => _submittingInterest = true);
    final result = await _projectRepo.markProjectInterest(
      _project.id,
      comment: comment.isEmpty ? null : comment,
    );
    if (!mounted) return;
    setState(() => _submittingInterest = false);
    if (result.errorMessage != null) {
      AppToast.error(result.errorMessage!);
      return;
    }
    setState(() {
      _interested = true;
      _myComment = comment.isEmpty ? null : comment;
      _commentController.clear();
    });
    await _loadProjectInterests();
    AppToast.success('projects.interest_submitted_success'.tr());
  }

  Future<void> _loadProjectInterests() async {
    if (_loadingInterests) return;
    setState(() => _loadingInterests = true);
    try {
      final res = await _projectRepo.fetchProjectInterests(_project.id);
      if (!mounted) return;
      final me = await SessionStorage().getUser();
      final token = await SessionStorage().getToken();
      final tokenSub = token == null ? null : TokenUtils.readSubject(token);
      final meUid = (me?.uid ?? '').trim();
      final knownIds = <String>{
        if (meUid.isNotEmpty) meUid,
        if (tokenSub != null && tokenSub.trim().isNotEmpty) tokenSub.trim(),
      };
      final myName = (me?.displayName ?? '').trim().toLowerCase();
      final myEmail = (me?.email ?? '').trim().toLowerCase();
      ProjectInterest? myInterest;
      for (final interest in res.interests) {
        final pid = interest.professionalId.trim();
        final pname = interest.professionalName.trim().toLowerCase();
        final byId = pid.isNotEmpty && knownIds.contains(pid);
        final byName = myName.isNotEmpty && pname == myName;
        final byEmail = myEmail.isNotEmpty && pname == myEmail;
        if (byId || byName || byEmail) {
          myInterest = interest;
          break;
        }
      }
      setState(() {
        _interestedCountOverride = res.interestedCount;
        _interestComments = res.comments;
        _interestProfiles = res.interests;
        if (myInterest != null) {
          _interested = true;
          final myComment = myInterest.comment.trim();
          _myComment = myComment.isEmpty ? _myComment : myComment;
        }
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.error(
        e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loadingInterests = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: CommonAppBar(title: tr('details.title')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Image ────────────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: ProjectImagePlaceholder.hasDisplayableUrl(project.imageUrl)
                        ? Image.network(
                            project.imageUrl!,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ProjectImagePlaceholder(height: 220),
                          )
                        : const ProjectImagePlaceholder(height: 220),
                  ),
                  const SizedBox(height: 20),

                  // ── Title & Budget ────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          project.title,
                          style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain),
                        ),
                      ),
                      if (project.budget != null &&
                          project.budget!.isNotEmpty)
                        Text(
                          project.budget!,
                          style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Category chip ─────────────────────────────────────
                  if (project.serviceType != null &&
                      project.serviceType!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        CategoryLocalizer.localize(project.serviceType, context),
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryRed),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Location & date ───────────────────────────────────
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (project.location.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.mapPin,
                                  size: 13, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  project.location,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (project.date.isNotEmpty)
                        Text(
                          project.date.replaceAll('/', '-'),
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Description ───────────────────────────────────────
                  Text(
                    project.description,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.textMain,
                        height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  if (_showCommentsSection) ...[
                    if (_loadingInterests) ...[
                      _buildCommentsShimmer(),
                      const SizedBox(height: 20),
                    ] else ...[
                      _buildCommentsSection(readOnly: _isClientViewingOwnProject),
                      const SizedBox(height: 20),
                    ]
                  ] else if (_loadingVerification || _loadingInterestStatus) ...[
                    _buildProfessionalStatusShimmer(),
                    const SizedBox(height: 20),
                  ] else if (!_isClientViewingOwnProject && _isProvider && !_isVerifiedProvider) ...[
                    _buildVerificationWarningBanner(),
                    const SizedBox(height: 20),
                  ] else if (_interested) ...[
                    _buildMyInterestCard(),
                    const SizedBox(height: 20),
                  ] else if (!_isClientViewingOwnProject && _isProvider && _isVerifiedProvider) ...[
                    _buildProfessionalCommentInput(),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),

          // ── Action buttons (professional mode) ─────────────────────
          if (_hasProfessionalActions)
            _buildProfessionalActions()
          else if (_showVisitorInterestAndComments)
            _buildInterestedAction(),
        ],
      ),
    );
  }

  Future<void> _submitInterestDirectly() async {
    final comment = _proCommentController.text.trim();
    setState(() => _submittingInterest = true);
    final result = await _projectRepo.markProjectInterest(
      widget.project.id,
      comment: comment.isEmpty ? null : comment,
    );
    if (!mounted) return;
    setState(() => _submittingInterest = false);
    if (result.errorMessage != null) {
      AppToast.error(result.errorMessage!);
      return;
    }
    setState(() {
      _interested = true;
      _myComment = comment.isEmpty ? null : comment;
    });
    AppToast.success('projects.interest_submitted_success'.tr());
  }

  Widget _buildCommentsShimmer() {
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 140, height: 18, radius: 4),
          const SizedBox(height: 16),
          ...List.generate(2, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerCircle(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(width: 100, height: 14, radius: 4),
                      const SizedBox(height: 6),
                      const ShimmerBox(width: double.infinity, height: 12, radius: 4),
                      const SizedBox(height: 4),
                      const ShimmerBox(width: 160, height: 12, radius: 4),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildProfessionalStatusShimmer() {
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 150, height: 18, radius: 4),
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 90, radius: 14),
        ],
      ),
    );
  }

  Widget _buildProfessionalCommentInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'projects.your_message_quote'.tr(),
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'projects.send_optional_message_hint'.tr(),
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _proCommentController,
          minLines: 3,
          maxLines: 5,
          maxLength: 300,
          inputFormatters: [LengthLimitingTextInputFormatter(300)],
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain),
          decoration: InputDecoration(
            hintText: 'projects.type_comment_hint'.tr(),
            hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primaryRed, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildMyInterestCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.checkCircle2, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'projects.you_marked_interest'.tr(),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          if (_myComment != null && _myComment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'projects.your_message_label'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _myComment!,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.shieldAlert, color: Colors.orange.shade800, size: 32),
          const SizedBox(height: 8),
          Text(
            'projects.verification_required_title'.tr(),
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'projects.verification_required_desc'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.orange.shade800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestedAction() {
    final isDisabled = _interested || _submittingInterest || (_isProvider && !_isVerifiedProvider) || _loadingVerification || _loadingInterestStatus;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isDisabled
              ? null
              : _submitInterestDirectly,
          style: ElevatedButton.styleFrom(
            backgroundColor: (_interested || (_isProvider && !_isVerifiedProvider))
                ? Colors.grey.shade300
                : AppColors.primaryRed,
            foregroundColor: (_interested || (_isProvider && !_isVerifiedProvider)) ? Colors.black54 : Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.black54,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: _submittingInterest
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_interested) ...[
                      const Icon(LucideIcons.check, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      (_loadingVerification || _loadingInterestStatus)
                          ? 'common.loading'.tr()
                          : (_isProvider && !_isVerifiedProvider)
                              ? 'projects.verification_required'.tr()
                              : _interested
                                  ? 'projects.interested'.tr()
                                  : 'projects.mark_as_interested'.tr(),
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCommentsSection({required bool readOnly}) {
    final existing = _interestComments.isNotEmpty ? _interestComments : widget.project.comments;
    final interestedCount = _interestedCountOverride ?? widget.project.acceptedCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_interested && !readOnly) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.checkCircle2, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'projects.job_marked_interested'.tr(),
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Text(
          'projects.interested_professionals_count'.tr(args: [interestedCount.toString()]),
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryRed,
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingInterests)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryRed,
              ),
            ),
          ),
        if (readOnly && _interestProfiles.isNotEmpty) ...[
          ..._interestProfiles.map(_buildInterestedProfessionalTile),
          const SizedBox(height: 12),
        ],
        Text(
          'projects.comments_title'.tr(),
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 10),
        if (existing.isNotEmpty)
          ...existing.map(
            (c) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE7E7E7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.userName,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.text,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_myComment != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7E7E7)),
            ),
            child: Text(
              _myComment!,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7E7E7)),
            ),
            child: Text(
              'projects.no_comments_yet'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ),
        if (!readOnly) ...[
          const SizedBox(height: 8),
          Text(
            _myComment == null
                ? 'projects.add_comment_hint'.tr()
                : 'projects.already_posted_comment'.tr(),
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            enabled: _myComment == null,
            minLines: 3,
            maxLines: 4,
            maxLength: 300,
            inputFormatters: [LengthLimitingTextInputFormatter(300)],
            decoration: InputDecoration(
              hintText: 'projects.write_comment_hint'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: (_myComment != null || _interested || _submittingInterest)
                  ? null
                  : _submitInterestAndComment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.black54,
                elevation: 0,
              ),
              child: Text('projects.post_comment'.tr()),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInterestedProfessionalTile(ProjectInterest interest) {
    return InkWell(
      onTap: interest.professionalId.trim().isEmpty
          ? null
          : () => _openProfessionalProfile(interest),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE7E7E7)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFECECEC),
              backgroundImage: (interest.professionalImageUrl != null && interest.professionalImageUrl!.trim().isNotEmpty)
                  ? NetworkImage(interest.professionalImageUrl!.trim())
                  : null,
              child: (interest.professionalImageUrl == null || interest.professionalImageUrl!.trim().isEmpty)
                  ? const Icon(LucideIcons.user, size: 18, color: Colors.black45)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    interest.professionalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                  if (interest.professionalSubtitle.trim().isNotEmpty)
                    Text(
                      interest.professionalSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 18, color: Colors.black45),
          ],
        ),
      ),
    );
  }

  Future<void> _openProfessionalProfile(ProjectInterest interest) async {
    final professionalId = interest.professionalId.trim();
    if (professionalId.isEmpty) {
      AppToast.info('projects.professional_details_unavailable'.tr());
      return;
    }
    ProfessionalListing listing;
    try {
      listing = await _professionalsDs.fetchProfessionalById(professionalId);
    } on ApiException catch (e) {
      final msg = e.message.trim();
      final low = msg.toLowerCase();
      if (e.statusCode == 404 &&
          (low.contains('not verified') || low.contains('professional not found'))) {
        AppToast.info(
          msg.isNotEmpty
              ? msg
              : 'projects.professional_not_verified'.tr(),
        );
        return;
      }
      AppToast.error(msg.isNotEmpty ? msg : 'projects.could_not_load_professional'.tr());
      return;
    } catch (_) {
      final subtitle = interest.professionalSubtitle.trim();
      listing = ProfessionalListing(
        id: professionalId,
        displayName: interest.professionalName.trim().isEmpty ? 'Professional' : interest.professionalName.trim(),
        specialty: subtitle.isEmpty ? 'Professional' : subtitle,
        roleLabel: subtitle.isEmpty ? 'Professional' : subtitle,
        location: '—',
        costDisplay: '—',
        dateDisplay: '—',
        profilePhotoUrl: interest.professionalImageUrl,
        coverPhotoUrl: null,
        profileAssetFallback: AppAssets.profilePlaceholder,
        backgroundAssetFallback: AppAssets.homeHeaderBg,
      );
    }
    if (!mounted) return;
    context.push('/professional-detail', extra: listing);
  }

  Widget _buildProfessionalActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          // Chat
          GestureDetector(
            onTap: _busy ? null : _openChat,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(LucideIcons.messageCircle,
                  size: 22, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),

          // Reject
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _reject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryRed,
                side: const BorderSide(
                    color: AppColors.primaryRed, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _rejecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryRed))
                  : Text('common.reject'.tr(),
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),

          // Accept
          Expanded(
            child: ElevatedButton(
              onPressed: _busy ? null : _accept,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238E10),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _accepting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('common.accept'.tr(),
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

}
