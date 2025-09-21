class Profile {
  final String id; // uuid (auth.users.id)
  final String email;
  final String? username;
  final String? displayName;
  final String role; // 'boss' | 'employee'

  Profile({
    required this.id,
    required this.email,
    this.username,
    this.displayName,
    required this.role,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'username': username,
    'display_name': displayName,
    'role': role,
  };

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
    id: m['id'] as String,
    email: m['email'] as String,
    username: m['username'] as String?,
    displayName: m['display_name'] as String?,
    role: m['role'] as String,
  );
}
