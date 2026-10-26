import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/network/api_config.dart';
import '../../../auth/domain/models/service_area_location.dart';
import '../../../projects/domain/models/project.dart';

/// Client-facing professional row (search / recommendations). Populated from API when available.
class ProfessionalListing {
  const ProfessionalListing({
    required this.id,
    required this.displayName,
    required this.specialty,
    required this.roleLabel,
    required this.location,
    required this.costDisplay,
    required this.dateDisplay,
    this.profilePhotoUrl,
    this.coverPhotoUrl,
    required this.profileAssetFallback,
    required this.backgroundAssetFallback,
    this.latitude,
    this.longitude,
    this.rating,
    this.serviceAreas = const [],
  });

  final String id;
  final String displayName;
  final String specialty;
  /// Shown on the card (e.g. "Cleaner"); API may send [role] / [jobTitle].
  final String roleLabel;
  final String location;
  final String costDisplay;
  final String dateDisplay;
  final String? profilePhotoUrl;
  final String? coverPhotoUrl;
  final String profileAssetFallback;
  final String backgroundAssetFallback;
  final double? latitude;
  final double? longitude;
  final double? rating;
  final List<ServiceAreaLocation> serviceAreas;

  factory ProfessionalListing.fromMap(Map<String, dynamic> map) {
    final portfolio = _firstPortfolioItem(map);
    final id = _firstNonEmpty([
      map['id'],
      map['_id'],
      map['professionalId'],
      map['userId'],
      map['uid'],
    ]) ?? '';

    final displayName = _composeDisplayName(map);
    final specialty = _firstNonEmpty([
      _portfolioString(portfolio, 'title'),
      _portfolioString(portfolio, 'projectTitle'),
      map['speciality'],
      map['specialty'],
      map['profession'],
      map['trade'],
      map['categoryName'],
      map['title'],
    ]) ?? 'Professional';

    final roleLabel = _firstNonEmpty([
      map['role'],
      map['jobTitle'],
      map['professionLabel'],
      map['speciality'],
      map['specialty'],
    ]) ??
        specialty;

    final location = _firstNonEmpty([
      _portfolioString(portfolio, 'completedPlace'),
      _portfolioString(portfolio, 'location'),
      _portfolioString(portfolio, 'city'),
      map['city'],
      map['location'],
      map['address'],
      map['serviceArea'],
      map['companyAddress'],
    ]) ?? '';

    final cost = _firstNonEmpty([
      _portfolioAmount(portfolio),
      _portfolioString(portfolio, 'price'),
      map['rateLabel'],
      map['hourlyRate'],
      map['startingPrice'],
      map['priceFrom'],
      map['budgetHint'],
    ]);

    final dateRaw = _firstNonEmpty([
      _portfolioString(portfolio, 'completedAt'),
      _portfolioString(portfolio, 'completionDate'),
      _portfolioString(portfolio, 'date'),
      _portfolioString(portfolio, 'createdAt'),
      map['availability'],
      map['nextAvailable'],
      map['availableFrom'],
    ]);

    final profileUrl = _absoluteUrl(_firstNonEmpty([
      map['profileImageUrl'],
      map['profilePhotoUrl'],
      map['profileImage'],
      map['avatarUrl'],
      map['photoUrl'],
      map['image'],
      _nestedString(map['user'], 'profileImageUrl'),
      _nestedString(map['user'], 'profilePhotoUrl'),
      _nestedString(map['user'], 'profileImage'),
      _nestedString(map['user'], 'avatar'),
      _nestedString(map['professional'], 'profileImageUrl'),
      _nestedString(map['professional'], 'profilePhotoUrl'),
    ]));

    final coverUrl = _absoluteUrl(_firstNonEmpty([
      _portfolioPhotoUrl(portfolio),
      map['coverPhotoUrl'],
      map['bannerUrl'],
      map['heroImage'],
      _firstPortfolioPhotoUrl(map['portfolio']),
      _firstPortfolioPhotoUrl(map['portfolioItems']),
    ]));

    final lat = map['latitude'] ?? map['lat'] ?? _nestedString(map['user'], 'latitude');
    final lng = map['longitude'] ?? map['lng'] ?? _nestedString(map['user'], 'longitude');

    final ratingRaw = map['performanceStarRating'] ??
        map['starRating'] ??
        map['rating'] ??
        (map['professional'] is Map
            ? (Map<String, dynamic>.from(map['professional'])['performanceStarRating'] ??
                Map<String, dynamic>.from(map['professional'])['starRating'])
            : null);
    final rating = ratingRaw != null ? double.tryParse(ratingRaw.toString()) : null;

    final areasRaw = map['serviceAreas'] ?? map['serviceAreaCities'];
    final serviceAreas = areasRaw is List
        ? areasRaw.map((e) => ServiceAreaLocation.fromDynamic(e)).toList()
        : const <ServiceAreaLocation>[];

    return ProfessionalListing(
      id: id,
      displayName: displayName.isEmpty ? 'Professional' : displayName,
      specialty: specialty,
      roleLabel: roleLabel,
      location: location.isEmpty ? '—' : location,
      costDisplay: cost == null || cost.isEmpty ? '—' : _stripDuplicateEuroPrefix(cost),
      dateDisplay: _prettyDate(dateRaw),
      profilePhotoUrl: profileUrl,
      coverPhotoUrl: coverUrl,
      profileAssetFallback: AppAssets.profilePlaceholder,
      backgroundAssetFallback: AppAssets.homeHeaderBg,
      latitude: lat != null ? double.tryParse(lat.toString()) : null,
      longitude: lng != null ? double.tryParse(lng.toString()) : null,
      rating: rating,
      serviceAreas: serviceAreas,
    );
  }

