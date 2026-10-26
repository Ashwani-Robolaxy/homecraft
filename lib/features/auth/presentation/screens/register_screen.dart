import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../domain/models/app_user.dart';
import '../providers/auth_provider.dart';
import '../utils/auth_validators.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Web OAuth client ID from Firebase config; used as ID token audience for backend validation.
  static const String _googleServerClientId =
      '30170613785-tget5is0cteckkacqmf7ofm0nbvj32b6.apps.googleusercontent.com';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _termsAccepted = false;
  bool _isLoading = false;
  bool _googleInitialized = false;

  UserRole get _role {
    final role = GoRouterState.of(context).uri.queryParameters['role'];
    return role == 'provider' ? UserRole.provider : UserRole.client;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_termsAccepted) {
      AppToast.error('auth.validation.terms_required'.tr());
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.registerWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _nameController.text.trim(),
      role: _role,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.errorMessage != null) {
      final msg = result.errorMessage!;
      final display = msg.startsWith('auth.') ? msg.tr() : msg;
      AppToast.error(display);
      return;
    }
    await ref.read(authStateNotifierProvider).refresh();
    if (!mounted) return;
    final isProvider = result.user!.isProvider;
    await _showSuccessSheet(isProvider);
  }

  Future<void> _showSuccessSheet(bool isProvider) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 180,
              child: Center(
                child: Image.asset(
                  AppAssets.registerSuccess,
                  height: 180,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'auth.register.success_title'.tr(),
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'auth.register.success_body'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 15,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () {
                Navigator.of(ctx).pop();
                if (isProvider) {
                  ref.read(providerTabIndexProvider.notifier).setIndex(0);
                  context.go('/provider-home');
                } else {
                  context.go('/home');
                }
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF900000), Color(0xFF4A0000)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  'auth.register.success_continue'.tr(),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _googleErrorMessage(Object error) {
    if (error is GoogleSignInException) {
      final d = error.description?.trim();
      return d == null || d.isEmpty
          ? 'Google sign-in failed (${error.code.name}).'
          : 'Google sign-in failed: $d';
    }
    if (error is FirebaseAuthException) {
      final msg = error.message?.trim();
      return msg == null || msg.isEmpty
          ? 'Firebase auth failed (${error.code}).'
          : msg;
    }
    if (error is UnsupportedError) {
      return 'Google sign-in is not supported on this device/build.';
    }
    return 'Google sign-in failed. Please try again.';
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: _googleServerClientId,
        );
        _googleInitialized = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final googleAuth = account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        AppToast.error('Google sign-in failed: missing idToken.');
        return;
      }
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.socialLogin(
        provider: 'google',
        idToken: idToken,
        role: _role,
      );
      if (!mounted) return;
      if (result.errorMessage != null) {
        AppToast.error(result.errorMessage!);
        return;
      }
      await ref.read(authStateNotifierProvider).refresh();
      if (!mounted) return;
      final user = result.user!;
      context.go(user.isProvider ? '/provider-home' : '/home');
    } catch (e, st) {
      debugPrint('[Auth][Google][Register] $e\n$st');
      if (!mounted) return;
      AppToast.error(_googleErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 30.0, bottom: 20.0),
              child: Image.asset(
                AppAssets.logoRed,
                height: 82,
                fit: BoxFit.contain,
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: AppColors.backgroundWhite,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      children: [
                        Text(tr('auth.register.title'), style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF7A0000))),
                        const SizedBox(height: 8),
                        Text(tr('auth.register.subtitle'), textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textMain.withValues(alpha: 0.7))),
                        const SizedBox(height: 30),
                        CustomTextField(
                          hintText: _role == UserRole.provider
                              ? tr('auth.register.professional_full_name_hint')
                              : tr('auth.register.username'),
                          prefixIcon: LucideIcons.user,
                          controller: _nameController,
                          validator: _role == UserRole.provider
                              ? (v) => AuthValidators.professionalFullName(v, context)
                              : AuthValidators.displayName,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          hintText: tr('auth.register.email'),
                          prefixIcon: LucideIcons.mail,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: AuthValidators.email,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          hintText: tr('auth.register.confirm_email'),
                          prefixIcon: LucideIcons.mail,
                          controller: _confirmEmailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => AuthValidators.confirmEmail(v, _emailController.text),
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          hintText: tr('auth.register.password'),
                          prefixIcon: LucideIcons.key,
                          isPassword: true,
                          controller: _passwordController,
                          validator: AuthValidators.password,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          hintText: tr('auth.register.confirm_password'),
                          prefixIcon: LucideIcons.key,
                          isPassword: true,
                          controller: _confirmPasswordController,
                          validator: (v) => AuthValidators.confirmPassword(v, _passwordController.text),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Checkbox(
                                value: _termsAccepted,
                                onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                                activeColor: AppColors.primaryRed,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Outfit'),
                                  children: [
                                    TextSpan(text: tr('auth.register.terms_prefix')),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: GestureDetector(
                                        onTap: () => context.push('/terms'),
                                        child: Text(tr('auth.register.terms_link'), style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, fontSize: 13, fontFamily: 'Outfit')),
                                      ),
                                    ),
                                    const TextSpan(text: ' & '),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: GestureDetector(
                                        onTap: () => context.push('/privacy'),
                                        child: Text(tr('auth.legal.privacy_title'), style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, fontSize: 13, fontFamily: 'Outfit')),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        PrimaryGradientButton(
                          text: tr('auth.register.button'),
                          onPressed: () => _submit(),
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(tr('auth.register.or_sign_in'), style: const TextStyle(color: AppColors.textSecondary))),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SocialButton(
                          text: tr('auth.register.google_sign_in'),
                          iconPath: 'google',
                          onTap: _signInWithGoogle,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(tr('auth.register.already_have'), style: const TextStyle(fontFamily: 'Outfit', fontSize: 14)),
                            TextButton(
                              onPressed: () => context.pop(),
                              child: Text(tr('auth.register.login_link'), style: const TextStyle(fontFamily: 'Outfit', color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ],
                        ),
                      ],
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
