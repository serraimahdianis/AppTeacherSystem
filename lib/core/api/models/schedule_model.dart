class Schedule {
  final String id;
  final String moduleName;
  final String groupName;
  final String type;
  final String year;
  final String room;
  final String dayOfWeek; // String like "Monday"
  final String startTime; // Time string like "08:00"
  final String endTime; // Time string like "09:30"
  final String teacherId;
  final String? speciality;

  Schedule({
    required this.id,
    required this.moduleName,
    required this.groupName,
    required this.type,
    required this.year,
    required this.room,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.teacherId,
    this.speciality,
  });

  int get dayOfWeekInt {
    final day = dayOfWeek.toLowerCase();
    if (day.contains('mon')) return 1;
    if (day.contains('tue')) return 2;
    if (day.contains('wed')) return 3;
    if (day.contains('thu')) return 4;
    if (day.contains('fri')) return 5;
    if (day.contains('sat')) return 6;
    return int.tryParse(dayOfWeek) ?? 1;
  }

  String get dayName => switch (dayOfWeekInt) {
    1 => 'Monday',
    2 => 'Tuesday',
    3 => 'Wednesday',
    4 => 'Thursday',
    5 => 'Friday',
    6 => 'Saturday',
    _ => 'Unknown',
  };

  factory Schedule.fromJson(Map<String, dynamic> json) {
    // Handle moduleName - could be string or object {name: ...}
    String parseModuleName() {
      final value = json['moduleId'] ?? json['module'] ?? json['moduleName'] ?? json['module_name'];
      if (value is String) return value;
      if (value is Map) return value['name']?.toString() ?? value['moduleName']?.toString() ?? value['_id']?.toString() ?? '';
      return '';
    }

    // Handle groupName - could be string or object
    String parseGroupName() {
      final value = json['group'] ?? json['groupName'] ?? json['group_name'];
      if (value is String) return value;
      if (value is Map) return value['name']?.toString() ?? value['groupName']?.toString() ?? '';
      return '';
    }

    // Handle type - could be string "TD" or object
    String parseType() {
      final value = json['type'];
      if (value is String) return value;
      if (value is Map) return value['name']?.toString() ?? value['type']?.toString() ?? 'cours';
      return 'cours';
    }

    // Handle room - could be string or object
    String parseRoom() {
      final value = json['room'];
      if (value is String) return value;
      if (value is Map) return value['name']?.toString() ?? value['room']?.toString() ?? '';
      return '';
    }

    // Handle dayOfWeek - backend sends string "Monday" etc. or could be number
    String parseDayOfWeek() {
      final value = json['dayOfWeek'] ?? json['day_of_week'];
      if (value is String) return value;
      if (value is int) return '$value';
      return 'Monday';
    }

    // Handle teacherId - could be string or object
    String parseTeacherId() {
      final value = json['teacherId'] ?? json['teacher_id'] ?? json['teacher'];
      if (value is String) return value;
      if (value is Map) return value['_id']?.toString() ?? value['id']?.toString() ?? '';
      return '';
    }

    // Year is on the module; fall back to moduleId populated object if schedule lacks it
    String parseYear() {
      final directYear = json['year']?.toString();
      if (directYear != null && directYear.isNotEmpty) return directYear;
      final moduleObj = json['moduleId'];
      if (moduleObj is Map) {
        return moduleObj['year']?.toString() ?? '';
      }
      return '';
    }

    return Schedule(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      moduleName: parseModuleName(),
      groupName: parseGroupName(),
      type: parseType(),
      year: parseYear(),
      room: parseRoom(),
      dayOfWeek: parseDayOfWeek(),
      startTime: (json['startTime'] ?? json['start_time'])?.toString() ?? '',
      endTime: (json['endTime'] ?? json['end_time'])?.toString() ?? '',
      teacherId: parseTeacherId(),
      speciality: json['speciality']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'moduleName': moduleName,
      'groupName': groupName,
      'type': type,
      'year': year,
      'room': room,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'teacherId': teacherId,
      'speciality': speciality,
    };
  }
}