  /// Maps an open project from [GET /professionals/projects] onto the discovery card (pro sees client brief).
  factory ProfessionalListing.fromProject(Project p) {
    final service = (p.serviceType != null && p.serviceType!.trim().isNotEmpty) ? p.serviceType!.trim() : '';
    final headline = service.isNotEmpty
        ? service
        : (p.title.trim().isNotEmpty ? p.title.trim() : tr('projects.open_project_badge'));
    final client = (p.clientDisplayName != null && p.clientDisplayName!.trim().isNotEmpty)
        ? p.clientDisplayName!.trim()
        : tr('projects.client_fallback');
    return ProfessionalListing(
      id: p.id,
      displayName: client,
      specialty: headline,
      roleLabel: tr('projects.open_project_badge'),
      location: p.location.trim().isEmpty ? '—' : p.location.trim(),
      costDisplay: _budgetForCostLine(p.budget),
      dateDisplay: p.date.trim().isEmpty ? '—' : p.date.trim(),
      profilePhotoUrl: null,
      coverPhotoUrl: (p.imageUrl != null && p.imageUrl!.trim().isNotEmpty) ? p.imageUrl : null,
      profileAssetFallback: AppAssets.profilePlaceholder,
      backgroundAssetFallback: AppAssets.homeHeaderBg,
      latitude: p.latitude,
      longitude: p.longitude,
      rating: null,
      serviceAreas: const [],
    );
  }

  static String _budgetForCostLine(String? budget) {
    if (budget == null || budget.trim().isEmpty) return '—';
    var t = budget.trim().replaceFirst(RegExp(r'^€\s*'), '').trim();
    if (t.isEmpty) return '—';
    if (!t.endsWith('€')) t = '$t€';
    return t;
  }

