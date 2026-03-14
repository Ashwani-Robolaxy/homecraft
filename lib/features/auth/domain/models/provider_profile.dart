/// Provider-specific profile data stored in Firestore (users/{uid}.providerProfile).
class ProviderProfile {
  const ProviderProfile({
    required this.displayName,
    required this.phone,
    required this.address,
    this.description,
    this.specialty,
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
  });

  final String displayName;
  final String phone;
  final String address;
  final String? description;
  final String? specialty;
  final String? companyName;
  final String? contactMail;
  final String? companyAddress;
  final String? postalCode;
  final String? siret;
  final List<String> serviceAreas;
  final String? website;
  final String? socialInstagram;
  final String? socialFacebook;
  final String? socialTwitter;
  final String? socialLinkedin;

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'phone': phone,
      'address': address,
      if (description != null && description!.isNotEmpty) 'description': description,
      if (specialty != null && specialty!.isNotEmpty) 'specialty': specialty,
      if (companyName != null && companyName!.isNotEmpty) 'companyName': companyName,
      if (contactMail != null && contactMail!.isNotEmpty) 'contactMail': contactMail,
      if (companyAddress != null && companyAddress!.isNotEmpty) 'companyAddress': companyAddress,
      if (postalCode != null && postalCode!.isNotEmpty) 'postalCode': postalCode,
      if (siret != null && siret!.isNotEmpty) 'siret': siret,
      'serviceAreas': serviceAreas,
      if (website != null && website!.isNotEmpty) 'website': website,
      if (socialInstagram != null && socialInstagram!.isNotEmpty) 'socialInstagram': socialInstagram,
      if (socialFacebook != null && socialFacebook!.isNotEmpty) 'socialFacebook': socialFacebook,
      if (socialTwitter != null && socialTwitter!.isNotEmpty) 'socialTwitter': socialTwitter,
      if (socialLinkedin != null && socialLinkedin!.isNotEmpty) 'socialLinkedin': socialLinkedin,
    };
  }

  factory ProviderProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ProviderProfile(displayName: '', phone: '', address: '');
    }
    final areas = map['serviceAreas'];
    return ProviderProfile(
      displayName: map['displayName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      description: map['description'] as String?,
      specialty: map['specialty'] as String?,
      companyName: map['companyName'] as String?,
      contactMail: map['contactMail'] as String?,
      companyAddress: map['companyAddress'] as String?,
      postalCode: map['postalCode'] as String?,
      siret: map['siret'] as String?,
      serviceAreas: areas is List<dynamic>
          ? areas.map((e) => e.toString()).toList()
          : const [],
      website: map['website'] as String?,
      socialInstagram: map['socialInstagram'] as String?,
      socialFacebook: map['socialFacebook'] as String?,
      socialTwitter: map['socialTwitter'] as String?,
      socialLinkedin: map['socialLinkedin'] as String?,
    );
  }

  ProviderProfile copyWith({
    String? displayName,
    String? phone,
    String? address,
    String? description,
    String? specialty,
    String? companyName,
    String? contactMail,
    String? companyAddress,
    String? postalCode,
    String? siret,
    List<String>? serviceAreas,
    String? website,
    String? socialInstagram,
    String? socialFacebook,
    String? socialTwitter,
    String? socialLinkedin,
  }) {
    return ProviderProfile(
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      description: description ?? this.description,
      specialty: specialty ?? this.specialty,
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
    );
  }
}
