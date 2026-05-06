import 'dart:convert';

enum SessionType { cours, td, tp }

enum SessionStatus { planned, inProgress, completed }

class Session {
  final String id;
  final String? scheduleId;
  final String moduleName;
  final String groupName;
  final SessionType type;
  final String room;
  final DateTime startTime;
  final DateTime endTime;
  final SessionStatus status;
  final String teacherId;
  final int presentCount;
  final int totalStudents;
  final DateTime createdAt;

  Session({
    required this.id,
    this.scheduleId,
    required this.moduleName,
    required this.groupName,
    required this.type,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.teacherId,
    this.presentCount = 0,
    this.totalStudents = 0,
    required this.createdAt,
  });

  String get typeString => switch (type) {
    SessionType.cours => 'Cours',
    SessionType.td => 'TD',
    SessionType.tp => 'TP',
  };

  String get statusString => switch (status) {
    SessionStatus.planned => 'Planned',
    SessionStatus.inProgress => 'In Progress',
    SessionStatus.completed => 'Completed',
  };

  String get timeRange {
    final start = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final end = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  // Helper to safely convert any value to String (handles _JsonMap from web)
  static String _toString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) return value['_id']?.toString() ?? value['id']?.toString() ?? value.toString();
    return value.toString();
  }

  // Helper to ensure proper Map<String, dynamic> type for web compatibility
  static Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    return jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }

  // Helper to parse DateTime from various web types
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        // Try parsing as time only "HH:MM"
        try {
          final parts = value.split(':');
          if (parts.length >= 2) {
            return DateTime(2024, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
          }
        } catch (e) {
          // Ignore
        }
        return DateTime.now();
      }
    }
    // Handle _JsonMap or other types from web
    try {
      final str = value.toString();
      return DateTime.parse(str);
    } catch (e) {
      return DateTime.now();
    }
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    // First, ensure proper map type for web compatibility
    final data = _ensureMap(json);

    // Handle moduleName - could be string or object {name: ...}
    String parseModuleName() {
      final value = data['module'] ?? data['moduleName'] ?? data['module_name'];
      return _toString(value);
    }

    // Handle groupName - could be string or object
    String parseGroupName() {
      final value = data['group'] ?? data['groupName'] ?? data['group_name'];
      return _toString(value);
    }

    // Handle type - could be string "TD" or object
    SessionType parseSessionType(dynamic type) {
      if (type == null) return SessionType.cours;
      final typeStr = type.toString().toLowerCase();
      if (typeStr.contains('td')) return SessionType.td;
      if (typeStr.contains('tp')) return SessionType.tp;
      if (typeStr.contains('cours')) return SessionType.cours;
      return SessionType.cours;
    }

    // Handle status - mapped from Swagger ["planned", "active", "closed"]
    SessionStatus parseSessionStatus(dynamic status) {
      if (status == null) return SessionStatus.planned;
      final statusStr = status.toString().toLowerCase();
      if (statusStr == 'active' || statusStr.contains('progress')) return SessionStatus.inProgress;
      if (statusStr == 'closed' || statusStr.contains('completed')) return SessionStatus.completed;
      if (statusStr == 'planned') return SessionStatus.planned;
      return SessionStatus.planned;
    }

    // Handle teacherId - could be string or object
    String parseTeacherId() {
      final value = data['teacherId'] ?? data['teacher_id'] ?? data['teacher'];
      return _toString(value);
    }

    // Handle scheduleId - could be string or null
    String? parseScheduleId() {
      final value = data['scheduleId'] ?? data['schedule_id'];
      if (value == null) return null;
      return _toString(value);
    }

    // Handle room - could be string or object
    String parseRoom() {
      final value = data['room'];
      return _toString(value);
    }

    return Session(
      id: _toString(data['id'] ?? data['_id']),
      scheduleId: parseScheduleId(),
      moduleName: parseModuleName(),
      groupName: parseGroupName(),
      type: parseSessionType(data['type']),
      room: parseRoom(),
      startTime: _parseDateTime(data['startTime']),
      endTime: _parseDateTime(data['endTime']),
      status: parseSessionStatus(data['status']),
      teacherId: parseTeacherId(),
      presentCount: data['presentCount'] ?? data['present_count'] ?? 0,
      totalStudents: data['totalStudents'] ?? data['total_students'] ?? 0,
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheduleId': scheduleId,
      'moduleName': moduleName,
      'groupName': groupName,
      'type': typeString,
      'room': room,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'status': statusString,
      'teacherId': teacherId,
      'presentCount': presentCount,
      'totalStudents': totalStudents,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
