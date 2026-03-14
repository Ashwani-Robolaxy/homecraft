import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/primary_gradient_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureReenter = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Texture
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage('assets/images/texture_bg.jpg'), fit: BoxFit.cover),
            ),
            child: Container(color: Colors.black.withValues(alpha: 0.8)),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                const SizedBox(height: 40),
                Center(
                  child: Image.asset(
                    'assets/images/logo_white.png',
                    height: 100,
                    errorBuilder: (context, error, stackTrace) => Text(
                      'H',
                      style: GoogleFonts.outfit(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'settings.reset_password_title'.tr(),
                          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        const SizedBox(height: 24),
                        _buildPasswordField(hint: 'settings.enter_old_password'.tr(), obscure: _obscureOld, onToggle: () => setState(() => _obscureOld = !_obscureOld)),
                        const SizedBox(height: 16),
                        _buildPasswordField(hint: 'settings.enter_new_password'.tr(), obscure: _obscureNew, onToggle: () => setState(() => _obscureNew = !_obscureNew)),
                        const SizedBox(height: 16),
                        _buildPasswordField(hint: 'settings.reenter_new_password'.tr(), obscure: _obscureReenter, onToggle: () => setState(() => _obscureReenter = !_obscureReenter)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: PrimaryGradientButton(text: 'settings.update_password'.tr(), onPressed: () => context.pop()),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
            ),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPasswordField({required String hint, required bool obscure, required VoidCallback onToggle}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: TextField(
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.black38, fontSize: 14),
          prefixIcon: const Icon(LucideIcons.key, color: Colors.black45, size: 20),
          suffixIcon: IconButton(
            icon: Icon(obscure ? LucideIcons.eyeOff : LucideIcons.eye, color: Colors.black38, size: 20),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
