import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/schedule_repository.dart';
import '../data/models.dart';

// ── Утилиты дат (дублируем из schedule_page) ─────────────────────

const _kMonthsT = [
  '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];

const _kWeekdaysT = [
  '', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница',
  'Суббота', 'Воскресенье',
];

const _kMonthsNomT = {
  'января': 1, 'февраля': 2, 'марта': 3, 'апреля': 4,
  'мая': 5, 'июня': 6, 'июля': 7, 'августа': 8,
  'сентября': 9, 'октября': 10, 'ноября': 11, 'декабря': 12,
};

const _kWeekdayIndexT = {
  'понедельник': 1, 'вторник': 2, 'среда': 3, 'среду': 3,
  'четверг': 4, 'пятница': 5, 'пятницу': 5,
  'суббота': 6, 'субботу': 6, 'воскресенье': 7,
};

String _fmtDateT(DateTime d) =>
    '${d.day} ${_kMonthsT[d.month]} ${d.year}';

String _weekdayT(DateTime d) => _kWeekdaysT[d.weekday];

DateTime _dateOnlyT(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime? _parseAnyDateT(String raw) {
  if (raw.isEmpty) return null;
  final s = raw.trim();
  try {
    final iso = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(s);
    if (iso != null) return _dateOnlyT(DateTime.parse(iso.group(1)!));
    final dmy = RegExp(r'(\d{1,2})[./](\d{1,2})[./](\d{4})').firstMatch(s);
    if (dmy != null) {
      return _dateOnlyT(DateTime(
        int.parse(dmy.group(3)!),
        int.parse(dmy.group(2)!),
        int.parse(dmy.group(1)!),
      ));
    }
    final rus = RegExp(
      r'(\d{1,2})\s+([а-яё]+)(?:\s+(\d{4}))?',
      caseSensitive: false,
    ).firstMatch(s);
    if (rus != null) {
      final day   = int.parse(rus.group(1)!);
      final month = _kMonthsNomT[rus.group(2)!.toLowerCase()];
      if (month != null) {
        final year = rus.group(3) != null
            ? int.parse(rus.group(3)!)
            : DateTime.now().year;
        return _dateOnlyT(DateTime(year, month, day));
      }
    }
  } catch (_) {}
  return null;
}

Map<DateTime, ScheduleDay> _buildDateMapT(List<ScheduleDay> days) {
  final map = <DateTime, ScheduleDay>{};
  for (final day in days) {
    DateTime? dt = _parseAnyDateT(day.date);
    dt ??= _parseAnyDateT(day.dayName);
    if (dt != null) map[dt] = day;
  }
  if (map.isEmpty) {
    final monday = _dateOnlyT(DateTime.now())
        .subtract(Duration(days: DateTime.now().weekday - 1));
    for (final day in days) {
      final text = (day.dayName + ' ' + day.date).toLowerCase();
      final wdIdx = _kWeekdayIndexT.entries
          .where((e) => text.contains(e.key))
          .map((e) => e.value)
          .firstOrNull;
      if (wdIdx != null) {
        map[monday.add(Duration(days: wdIdx - 1))] = day;
      }
    }
  }
  return map;
}

// ═══════════════════════ TEACHER PAGE ════════════════════════════

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key});

  static final globalKey = GlobalKey<_TeacherPageState>();

  static void openCalendarGlobal() {
    globalKey.currentState?._openCalendarFromOutside();
  }

  static VoidCallback? onNavigateToSettings;

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  static DateTime _selectedDate = _dateOnlyT(DateTime.now());

  void _nextDay() => setState(
      () => _selectedDate = _selectedDate.add(const Duration(days: 1)));

  void _prevDay() => setState(
      () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));

  void _openCalendarFromOutside() {
    final repo = ScheduleRepository.instance;
    if (repo.teacherDays.isNotEmpty) {
      final dateMap = _buildDateMapT(repo.teacherDays);
      _openCalendar(dateMap);
    }
  }

  Future<void> _openCalendar(Map<DateTime, ScheduleDay> dateMap) async {
    final dates = dateMap.keys.toList()..sort();
    final picked = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.black.withOpacity(0.40),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => _TCalendarDialog(
        selected:  _selectedDate,
        available: dates,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = _dateOnlyT(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppThemeNotifier.instance,
        ScheduleRepository.instance,
      ]),
      builder: (context, _) {
        final isDark = AppThemeNotifier.instance.isDark;
        final seed   = AppThemeNotifier.instance.seedColor;
        final repo   = ScheduleRepository.instance;

        final textPrimary   = isDark ? Colors.white : const Color(0xFF1A3A5C);
        final textSecondary = isDark ? Colors.white54 : const Color(0xFF5A7FA8);
        final textTeacher   = isDark
            ? Colors.white.withOpacity(0.52)
            : const Color(0xFF4A6580);

        final dateMap = _buildDateMapT(repo.teacherDays);

        return _TBody(
          repo:           repo,
          isDark:         isDark,
          seed:           seed,
          textPrimary:    textPrimary,
          textSecondary:  textSecondary,
          textTeacher:    textTeacher,
          selectedDate:   _selectedDate,
          dateMap:        dateMap,
          onSwipeLeft:    _nextDay,
          onSwipeRight:   _prevDay,
        );
      },
    );
  }
}

