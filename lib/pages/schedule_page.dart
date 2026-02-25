import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/schedule_repository.dart';
import '../data/models.dart';

// ── Утилиты дат ───────────────────────────────────────────────────

const _kMonths = [
  '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];

// Для парсинга месяца из строки (именительный → число)
const _kMonthsNom = {
  'январь': 1, 'февраль': 2, 'март': 3, 'апрель': 4,
  'май': 5, 'июнь': 6, 'июль': 7, 'август': 8,
  'сентябрь': 9, 'октябрь': 10, 'ноябрь': 11, 'декабрь': 12,
  // Родительный падеж
  'января': 1, 'февраля': 2, 'марта': 3, 'апреля': 4,
  'мая': 5, 'июня': 6, 'июля': 7, 'августа': 8,
  'сентября': 9, 'октября': 10, 'ноября': 11, 'декабря': 12,
};

const _kWeekdays = [
  '', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница',
  'Суббота', 'Воскресенье',
];

// weekday name (lower) → weekday index (1=пн … 7=вс)
const _kWeekdayIndex = {
  'понедельник': 1, 'вторник': 2, 'среда': 3, 'среду': 3,
  'четверг': 4, 'пятница': 5, 'пятницу': 5,
  'суббота': 6, 'субботу': 6, 'воскресенье': 7,
};

String _formatDate(DateTime d) =>
    '${d.day} ${_kMonths[d.month]} ${d.year}';

String _weekday(DateTime d) => _kWeekdays[d.weekday];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Понедельник текущей или следующей недели (ближайший понедельник)
DateTime _thisWeekMonday([DateTime? ref]) {
  final now = ref ?? DateTime.now();
  final today = _dateOnly(now);
  return today.subtract(Duration(days: today.weekday - 1));
}

/// Извлекает дату из любой строки.
/// Стратегии по приоритету:
///   1. ISO 8601: '2025-02-17'
///   2. DD.MM.YYYY или DD/MM/YYYY
///   3. Русская дата: '24 февраля 2025' или '24 февраля'
///   4. DD.MM (без года — подставляем текущий год или следующий)
DateTime? _parseAnyDate(String raw, {DateTime? weekRef}) {
  if (raw.isEmpty) return null;
  final s = raw.trim();
  try {
    // 1. ISO 8601
    final iso = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(s);
    if (iso != null) return _dateOnly(DateTime.parse(iso.group(1)!));

    // 2. DD.MM.YYYY или DD/MM/YYYY
    final dmy = RegExp(r'(\d{1,2})[./](\d{1,2})[./](\d{4})').firstMatch(s);
    if (dmy != null) {
      return _dateOnly(DateTime(
        int.parse(dmy.group(3)!),
        int.parse(dmy.group(2)!),
        int.parse(dmy.group(1)!),
      ));
    }

    // 3. Русская дата: '24 февраля 2025' или '24 февраля'
    final rus = RegExp(
      r'(\d{1,2})\s+([а-яё]+)(?:\s+(\d{4}))?',
      caseSensitive: false,
    ).firstMatch(s);
    if (rus != null) {
      final day   = int.parse(rus.group(1)!);
      final month = _kMonthsNom[rus.group(2)!.toLowerCase()];
      if (month != null) {
        final year = rus.group(3) != null
            ? int.parse(rus.group(3)!)
            : DateTime.now().year;
        return _dateOnly(DateTime(year, month, day));
      }
    }

    // 4. DD.MM без года
    final dm = RegExp(r'(\d{1,2})[./](\d{1,2})').firstMatch(s);
    if (dm != null) {
      final day   = int.parse(dm.group(1)!);
      final month = int.parse(dm.group(2)!);
      final now   = DateTime.now();
      // Подбираем год (если месяц уже прошёл — следующий год)
      var year = now.year;
      if (month < now.month || (month == now.month && day < now.day)) {
        year++;
      }
      return _dateOnly(DateTime(year, month, day));
    }
  } catch (_) {}
  return null;
}

/// Строит карту { дата → ScheduleDay } для списка дней расписания.
/// Если в данных нет явных дат — выводит их из названий дней недели
/// (относительно понедельника текущей/следующей недели).
Map<DateTime, ScheduleDay> _buildDateMap(List<ScheduleDay> days) {
  final map = <DateTime, ScheduleDay>{};

  // Первый проход: ищем явные даты в date и dayName
  for (final day in days) {
    DateTime? dt = _parseAnyDate(day.date);
    dt ??= _parseAnyDate(day.dayName);
    if (dt != null) map[dt] = day;
  }

  // Второй проход: если дат нет — выводим из названий дней недели
  if (map.isEmpty) {
    final monday = _thisWeekMonday();
    for (final day in days) {
      final text  = (day.dayName + ' ' + day.date).toLowerCase();
      final wdIdx = _kWeekdayIndex.entries
          .where((e) => text.contains(e.key))
          .map((e) => e.value)
          .firstOrNull;
      if (wdIdx != null) {
        final date = monday.add(Duration(days: wdIdx - 1));
        map[date] = day;
      }
    }
  }

  return map;
}

// ═══════════════════════ SCHEDULE PAGE ═══════════════════════════

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  static final globalKey = GlobalKey<_SchedulePageState>();

  static void openCalendarGlobal() {
    globalKey.currentState?._openCalendarFromOutside();
  }

  // Коллбэк для перехода в настройки — регистрируется из main.dart
  static VoidCallback? onNavigateToSettings;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  // static — сохраняется при переключении вкладок
  static DateTime _selectedDate = _dateOnly(DateTime.now());

  void _nextDay() =>
      setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));

  void _prevDay() =>
      setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));

  void _openCalendarFromOutside() {
    final repo = ScheduleRepository.instance;
    if (repo.scheduleDays.isNotEmpty) {
      final dateMap = _buildDateMap(repo.scheduleDays);
      _openCalendar(dateMap);
    }
  }

  // Открыть кастомный календарь
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
      pageBuilder: (ctx, _, __) => _CalendarDialog(
        selected:  _selectedDate,
        available: dates,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = _dateOnly(picked));
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

        // Строим карту дат один раз — используется и в body, и в FAB
        final dateMap = _buildDateMap(repo.scheduleDays);

        return _ScheduleBody(
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

class _ScheduleBody extends StatelessWidget {
  final ScheduleRepository repo;
  final bool     isDark;
  final Color    seed;
  final Color    textPrimary;
  final Color    textSecondary;
  final Color    textTeacher;
  final DateTime selectedDate;
  final Map<DateTime, ScheduleDay> dateMap;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  const _ScheduleBody({
    required this.repo,
    required this.isDark,
    required this.seed,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTeacher,
    required this.selectedDate,
    required this.dateMap,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 76;

    if (repo.selectedGroup == null) {
      return _NoGroupPlaceholder(
        topPad: topPad, seed: seed, isDark: isDark,
        textPrimary: textPrimary, textSecondary: textSecondary,
        onGoToSettings: SchedulePage.onNavigateToSettings,
      );
    }

    if (repo.scheduleLoading && repo.scheduleDays.isEmpty) {
      return _LoadingGroupPlaceholder(
        topPad: topPad, groupName: repo.selectedGroup!.name,
        isDark: isDark, seed: seed,
        textPrimary: textPrimary, textSecondary: textSecondary,
      );
    }

    if (repo.scheduleDays.isNotEmpty) {
      // Ищем день по дате из карты
      final day = dateMap[selectedDate];
      return _DayView(
        day:           day,
        selectedDate:  selectedDate,
        groupName:     repo.selectedGroup!.name,
        isDark:        isDark,
        seed:          seed,
        textPrimary:   textPrimary,
        textSecondary: textSecondary,
        textTeacher:   textTeacher,
        scheduleError: repo.scheduleError,
        onSwipeLeft:   onSwipeLeft,
        onSwipeRight:  onSwipeRight,
      );
    }

    return _ErrorPlaceholder(
      topPad: topPad,
      message: repo.scheduleError ?? 'Расписание недоступно.',
      isDark: isDark, seed: seed,
      textPrimary: textPrimary, textSecondary: textSecondary,
      onRetry: () => repo.fetchSchedule(repo.selectedGroup!.name),
    );
  }
}

// ═══════════════════════ DAY VIEW ════════════════════════════════

class _DayView extends StatelessWidget {
  final ScheduleDay? day;
  final DateTime     selectedDate;
  final String       groupName;
  final bool         isDark;
  final Color        seed;
  final Color        textPrimary;
  final Color        textSecondary;
  final Color        textTeacher;
  final String?      scheduleError;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  const _DayView({
    required this.day,
    required this.selectedDate,
    required this.groupName,
    required this.isDark,
    required this.seed,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTeacher,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.scheduleError,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = selectedDate == _dateOnly(DateTime.now());
    final seedHsv = HSVColor.fromColor(seed);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -200) onSwipeLeft();
        if (details.primaryVelocity! > 200)  onSwipeRight();
      },
      child: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 76,
          bottom: 120,
          left: 16,
          right: 16,
        ),
        children: [
          // ── Заголовок дня ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 18, top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday
                      ? 'Сегодня · ${_weekday(selectedDate)}'
                      : _weekday(selectedDate),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(children: [
                  Text(
                    _formatDate(selectedDate),
                    style: TextStyle(fontSize: 15, color: textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: seed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: seed.withOpacity(0.25), width: 1),
                    ),
                    child: Text(
                      groupName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: seed,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),

          // ── Ошибка обновления ──────────────────────────────
          if (scheduleError != null) ...[
            _ErrorBanner(
              message: scheduleError!,
              isDark: isDark,
              seed: seed,
              onRetry: () => ScheduleRepository.instance
                  .fetchSchedule(groupName),
            ),
            const SizedBox(height: 12),
          ],

          // ── Пары или «выходной» ────────────────────────────
          if (day == null || day!.lessons.isEmpty)
            _EmptyDay(
              isDark: isDark, seed: seed,
              textPrimary: textPrimary, textSecondary: textSecondary,
            )
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
              return _LessonCard(
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

// ═══════════════════ CALENDAR DIALOG ═════════════════════════════

class _CalendarDialog extends StatefulWidget {
  final DateTime       selected;
  final List<DateTime> available;

  const _CalendarDialog({
    required this.selected,
    required this.available,
  });

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late DateTime _viewing;    // какой месяц показываем
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _viewing  = DateTime(widget.selected.year, widget.selected.month);
  }

  void _prevMonth() => setState(() =>
  _viewing = DateTime(_viewing.year, _viewing.month - 1));

  void _nextMonth() => setState(() =>
  _viewing = DateTime(_viewing.year, _viewing.month + 1));

  bool _hasLesson(DateTime d) => widget.available.contains(d);
  bool _isSelected(DateTime d) => d == _selected;
  bool _isToday(DateTime d) => d == _dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeNotifier.instance.isDark;
    final seed   = AppThemeNotifier.instance.seedColor;
    final textPrimary   = isDark ? Colors.white : const Color(0xFF1A3A5C);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF5A7FA8);

    final bg = isDark
        ? Color.lerp(seed, Colors.black, 0.78)!.withOpacity(0.96)
        : Color.lerp(seed, Colors.white, 0.68)!.withOpacity(0.96);

    // Дни месяца
    final firstDay  = DateTime(_viewing.year, _viewing.month, 1);
    final daysCount = DateTime(_viewing.year, _viewing.month + 1, 0).day;
    // Отступ: weekday 1=пн, делаем пн первым
    final startOffset = (firstDay.weekday - 1);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! < -200) _nextMonth();
              if (details.primaryVelocity! > 200)  _prevMonth();
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
                  BoxShadow(
                    color: seed.withOpacity(0.25),
                    blurRadius: 32, spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── Шапка месяца ─────────────────────────────────
                Row(children: [
                  _MonthNavBtn(
                    icon: Icons.chevron_left_rounded,
                    color: textSecondary,
                    onTap: _prevMonth,
                  ),
                  Expanded(
                    child: Text(
                      '${_kMonths[_viewing.month].capitalize()} ${_viewing.year}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  _MonthNavBtn(
                    icon: Icons.chevron_right_rounded,
                    color: textSecondary,
                    onTap: _nextMonth,
                  ),
                ]),

                const SizedBox(height: 12),

                // ── Дни недели ────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['Пн','Вт','Ср','Чт','Пт','Сб','Вс']
                      .map((d) => SizedBox(
                    width: 36,
                    child: Text(d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textSecondary)),
                  ))
                      .toList(),
                ),

                const SizedBox(height: 8),

                // ── Сетка дней ───────────────────────────────────
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 0,
                  ),
                  itemCount: startOffset + daysCount,
                  itemBuilder: (_, i) {
                    if (i < startOffset) return const SizedBox();
                    final day = DateTime(
                        _viewing.year, _viewing.month, i - startOffset + 1);
                    final isSel   = _isSelected(day);
                    final isToday = _isToday(day);
                    final hasL    = _hasLesson(day);

                    return GestureDetector(
                      onTap: () => setState(
                            () => _selected = _dateOnly(day),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSel
                              ? seed
                              : isToday
                              ? seed.withOpacity(0.18)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !isSel
                              ? Border.all(color: seed.withOpacity(0.5), width: 1.5)
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSel || isToday
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isSel
                                    ? Colors.white
                                    : hasL
                                    ? textPrimary
                                    : textSecondary.withOpacity(0.5),
                              ),
                            ),
                            // Точка = есть занятия в этот день
                            if (hasL && !isSel)
                              Positioned(
                                bottom: 3,
                                child: Container(
                                  width: 4, height: 4,
                                  decoration: BoxDecoration(
                                    color: seed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),
                Divider(color: Colors.white.withOpacity(isDark ? 0.10 : 0.45)),

                // ── Кнопки ──────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text('Отмена',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15, color: textSecondary)),
                      ),
                    ),
                  ),
                  Container(
                    width: 1, height: 36,
                    color: Colors.white.withOpacity(isDark ? 0.10 : 0.45),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, _selected),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text('Выбрать',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: seed)),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),        // Container
          ),        // GestureDetector
        ),
      ),
    );
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);
}

