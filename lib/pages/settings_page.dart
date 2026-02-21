import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─────────────────────────── Данные ──────────────────────────────

const _kGroups = [
  'И-2-23-01', 'И-2-23-02',
  'И-2-22-01', 'И-2-22-02',
  'П-2-23-01', 'П-2-23-02',
  'П-2-22-01', 'П-2-22-02',
  'Б-2-23-01', 'Б-2-23-02',
  'Б-2-22-01', 'Б-2-22-02',
];

const _kTeachers = [
  'Иванов А.П.',
  'Петрова М.В.',
  'Сидоров К.Н.',
  'Козлова Н.А.',
  'Новикова Е.С.',
  'Захаров Д.И.',
  'Морозова Т.Ю.',
  'Волков С.Р.',
  'Лебедева О.М.',
  'Соколов В.Г.',
  'Фёдорова Ирина Константиновна',
  'Алексеев Павел Владимирович',
  'Черепанова Светлана Анатольевна',
  'Воронцов-Вельяминов Борис Александрович',
];

const _kPresetColors = [
  Color(0xFF6C9EE8), Color(0xFF5B8AF0), Color(0xFF7C6EE8),
  Color(0xFFE87C6C), Color(0xFFE8A86C), Color(0xFF6CE8A0),
  Color(0xFF6CC8E8), Color(0xFFE8D46C), Color(0xFFE86CA0),
  Color(0xFF6CE8D4),
];

const _kPresetNames = [
  'Небесный', 'Лавандовый', 'Фиолетовый', 'Коралловый', 'Персиковый',
  'Мятный', 'Голубой', 'Золотой', 'Розовый', 'Бирюзовый',
];

// ═══════════════════════ SETTINGS PAGE ═══════════════════════════

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedGroup = 'И-2-23-01';
  String _selectedTeacher = 'Иванов А.П.';

  Future<void> _openSearch({
    required String title,
    required List<String> items,
    required String selected,
    required ValueChanged<String> onSelected,
  }) async {
    await Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withOpacity(0.35),
      pageBuilder: (_, __, ___) => _SearchPage(
        title: title, items: items, selected: selected,
        onSelected: (v) { onSelected(v); Navigator.pop(context); },
      ),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
  }

  Future<void> _openColorPicker() async {
    await Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withOpacity(0.35),
      pageBuilder: (_, __, ___) => const _ColorPickerPage(),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeNotifier.instance,
      builder: (context, _) {
        final th = AppThemeNotifier.instance;
        final isDark = th.isDark;
        final seed = th.seedColor;

        final textPrimary = isDark ? Colors.white : const Color(0xFF1A3A5C);
        final textSecondary =
        isDark ? Colors.white60 : const Color(0xFF5A7FA8);
        final cardBg = isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.30);
        final cardBorder = isDark
            ? Colors.white.withOpacity(0.14)
            : Colors.white.withOpacity(0.65);
        final divColor =
        isDark ? Colors.white.withOpacity(0.10) : const Color(0x22000000);

        Widget div() => Divider(height: 1, indent: 16, endIndent: 16, color: divColor);

        return ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 76,
            bottom: 120, left: 16, right: 16,
          ),
          children: [
            // Заголовок
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Настройки',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700,
                        color: textPrimary)),
                const SizedBox(height: 2),
                Text('Персонализация приложения',
                    style: TextStyle(fontSize: 15, color: textSecondary)),
              ]),
            ),

            // ── Внешний вид ─────────────────────────────────────
            _SectionLabel('Внешний вид', textSecondary),
            _GlassCard(bg: cardBg, border: cardBorder, children: [
              _ToggleTile(
                icon: Icons.dark_mode_rounded,
                title: 'Тёмная тема',
                subtitle: 'Переключить тему оформления',
                value: isDark, textPrimary: textPrimary,
                textSecondary: textSecondary, seed: seed,
                onChanged: (v) => th.setDark(v),
              ),
              div(),
              _ColorSchemeTile(
                currentColor: seed, textPrimary: textPrimary,
                textSecondary: textSecondary, onTap: _openColorPicker,
              ),
            ]),

            const SizedBox(height: 16),

            // ── Расписание ──────────────────────────────────────
            _SectionLabel('Расписание', textSecondary),
            _GlassCard(bg: cardBg, border: cardBorder, children: [
              _SelectTile(
                icon: Icons.group_rounded, title: 'Группа',
                value: _selectedGroup, textPrimary: textPrimary, seed: seed,
                onTap: () => _openSearch(
                  title: 'Выбор группы', items: _kGroups,
                  selected: _selectedGroup,
                  onSelected: (v) => setState(() => _selectedGroup = v),
                ),
              ),
              div(),
              _SelectTile(
                icon: Icons.person_rounded, title: 'Преподаватель',
                value: _selectedTeacher, textPrimary: textPrimary, seed: seed,
                onTap: () => _openSearch(
                  title: 'Выбор преподавателя', items: _kTeachers,
                  selected: _selectedTeacher,
                  onSelected: (v) => setState(() => _selectedTeacher = v),
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // ── О приложении ────────────────────────────────────
            _SectionLabel('О приложении', textSecondary),
            _GlassCard(bg: cardBg, border: cardBorder, children: [
              _ActionTile(
                icon: Icons.info_outline_rounded, title: 'Версия приложения',
                subtitle: '1.0.0 (build 1)', textPrimary: textPrimary,
                textSecondary: textSecondary, seed: seed, onTap: () {},
              ),
              div(),
              _ActionTile(
                icon: Icons.help_outline_rounded, title: 'Помощь и поддержка',
                subtitle: 'FAQ и контакты', textPrimary: textPrimary,
                textSecondary: textSecondary, seed: seed, onTap: () {},
              ),
            ]),
          ],
        );
      },
    );
  }
}

