import 'provider_profile.dart';

/// App user model stored in Firestore and used after login.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.username,
    required this.role,
    required this.createdAt,
    this.updatedAt,
    this.phone,
    this.city,
    this.profilePhotoUrl,
    this.providerProfile,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? username;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? phone;
  final String? city;

  /// Client profile image from API (e.g. GET /users/me/profile).
  final String? profilePhotoUrl;

  /// Present when [role] is [UserRole.provider]; stores full profile setup data.
  final ProviderProfile? providerProfile;

  bool get isProvider => role == UserRole.provider;
  bool get isClient => role == UserRole.client;

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'uid': uid,
      'email': email,
      'displayName': displayName,
      if (username != null) 'username': username,
      'role': role.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      if (phone != null) 'phone': phone,
      if (city != null) 'city': city,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
    };
    if (providerProfile != null) {
      data['providerProfile'] = providerProfile!.toMap();
    }
    return data;
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final role = UserRole.fromString(map['role'] as String?);
    ProviderProfile? providerProfile;
    if (role == UserRole.provider && map['providerProfile'] != null) {
      providerProfile = ProviderProfile.fromMap(map['providerProfile'] as Map<String, dynamic>?);
    }
    return AppUser(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String? ?? '',
      username: map['username'] as String?,
      role: role,
      createdAt: map['createdAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int) : null,
      phone: map['phone'] as String?,
      city: map['city'] as String?,
      profilePhotoUrl: map['profilePhotoUrl'] as String?,
      providerProfile: providerProfile,
    );
  }
}

enum UserRole {
  client,
  provider;

  static UserRole fromString(String? value) {
    if (value == 'provider') return UserRole.provider;
    return UserRole.client;
  }
}