// ── Навигация по месяцу ───────────────────────────────────────────

class _MonthNavBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;

  const _MonthNavBtn({
    required this.icon, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: color),
    ),
  );
}

// ═════════════════════ CALENDAR FAB ══════════════════════════════

class _CalendarFab extends StatelessWidget {
  final Color        seed;
  final bool         isDark;
  final VoidCallback onTap;

  const _CalendarFab({
    required this.seed, required this.isDark, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Color.lerp(seed, Colors.black, 0.55)!
        : seed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: seed.withOpacity(0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(isDark ? 0.15 : 0.35),
            width: 1.2,
          ),
        ),
        child: const Icon(
          Icons.calendar_month_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

// ════════════════════ LOADING BANNER ═════════════════════════════

class _LoadingBanner extends StatefulWidget {
  final bool  visible;
  final bool  isDark;
  final Color seed;

  const _LoadingBanner({
    required this.visible, required this.isDark, required this.seed,
  });

  @override
  State<_LoadingBanner> createState() => _LoadingBannerState();
}

class _LoadingBannerState extends State<_LoadingBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    if (widget.visible) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_LoadingBanner old) {
    super.didUpdateWidget(old);
    if (widget.visible != old.visible) {
      widget.visible ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final seed   = widget.seed;
    final bgColor = isDark
        ? Color.lerp(seed, Colors.black, 0.65)!.withOpacity(0.92)
        : Color.lerp(seed, Colors.white, 0.45)!.withOpacity(0.92);
    final textColor = isDark ? Colors.white : const Color(0xFF1A3A5C);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        if (_ctrl.isDismissed) return const SizedBox.shrink();
        return FadeTransition(
          opacity: _ctrl,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1), end: Offset.zero,
            ).animate(CurvedAnimation(
                parent: _ctrl, curve: Curves.easeOutCubic)),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white
                            .withOpacity(isDark ? 0.15 : 0.60),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: seed.withOpacity(0.25),
                          blurRadius: 12, offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 15, height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(seed),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Загрузка расписания...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          )),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════ PLACEHOLDERS ═════════════════════════════

class _NoGroupPlaceholder extends StatelessWidget {
  final double topPad; final Color seed; final bool isDark;
  final Color textPrimary, textSecondary;
  final VoidCallback? onGoToSettings;
  const _NoGroupPlaceholder({
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
        child: Text('Расписание',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700,
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
            child: Icon(Icons.groups_rounded, size: 30, color: seed),
          ),
          const SizedBox(height: 16),
          Text('Группа не выбрана',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                  color: textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Расписание отобразится после того,\n'
                'как вы выберете группу в настройках.',
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
                Text('Настройки → Расписание',
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

class _LoadingGroupPlaceholder extends StatelessWidget {
  final double topPad; final String groupName; final bool isDark;
  final Color seed, textPrimary, textSecondary;
  const _LoadingGroupPlaceholder({
    required this.topPad, required this.groupName, required this.isDark,
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
              Text('Расписание',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700,
                      color: textPrimary)),
              const SizedBox(height: 2),
              Text('Группа $groupName',
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
          Text('Подгружаем данные для группы $groupName',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textSecondary,
                  height: 1.4)),
        ]),
      ),
    ],
  );
}

class _ErrorPlaceholder extends StatelessWidget {
  final double topPad; final String message; final bool isDark;
  final Color seed, textPrimary, textSecondary;
  final String debugInfo;
  final VoidCallback onRetry;
  const _ErrorPlaceholder({
    required this.topPad, required this.message, required this.isDark,
    required this.seed, required this.textPrimary, required this.textSecondary,
    required this.onRetry, this.debugInfo = '',
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.only(
        top: topPad, bottom: 120, left: 16, right: 16),
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 18, top: 8),
        child: Text('Расписание',
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
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded,
                size: 26, color: Colors.orange),
          ),
          const SizedBox(height: 14),
          Text('Не удалось загрузить',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: textPrimary)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
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

