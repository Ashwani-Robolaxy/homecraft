import 'package:easy_localization/easy_localization.dart';

/// Auth form validators using translated messages.
class AuthValidators {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auth.validation.email_required'.tr();
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'auth.validation.email_invalid'.tr();
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'auth.validation.password_required'.tr();
    }
    if (value.length < 6) {
      return 'auth.validation.password_min'.tr();
    }
    return null;
  }

  static String? confirmPassword(String? value, String? password) {
    final err = AuthValidators.password(value);
    if (err != null) return err;
    if (password == null || value != password) {
      return 'auth.validation.password_confirm'.tr();
    }
    return null;
  }

  static String? displayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auth.validation.username_required'.tr();
    }
    if (value.trim().length < 2) {
      return 'auth.validation.username_min'.tr();
    }
    return null;
  }
}
