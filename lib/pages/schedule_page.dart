import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  // Карточки получают цвет через смещение оттенка от seed
  static const _lessons = [
    _LessonData(time: '08:30', endTime: '10:00', subject: 'Математика',
        teacher: 'Иванов А.П.', room: '214', hueShift: 0),
    _LessonData(time: '10:15', endTime: '11:45', subject: 'Физика',
        teacher: 'Петрова М.В.', room: '301', hueShift: 30),
    _LessonData(time: '12:30', endTime: '14:00', subject: 'Информатика',
        teacher: 'Сидоров К.Н.', room: '115', hueShift: -25),
    _LessonData(time: '14:15', endTime: '15:45', subject: 'История',
        teacher: 'Козлова Н.А.', room: '208', hueShift: 55),
    _LessonData(time: '16:00', endTime: '17:30', subject: 'Английский',
        teacher: 'Новикова Е.С.', room: '401', hueShift: -50),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeNotifier.instance,
      builder: (context, _) {
        final isDark = AppThemeNotifier.instance.isDark;
        final seed = AppThemeNotifier.instance.seedColor;

        // Вычисляем базовый HSV из seed, чтобы строить вариации
        final seedHsv = HSVColor.fromColor(seed);

        // Цвета текста
        final textPrimary = isDark ? Colors.white : const Color(0xFF1A3A5C);
        final textSecondary =
        isDark ? Colors.white54 : const Color(0xFF5A7FA8);
        // Нейтральный читаемый цвет — не зависит от оттенка seed
        final textTeacher =
        isDark ? Colors.white.withOpacity(0.52) : const Color(0xFF4A6580);

        return ListView.builder(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 76,
            bottom: 120,
            left: 16,
            right: 16,
          ),
          itemCount: _lessons.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18, top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Понедельник',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: textPrimary)),
                    const SizedBox(height: 2),
                    Text('17 февраля 2025',
                        style:
                        TextStyle(fontSize: 15, color: textSecondary)),
                  ],
                ),
              );
            }
            final data = _lessons[index - 1];
            // Цвет карточки — оттенок seed сдвинут на hueShift, сохраняем насыщенность
            final cardHue =
            (seedHsv.hue + data.hueShift).clamp(0.0, 360.0);
            final cardColor = HSVColor.fromAHSV(
              1,
              cardHue,
              (seedHsv.saturation * 0.75).clamp(0.3, 0.9),
              isDark ? 0.65 : 0.78,
            ).toColor();

            return _LessonCard(
              data: data,
              cardColor: cardColor,
              isDark: isDark,
              textPrimary: textPrimary,
              textTeacher: textTeacher,
            );
          },
        );
      },
    );
  }
}

// ── Модель данных урока ───────────────────────────────────────────

class _LessonData {
  final String time;
  final String endTime;
  final String subject;
  final String teacher;
  final String room;
  // Смещение оттенка относительно seedColor
  final double hueShift;

  const _LessonData({
    required this.time,
    required this.endTime,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.hueShift,
  });
}

// ── Карточка урока ────────────────────────────────────────────────

class _LessonCard extends StatelessWidget {
  final _LessonData data;
  final Color cardColor;
  final bool isDark;
  final Color textPrimary;
  final Color textTeacher;

  const _LessonCard({
    required this.data,
    required this.cardColor,
    required this.isDark,
    required this.textPrimary,
    required this.textTeacher,
  });

  @override
  Widget build(BuildContext context) {
    final bgOpacity = isDark ? 0.20 : 0.24;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.70);
    final shadowOpacity = isDark ? 0.10 : 0.18;
    // Нейтральный читаемый второстепенный цвет времени
    final timeSecondary = isDark
        ? Colors.white.withOpacity(0.42)
        : const Color(0xFF6A85A0);
    final roomBg = isDark
        ? cardColor.withOpacity(0.25)
        : cardColor.withOpacity(0.28);
    final roomBorder = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          color: cardColor.withOpacity(bgOpacity),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(shadowOpacity),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Время
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.time,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary)),
                  Text(data.endTime,
                      style: TextStyle(fontSize: 12, color: timeSecondary)),
                ],
              ),
            ),
            // Вертикальная линия — цвет карточки
            Container(
              width: 2,
              height: 46,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(isDark ? 0.85 : 0.75),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            // Предмет и преподаватель
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.subject,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimary)),
                  const SizedBox(height: 3),
                  Text(data.teacher,
                      style: TextStyle(fontSize: 13, color: textTeacher)),
                ],
              ),
            ),
            // Кабинет
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: roomBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: roomBorder, width: 1),
              ),
              child: Text('к. ${data.room}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}