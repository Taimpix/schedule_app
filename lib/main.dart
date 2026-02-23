import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'theme/app_theme.dart';
import 'data/schedule_repository.dart';
import 'pages/schedule_page.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    AppThemeNotifier.instance.load(),
    ScheduleRepository.instance.init(),
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeNotifier.instance,
      builder: (context, _) {
        final n = AppThemeNotifier.instance;
        return MaterialApp(
          title: 'Расписание',
          debugShowCheckedModeBanner: false,
          theme: n.lightTheme,
          darkTheme: n.darkTheme,
          themeMode: n.themeMode,
          home: const MainScreen(),
        );
      },
    );
  }
}

// ═══════════════════════ MAIN SCREEN ═════════════════════════════

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeNotifier.instance,
      builder: (context, _) {
        final isDark = AppThemeNotifier.instance.isDark;
        final seed   = AppThemeNotifier.instance.seedColor;

        final bgColors = isDark
            ? [
          Color.lerp(seed, Colors.black, 0.80)!,
          Color.lerp(seed, Colors.black, 0.68)!,
          Color.lerp(seed, Colors.black, 0.62)!,
          Color.lerp(seed, Colors.black, 0.75)!,
        ]
            : [
          Color.lerp(seed, Colors.white, 0.52)!,
          Color.lerp(seed, Colors.white, 0.68)!,
          Color.lerp(seed, Colors.white, 0.78)!,
          Color.lerp(seed, Colors.white, 0.58)!,
        ];

        final titleColor      = isDark ? Colors.white : const Color(0xFF1A3A5C);
        final navIconColor    = isDark ? Colors.white.withOpacity(0.45) : const Color(0xFF5A7FA8);
        final navSelectedColor= isDark ? Colors.white : const Color(0xFF1A3A5C);

        final glassSettings = LiquidGlassSettings(
          thickness: 20,
          blur: 16,
          glassColor: isDark ? const Color(0x30FFFFFF) : const Color(0x44FFFFFF),
          lightIntensity: 1.35,
          saturation: 1.2,
        );

        return Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          body: Stack(children: [
            // ── Градиентный фон ────────────────────────────────
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: bgColors,
                    stops: const [0.0, 0.35, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            // ── Декоративные блобы ────────────────────────────
            Positioned(top: -80, left: -60,
                child: _Blob(size: 280, color: seed, opacity: isDark ? 0.18 : 0.32)),
            Positioned(bottom: 100, right: -80,
                child: _Blob(size: 320, color: seed, opacity: isDark ? 0.12 : 0.22)),
            Positioned(top: 320, left: -40,
                child: _Blob(size: 200, color: seed, opacity: isDark ? 0.15 : 0.28)),
            Positioned(top: 620, right: 20,
                child: _Blob(size: 160, color: seed, opacity: isDark ? 0.10 : 0.20)),

            // ── Страницы ──────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: _currentIndex == 0
                  ? SchedulePage(key: SchedulePage.globalKey)
                  : const SettingsPage(key: ValueKey(1)),
            ),

            // ── AppBar: капсула по центру ──────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: LiquidGlass.withOwnLayer(
                      settings: glassSettings,
                      shape: LiquidRoundedSuperellipse(borderRadius: 100),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 13),
                        child: Text(
                          _currentIndex == 0 ? 'Расписание' : 'Настройки',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom bar: капсула слева + кнопка справа ──────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Навкапсула
                      LiquidGlass.withOwnLayer(
                        settings: glassSettings,
                        shape: LiquidRoundedSuperellipse(borderRadius: 50),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _NavBtn(
                                icon: Icons.calendar_today_rounded,
                                isSelected: _currentIndex == 0,
                                selectedColor: navSelectedColor,
                                unselectedColor: navIconColor,
                                isDark: isDark,
                                onTap: () => setState(() => _currentIndex = 0),
                              ),
                              const SizedBox(width: 4),
                              _NavBtn(
                                icon: Icons.settings_rounded,
                                isSelected: _currentIndex == 1,
                                selectedColor: navSelectedColor,
                                unselectedColor: navIconColor,
                                isDark: isDark,
                                onTap: () => setState(() => _currentIndex = 1),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Кнопка календаря (только на вкладке расписания)
                      AnimatedOpacity(
                        opacity: _currentIndex == 0 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: _currentIndex != 0,
                          child: LiquidGlass.withOwnLayer(
                            settings: glassSettings,
                            shape: LiquidRoundedSuperellipse(borderRadius: 50),
                            child: GestureDetector(
                              onTap: () => SchedulePage.openCalendarGlobal(),
                              child: Padding(
                                padding: const EdgeInsets.all(21),
                                child: Icon(
                                  Icons.calendar_month_rounded,
                                  size: 28,
                                  color: navSelectedColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────── Helpers ────────────────────────────

class _Blob extends StatelessWidget {
  final double size;
  final Color  color;
  final double opacity;
  const _Blob({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 450),
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );
}

// Кнопка навбара: иконка + пилюля-подложка при выборе
class _NavBtn extends StatelessWidget {
  final IconData     icon;
  final bool         isSelected;
  final Color        selectedColor;
  final Color        unselectedColor;
  final bool         isDark;
  final VoidCallback onTap;

  const _NavBtn({
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
            ? Colors.white.withOpacity(0.20)
            : Colors.black.withOpacity(0.10))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Icon(
        icon,
        size: 26,
        color: isSelected ? selectedColor : unselectedColor,
      ),
    ),
  );
}