// ══════════════════════ COLOR PICKER PAGE ════════════════════════

class _ColorPickerPage extends StatefulWidget {
  const _ColorPickerPage();

  @override
  State<_ColorPickerPage> createState() => _ColorPickerPageState();
}

class _ColorPickerPageState extends State<_ColorPickerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  double _hue = 0, _sat = 0.6, _val = 0.85;

  Color get _custom => HSVColor.fromAHSV(1, _hue, _sat, _val).toColor();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final hsv = HSVColor.fromColor(AppThemeNotifier.instance.seedColor);
    _hue = hsv.hue; _sat = hsv.saturation; _val = hsv.value;
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _apply(Color color) {
    AppThemeNotifier.instance.setSeedColor(color);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeNotifier.instance,
      builder: (context, _) {
        final isDark = AppThemeNotifier.instance.isDark;
        final seed = AppThemeNotifier.instance.seedColor;
        final top = MediaQuery.of(context).padding.top;
        final bg = isDark ? const Color(0xFF16202E) : const Color(0xFFF0F6FF);
        final textPrimary = isDark ? Colors.white : const Color(0xFF1A3A5C);
        final textSecondary =
        isDark ? Colors.white60 : const Color(0xFF5A7FA8);
        // Фон таб-бара
        final tabBarBg = isDark
            ? Colors.white.withOpacity(0.07)
            : Colors.white.withOpacity(0.55);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            margin: EdgeInsets.only(top: top + 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32), topRight: Radius.circular(32),
              ),
            ),
            child: Column(children: [
              _Handle(color: textSecondary),
              // Шапка
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
                child: Row(children: [
                  Text('Цветовая схема',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                          color: textPrimary)),
                  const Spacer(),
                  _CloseButton(color: textSecondary),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Таб-бар: индикатор на полную ширину половины ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: tabBarBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.white.withOpacity(0.6),
                      width: 1,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    dividerColor: Colors.transparent,
                    // Кастомный индикатор — занимает ровно половину
                    indicator: _FullTabIndicator(
                      color: seed.withOpacity(isDark ? 0.35 : 0.28),
                      radius: 12,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: textPrimary,
                    unselectedLabelColor: textSecondary,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
                    tabs: const [
                      Tab(text: '🎨  Готовые'),
                      Tab(text: '✏️  Свой цвет'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _PresetColorsTab(onSelect: _apply),
                    _CustomColorTab(
                      hue: _hue, sat: _sat, val: _val, custom: _custom,
                      textPrimary: textPrimary, textSecondary: textSecondary,
                      onHue: (v) => setState(() => _hue = v),
                      onSat: (v) => setState(() => _sat = v),
                      onVal: (v) => setState(() => _val = v),
                      onApply: () => _apply(_custom),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Кастомный индикатор таба — на полную ширину ───────────────────

class _FullTabIndicator extends Decoration {
  final Color color;
  final double radius;
  const _FullTabIndicator({required this.color, required this.radius});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _FullTabPainter(color: color, radius: radius);
}

class _FullTabPainter extends BoxPainter {
  final Color color;
  final double radius;
  const _FullTabPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration config) {
    final rect = offset & config.size!;
    // Небольшой внутренний отступ чтобы не залезать за края контейнера
    final inset = rect.deflate(3);
    final rRect = RRect.fromRectAndRadius(inset, Radius.circular(radius));
    canvas.drawRRect(rRect, Paint()..color = color);
  }
}

// ── Вкладка готовых цветов ────────────────────────────────────────

class _PresetColorsTab extends StatelessWidget {
  final ValueChanged<Color> onSelect;
  const _PresetColorsTab({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final current = AppThemeNotifier.instance.seedColor;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12,
        mainAxisSpacing: 12, childAspectRatio: 1.6,
      ),
      itemCount: _kPresetColors.length,
      itemBuilder: (context, i) {
        final color = _kPresetColors[i];
        final isSelected = color.toARGB32() == current.toARGB32();
        return GestureDetector(
          onTap: () => onSelect(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [color, Color.lerp(color, Colors.black, 0.28)!],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.22),
                width: isSelected ? 2.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(isSelected ? 0.5 : 0.15),
                  blurRadius: isSelected ? 18 : 6, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Text(_kPresetNames[i],
                    style: const TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              if (isSelected)
                Positioned(
                  right: 10, bottom: 10,
                  child: Container(
                    width: 24, height: 24,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.check_rounded, size: 14, color: color),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Вкладка своего цвета ─────────────────────────────────────────

class _CustomColorTab extends StatelessWidget {
  final double hue, sat, val;
  final Color custom;
  final Color textPrimary, textSecondary;
  final ValueChanged<double> onHue, onSat, onVal;
  final VoidCallback onApply;

  const _CustomColorTab({
    required this.hue, required this.sat, required this.val,
    required this.custom, required this.textPrimary, required this.textSecondary,
    required this.onHue, required this.onSat, required this.onVal,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Превью
        Container(
          width: double.infinity, height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              custom, Color.lerp(custom, Colors.black, 0.3)!,
            ]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: custom.withOpacity(0.45),
                blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Center(
            child: Text(
              '#${custom.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: 2,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 4)]),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _GradientSlider(
          label: 'Оттенок', value: hue / 360, textSecondary: textSecondary,
          gradient: const LinearGradient(colors: [
            Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
            Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ]),
          thumbColor: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
          onChanged: (v) => onHue(v * 360),
        ),
        const SizedBox(height: 16),
        _GradientSlider(
          label: 'Насыщенность', value: sat, textSecondary: textSecondary,
          gradient: LinearGradient(colors: [
            HSVColor.fromAHSV(1, hue, 0, val).toColor(),
            HSVColor.fromAHSV(1, hue, 1, val).toColor(),
          ]),
          thumbColor: custom, onChanged: onSat,
        ),
        const SizedBox(height: 16),
        _GradientSlider(
          label: 'Яркость', value: val, textSecondary: textSecondary,
          gradient: LinearGradient(colors: [
            Colors.black, HSVColor.fromAHSV(1, hue, sat, 1).toColor(),
          ]),
          thumbColor: custom, onChanged: onVal,
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: onApply,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                custom, Color.lerp(custom, Colors.black, 0.2)!,
              ]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: custom.withOpacity(0.4),
                  blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: const Center(
              child: Text('Применить',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: 0.3)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Слайдер с градиентным треком ─────────────────────────────────

class _GradientSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color textSecondary;
  final LinearGradient gradient;
  final Color thumbColor;
  final ValueChanged<double> onChanged;

  const _GradientSlider({
    required this.label, required this.value, required this.textSecondary,
    required this.gradient, required this.thumbColor, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: textSecondary, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Stack(alignment: Alignment.center, children: [
        Container(height: 12,
            decoration: BoxDecoration(
                gradient: gradient, borderRadius: BorderRadius.circular(6))),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 12,
            thumbShape: _ColorThumb(color: thumbColor),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
          ),
          child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
        ),
      ]),
    ]);
  }
}

class _ColorThumb extends SliderComponentShape {
  final Color color;
  static const double _r = 13;
  const _ColorThumb({required this.color});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_r);

  @override
  void paint(PaintingContext context, Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final c = context.canvas;
    c.drawCircle(center, _r, Paint()
      ..color = Colors.black.withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    c.drawCircle(center, _r, Paint()..color = Colors.white);
    c.drawCircle(center, _r - 2.5, Paint()..color = color);
  }
}

// ════════════════════════ SEARCH PAGE ════════════════════════════

class _SearchPage extends StatefulWidget {
  final String title;
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;

  const _SearchPage({
    required this.title, required this.items,
    required this.selected, required this.onSelected,
  });

  @override
  State<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPage> {
  late List<String> _filtered;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _ctrl.addListener(() {
      final q = _ctrl.text.toLowerCase();
      setState(() => _filtered =
          widget.items.where((e) => e.toLowerCase().contains(q)).toList());
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeNotifier.instance,
      builder: (context, _) {
        final isDark = AppThemeNotifier.instance.isDark;
        final seed = AppThemeNotifier.instance.seedColor;
        final top = MediaQuery.of(context).padding.top;
        final bg = isDark ? const Color(0xFF16202E) : const Color(0xFFF0F6FF);
        final textPrimary = isDark ? Colors.white : const Color(0xFF1A3A5C);
        final textSecondary =
        isDark ? Colors.white60 : const Color(0xFF5A7FA8);
        final itemBg = isDark
            ? Colors.white.withOpacity(0.07)
            : Colors.white.withOpacity(0.55);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            margin: EdgeInsets.only(top: top + 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32), topRight: Radius.circular(32),
              ),
            ),
            child: Column(children: [
              _Handle(color: textSecondary),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 16, 16),
                child: Row(children: [
                  Text(widget.title,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                          color: textPrimary)),
                  const Spacer(),
                  _CloseButton(color: textSecondary),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: itemBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: seed.withOpacity(0.3), width: 1.2),
                  ),
                  child: TextField(
                    controller: _ctrl, autofocus: true,
                    style: TextStyle(fontSize: 15, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Поиск...',
                      hintStyle: TextStyle(fontSize: 15,
                          color: textSecondary.withOpacity(0.7)),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: textSecondary, size: 22),
                      suffixIcon: _ctrl.text.isNotEmpty
                          ? GestureDetector(
                          onTap: () {
                            _ctrl.clear();
                            setState(() => _filtered = widget.items);
                          },
                          child: Icon(Icons.cancel_rounded,
                              color: textSecondary, size: 18))
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Text('Ничего не найдено',
                    style: TextStyle(fontSize: 15, color: textSecondary)))
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final item = _filtered[i];
                    final isSel = item == widget.selected;
                    return GestureDetector(
                      onTap: () => widget.onSelected(item),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSel ? seed.withOpacity(0.18) : itemBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSel ? seed.withOpacity(0.5)
                                : Colors.white.withOpacity(0.15),
                            width: 1.3,
                          ),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Text(item,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSel
                                      ? FontWeight.w600 : FontWeight.w400,
                                  color: textPrimary, height: 1.35,
                                )),
                          ),
                          if (isSel) ...[
                            const SizedBox(width: 10),
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                  color: seed, shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ════════════════════ ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ════════════════════

class _Handle extends StatelessWidget {
  final Color color;
  const _Handle({required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Container(width: 40, height: 4,
        decoration: BoxDecoration(
            color: color.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2))),
  );
}

class _CloseButton extends StatelessWidget {
  final Color color;
  const _CloseButton({required this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.pop(context),
    child: Container(width: 34, height: 34,
        decoration: BoxDecoration(
            color: color.withOpacity(0.15), shape: BoxShape.circle),
        child: Icon(Icons.close_rounded, size: 18, color: color)),
  );
}

class _ColorSchemeTile extends StatelessWidget {
  final Color currentColor, textPrimary, textSecondary;
  final VoidCallback onTap;
  const _ColorSchemeTile({required this.currentColor, required this.textPrimary,
    required this.textSecondary, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(children: [
        _IconBox(icon: Icons.palette_rounded, seed: currentColor),
        const SizedBox(width: 12),
        Expanded(child: Text('Цветовая схема',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
                color: textPrimary))),
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: currentColor, shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
            boxShadow: [BoxShadow(color: currentColor.withOpacity(0.4),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
      ]),
    ),
  );
}

class _SelectTile extends StatelessWidget {
  final IconData icon;
  final String title, value;
  final Color textPrimary, seed;
  final VoidCallback onTap;
  const _SelectTile({required this.icon, required this.title, required this.value,
    required this.textPrimary, required this.seed, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        _IconBox(icon: icon, seed: seed),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 15,
              fontWeight: FontWeight.w500, color: textPrimary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: seed.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: seed.withOpacity(0.25), width: 1),
            ),
            child: Text(value, softWrap: true,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: textPrimary, height: 1.3)),
          ),
        ])),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded,
            color: textPrimary.withOpacity(0.3), size: 20),
      ]),
    ),
  );
}

class _GlassCard extends StatelessWidget {
  final List<Widget> children;
  final Color bg, border;
  const _GlassCard({required this.children, required this.bg, required this.border});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: border, width: 1.4),
      boxShadow: [BoxShadow(
        color: AppThemeNotifier.instance.seedColor.withOpacity(0.07),
        blurRadius: 14, offset: const Offset(0, 4),
      )],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text; final Color color;
  const _SectionLabel(this.text, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 8),
    child: Text(text.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: color, letterSpacing: 1.1)),
  );
}

class _IconBox extends StatelessWidget {
  final IconData icon; final Color seed;
  const _IconBox({required this.icon, required this.seed});
  @override
  Widget build(BuildContext context) => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
        color: seed.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, size: 20, color: seed),
  );
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final Color textPrimary, textSecondary, seed;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({required this.icon, required this.title,
    required this.subtitle, required this.value, required this.textPrimary,
    required this.textSecondary, required this.seed, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(children: [
      _IconBox(icon: icon, seed: seed),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w500, color: textPrimary)),
            Text(subtitle,
                style: TextStyle(fontSize: 12, color: textSecondary)),
          ])),
      Switch.adaptive(value: value, onChanged: onChanged, activeColor: seed),
    ]),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color textPrimary, textSecondary, seed;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title,
    required this.subtitle, required this.textPrimary,
    required this.textSecondary, required this.seed, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        _IconBox(icon: icon, seed: seed),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w500, color: textPrimary)),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: textSecondary)),
            ])),
        Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
      ]),
    ),
  );
}