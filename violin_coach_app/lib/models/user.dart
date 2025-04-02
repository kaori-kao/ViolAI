enum UserRole { student, teacher }

class User {
  final String id;
  final String username;
  final String email;
  final String name;
  final UserRole role;
  final DateTime createdAt;
  
  bool get isTeacher => role == UserRole.teacher;
  bool get isStudent => role == UserRole.student;
  
  User({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      name: json['name'] ?? json['username'],
      role: UserRole.values.firstWhere(
        (r) => r.toString() == 'UserRole.${json['role']}',
        orElse: () => UserRole.student,
      ),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'name': name,
      'role': role.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  User copyWith({
    String? id,
    String? username,
    String? email,
    String? name,
    UserRole? role,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  
  @override
  String toString() {
    return 'User(id: $id, username: $username, name: $name, role: $role)';
  }
}