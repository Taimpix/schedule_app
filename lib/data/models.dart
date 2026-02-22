class Group {
  final int id;
  final String name;
  final String faculty;
  final String direction;
  final String level;

  const Group({
    required this.id,
    required this.name,
    required this.faculty,
    required this.direction,
    required this.level,
  });

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json['id'] as int,
    name: json['name'] as String,
    faculty: json['faculty'] as String,
    direction: json['direction'] as String,
    level: json['level'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'faculty': faculty,
    'direction': direction,
    'level': level,
  };
}

class Teacher {
  final int id;
  final String name;

  const Teacher({required this.id, required this.name});

  factory Teacher.fromJson(Map<String, dynamic> json) => Teacher(
    id: json['id'] as int,
    name: json['name'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}