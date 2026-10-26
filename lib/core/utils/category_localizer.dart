import 'package:flutter/widgets.dart';
import 'package:easy_localization/easy_localization.dart';

class CategoryLocalizer {
  static const Map<String, String> _frMap = {
    'landscaping': 'Paysagisme',
    'landscaper': 'Paysagiste',
    'gardeners, landscaper': 'Jardiniers, paysagiste',
    'gardener, landscaper': 'Jardinier, paysagiste',
    'garden': 'Jardinage',
    'gardening': 'Jardinage',
    'cleaning': 'Nettoyage',
    'cleaner': 'Agent d\'entretien',
    'painters': 'Peintres',
    'painter': 'Peintre',
    'painting': 'Peinture',
    'plumbing': 'Plomberie',
    'plumber': 'Plombier',
    'electrician': 'Électricien',
    'electricity': 'Électricité',
    'carpentry': 'Menuiserie',
    'carpenters': 'Menuisiers',
    'carpenter': 'Menuisier',
    'masonry': 'Maçonnerie',
    'mason': 'Maçon',
    'tiler': 'Carreleur',
    'tiling': 'Carrelage',
    'kitchen\'s specialist': 'Cuisiniste',
    'kitchen specialist': 'Cuisiniste',
    'piscinist': 'Pisciniste',
    'piscinist ( pool maintenance)': 'Pisciniste (entretien de piscine)',
    'piscinist (pool maintenance)': 'Pisciniste (entretien de piscine)',
    'exterior architect': 'Architecte d\'extérieur',
    'roofer': 'Couvreur',
    'roofing': 'Couverture / Toiture',
    'handyman': 'Bricolage',
    'hvac': 'Chauffage / Climatisation',
    'heating': 'Chauffage',
    'locksmith': 'Serrurier',
    'flooring': 'Revêtement de sol',
    'plastering': 'Plâtrerie',
    'plasterer': 'Plâtrier',
    'remodeler': 'Rénovateur',
    'renovation': 'Rénovation',
    'moving': 'Déménagement',
    'mover': 'Déménageur',
    'appliance repair': 'Réparation d\'appareils',
    'pest control': 'Lutte antiparasitaire',
  };

  /// Localizes a category or service type name based on the current context locale.
  static String localize(String? name, BuildContext context) {
    if (name == null || name.trim().isEmpty) return '';
    final trimmed = name.trim();
    final isFr = context.locale.languageCode == 'fr';
    if (!isFr) return trimmed;

    final lower = trimmed.toLowerCase();
    if (_frMap.containsKey(lower)) {
      return _frMap[lower]!;
    }

    return trimmed;
  }
}
