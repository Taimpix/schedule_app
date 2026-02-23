// ── Group ──────────────────────────────────────────────────────────

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

// ── Teacher ────────────────────────────────────────────────────────

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

// ── Lesson ─────────────────────────────────────────────────────────

class Lesson {
  final String timeStart;
  final String timeEnd;
  final String subject;
  final String teacher;
  final String room;
  final String type;

  const Lesson({
    required this.timeStart,
    required this.timeEnd,
    required this.subject,
    required this.teacher,
    required this.room,
    this.type = '',
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    // Парсим time: '10:40-12:10' → start='10:40', end='12:10'
    // или '9:00' → start='9:00', end=''
    final rawTime = (json['time'] ?? '') as String;
    final timeParts = rawTime.split(RegExp(r'[-–—]'));
    final timeStart = timeParts.isNotEmpty ? timeParts[0].trim() : '';
    final timeEnd   = timeParts.length > 1  ? timeParts[1].trim() : '';

    return Lesson(
      timeStart: timeStart,
      timeEnd:   timeEnd,
      subject:   (json['name']      ?? json['subject'] ?? '') as String,
      teacher:   (json['teacher']   ?? '') as String,
      room:      (json['classroom'] ?? json['room']    ?? '') as String,
      type:      (json['type']      ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'time_start': timeStart,
    'time_end':   timeEnd,
    'subject':    subject,
    'teacher':    teacher,
    'room':       room,
    'type':       type,
  };
}


// ── ScheduleDay ────────────────────────────────────────────────────

class ScheduleDay {
  final String date;
  final String dayName;
  final List<Lesson> lessons;

  const ScheduleDay({
    required this.date,
    required this.dayName,
    required this.lessons,
  });

  factory ScheduleDay.fromJson(Map<String, dynamic> json) => ScheduleDay(
    date:    (json['date']     ?? '') as String,
    dayName: (json['day_name'] ?? json['dayName'] ?? '') as String,
    lessons: (json['lessons'] as List<dynamic>? ?? [])
        .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'date':     date,
    'day_name': dayName,
    'lessons':  lessons.map((l) => l.toJson()).toList(),
  };
}