// ════════════════════════ BODY ════════════════════════════════════

class _TBody extends StatelessWidget {
  final ScheduleRepository repo;
  final bool     isDark;
  final Color    seed;
  final Color    textPrimary, textSecondary, textTeacher;
  final DateTime selectedDate;
  final Map<DateTime, ScheduleDay> dateMap;
  final VoidCallback onSwipeLeft, onSwipeRight;

  const _TBody({
    required this.repo,
    required this.isDark, required this.seed,
    required this.textPrimary, required this.textSecondary,
    required this.textTeacher,
    required this.selectedDate, required this.dateMap,
    required this.onSwipeLeft, required this.onSwipeRight,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 76;

    // Преподаватель не выбран
    if (repo.selectedTeacher == null) {
      return _TNoTeacherPlaceholder(
        topPad: topPad, seed: seed, isDark: isDark,
        textPrimary: textPrimary, textSecondary: textSecondary,
        onGoToSettings: TeacherPage.onNavigateToSettings,
      );
    }

    // Первая загрузка
    if (repo.teacherLoading && repo.teacherDays.isEmpty) {
      return _TLoadingPlaceholder(
        topPad: topPad, name: repo.selectedTeacher!.name,
        isDark: isDark, seed: seed,
        textPrimary: textPrimary, textSecondary: textSecondary,
      );
    }

    // Данные есть
    if (repo.teacherDays.isNotEmpty) {
      final day = dateMap[selectedDate];
      return _TDayView(
        day:          day,
        selectedDate: selectedDate,
        teacherName:  repo.selectedTeacher!.name,
        isDark:       isDark, seed: seed,
        textPrimary:  textPrimary, textSecondary: textSecondary,
        textTeacher:  textTeacher,
        scheduleError: repo.teacherError,
        onSwipeLeft:  onSwipeLeft, onSwipeRight: onSwipeRight,
      );
    }

    // Ошибка без данных
    return _TErrorPlaceholder(
      topPad: topPad,
      message: repo.teacherError ?? 'Расписание недоступно.',
      isDark: isDark, seed: seed,
      textPrimary: textPrimary, textSecondary: textSecondary,
      onRetry: () => repo.fetchTeacherSchedule(repo.selectedTeacher!.name),
    );
  }
}

// ════════════════════════ DAY VIEW ═══════════════════════════════

class _TDayView extends StatelessWidget {
  final ScheduleDay? day;
  final DateTime     selectedDate;
  final String       teacherName;
  final bool         isDark;
  final Color        seed, textPrimary, textSecondary, textTeacher;
  final String?      scheduleError;
  final VoidCallback onSwipeLeft, onSwipeRight;

