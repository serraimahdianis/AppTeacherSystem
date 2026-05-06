class Module {
  final String id;
  final String name;
  final String teacherId;
  final String year;

  Module({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.year,
  });

  factory Module.fromJson(Map<String, dynamic> json) {
    // Handle teacherId - could be string or object
    String parseTeacherId() {
      final value = json['teacherId'] ?? json['teacher_id'] ?? json['teacher'];
      if (value is String) return value;
      if (value is Map) return value['_id']?.toString() ?? value['id']?.toString() ?? '';
      return '';
    }

    String parseString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is Map) return value['name']?.toString() ?? value['_id']?.toString() ?? value['id']?.toString() ?? value.toString();
      return value.toString();
    }

    return Module(
      id: parseString(json['id'] ?? json['_id']),
      name: parseString(json['name']),
      teacherId: parseTeacherId(),
      year: json['year']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'teacherId': teacherId,
      'year': year,
    };
  }

  @override
  String toString() => '$name ($year)';
}
