import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// Auth form validators using translated messages.
class AuthValidators {
  // Practical RFC-5321 email regex:
  //  • Local part: alphanumeric + . _ % + - (no leading/trailing/consecutive dots)
  //  • Domain: alphanumeric + hyphens, separated by dots (no consecutive dots)
  //  • TLD: letters only, 2+ chars
  static final _emailRegex = RegExp(
    r'^(?!.*\.\.)(?!\.)(?!.*\.$)'   // no consecutive or leading/trailing dots
    r'[a-zA-Z0-9._%+\-]+'           // local part
    r'@'
    r'(?!-)[a-zA-Z0-9\-]+'          // domain label (no leading hyphen)
    r'(\.[a-zA-Z0-9\-]+)*'          // optional subdomains
    r'\.[a-zA-Z]{2,}$',             // TLD: letters only, 2+ chars
  );

  static const _validTlds = <String>{
    'com',
    'fr',
    'org',
    'net',
    'archi',
  };

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auth.validation.email_required'.tr();
    }
    final trimmed = value.trim();
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'auth.validation.email_invalid'.tr();
    }
    // Extract the TLD and validate it
    final tld = trimmed.split('.').last.toLowerCase();
    if (!_validTlds.contains(tld)) {
      return 'Only .com .fr .org .net .archi';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'auth.validation.password_required'.tr();
    }
    if (value.length < 8) {
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

  static String? confirmEmail(String? value, String? email) {
    final err = AuthValidators.email(value);
    if (err != null) return err;
    if (email == null || value!.trim() != email.trim()) {
      return 'auth.validation.email_confirm'.tr();
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

  /// Professional signup API requires [firstName] and [lastName]; enforce two parts.
  /// Pass [context] so EasyLocalization can resolve the string (validators run without locale if omitted).
  static String? professionalFullName(String? value, BuildContext context) {
    final base = displayName(value);
    if (base != null) return base;
    final trimmed = value!.trim();
    if (!trimmed.contains(RegExp(r'\s'))) {
      const key = 'auth.validation.professional_name_two_parts';
      final msg = key.tr(context: context);
      if (msg == key) {
        return 'Enter first and last name (e.g. John Smith).';
      }
      return msg;
    }
    return null;
  }
}
