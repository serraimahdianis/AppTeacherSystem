import 'dart:convert';

enum SessionType { cours, td, tp }

enum SessionStatus { planned, inProgress, completed, canceled }

class Session {
  final String id;
  final String? scheduleId;
  final String moduleName;
  final String groupName;
  final SessionType type;
  final String room;
  final DateTime date;
  final String startTimeStr;
  final String endTimeStr;
  final SessionStatus status;
  final String teacherId;
  final int presentCount;
  final int totalStudents;
  final bool isReplacement;
  final String? reasonForReplacement;
  final String year;
  final DateTime createdAt;
  final String? speciality;

  Session({
    required this.id,
    this.scheduleId,
    required this.moduleName,
    required this.groupName,
    required this.type,
    required this.room,
    required this.date,
    required this.startTimeStr,
    required this.endTimeStr,
    required this.status,
    required this.teacherId,
    this.presentCount = 0,
    this.totalStudents = 0,
    this.isReplacement = false,
    this.reasonForReplacement,
    this.year = '',
    required this.createdAt,
    this.speciality,
  });

  DateTime get startTime {
    final parts = startTimeStr.split(':');
    return DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  DateTime get endTime {
    final parts = endTimeStr.split(':');
    return DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  String get typeString => switch (type) {
    SessionType.cours => 'Cours',
    SessionType.td => 'TD',
    SessionType.tp => 'TP',
  };

  String get statusString => switch (status) {
    SessionStatus.planned => 'Planned',
    SessionStatus.inProgress => 'In Progress',
    SessionStatus.completed => 'Completed',
    SessionStatus.canceled => 'Canceled',
  };

  String get timeRange => '$startTimeStr - $endTimeStr';

  static String _toString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      // Prefer human-readable name field over ID
      final name = value['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
      return value['_id']?.toString() ?? value['id']?.toString() ?? value.toString();
    }
    return value.toString();
  }

  static Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    return jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    final data = _ensureMap(json);

    String parseModuleName() {
      final value = data['moduleId'] ?? data['module'] ?? data['moduleName'] ?? data['module_name'];
      return _toString(value);
    }

    String parseGroupName() {
      final value = data['group'] ?? data['groupName'] ?? data['group_name'];
      return _toString(value);
    }

    SessionType parseSessionType(dynamic type) {
      if (type == null) return SessionType.cours;
      final typeStr = type.toString().toLowerCase();
      if (typeStr.contains('td')) return SessionType.td;
      if (typeStr.contains('tp')) return SessionType.tp;
      if (typeStr.contains('cours')) return SessionType.cours;
      return SessionType.cours;
    }

    SessionStatus parseSessionStatus(dynamic status) {
      if (status == null) return SessionStatus.planned;
      final statusStr = status.toString().toLowerCase();
      if (statusStr == 'active' || statusStr.contains('progress')) return SessionStatus.inProgress;
      if (statusStr == 'closed' || statusStr.contains('completed')) return SessionStatus.completed;
      if (statusStr == 'canceled' || statusStr.contains('cancelled')) return SessionStatus.canceled;
      if (statusStr == 'planned') return SessionStatus.planned;
      return SessionStatus.planned;
    }

    String parseTeacherId() {
      final value = data['teacherId'] ?? data['teacher_id'] ?? data['teacher'];
      return _toString(value);
    }

    String? parseScheduleId() {
      final value = data['scheduleId'] ?? data['schedule_id'];
      if (value == null) return null;
      // Could be a populated object or just a string ID
      if (value is Map) return value['_id']?.toString() ?? value['id']?.toString();
      return _toString(value);
    }

    String parseRoom() {
      // room is on the schedule, not the session itself
      final scheduleObj = data['scheduleId'];
      if (scheduleObj is Map) {
        final r = scheduleObj['room']?.toString();
        if (r != null && r.isNotEmpty) return r;
      }
      final value = data['room'];
      return _toString(value);
    }

    final sessionDate = _parseDate(data['date']);

    return Session(
      id: _toString(data['id'] ?? data['_id']),
      scheduleId: parseScheduleId(),
      moduleName: parseModuleName(),
      groupName: parseGroupName(),
      type: parseSessionType(data['type']),
      room: parseRoom(),
      date: sessionDate,
      startTimeStr: data['startTime']?.toString() ?? '00:00',
      endTimeStr: data['endTime']?.toString() ?? '00:00',
      status: parseSessionStatus(data['status']),
      teacherId: parseTeacherId(),
      presentCount: data['presentCount'] ?? data['present_count'] ?? 0,
      totalStudents: data['totalStudents'] ?? data['total_students'] ?? 0,
      isReplacement: data['isReplacement'] == true || data['isReplacement'] == 'true',
      reasonForReplacement: data['reasonForReplacement']?.toString(),
      year: () {
        // Year is not on session schema — comes from the module
        if (data['year'] != null && data['year'].toString().isNotEmpty) return data['year'].toString();
        final moduleObj = data['moduleId'];
        if (moduleObj is Map) return moduleObj['year']?.toString() ?? '';
        return '';
      }(),
      createdAt: _parseDate(data['createdAt']),
      speciality: data['speciality']?.toString(),
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
      'date': date.toIso8601String(),
      'startTime': startTimeStr,
      'endTime': endTimeStr,
      'status': statusString,
      'teacherId': teacherId,
      'presentCount': presentCount,
      'totalStudents': totalStudents,
      'isReplacement': isReplacement,
      'year': year,
      'createdAt': createdAt.toIso8601String(),
      'speciality': speciality,
    };
  }
}