      // ── Отладочный блок ─────────────────────────────────
      if (debugInfo.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔍 DEBUG — ответ сервера',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.greenAccent)),
              const SizedBox(height: 6),
              SelectableText(
                debugInfo,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

// ── Выходной день ─────────────────────────────────────────────────

class _EmptyDay extends StatelessWidget {
  final bool isDark; final Color seed, textPrimary, textSecondary;
  const _EmptyDay({
    required this.isDark, required this.seed,
    required this.textPrimary, required this.textSecondary,
  });

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
      Text('В этот день пар нет. Отдыхайте!',
          style: TextStyle(fontSize: 13, color: textSecondary,
              height: 1.4)),
    ]),
  );
}

// ── Баннер ошибки обновления ──────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final bool isDark;
  final Color seed;
  final VoidCallback? onRetry;

  const _ErrorBanner({
    required this.message,
    required this.isDark,
    required this.seed,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(isDark ? 0.15 : 0.10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: Colors.orange.withOpacity(0.28), width: 1),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded,
          color: Colors.orange, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(message,
            style: const TextStyle(
                fontSize: 12, color: Colors.orange, height: 1.3)),
      ),
      if (onRetry != null) ...[
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.orange.withOpacity(0.35), width: 1),
            ),
            child: const Text(
              'Повторить',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ),
        ),
      ],
    ]),
  );
}

