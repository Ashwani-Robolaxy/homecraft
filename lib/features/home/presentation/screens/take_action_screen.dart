import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../report/data/report_remote_datasource.dart';
import '../../../report/domain/report_args.dart';

class TakeActionScreen extends StatefulWidget {
  const TakeActionScreen({super.key, this.args});
  final ReportArgs? args;

  @override
  State<TakeActionScreen> createState() => _TakeActionScreenState();
}

class _TakeActionScreenState extends State<TakeActionScreen> {
  ReportReason? _selected;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  final _ds = ReportRemoteDatasource();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) {
      AppToast.error('Please select a reason.');
      return;
    }

    final args = widget.args;
    if (args == null || args.professionalId.isEmpty) {
      AppToast.error('Could not identify who to report.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _ds.reportProfessional(
        professionalId: args.professionalId,
        reason: _selected!,
        description: _commentController.text.trim().isNotEmpty
            ? _commentController.text.trim()
            : null,
      );
      if (!mounted) return;
      AppToast.success('Report submitted. Our team will review it.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('ApiException: ', '');
      AppToast.error(msg.isNotEmpty ? msg : 'Could not submit report.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const CommonAppBar(
          title: 'Take action',
          showBackButton: true,
          showLogo: true,
          showNotification: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Find Support or Report User',
                style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                'Help us understanding what\'s happening',
                style:
                    GoogleFonts.outfit(fontSize: 14, color: Colors.black54),
              ),
              if (widget.args != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Reporting: ${widget.args!.professionalName}',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 28),
              ...ReportReason.values
                  .map((r) => _buildOptionTile(r))
                  .toList(),
              const SizedBox(height: 16),
              _buildCommentField(),
              const SizedBox(height: 40),
              PrimaryGradientButton(
                text: 'Submit Report',
                isLoading: _submitting,
                onPressed: _submitting ? () {} : _submit,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(ReportReason reason) {
    final isSelected = _selected == reason;
    return GestureDetector(
      onTap: () => setState(() => _selected = reason),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryRed.withOpacity(0.04)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? AppColors.primaryRed
                : Colors.black.withOpacity(0.15),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Radio circle
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryRed
                      : Colors.black.withOpacity(0.25),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryRed),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Text(
              reason.label,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color:
                    isSelected ? AppColors.primaryRed : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentField() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border:
            Border.all(color: Colors.black.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _commentController,
        maxLines: 5,
        style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Additional details (optional)…',
          hintStyle:
              GoogleFonts.outfit(fontSize: 14, color: Colors.black38),
          contentPadding: const EdgeInsets.all(16),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }
}