  static List<ProfessionalListing> demoUntilApiAvailable() {
    return const [
      ProfessionalListing(
        id: 'demo-1',
        displayName: 'David Miller',
        specialty: 'Kitchen Renovation',
        roleLabel: 'Cleaner',
        location: 'Paris, FR',
        costDisplay: '322€',
        dateDisplay: 'Jun 12, 2025',
        profilePhotoUrl: null,
        coverPhotoUrl: null,
        profileAssetFallback: AppAssets.profilePlaceholder,
        backgroundAssetFallback: AppAssets.homeHeaderBg,
        latitude: 48.8656,
        longitude: 2.3522,
        rating: 5.0,
        serviceAreas: [],
      ),
      ProfessionalListing(
        id: 'demo-2',
        displayName: 'Sarah Jenkins',
        specialty: 'Living Room Decor',
        roleLabel: 'Painter',
        location: 'Paris, FR',
        costDisplay: '450€',
        dateDisplay: 'Jul 05, 2025',
        profilePhotoUrl: null,
        coverPhotoUrl: null,
        profileAssetFallback: AppAssets.profilePlaceholder,
        backgroundAssetFallback: AppAssets.textureBg,
        latitude: 48.8566,
        longitude: 2.3622,
        rating: 4.5,
        serviceAreas: [],
      ),
      ProfessionalListing(
        id: 'demo-3',
        displayName: 'Mark Stevens',
        specialty: 'Pipe Repair',
        roleLabel: 'Plumber',
        location: 'Paris, FR',
        costDisplay: '180€',
        dateDisplay: 'May 05, 2025',
        profilePhotoUrl: null,
        coverPhotoUrl: null,
        profileAssetFallback: AppAssets.profilePlaceholder,
        backgroundAssetFallback: AppAssets.homeHeaderBg,
        latitude: 48.8466,
        longitude: 2.3522,
        rating: 4.0,
        serviceAreas: [],
      ),
      ProfessionalListing(
        id: 'demo-4',
        displayName: 'James Wilson',
        specialty: 'Office Cleaning',
        roleLabel: 'Cleaner',
        location: 'Paris, FR',
        costDisplay: '210€',
        dateDisplay: 'Jul 07, 2025',
        profilePhotoUrl: null,
        coverPhotoUrl: null,
        profileAssetFallback: AppAssets.profilePlaceholder,
        backgroundAssetFallback: AppAssets.textureBg,
        latitude: 48.8566,
        longitude: 2.3422,
        rating: 3.5,
        serviceAreas: [],
      ),
    ];
  }

  static String? _firstNonEmpty(List<dynamic> keys) {
    for (final v in keys) {
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static String? _nestedString(dynamic parent, String key) {
    if (parent is! Map) return null;
    final m = Map<String, dynamic>.from(parent);
    return _firstNonEmpty([m[key]]);
  }

  static String? _firstPortfolioPhotoUrl(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    final first = raw.first;
    if (first is Map<String, dynamic>) {
      return _firstNonEmpty([first['url'], first['photoUrl'], first['imageUrl']]);
    }
    return null;
  }

  static Map<String, dynamic>? _firstPortfolioItem(Map<String, dynamic> map) {
    for (final key in const ['portfolio', 'portfolioItems', 'portfolioData']) {
      final node = map[key];
      if (node is List && node.isNotEmpty && node.first is Map) {
        return Map<String, dynamic>.from(node.first as Map);
      }
    }
    return null;
  }

  static String? _portfolioString(Map<String, dynamic>? portfolio, String key) {
    if (portfolio == null) return null;
    return _firstNonEmpty([portfolio[key]]);
  }

  static String? _portfolioAmount(Map<String, dynamic>? portfolio) {
    if (portfolio == null) return null;
    final raw = portfolio['amount'];
    if (raw == null) return null;
    final n = raw is num ? raw.toDouble() : double.tryParse(raw.toString().trim());
    if (n == null) return _firstNonEmpty([raw]);
    final text = n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(0);
    return '$text€';
  }

  static String? _portfolioPhotoUrl(Map<String, dynamic>? portfolio) {
    if (portfolio == null) return null;
    final photos = portfolio['photos'];
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first;
      if (first is Map) {
        final m = Map<String, dynamic>.from(first);
        return _firstNonEmpty([m['url'], m['photoUrl'], m['imageUrl']]);
      }
      if (first is String) return first.trim();
    }
    return _firstNonEmpty([portfolio['coverPhotoUrl'], portfolio['imageUrl'], portfolio['photoUrl']]);
  }

  static String _composeDisplayName(Map<String, dynamic> map) {
    final single = _firstNonEmpty([map['displayName'], map['username'], map['fullName'], map['name']]);
    if (single != null) return single;
    final first = _firstNonEmpty([map['firstName']]);
    final last = _firstNonEmpty([map['lastName']]);
    if (first != null && last != null) return '$first $last';
    return first ?? last ?? '';
  }

  static String? _absoluteUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final t = raw.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    final base = ApiConfig.baseUrl.endsWith('/') ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) : ApiConfig.baseUrl;
    final path = t.startsWith('/') ? t : '/$t';
    return '$base$path';
  }

  static String _stripDuplicateEuroPrefix(String s) {
    var t = s.trim();
    if (t.startsWith('€')) t = t.substring(1).trim();
    return t;
  }

  static String _prettyDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    final value = raw.trim();
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final mm = parsed.month.toString().padLeft(2, '0');
    final dd = parsed.day.toString().padLeft(2, '0');
    final yy = parsed.year.toString();
    return '$mm-$dd-$yy';
  }
}
