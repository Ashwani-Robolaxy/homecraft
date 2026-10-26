import 'service_area_location.dart';

/// Provider-specific profile data stored in Firestore (users/{uid}.providerProfile).
class ProviderProfile {
  const ProviderProfile({
    required this.displayName,
    required this.phone,
    required this.address,
    this.description,
    this.specialty,
    this.categoryId,
    this.companyName,
    this.contactMail,
    this.companyAddress,
    this.postalCode,
    this.siret,
    this.serviceAreas = const [],
    this.website,
    this.socialInstagram,
    this.socialFacebook,
    this.socialTwitter,
    this.socialLinkedin,
    this.kbisExtractUrl,
    this.projectUploads = const [],
    this.certificateUploads = const [],
  });

  final String displayName;
  final String phone;
  final String address;
  final String? description;
  final String? specialty;
  final int? categoryId;
  final String? companyName;
  final String? contactMail;
  final String? companyAddress;
  final String? postalCode;
  final String? siret;
  final List<ServiceAreaLocation> serviceAreas;
  final String? website;
  final String? socialInstagram;
  final String? socialFacebook;
  final String? socialTwitter;
  final String? socialLinkedin;
  final String? kbisExtractUrl;
  final List<String> projectUploads;
  final List<String> certificateUploads;

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'phone': phone,
      'address': address,
      if (description != null && description!.isNotEmpty)
        'description': description,
      if (specialty != null && specialty!.isNotEmpty) 'specialty': specialty,
      if (categoryId != null && categoryId! > 0) 'categoryId': categoryId,
      if (companyName != null && companyName!.isNotEmpty)
        'companyName': companyName,
      if (contactMail != null && contactMail!.isNotEmpty)
        'contactMail': contactMail,
      if (companyAddress != null && companyAddress!.isNotEmpty)
        'companyAddress': companyAddress,
      if (postalCode != null && postalCode!.isNotEmpty)
        'postalCode': postalCode,
      if (siret != null && siret!.isNotEmpty) 'siret': siret,
      'serviceAreas': serviceAreas.map((e) => e.toJson()).toList(),
      if (website != null && website!.isNotEmpty) 'website': website,
      if (socialInstagram != null && socialInstagram!.isNotEmpty)
        'socialInstagram': socialInstagram,
      if (socialFacebook != null && socialFacebook!.isNotEmpty)
        'socialFacebook': socialFacebook,
      if (socialTwitter != null && socialTwitter!.isNotEmpty)
        'socialTwitter': socialTwitter,
      if (socialLinkedin != null && socialLinkedin!.isNotEmpty)
        'socialLinkedin': socialLinkedin,
      if (kbisExtractUrl != null && kbisExtractUrl!.isNotEmpty)
        'kbisExtractUrl': kbisExtractUrl,
      'projectUploads': projectUploads,
      'certificateUploads': certificateUploads,
    };
  }

  Map<String, dynamic> toCompleteProfileApiMap() {
    final normalizedWebsite = _normalizeUrlOrNull(website);
    final normalizedKbis = _normalizeUrlOrNull(
      kbisExtractUrl,
      requireSchemeOrWww: true,
    );
    final socialMediaLinks = <String>[
      if (_normalizeUrlOrNull(socialInstagram) case final value?) value,
      if (_normalizeUrlOrNull(socialFacebook) case final value?) value,
      if (_normalizeUrlOrNull(socialTwitter) case final value?) value,
      if (_normalizeUrlOrNull(socialLinkedin) case final value?) value,
    ];
    return {
      'username': displayName,
      'phone': phone,
      'address': companyAddress?.isNotEmpty == true ? companyAddress! : address,
      'description': description ?? '',
      'speciality': specialty ?? '',
      if (categoryId != null && categoryId! > 0) 'categoryId': categoryId,
      'companyName': companyName ?? '',
      'contactEmail': contactMail ?? '',
      'companyAddress': companyAddress ?? '',
      'postalCode': postalCode ?? '',
      'siretNumber': siret ?? '',
      'kbisExtractUrl': normalizedKbis,
      'projectUploads': projectUploads,
      'certificateUploads': certificateUploads,
      'serviceAreaCities': serviceAreas
          .where((e) => e.isValidForApi)
          .map((e) => e.toCompleteProfileJson())
          .toList(),
      'websiteUrl': normalizedWebsite,
      'socialMediaLinks': socialMediaLinks,
    };
  }

  static String? _normalizeUrlOrNull(
    String? raw, {
    bool requireSchemeOrWww = false,
  }) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://'))
      return value;
    if (lower.startsWith('www.')) return 'https://$value';
    if (requireSchemeOrWww) return null;
    if (_looksLikeDomain(value)) return 'https://$value';
    return null;
  }

  static bool _looksLikeDomain(String value) {
    if (value.contains(' ')) return false;
    final regex = RegExp(r'^[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+([/?#].*)?$');
    return regex.hasMatch(value);
  }

  factory ProviderProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ProviderProfile(displayName: '', phone: '', address: '');
    }
    final areas = map['serviceAreas'] ?? map['serviceAreaCities'];
    final socialList = map['socialMediaLinks'];
    String? sInstagram;
    String? sFacebook;
    String? sTwitter;
    String? sLinkedin;
    if (socialList is List) {
      for (final item in socialList) {
        final url = item.toString();
        final low = url.toLowerCase();
        if (low.contains('instagram')) sInstagram = url;
        if (low.contains('facebook')) sFacebook = url;
        if (low.contains('twitter') || low.contains('x.com')) sTwitter = url;
        if (low.contains('linkedin')) sLinkedin = url;
      }
    }
    return ProviderProfile(
      displayName:
          map['displayName'] as String? ?? map['username'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      description: map['description'] as String?,
      specialty: map['specialty'] as String? ?? map['speciality'] as String?,
      categoryId: _pickPositiveInt([
        map['categoryId'],
        map['specialityId'],
        map['specialtyId'],
        (map['category'] is Map ? (map['category'] as Map)['id'] : null),
      ]),
      companyName: map['companyName'] as String?,
      contactMail:
          map['contactMail'] as String? ?? map['contactEmail'] as String?,
      companyAddress: map['companyAddress'] as String?,
      postalCode: map['postalCode'] as String?,
      siret: map['siret'] as String? ?? map['siretNumber'] as String?,
      serviceAreas: areas is List<dynamic>
          ? areas.map((e) => ServiceAreaLocation.fromDynamic(e)).toList()
          : const [],
      website: map['website'] as String? ?? map['websiteUrl'] as String?,
      socialInstagram: map['socialInstagram'] as String? ?? sInstagram,
      socialFacebook: map['socialFacebook'] as String? ?? sFacebook,
      socialTwitter: map['socialTwitter'] as String? ?? sTwitter,
      socialLinkedin: map['socialLinkedin'] as String? ?? sLinkedin,
      kbisExtractUrl: map['kbisExtractUrl'] as String?,
      projectUploads: map['projectUploads'] is List
          ? (map['projectUploads'] as List).map((e) => e.toString()).toList()
          : const [],
      certificateUploads: map['certificateUploads'] is List
          ? (map['certificateUploads'] as List)
                .map((e) => e.toString())
                .toList()
          : const [],
    );
  }

  ProviderProfile copyWith({
    String? displayName,
    String? phone,
    String? address,
    String? description,
    String? specialty,
    int? categoryId,
    String? companyName,
    String? contactMail,
    String? companyAddress,
    String? postalCode,
    String? siret,
    List<ServiceAreaLocation>? serviceAreas,
    String? website,
    String? socialInstagram,
    String? socialFacebook,
    String? socialTwitter,
    String? socialLinkedin,
    String? kbisExtractUrl,
    List<String>? projectUploads,
    List<String>? certificateUploads,
  }) {
    return ProviderProfile(
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      description: description ?? this.description,
      specialty: specialty ?? this.specialty,
      categoryId: categoryId ?? this.categoryId,
      companyName: companyName ?? this.companyName,
      contactMail: contactMail ?? this.contactMail,
      companyAddress: companyAddress ?? this.companyAddress,
      postalCode: postalCode ?? this.postalCode,
      siret: siret ?? this.siret,
      serviceAreas: serviceAreas ?? this.serviceAreas,
      website: website ?? this.website,
      socialInstagram: socialInstagram ?? this.socialInstagram,
      socialFacebook: socialFacebook ?? this.socialFacebook,
      socialTwitter: socialTwitter ?? this.socialTwitter,
      socialLinkedin: socialLinkedin ?? this.socialLinkedin,
      kbisExtractUrl: kbisExtractUrl ?? this.kbisExtractUrl,
      projectUploads: projectUploads ?? this.projectUploads,
      certificateUploads: certificateUploads ?? this.certificateUploads,
    );
  }

  static int? _pickPositiveInt(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final parsed = value is num ? value.toInt() : int.tryParse(value.toString());
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }
}
