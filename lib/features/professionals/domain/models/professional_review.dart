class ProfessionalReview {
  const ProfessionalReview({required this.id, required this.rating, this.comment, this.createdAt, this.bookingDescription, this.reviewerName});

  final int id;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final String? bookingDescription;
  final String? reviewerName;

  factory ProfessionalReview.fromMap(Map<String, dynamic> map) {
    return ProfessionalReview(
      id: (map['id'] is int) ? map['id'] as int : int.tryParse(map['id']?.toString() ?? '') ?? 0,
      rating: (map['rating'] is int)
          ? map['rating'] as int
          : (map['rating'] is num)
          ? (map['rating'] as num).toInt()
          : int.tryParse(map['rating']?.toString() ?? '') ?? 0,
      comment: map['comment']?.toString().trim(),
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
      bookingDescription: map['bookingDescription']?.toString().trim(),
      reviewerName: map['reviewerName']?.toString().trim(),
    );
  }
}

class ProfessionalReviewsSummary {
  const ProfessionalReviewsSummary({required this.success, this.message, required this.averageRating, required this.totalReviews, required this.reviews});

  final bool success;
  final String? message;
  final double averageRating;
  final int totalReviews;
  final List<ProfessionalReview> reviews;

  factory ProfessionalReviewsSummary.fromMap(Map<String, dynamic> map) {
    final rawReviews = map['reviews'];
    final reviewsList = <ProfessionalReview>[];
    if (rawReviews is List) {
      for (final item in rawReviews) {
        if (item is Map) {
          reviewsList.add(ProfessionalReview.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final avgRaw = map['averageRating'] ?? map['avgRating'] ?? map['rating'];
    final avgRating = avgRaw != null ? (double.tryParse(avgRaw.toString()) ?? 0.0) : 0.0;

    final totalRaw = map['totalReviews'] ?? map['count'] ?? reviewsList.length;
    final totalCount = totalRaw != null ? (int.tryParse(totalRaw.toString()) ?? reviewsList.length) : reviewsList.length;

    return ProfessionalReviewsSummary(
      success: map['success'] == true || map['success'] == null,
      message: map['message']?.toString(),
      averageRating: avgRating,
      totalReviews: totalCount,
      reviews: reviewsList,
    );
  }
}