  const _TDayView({
    required this.day, required this.selectedDate, required this.teacherName,
    required this.isDark, required this.seed,
    required this.textPrimary, required this.textSecondary,
    required this.textTeacher,
    required this.onSwipeLeft, required this.onSwipeRight,
    this.scheduleError,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = selectedDate == _dateOnlyT(DateTime.now());
    final seedHsv = HSVColor.fromColor(seed);

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        if (d.primaryVelocity == null) return;
        if (d.primaryVelocity! < -200) onSwipeLeft();
        if (d.primaryVelocity! > 200)  onSwipeRight();
      },
      child: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 76,
          bottom: 120, left: 16, right: 16,
        ),
        children: [
          // ── Заголовок ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 18, top: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                isToday ? 'Сегодня · ${_weekdayT(selectedDate)}'
                        : _weekdayT(selectedDate),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                    color: textPrimary),
              ),
              const SizedBox(height: 3),
              Row(children: [
                Text(_fmtDateT(selectedDate),
                    style: TextStyle(fontSize: 15, color: textSecondary)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: seed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: seed.withOpacity(0.25), width: 1),
                  ),
                  child: Text(teacherName,
                      style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w600, color: seed)),
                ),
              ]),
            ]),
          ),

          // ── Ошибка обновления ──────────────────────────────
          if (scheduleError != null) ...[
            _TErrorBanner(
              message: scheduleError!, isDark: isDark, seed: seed,
              onRetry: () => ScheduleRepository.instance
                  .fetchTeacherSchedule(teacherName),
            ),
            const SizedBox(height: 12),
          ],

          // ── Пары / выходной ────────────────────────────────
          if (day == null || day!.lessons.isEmpty)
            _TEmptyDay(isDark: isDark, seed: seed,
                textPrimary: textPrimary, textSecondary: textSecondary)
          else
            ...day!.lessons.asMap().entries.map((e) {
              final i = e.key;
              final lesson = e.value;
              final hueShift = ((i * 29) % 80) - 40.0;
              final hue = (seedHsv.hue + hueShift).clamp(0.0, 360.0);
              final cardColor = HSVColor.fromAHSV(
                1, hue,
                (seedHsv.saturation * 0.75).clamp(0.3, 0.9),
                isDark ? 0.65 : 0.78,
              ).toColor();
              return _TLessonCard(
                lesson: lesson, cardColor: cardColor,
                isDark: isDark, textPrimary: textPrimary,
                textTeacher: textTeacher,
              );
            }),
        ],
      ),
    );
  }
}

// ════════════════════════ LESSON CARD ════════════════════════════
// Отличие от группового: вместо teacher показываем group

class _TLessonCard extends StatelessWidget {
  final Lesson lesson;
  final Color  cardColor, textPrimary, textTeacher;
  final bool   isDark;

  const _TLessonCard({
    required this.lesson, required this.cardColor,
    required this.isDark, required this.textPrimary,
    required this.textTeacher,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withOpacity(0.14)
        : Colors.white.withOpacity(0.72);
    final timeSub = isDark
        ? Colors.white.withOpacity(0.42)
        : const Color(0xFF6A85A0);
    final roomBg = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.45);
    final cardBg = isDark
        ? Color.lerp(cardColor, Colors.black, 0.55)!.withOpacity(0.72)
        : Color.lerp(cardColor, Colors.white, 0.58)!.withOpacity(0.78);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(isDark ? 0.18 : 0.22),
              blurRadius: 14, offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Время
          SizedBox(
            width: 54,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(lesson.timeStart,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: textPrimary)),
              if (lesson.timeEnd.isNotEmpty)
                Text(lesson.timeEnd,
                    style: TextStyle(fontSize: 12, color: timeSub)),
            ]),
          ),

          // Разделитель
          Container(
            width: 2,
            height: lesson.timeEnd.isNotEmpty ? 40 : 26,
            margin: const EdgeInsets.only(left: 8, right: 12, top: 2),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(isDark ? 0.90 : 0.70),
              borderRadius: BorderRadius.circular(1),
            ),
          ),

          // Название, группа (вместо teacher), тип, кабинет
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(lesson.subject,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                      color: textPrimary)),
              if (lesson.group.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(lesson.group,
                    style: TextStyle(fontSize: 12, color: textTeacher)),
              ],
              if (lesson.type.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(lesson.type,
                    style: TextStyle(fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: textTeacher.withOpacity(0.72))),
              ],
              if (lesson.room.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: roomBg,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.10)
                          : Colors.white.withOpacity(0.60),
                      width: 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.room_rounded, size: 11,
                        color: textTeacher.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(lesson.room,
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: textTeacher)),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════ PLACEHOLDERS ═══════════════════════════

class _TNoTeacherPlaceholder extends StatelessWidget {
  final double topPad; final Color seed; final bool isDark;
  final Color textPrimary, textSecondary;
  final VoidCallback? onGoToSettings;

