class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.profilePictureUrl,
  });

  final String id;
  final String? name;
  final String email;
  final String role; // 'admin' | 'member'
  final String? profilePictureUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      profilePictureUrl: json['profile_picture_url'] as String?,
    );
  }
}

