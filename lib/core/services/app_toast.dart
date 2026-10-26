import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../constants/app_colors.dart';

enum AppToastType { info, success, error }

class AppToast {
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static OverlayEntry? _entry;
  static Timer? _dismissTimer;

  static void info(String message) => _show(message, AppToastType.info);
  static void success(String message) => _show(message, AppToastType.success);
  static void error(String message) => _show(message, AppToastType.error);

  static String localizeBackendMessage(String msg, [BuildContext? context]) {
    try {
      final ctx = context ?? navigatorKey.currentContext ?? messengerKey.currentContext;
      final isFr = ctx != null
          ? EasyLocalization.of(ctx)?.currentLocale?.languageCode == 'fr'
          : true; // default to French translation if context is unavailable and method was invoked for localized display
      if (!isFr) return msg;

      final clean = msg.trim();
      final lower = clean.toLowerCase();

      // Common backend error & status messages
      if (lower.contains('an active subscription is required to initiate chat') ||
          lower == 'an active subscription is required to initiate chat conversations' ||
          lower == 'an active subscription is required to initiate chat conversations.') {
        return 'Un abonnement actif est requis pour démarrer des conversations par chat';
      }
      if (lower.contains('an active subscription is required to express interest in projects') || lower == 'an active subscription is required to express interest in projects') {
        return 'Un abonnement actif est requis pour exprimer votre intérêt pour les projets';
      }
      if (lower == 'please select at least one day.' || lower == 'please select at least one day') {
        return 'Veuillez sélectionner au moins un jour.';
      }
      if (lower == 'your trial will start once your account is verified.' || lower == 'your trial will start once your account is verified' || lower == 'trial starts after account verification') {
        return 'Votre essai commencera une fois votre compte vérifié.';
      }
      if (lower == 'you are already on a free trial.' || lower == 'you are already on a free trial') {
        return 'Vous bénéficiez déjà d\'un essai gratuit.';
      }
      if (lower == 'contact support to activate your free trial.' || lower == 'contact support to activate your free trial') {
        return 'Contactez le support pour activer votre essai gratuit.';
      }
      if (lower == 'you already have an active subscription.' || lower == 'you already have an active subscription') {
        return 'Vous avez déjà un abonnement actif.';
      }
      if (lower.contains('auto-renewal turned off') ||
          lower == 'auto-renewal turned off. your subscription will cancel at period end.' ||
          lower == 'auto-renewal turned off. your subscription will cancel at period end') {
        return 'Renouvellement automatique désactivé. Votre abonnement prendra fin à la date d\'échéance.';
      }
      if (lower.contains('subscription canceled') || lower.contains('subscription cancelled') || lower.contains('auto-renewal disabled') || lower.contains('subscription cancellation')) {
        return 'Abonnement résilié ou renouvellement automatique désactivé.';
      }
      if (lower.contains('no active subscription found') || lower.contains('no active subscription')) {
        return 'Aucun abonnement actif trouvé.';
      }
      if (lower == 'this plan is not available for your account.' || lower == 'this plan is not available for your account') {
        return 'Ce forfait n\'est pas disponible pour votre compte.';
      }
      if (lower == 'payment cancelled.' || lower == 'payment cancelled') {
        return 'Paiement annulé.';
      }
      if (lower == 'invalid payment configuration received from server.' || lower == 'invalid payment configuration received from server') {
        return 'Configuration de paiement invalide reçue du serveur.';
      }
      if (lower == 'payment failed. please try again.' || lower == 'payment failed. please try again') {
        return 'Échec du paiement. Veuillez réessayer.';
      }
      if (lower == 'payment could not be completed.' || lower == 'payment could not be completed') {
        return 'Le paiement n\'a pas pu être finalisé.';
      }
      if (lower == 'please log in as a professional to subscribe.' || lower == 'please log in as a professional to subscribe') {
        return 'Veuillez vous connecter en tant que professionnel pour souscrire.';
      }
      if (lower == 'could not load plans.' || lower == 'could not load plans') {
        return 'Impossible de charger les forfaits.';
      }
      if (lower == 'please login again.' || lower == 'please login again') {
        return 'Veuillez vous reconnecter.';
      }
      if (lower == 'chat connection failed. please retry.' || lower == 'chat connection failed. please retry') {
        return 'Échec de la connexion au chat. Veuillez réessayer.';
      }
      if (lower == 'could not delete conversation.' || lower == 'could not delete conversation') {
        return 'Impossible de supprimer la conversation.';
      }
      if (lower == 'interest submitted successfully.' || lower == 'interest submitted successfully') {
        return 'Intérêt enregistré avec succès.';
      }
      if (lower == 'booking accepted!' || lower == 'booking accepted') {
        return 'Réservation acceptée !';
      }
      if (lower == 'booking rejected.' || lower == 'booking rejected') {
        return 'Réservation refusée.';
      }
      if (lower == 'delivery accepted!' || lower == 'delivery accepted') {
        return 'Livraison acceptée !';
      }
      if (lower == 'delivery rejected.' || lower == 'delivery rejected') {
        return 'Livraison refusée.';
      }
      if (lower == 'project marked as delivered!' || lower == 'project marked as delivered') {
        return 'Projet marqué comme livré !';
      }
      if (lower == 'could not mark notifications as read.' || lower == 'could not mark notifications as read') {
        return 'Impossible de marquer les notifications comme lues.';
      }
      if (lower == 'could not load notifications.' || lower == 'could not load notifications') {
        return 'Impossible de charger les notifications.';
      }
      if (lower == 'network error. check your connection.' || lower == 'network error. check your connection') {
        return 'Erreur réseau. Vérifiez votre connexion.';
      }
      if (lower == 'client information is not available.' || lower == 'client information is not available') {
        return 'Les informations du client ne sont pas disponibles.';
      }
      if (lower == 'professional details are not available.' || lower == 'professional details are not available') {
        return 'Les détails du professionnel ne sont pas disponibles.';
      }
      if (lower == 'please fill all required fields.' || lower == 'please fill all required fields') {
        return 'Veuillez remplir tous les champs obligatoires.';
      }
      if (lower == 'no available dates found for this professional.' || lower == 'no available dates found for this professional') {
        return 'Aucune date disponible trouvée pour ce professionnel.';
      }
      if (lower == 'please provide a location.' || lower == 'please provide a location') {
        return 'Veuillez indiquer un emplacement.';
      }
      if (lower == 'please choose a valid desired date.' || lower == 'please choose a valid desired date') {
        return 'Veuillez choisir une date souhaitée valide.';
      }
      if (lower == 'project updated successfully' || lower == 'project updated successfully.') {
        return 'Projet mis à jour avec succès.';
      }
      if (lower == 'project created successfully' || lower == 'project created successfully.') {
        return 'Projet créé avec succès.';
      }
      if (lower == 'unable to load categories. please try again.' || lower == 'unable to load categories. please try again') {
        return 'Impossible de charger les catégories. Veuillez réessayer.';
      }
      if (lower == 'could not load that place. try another.' || lower == 'could not load that place. try another') {
        return 'Impossible de charger ce lieu. Essayez une autre recherche.';
      }
      if (lower == 'you do not have access to this conversation' || lower == 'you do not have access to this conversation.') {
        return 'Vous n\'avez pas accès à cette conversation.';
      }
      if (lower == 'phone is required' || lower == 'phone is required.') {
        return 'Le numéro de téléphone est obligatoire.';
      }
      if (lower == 'phone must be between 6 and 30 characters' || lower == 'phone must be between 6 and 30 characters.') {
        return 'Le numéro de téléphone doit comporter entre 6 et 30 caractères.';
      }
      if (lower == 'address is required' || lower == 'address is required.') {
        return 'L\'adresse est obligatoire.';
      }
      if (lower == 'company address is required' || lower == 'company address is required.') {
        return 'L\'adresse de l\'entreprise est obligatoire.';
      }
      if (lower == 'company name is required' || lower == 'company name is required.') {
        return 'Le nom de l\'entreprise est obligatoire.';
      }
      if (lower == 'first name is required' || lower == 'first name is required.') {
        return 'Le prénom est obligatoire.';
      }
      if (lower == 'last name is required' || lower == 'last name is required.') {
        return 'Le nom est obligatoire.';
      }
      if (lower == 'email is required' || lower == 'email is required.') {
        return 'L\'adresse e-mail est obligatoire.';
      }
      if (lower == 'siret number is required' || lower == 'siret is required' || lower == 'siret number is required.' || lower == 'siret is required.') {
        return 'Le numéro SIRET est obligatoire.';
      }
      if (lower == 'category is required' || lower == 'category is required.') {
        return 'La catégorie est obligatoire.';
      }
      if (lower == 'biography is required' || lower == 'bio is required' || lower == 'biography is required.' || lower == 'bio is required.') {
        return 'La biographie est obligatoire.';
      }
      if (lower == 'this professional profile is not verified yet and cannot be viewed.' || lower == 'this professional profile is not verified yet and cannot be viewed') {
        return 'Ce profil professionnel n\'est pas encore vérifié et ne peut pas être consulté.';
      }

      final paymentSuccessMatch = RegExp(r'Payment successful!\s*Welcome to\s*(.+)\.?', caseSensitive: false).firstMatch(clean);
      if (paymentSuccessMatch != null) {
        return 'Paiement réussi ! Bienvenue sur ${paymentSuccessMatch.group(1)}.';
      }

      final availMatch = RegExp(r'Availability updated for (\d+) day\(s\)\.?', caseSensitive: false).firstMatch(clean);
      if (availMatch != null) {
        return 'Disponibilité mise à jour pour ${availMatch.group(1)} jour(s).';
      }

      final failedUpdateMatch = RegExp(r'Failed to update (\d+) day\(s\):\s*(.+)', caseSensitive: false).firstMatch(clean);
      if (failedUpdateMatch != null) {
        return 'Échec de la mise à jour pour ${failedUpdateMatch.group(1)} jour(s) : ${failedUpdateMatch.group(2)}';
      }

      if (lower.startsWith('saved to "') && lower.endsWith('"')) {
        final colName = clean.substring(10, clean.length - 1);
        return 'Enregistré dans « $colName »';
      }
    } catch (_) {}
    return msg;
  }

