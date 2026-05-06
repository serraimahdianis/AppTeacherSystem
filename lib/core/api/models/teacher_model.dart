class Teacher {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? department;
  final String? profileImage;
  final DateTime createdAt;

  Teacher({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.department,
    this.profileImage,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) return value['name']?.toString() ?? value['_id']?.toString() ?? value['id']?.toString() ?? value.toString();
    return value.toString();
  }

  factory Teacher.fromJson(Map<String, dynamic> json) {
    String firstName = _parseString(json['firstName'] ?? json['first_name']);
    String lastName = _parseString(json['lastName'] ?? json['last_name']);
    final fullName = _parseString(json['fullName'] ?? json['full_name']);

    if ((firstName.isEmpty || lastName.isEmpty) && fullName.isNotEmpty) {
      final parts = fullName.split(' ');
      if (parts.length >= 2) {
        firstName = parts[0];
        lastName = parts.sublist(1).join(' ');
      } else {
        firstName = fullName;
        lastName = '';
      }
    }

    return Teacher(
      id: _parseString(json['id'] ?? json['_id']),
      email: _parseString(json['email']),
      firstName: firstName,
      lastName: lastName,
      phone: json['phone']?.toString(),
      department: json['department'] != null ? _parseString(json['department']) : null,
      profileImage: json['profileImage']?.toString() ?? json['profile_image']?.toString(),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString()) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'department': department,
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class LoginResponse {
  final String token;
  final Teacher teacher;

  LoginResponse({required this.token, required this.teacher});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] ?? json['accessToken'] ?? json['access_token'] ?? '',
      teacher: Teacher.fromJson(json['teacher'] ?? json['user'] ?? json['teacher'] ?? {}),
    );
  }
}