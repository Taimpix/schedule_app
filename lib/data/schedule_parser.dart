import 'models.dart';

/// Парсер HTML-страницы расписания zukl.ru.
/// Сайт отдаёт таблицу вида:
///   <table class="schedule"> ... </table>
/// Каждая строка — одна пара. Столбцы зависят от конкретной страницы,
/// поэтому парсер старается найти данные эвристически.
class ScheduleParser {
  ScheduleParser._();

  static List<ScheduleDay> parseHtml(String html) {
    try {
      return _parseByTable(html);
    } catch (e) {
      return [];
    }
  }

  // ── Основной проход по таблицам ──────────────────────────────────
  static List<ScheduleDay> _parseByTable(String html) {
    final days = <ScheduleDay>[];

    // Ищем все блоки, обозначающие день
    // Заголовки дней обычно: <h3>, <th colspan=...>, или отдельная строка с классом "day"
    // Разбиваем HTML по разделителям дней
    final dayBlocks = _splitByDays(html);

    for (final block in dayBlocks) {
      final dayName = _extractDayName(block.$1);
      final date    = _extractDate(block.$1);
      final lessons = _extractLessons(block.$2);

      if (lessons.isNotEmpty || dayName.isNotEmpty) {
        days.add(ScheduleDay(date: date, dayName: dayName, lessons: lessons));
      }
    }

    return days;
  }

  // ── Разбивка на блоки дней ───────────────────────────────────────
  static List<(String header, String body)> _splitByDays(String html) {
    final result = <(String, String)>[];

    // Паттерн: ищем что-то похожее на заголовок дня
    // Поддерживаем: <tr class="...day...">, <h2>, <h3>, <td class="...day...">
    final dayHeaderPattern = RegExp(
      r'(<(?:h[123]|tr[^>]*(?:day|date|weekday)[^>]*|td[^>]*(?:day|date|weekday)[^>]*)[^>]*>.*?</(?:h[123]|tr|td)>)',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = dayHeaderPattern.allMatches(html).toList();

    if (matches.isEmpty) {
      // Нет явных заголовков — весь HTML как один день
      result.add(('', html));
      return result;
    }

    for (int i = 0; i < matches.length; i++) {
      final header = matches[i].group(0) ?? '';
      final start  = matches[i].end;
      final end    = i + 1 < matches.length ? matches[i + 1].start : html.length;
      final body   = html.substring(start, end);
      result.add((header, body));
    }

    return result;
  }

  // ── Извлечь название дня ─────────────────────────────────────────
  static String _extractDayName(String header) {
    if (header.isEmpty) return '';
    final text = _stripTags(header).trim();
    // Убираем дату если она есть рядом
    final dateRemoved = text.replaceAll(RegExp(r'\d{1,2}[./]\d{1,2}([./]\d{2,4})?'), '').trim();
    return dateRemoved.isNotEmpty ? dateRemoved : text;
  }

  // ── Извлечь дату из заголовка ────────────────────────────────────
  static String _extractDate(String header) {
    final match = RegExp(r'(\d{4}-\d{2}-\d{2}|\d{1,2}[./]\d{1,2}[./]\d{2,4})')
        .firstMatch(header);
    return match?.group(0) ?? '';
  }

  // ── Извлечь пары из тела блока ───────────────────────────────────
  static List<Lesson> _extractLessons(String body) {
    final lessons = <Lesson>[];

    // Ищем строки таблицы
    final rowPattern = RegExp(r'<tr[^>]*>(.*?)</tr>', caseSensitive: false, dotAll: true);
    final rows = rowPattern.allMatches(body).toList();

    for (final row in rows) {
      final rowHtml = row.group(1) ?? '';

      // Ячейки: td или th
      final cellPattern = RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>', caseSensitive: false, dotAll: true);
      final cells = cellPattern.allMatches(rowHtml)
          .map((m) => _stripTags(m.group(1) ?? '').trim())
          .where((c) => c.isNotEmpty)
          .toList();

      if (cells.length < 2) continue;

      // Пытаемся извлечь данные эвристически
      final lesson = _parseRow(cells);
      if (lesson != null) lessons.add(lesson);
    }

    return lessons;
  }

  // ── Эвристический разбор строки ─────────────────────────────────
  static Lesson? _parseRow(List<String> cells) {
    // Ищем ячейку с временем: "08:30", "8:30 – 10:00", "08.30-09.50"
    final timeRe = RegExp(r'(\d{1,2})[:.]\d{2}');

    String timeStart = '';
    String timeEnd   = '';
    String subject   = '';
    String teacher   = '';
    String room      = '';
    String type      = '';

    // Сначала ищем явное время
    for (int i = 0; i < cells.length; i++) {
      final cell = cells[i];
      final times = timeRe.allMatches(cell).toList();
      if (times.length >= 2) {
        // "08:30 – 10:00" или "08:30-10:00"
        final parts = cell.split(RegExp(r'[–—-]'));
        timeStart = _cleanTime(parts.first);
        timeEnd   = _cleanTime(parts.length > 1 ? parts.last : '');
        continue;
      }
      if (times.length == 1 && timeStart.isEmpty) {
        timeStart = _cleanTime(cell);
        continue;
      }
    }

    // Если нет времени — вероятно не строка с парой
    if (timeStart.isEmpty) return null;

    // Остальные ячейки распределяем по смыслу
    for (final cell in cells) {
      if (cell == timeStart || cell == timeEnd) continue;
      if (cell.contains(RegExp(r'\d{1,2}[:.]\d{2}'))) continue;

      // Кабинет: короткий, содержит цифры или слово "зал", "аудитор"
      if (room.isEmpty &&
          cell.length < 20 &&
          RegExp(r'\d').hasMatch(cell)) {
        room = cell;
        continue;
      }

      // Тип пары: 'лек', 'пр', 'лаб' и т.д.
      if (type.isEmpty &&
          RegExp(r'^(лекц|практ|лаб|семин|конс|экз|зач)', caseSensitive: false)
              .hasMatch(cell)) {
        type = cell;
        continue;
      }

      // Преподаватель: содержит заглавную букву с точкой (инициалы) или длинное слово
      if (teacher.isEmpty &&
          RegExp(r'[А-ЯA-Z][а-яa-z]{2,}\s+[А-ЯA-Z]').hasMatch(cell)) {
        teacher = cell;
        continue;
      }

      // Остальное — название предмета (берём самую длинную ячейку)
      if (cell.length > subject.length) {
        subject = cell;
      }
    }

    if (subject.isEmpty) return null;

    return Lesson(
      timeStart: timeStart,
      timeEnd:   timeEnd,
      subject:   subject,
      teacher:   teacher,
      room:      room,
      type:      type,
    );
  }

  // ── Вспомогательные ─────────────────────────────────────────────
  static String _stripTags(String html) =>
      html.replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .trim();

  static String _cleanTime(String s) {
    final m = RegExp(r'(\d{1,2})[:.]\d{2}').firstMatch(s.trim());
    if (m == null) return '';
    // Нормализуем к HH:MM
    return s.trim()
        .replaceAll(RegExp(r'[^\d:]'), '')
        .replaceFirst('.', ':');
  }
}