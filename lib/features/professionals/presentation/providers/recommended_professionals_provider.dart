import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/professionals_remote_datasource.dart';
import '../../domain/models/professional_listing.dart';

class ProfessionalSearchFilters {
  const ProfessionalSearchFilters({
    this.query = '',
    this.location = '',
    this.categoryId,
    this.maxDistanceKm = 500,
    this.availability = const <String>{},
    this.minRating,
    this.limit = 24,
    this.latitude,
    this.longitude,
    this.interventionDate,
  });

  final String query;
  final String location;
  final int? categoryId;
  final double maxDistanceKm;
  /// Allowed values: today, within_week, next_week.
  final Set<String> availability;
  /// 3, 4, 5 stars threshold.
  final int? minRating;
  final int limit;
  final double? latitude;
  final double? longitude;
  final DateTime? interventionDate;

  ProfessionalSearchFilters copyWith({
    String? query,
    String? location,
    int? categoryId,
    bool clearCategory = false,
    double? maxDistanceKm,
    Set<String>? availability,
    int? minRating,
    bool clearMinRating = false,
    int? limit,
    double? latitude,
    double? longitude,
    DateTime? interventionDate,
    bool clearCoordinates = false,
    bool clearInterventionDate = false,
  }) {
    return ProfessionalSearchFilters(
      query: query ?? this.query,
      location: location ?? this.location,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      availability: availability ?? this.availability,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      limit: limit ?? this.limit,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      interventionDate:
          clearInterventionDate ? null : (interventionDate ?? this.interventionDate),
    );
  }
}

final professionalsRemoteDatasourceProvider = Provider<ProfessionalsRemoteDatasource>((ref) {
  return ProfessionalsRemoteDatasource();
});

class ProfessionalSearchFiltersNotifier extends Notifier<ProfessionalSearchFilters> {
  @override
  ProfessionalSearchFilters build() => const ProfessionalSearchFilters();
  void set(ProfessionalSearchFilters next) => state = next;
}

final professionalSearchFiltersProvider = NotifierProvider<ProfessionalSearchFiltersNotifier, ProfessionalSearchFilters>(() {
  return ProfessionalSearchFiltersNotifier();
});

final recommendedProfessionalsProvider = FutureProvider<List<ProfessionalListing>>((ref) async {
  final ds = ref.watch(professionalsRemoteDatasourceProvider);
  final filters = ref.watch(professionalSearchFiltersProvider);
  return ds.fetchRecommended(
    limit: filters.limit,
    query: filters.query,
    location: filters.location,
    categoryId: filters.categoryId,
    maxDistanceKm: filters.maxDistanceKm,
    availability: filters.availability,
    minRating: filters.minRating,
    latitude: filters.latitude,
    longitude: filters.longitude,
    interventionDate: filters.interventionDate,
  );
});

class ClientRecommendationCategoryNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void setCategory(int? categoryId) => state = categoryId;
}

final clientRecommendationCategoryProvider = NotifierProvider<ClientRecommendationCategoryNotifier, int?>(
  ClientRecommendationCategoryNotifier.new,
);

final allProfessionalsProvider = FutureProvider<List<ProfessionalListing>>((ref) async {
  final ds = ref.watch(professionalsRemoteDatasourceProvider);
  final categoryId = ref.watch(clientRecommendationCategoryProvider);
  return ds.fetchRecommended(limit: 100, categoryId: categoryId);
});
