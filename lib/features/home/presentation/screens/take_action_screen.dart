import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/primary_gradient_button.dart';

class TakeActionScreen extends StatefulWidget {
  const TakeActionScreen({super.key});

  @override
  State<TakeActionScreen> createState() => _TakeActionScreenState();
}

class _TakeActionScreenState extends State<TakeActionScreen> {
  String? _selectedOption;
  final TextEditingController _commentController = TextEditingController();

  final List<String> _options = ['Hate Speech', 'Nudity or Sexual Content', 'Threat', 'Harassment', 'Diffamation', 'Fraud Or Scam', 'Something Else'];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(title: 'Take action', showBackButton: true, showLogo: true, showNotification: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              'Find Support or Report User',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black),
            ),
            const SizedBox(height: 8),
            Text('Help us understanding what’s happening', style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 32),
            ..._options.map((option) => _buildOptionTile(option)),
            const SizedBox(height: 16),
            _buildCommentField(),
            const SizedBox(height: 40),
            PrimaryGradientButton(text: 'Submit', onPressed: () => Navigator.pop(context)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(String option) {
    bool isSelected = _selectedOption == option;
    return GestureDetector(
      onTap: () => setState(() => _selectedOption = option),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? AppColors.primaryRed : Colors.black.withValues(alpha: 0.2), width: 2),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryRed),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Text(
              option,
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentField() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _commentController,
        maxLines: 5,
        decoration: InputDecoration(
          hintText: 'Other',
          hintStyle: GoogleFonts.outfit(color: Colors.black54),
          contentPadding: const EdgeInsets.all(16),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