// ═══════════════════════ LESSON CARD ═════════════════════════════

class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final Color  cardColor;
  final bool   isDark;
  final Color  textPrimary;
  final Color  textTeacher;

  const _LessonCard({
    required this.lesson, required this.cardColor,
    required this.isDark, required this.textPrimary,
    required this.textTeacher,
  });


  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.white.withOpacity(0.80);
    final timeSub = isDark
        ? Colors.white.withOpacity(0.42)
        : const Color(0xFF6A85A0);
    final roomBg = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.45);

    // Стабильный «матовый» цвет — не зависит от того что под ним
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
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Время ───────────────────────────────────────
            SizedBox(
              width: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.timeStart,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  if (lesson.timeEnd.isNotEmpty)
                    Text(
                      lesson.timeEnd,
                      style: TextStyle(fontSize: 12, color: timeSub),
                    ),
                ],
              ),
            ),

            // ── Разделитель ────────────────────────────────
            Container(
              width: 2,
              height: lesson.timeEnd.isNotEmpty ? 40 : 26,
              margin: const EdgeInsets.only(left: 8, right: 12, top: 2),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(isDark ? 0.90 : 0.70),
                borderRadius: BorderRadius.circular(1),
              ),
            ),

            // ── Название, преподаватель, тип, кабинет ──────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.subject,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  if (lesson.teacher.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      lesson.teacher,
                      style: TextStyle(fontSize: 12, color: textTeacher),
                    ),
                  ],
                  if (lesson.type.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      lesson.type,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: textTeacher.withOpacity(0.72),
                      ),
                    ),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.room_rounded,
                              size: 11,
                              color: textTeacher.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              lesson.room,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: textTeacher,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}