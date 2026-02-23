import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'schedule_parser.dart';

const _apiBase     = 'https://redoc.zukl.ru';
const _siteBase    = 'https://zukl.ru';

const _keyGroups          = 'cached_groups';
const _keyTeachers        = 'cached_teachers';
const _keyLoaded          = 'data_loaded';
const _keySelectedGroupId = 'selected_group_id';
const _keySelectedTeacherId = 'selected_teacher_id';
const _keySchedulePrefix  = 'schedule_';  // + groupName

class ScheduleRepository extends ChangeNotifier {
  static final ScheduleRepository instance = ScheduleRepository._();
  ScheduleRepository._();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 14),
    receiveTimeout: const Duration(seconds: 14),
    validateStatus: (_) => true,
    headers: {
      'Accept': 'text/html,application/xhtml+xml,application/json',
      'User-Agent': 'Mozilla/5.0 (compatible; ScheduleApp/1.0)',
    },
  ));

  // ── Каталог ────────────────────────────────────────────────────
  List<Group>   _groups   = [];
  List<Teacher> _teachers = [];
  bool    _catalogLoading = false;
  String? _catalogError;

  // ── Расписание ─────────────────────────────────────────────────
  List<ScheduleDay> _days          = [];
  bool    _scheduleLoading         = false;
  String? _scheduleError;

  // ── Выбор ──────────────────────────────────────────────────────
  Group?   _selectedGroup;
  Teacher? _selectedTeacher;

  // ── Геттеры ────────────────────────────────────────────────────
  List<Group>       get groups          => _groups;
  List<Teacher>     get teachers        => _teachers;
  bool              get isLoading       => _catalogLoading;
  String?           get error           => _catalogError;
  bool              get hasData         => _groups.isNotEmpty || _teachers.isNotEmpty;

  List<ScheduleDay> get scheduleDays    => _days;
  bool              get scheduleLoading => _scheduleLoading;
  String?           get scheduleError   => _scheduleError;

  Group?   get selectedGroup   => _selectedGroup;
  Teacher? get selectedTeacher => _selectedTeacher;

  // ══════════════════════════════════════════════════════════════

  /// Вызывается один раз при запуске приложения.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Читаем кеш мгновенно
    _loadCatalogFromCache(prefs);
    _restoreSelection(prefs);

    // Запускаем загрузку каталога в фоне если нет кеша
    if (!hasData) {
      await _fetchCatalog(prefs);
      _restoreSelection(prefs);
    } else {
      // Каталог есть — обновляем в фоне без блокировки
      _fetchCatalog(prefs).then((_) => _restoreSelection(prefs));
    }

    // Если группа выбрана — сначала показываем кеш, потом обновляем
    if (_selectedGroup != null) {
      await _loadScheduleFromCache(prefs, _selectedGroup!.name);
      // Фоновое обновление
      fetchSchedule(_selectedGroup!.name);
    }
  }

  /// Обновить каталог групп/преподавателей.
  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    await _fetchCatalog(prefs);
    _restoreSelection(prefs);
  }

  /// Загрузить расписание для группы (отображает прогресс через notifyListeners).
  Future<void> fetchSchedule(String groupName) async {
    if (groupName.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    _scheduleLoading = true;
    _scheduleError   = null;
    notifyListeners();

    try {
      final url  = '$_siteBase/schedule/group/$groupName';
      final resp = await _dio.get<dynamic>(url);
      final data = resp.data;

      List<ScheduleDay> parsed = [];

      // Реальный формат API — плоский список уроков
      if (data is List) {
        parsed = _groupLessonsByDate(data);
      } else if (data is Map) {
        final m   = data as Map<String, dynamic>;
        final key = m.containsKey('days')     ? 'days'
            : m.containsKey('schedule') ? 'schedule'
            : m.containsKey('data')     ? 'data'
            : m.containsKey('lessons')  ? 'lessons'
            : null;
        if (key != null && m[key] is List) {
          parsed = _groupLessonsByDate(m[key] as List);
        }
      }

      // Крайний случай — HTML
      if (parsed.isEmpty && data is String && data.contains('<')) {
        parsed = ScheduleParser.parseHtml(data);
      }

      if (parsed.isNotEmpty) {
        _days          = parsed;
        _scheduleError = null;
        await prefs.setString(
          '$_keySchedulePrefix$groupName',
          jsonEncode(parsed.map((d) => d.toJson()).toList()),
        );
      } else {
        _scheduleError =
        'Расписание для группы "$groupName" не найдено или недоступно.';
        // Оставляем кеш, если он был
      }
    } on DioException catch (e) {
      _scheduleError = _scheduleFriendlyError(e);
      debugPrint('[Repo] schedule DioException [${e.type}]: ${e.message}');
    } catch (e, s) {
      _scheduleError = 'Ошибка загрузки расписания.';
      debugPrint('[Repo] schedule error: $e\n$s');
    } finally {
      _scheduleLoading = false;
      notifyListeners();
    }
  }

  /// Сохранить группу, очистить старое расписание, запустить загрузку.
  Future<void> saveSelectedGroup(Group? group) async {
    _selectedGroup   = group;
    _days            = [];        // сразу стираем старое расписание
    _scheduleError   = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (group == null) {
      await prefs.remove(_keySelectedGroupId);
    } else {
      await prefs.setInt(_keySelectedGroupId, group.id);
      // Показываем кеш (если есть) пока грузим свежее
      await _loadScheduleFromCache(prefs, group.name);
      fetchSchedule(group.name);  // фон
    }
  }

  Future<void> saveSelectedTeacher(Teacher? teacher) async {
    _selectedTeacher = teacher;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (teacher == null) {
      await prefs.remove(_keySelectedTeacherId);
    } else {
      await prefs.setInt(_keySelectedTeacherId, teacher.id);
    }
  }

  // ── Private ────────────────────────────────────────────────────

  void _loadCatalogFromCache(SharedPreferences prefs) {
    try {
      final gRaw = prefs.getString(_keyGroups);
      if (gRaw != null) {
        _groups = (jsonDecode(gRaw) as List)
            .map((e) => Group.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }
      final tRaw = prefs.getString(_keyTeachers);
      if (tRaw != null) {
        _teachers = (jsonDecode(tRaw) as List)
            .map((e) => Teacher.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Repo] catalog cache error: $e');
    }
  }

  Future<void> _loadScheduleFromCache(
      SharedPreferences prefs, String groupName) async {
    try {
      final raw = prefs.getString('$_keySchedulePrefix$groupName');
      if (raw != null) {
        _days = (jsonDecode(raw) as List)
            .map((e) => ScheduleDay.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Repo] schedule cache error: $e');
    }
  }

  void _restoreSelection(SharedPreferences prefs) {
    final gId = prefs.getInt(_keySelectedGroupId);
    if (gId != null && _groups.isNotEmpty) {
      try { _selectedGroup = _groups.firstWhere((g) => g.id == gId); }
      catch (_) { _selectedGroup = null; }
    }
    final tId = prefs.getInt(_keySelectedTeacherId);
    if (tId != null && _teachers.isNotEmpty) {
      try { _selectedTeacher = _teachers.firstWhere((t) => t.id == tId); }
      catch (_) { _selectedTeacher = null; }
    }
    notifyListeners();
  }

  Future<void> _fetchCatalog(SharedPreferences prefs) async {
    _catalogLoading = true;
    _catalogError   = null;
    notifyListeners();

    try {
      final dio = Dio(BaseOptions(
        validateStatus: (_) => true,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
      ));
      final results = await Future.wait([
        dio.get<dynamic>('$_apiBase/get_groups'),
        dio.get<dynamic>('$_apiBase/get_teachers'),
      ]);

      final gRaw = results[0].data;
      final tRaw = results[1].data;

      if (gRaw is List) {
        _groups = gRaw
            .map((e) => Group.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        await prefs.setString(_keyGroups,
            jsonEncode(_groups.map((g) => g.toJson()).toList()));
      }
      if (tRaw is List) {
        _teachers = tRaw
            .map((e) => Teacher.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        await prefs.setString(_keyTeachers,
            jsonEncode(_teachers.map((t) => t.toJson()).toList()));
      }

      if (_groups.isNotEmpty || _teachers.isNotEmpty) {
        await prefs.setBool(_keyLoaded, true);
        _catalogError = null;
      } else {
        _catalogError = 'Сервер вернул пустые данные.';
      }
    } on DioException catch (e) {
      _catalogError = _catalogFriendlyError(e);
      debugPrint('[Repo] catalog DioException [${e.type}]: ${e.message}');
    } catch (e) {
      _catalogError = 'Ошибка загрузки: $e';
    } finally {
      _catalogLoading = false;
      notifyListeners();
    }
  }

  String _catalogFriendlyError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Сервер не отвечает. Попробуйте позже.';
      case DioExceptionType.connectionError:
        return 'Нет подключения к интернету.';
      default:
        return 'Не удалось загрузить данные.';
    }
  }

  String _scheduleFriendlyError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Сервер не отвечает. Показано кешированное расписание.';
      case DioExceptionType.connectionError:
        return 'Нет интернета. Показано кешированное расписание.';
      default:
        return 'Не удалось обновить расписание.';
    }
  }

  /// Группирует плоский список уроков по полю `date`.
  /// Сортирует дни по дате, уроки внутри дня — по времени начала.
  List<ScheduleDay> _groupLessonsByDate(List<dynamic> rawList) {
    // { dateString → [lessons] }
    final map = <String, List<Lesson>>{};

    for (final item in rawList) {
      if (item is! Map<String, dynamic>) continue;
      final date   = (item['date'] ?? '') as String;
      final lesson = Lesson.fromJson(item);
      map.putIfAbsent(date, () => []).add(lesson);
    }

    // Сортируем уроки внутри каждого дня по времени начала
    for (final lessons in map.values) {
      lessons.sort((a, b) => a.timeStart.compareTo(b.timeStart));
    }

    // Строим ScheduleDay-ы и сортируем по дате
    final days = map.entries.map((e) {
      return ScheduleDay(date: e.key, dayName: '', lessons: e.value);
    }).toList();

    // Сортируем по дате: DD.MM.YYYY → парсим для сравнения
    days.sort((a, b) {
      final da = _parseDateForSort(a.date);
      final db = _parseDateForSort(b.date);
      return da.compareTo(db);
    });

    return days;
  }

  /// Парсит DD.MM.YYYY → DateTime для сортировки. Возвращает DateTime(0) при ошибке.
  DateTime _parseDateForSort(String raw) {
    try {
      final m = RegExp(r'^(\d{1,2})[./](\d{1,2})[./](\d{4})').firstMatch(raw);
      if (m != null) {
        return DateTime(
          int.parse(m.group(3)!),
          int.parse(m.group(2)!),
          int.parse(m.group(1)!),
        );
      }
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw)) {
        return DateTime.parse(raw);
      }
    } catch (_) {}
    return DateTime(0);
  }
}