  static void _show(String message, AppToastType type) {
    final context = navigatorKey.currentContext ?? messengerKey.currentContext;
    if (context == null) return;
    final overlay = navigatorKey.currentState?.overlay ?? Overlay.maybeOf(context, rootOverlay: true) ?? Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay == null) return;

    final config = _ToastConfig.fromType(type);
    final displayMessage = localizeBackendMessage(message, context);
    _dismissTimer?.cancel();
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 16,
        right: 16,
        top: MediaQuery.of(ctx).padding.top + 12,
        child: IgnorePointer(
          ignoring: true,
          child: SafeArea(
            top: false,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: config.borderColor.withValues(alpha: 0.6)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 5))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: config.bgColor, shape: BoxShape.circle),
                      child: Icon(config.icon, size: 14, color: config.iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        displayMessage,
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 13.5, color: AppColors.textMain, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
    _dismissTimer = Timer(const Duration(seconds: 2), () {
      _entry?.remove();
      _entry = null;
    });
  }
}

class _ToastConfig {
  const _ToastConfig({required this.bgColor, required this.borderColor, required this.iconColor, required this.icon});

  final Color bgColor;
  final Color borderColor;
  final Color iconColor;
  final IconData icon;

  factory _ToastConfig.fromType(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return const _ToastConfig(bgColor: Color(0xFFE8F8EE), borderColor: Color(0xFF3B9B5B), iconColor: Color(0xFF26733F), icon: LucideIcons.check);
      case AppToastType.error:
        return const _ToastConfig(bgColor: Color(0xFFFCEBEC), borderColor: AppColors.primaryRed, iconColor: AppColors.primaryRed, icon: LucideIcons.alertCircle);
      case AppToastType.info:
        return const _ToastConfig(bgColor: Color(0xFFEEF2FF), borderColor: Color(0xFF566DE8), iconColor: Color(0xFF4058D6), icon: LucideIcons.info);
    }
  }
}