  const _TNoTeacherPlaceholder({
    required this.topPad, required this.seed, required this.isDark,
    required this.textPrimary, required this.textSecondary,
    this.onGoToSettings,
  });

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.only(
            top: topPad, bottom: 120, left: 16, right: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 18, top: 8),
            child: Text('По преподавателю',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                    color: textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.white.withOpacity(0.40),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.65),
                width: 1.4,
              ),
            ),
            child: Column(children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                    color: seed.withOpacity(0.14), shape: BoxShape.circle),
                child: Icon(Icons.person_rounded, size: 30, color: seed),
              ),
              const SizedBox(height: 16),
              Text('Преподаватель не выбран',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Выберите преподавателя в настройках,\n'
                'чтобы увидеть его расписание.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: textSecondary,
                    height: 1.45),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onGoToSettings,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: seed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: seed.withOpacity(0.3), width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.settings_rounded, size: 16, color: seed),
                    const SizedBox(width: 8),
                    Text('Настройки → Преподаватель',
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600, color: seed)),
                  ]),
                ),
              ),
            ]),
          ),
        ],
      );
}

class _TLoadingPlaceholder extends StatelessWidget {
  final double topPad; final String name; final bool isDark;
  final Color seed, textPrimary, textSecondary;
  const _TLoadingPlaceholder({
    required this.topPad, required this.name, required this.isDark,
    required this.seed, required this.textPrimary, required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.only(
            top: topPad, bottom: 120, left: 16, right: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 18, top: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('По преподавателю',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                      color: textPrimary)),
              const SizedBox(height: 2),
              Text(name,
                  style: TextStyle(fontSize: 15, color: textSecondary)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.white.withOpacity(0.40),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.65),
                width: 1.4,
              ),
            ),
            child: Column(children: [
              SizedBox(
                width: 40, height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(seed),
                ),
              ),
              const SizedBox(height: 18),
              Text('Загружаем расписание...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                      color: textPrimary)),
              const SizedBox(height: 6),
              Text('Подгружаем данные для $name',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textSecondary,
                      height: 1.4)),
            ]),
          ),
        ],
      );
}

class _TErrorPlaceholder extends StatelessWidget {
  final double topPad; final String message; final bool isDark;
  final Color seed, textPrimary, textSecondary;
  final VoidCallback onRetry;
  const _TErrorPlaceholder({
    required this.topPad, required this.message, required this.isDark,
    required this.seed, required this.textPrimary, required this.textSecondary,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.only(
            top: topPad, bottom: 120, left: 16, right: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 18, top: 8),
            child: Text('По преподавателю',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                    color: textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: Colors.orange.withOpacity(0.3), width: 1.2),
            ),
            child: Column(children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    shape: BoxShape.circle),
                child: const Icon(Icons.wifi_off_rounded,
                    size: 26, color: Colors.orange),
              ),
              const SizedBox(height: 14),
              Text('Не удалось загрузить',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: textPrimary)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textSecondary,
                      height: 1.4)),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 11),
                  decoration: BoxDecoration(
                    color: seed.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: seed.withOpacity(0.35), width: 1),
                  ),
                  child: Text('Повторить',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w600, color: seed)),
                ),
              ),
            ]),
          ),
        ],
      );
}

class _TEmptyDay extends StatelessWidget {
  final bool isDark; final Color seed, textPrimary, textSecondary;
  const _TEmptyDay({required this.isDark, required this.seed,
      required this.textPrimary, required this.textSecondary});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.white.withOpacity(0.35),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.10)
                : Colors.white.withOpacity(0.60),
            width: 1.3,
          ),
        ),
        child: Column(children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
                color: seed.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(Icons.wb_sunny_rounded, size: 26, color: seed),
          ),
          const SizedBox(height: 14),
          Text('Занятий нет',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: textPrimary)),
          const SizedBox(height: 6),
          Text('В этот день пар нет.',
              style: TextStyle(fontSize: 13, color: textSecondary,
                  height: 1.4)),
        ]),
      );
}

class _TErrorBanner extends StatelessWidget {
  final String message; final bool isDark; final Color seed;
  final VoidCallback? onRetry;
  const _TErrorBanner({required this.message, required this.isDark,
      required this.seed, this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(isDark ? 0.15 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withOpacity(0.28), width: 1),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 12, color: Colors.orange,
                    height: 1.3)),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.35), width: 1),
                ),
                child: const Text('Повторить',
                    style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w600, color: Colors.orange)),
              ),
            ),
          ],
        ]),
      );
}

