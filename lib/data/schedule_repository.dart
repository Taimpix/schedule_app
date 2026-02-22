import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const _baseUrl = 'https://redoc.zukl.ru';
const _keyGroups = 'cached_groups';
const _keyTeachers = 'cached_teachers';
const _keyLoaded = 'data_loaded';

/// Singleton-репозиторий расписания.
/// Загружает группы и преподавателей с сервера при первом запуске,
/// затем отдаёт закешированные данные из SharedPreferences.
class ScheduleRepository extends ChangeNotifier {
  static final ScheduleRepository instance = ScheduleRepository._();
  ScheduleRepository._();

  final _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  List<Group> _groups = [];
  List<Teacher> _teachers = [];
  bool _isLoading = false;
  String? _error;

  List<Group> get groups => _groups;
  List<Teacher> get teachers => _teachers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _groups.isNotEmpty || _teachers.isNotEmpty;

  /// Вызывается при старте приложения.
  /// Если данные уже есть в кеше — читает оттуда.
  /// Если нет — делает сетевые запросы.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final alreadyLoaded = prefs.getBool(_keyLoaded) ?? false;
    if (alreadyLoaded) {
      _loadFromCache(prefs);
      return;
    }

    await _fetchFromNetwork(prefs);
  }

  /// Принудительное обновление данных с сервера (например, pull-to-refresh).
  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    await _fetchFromNetwork(prefs);
  }

  // ── Приватные методы ────────────────────────────────────────────

  void _loadFromCache(SharedPreferences prefs) {
    try {
      final groupsJson = prefs.getString(_keyGroups);
      final teachersJson = prefs.getString(_keyTeachers);

      if (groupsJson != null) {
        final list = jsonDecode(groupsJson) as List<dynamic>;
        _groups = list
            .map((e) => Group.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (teachersJson != null) {
        final list = jsonDecode(teachersJson) as List<dynamic>;
        _teachers = list
            .map((e) => Teacher.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('ScheduleRepository: cache read error — $e');
    }
  }

  Future<void> _fetchFromNetwork(SharedPreferences prefs) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Оба запроса параллельно
      final results = await Future.wait([
        _dio.get<List<dynamic>>('/get_groups'),
        _dio.get<List<dynamic>>('/get_teachers'),
      ]);

      final groupsData = results[0].data as List<dynamic>;
      final teachersData = results[1].data as List<dynamic>;

      _groups = groupsData
          .map((e) => Group.fromJson(e as Map<String, dynamic>))
          .toList();
      _teachers = teachersData
          .map((e) => Teacher.fromJson(e as Map<String, dynamic>))
          .toList();

      // Сохраняем в кеш
      await prefs.setString(
          _keyGroups, jsonEncode(_groups.map((g) => g.toJson()).toList()));
      await prefs.setString(
          _keyTeachers,
          jsonEncode(_teachers.map((t) => t.toJson()).toList()));
      await prefs.setBool(_keyLoaded, true);
    } on DioException catch (e) {
      _error = _friendlyError(e);
      debugPrint('ScheduleRepository: network error — $e');
      // Если есть старый кеш — всё равно покажем его
      _loadFromCache(prefs);
    } catch (e) {
      _error = 'Неизвестная ошибка';
      debugPrint('ScheduleRepository: unexpected error — $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Сервер не отвечает. Используются сохранённые данные.';
      case DioExceptionType.connectionError:
        return 'Нет подключения к интернету. Используются сохранённые данные.';
      default:
        return 'Ошибка загрузки данных. Используются сохранённые данные.';
    }
  }
}