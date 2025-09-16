class Profile {
  final String id;          // uuid (auth.users.id)
  final String email;
  final String? username;
  final String role;        // 'boss' | 'employee'

  Profile({required this.id, required this.email, this.username, required this.role});

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'username': username,
    'role': role,
  };

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
    id: m['id'] as String,
    email: m['email'] as String,
    username: m['username'] as String?,
    role: m['role'] as String,
  );
}