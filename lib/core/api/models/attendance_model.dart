import 'dart:convert';

enum AttendanceStatus { present, absent, late }

class Attendance {
  final String id;
  final String studentId;
  final String sessionId;
  final AttendanceStatus status;
  final DateTime timestamp;
  final String? notes;

  Attendance({
    required this.id,
    required this.studentId,
    required this.sessionId,
    required this.status,
    required this.timestamp,
    this.notes,
  });

  String get statusString => switch (status) {
    AttendanceStatus.present => 'Present',
    AttendanceStatus.absent => 'Absent',
    AttendanceStatus.late => 'Late',
  };

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) return value['name']?.toString() ?? value['_id']?.toString() ?? value['id']?.toString() ?? value.toString();
    return value.toString();
  }

  factory Attendance.fromJson(Map<String, dynamic> json) {
    // Handle _JsonMap type from web - ensure proper type conversion
    final data = _ensureMap(json);

    return Attendance(
      id: _parseString(data['id'] ?? data['_id']),
      studentId: _parseString(data['studentId'] ?? data['student_id']),
      sessionId: _parseString(data['sessionId'] ?? data['session_id']),
      status: _parseStatus(data['status']),
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] is DateTime
              ? data['timestamp']
              : DateTime.parse(data['timestamp'].toString()))
          : DateTime.now(),
      notes: data['notes']?.toString(),
    );
  }

  static AttendanceStatus _parseStatus(dynamic status) {
    if (status == null) return AttendanceStatus.absent;
    final statusStr = status.toString().toLowerCase();
    if (statusStr.contains('late')) return AttendanceStatus.late;
    if (statusStr.contains('present')) return AttendanceStatus.present;
    return AttendanceStatus.absent;
  }

  // Helper to ensure proper Map<String, dynamic> type for web compatibility
  static Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    // If it's a JSON string, decode it
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    // Otherwise, re-encode and decode to fix web _JsonMap issues
    return jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'sessionId': sessionId,
      'status': statusString,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
    };
  }
}

class AttendanceRecord {
  final String studentId;
  final String studentName;
  final AttendanceStatus status;
  final DateTime? timestamp;

  AttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.status,
    this.timestamp,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    // Handle _JsonMap type from web - ensure proper type conversion
    final data = Attendance._ensureMap(json);

    return AttendanceRecord(
      studentId: Attendance._parseString(data['studentId'] ?? data['student_id']),
      studentName: Attendance._parseString(data['studentName'] ?? data['student_name']),
      status: Attendance._parseStatus(data['status']),
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] is DateTime
              ? data['timestamp']
              : DateTime.parse(data['timestamp'].toString()))
          : null,
    );
  }

  // Removed duplicate _parseStatus - using Attendance._parseStatus instead
}
