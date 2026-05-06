class Student {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String group;
  final String? studentId;
  final String? year;
  final String? speciality;
  final double attendanceRate;
  final String? profileImage;
  final DateTime createdAt;

  Student({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    required this.group,
    this.studentId,
    this.year,
    this.speciality,
    this.attendanceRate = 0.0,
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

  factory Student.fromJson(Map<String, dynamic> json) {
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

    return Student(
      id: _parseString(json['id'] ?? json['_id']),
      email: _parseString(json['email']),
      firstName: firstName,
      lastName: lastName,
      phone: json['phone']?.toString(),
      group: _parseString(json['group'] ?? json['groupName']),
      studentId: json['studentId']?.toString() ?? json['student_id']?.toString(),
      year: json['year']?.toString(),
      speciality: json['speciality']?.toString(),
      attendanceRate: (json['attendanceRate'] ?? json['attendance_rate'] ?? 0).toDouble(),
      profileImage: json['profileImage']?.toString() ?? json['profile_image']?.toString(),
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
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
      'group': group,
      'studentId': studentId,
      'year': year,
      'speciality': speciality,
      'attendanceRate': attendanceRate,
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}