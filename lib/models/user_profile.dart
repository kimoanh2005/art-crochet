class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.email,
    this.bio = '',
  });

  final String displayName;
  final String email;
  final String bio;

  String get initial {
    final value = displayName.trim();
    return value.isEmpty ? '?' : value[0].toUpperCase();
  }

  UserProfile copyWith({String? displayName, String? email, String? bio}) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      bio: bio ?? this.bio,
    );
  }
}