// ════════════════════ CALENDAR DIALOG ════════════════════════════

class _TCalendarDialog extends StatefulWidget {
  final DateTime selected;
  final List<DateTime> available;
  const _TCalendarDialog({required this.selected, required this.available});

  @override
  State<_TCalendarDialog> createState() => _TCalendarDialogState();
}

class _TCalendarDialogState extends State<_TCalendarDialog> {
  late DateTime _viewing;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _viewing  = DateTime(widget.selected.year, widget.selected.month);
  }

  void _prevMonth() => setState(
      () => _viewing = DateTime(_viewing.year, _viewing.month - 1));
  void _nextMonth() => setState(
      () => _viewing = DateTime(_viewing.year, _viewing.month + 1));

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeNotifier.instance.isDark;
    final seed   = AppThemeNotifier.instance.seedColor;
    final textPrimary   = isDark ? Colors.white : const Color(0xFF1A3A5C);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF5A7FA8);

    final bg = isDark
        ? Color.lerp(seed, Colors.black, 0.78)!.withOpacity(0.96)
        : Color.lerp(seed, Colors.white, 0.68)!.withOpacity(0.96);

    final firstDay   = DateTime(_viewing.year, _viewing.month, 1);
    final daysCount  = DateTime(_viewing.year, _viewing.month + 1, 0).day;
    final startOffset = firstDay.weekday - 1;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity == null) return;
              if (d.primaryVelocity! < -200) _nextMonth();
              if (d.primaryVelocity! > 200)  _prevMonth();
            },
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(isDark ? 0.14 : 0.65),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(color: seed.withOpacity(0.25),
                      blurRadius: 32, spreadRadius: 2,
                      offset: const Offset(0, 8)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Шапка
                Row(children: [
                  _TMonthBtn(icon: Icons.chevron_left_rounded,
                      color: textSecondary, onTap: _prevMonth),
                  Expanded(
                    child: Text(
                      '${_kMonthsT[_viewing.month][0].toUpperCase()}'
                      '${_kMonthsT[_viewing.month].substring(1)} '
                      '${_viewing.year}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                  ),
                  _TMonthBtn(icon: Icons.chevron_right_rounded,
                      color: textSecondary, onTap: _nextMonth),
                ]),

                const SizedBox(height: 12),

                // Дни недели
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['Пн','Вт','Ср','Чт','Пт','Сб','Вс']
                      .map((d) => SizedBox(
                            width: 36,
                            child: Text(d, textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary)),
                          ))
                      .toList(),
                ),

                const SizedBox(height: 8),

                // Сетка
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, childAspectRatio: 1,
                    mainAxisSpacing: 4, crossAxisSpacing: 0,
                  ),
                  itemCount: startOffset + daysCount,
                  itemBuilder: (_, i) {
                    if (i < startOffset) return const SizedBox();
                    final day = DateTime(
                        _viewing.year, _viewing.month, i - startOffset + 1);
                    final isSel   = day == _selected;
                    final isToday = day == _dateOnlyT(DateTime.now());
                    final hasL    = widget.available.contains(day);

                    return GestureDetector(
                      onTap: () => setState(() => _selected = day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSel ? seed
                              : isToday ? seed.withOpacity(0.18)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !isSel
                              ? Border.all(
                                  color: seed.withOpacity(0.5), width: 1.5)
                              : null,
                        ),
                        child: Stack(alignment: Alignment.center, children: [
                          Text('${day.day}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSel || isToday
                                    ? FontWeight.w700 : FontWeight.w400,
                                color: isSel ? Colors.white
                                    : hasL ? textPrimary
                                    : textSecondary.withOpacity(0.5),
                              )),
                          if (hasL && !isSel)
                            Positioned(
                              bottom: 3,
                              child: Container(
                                width: 4, height: 4,
                                decoration: BoxDecoration(
                                    color: seed, shape: BoxShape.circle),
                              ),
                            ),
                        ]),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),
                Divider(color: Colors.white.withOpacity(isDark ? 0.10 : 0.45)),

                // Кнопки
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text('Отмена', textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15, color: textSecondary)),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 36,
                      color: Colors.white.withOpacity(isDark ? 0.10 : 0.45)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, _selected),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text('Выбрать', textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w700, color: seed)),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _TMonthBtn extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _TMonthBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: color),
        ),
      );
}