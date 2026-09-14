import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/leaderboard_service.dart';
import 'round.dart';

class GameState extends ChangeNotifier {
  static const String _prefKey = 'domino_score_state';

  int _metaPuntos = 200;
  String _nombreE1 = 'Pareja 1';
  String _nombreE2 = 'Pareja 2';
  List<Round> _rondas = [];
  bool _isLoaded = false;
  bool _matchRecorded = false;

  GameState() {
    _loadFromPrefs();
  }

  int get metaPuntos => _metaPuntos;
  String get nombreE1 => _nombreE1;
  String get nombreE2 => _nombreE2;
  List<Round> get rondas => List.unmodifiable(_rondas);
  bool get isLoaded => _isLoaded;
  bool get matchRecorded => _matchRecorded;

  int get totalE1 {
    int sum = 0;
    for (final r in _rondas) {
      if (r.equipo == 1) sum += r.puntos;
    }
    return sum;
  }

  int get totalE2 {
    int sum = 0;
    for (final r in _rondas) {
      if (r.equipo == 2) sum += r.puntos;
    }
    return sum;
  }

  int get rondasE1Count {
    return _rondas.where((r) => r.equipo == 1).length;
  }

  int get rondasE2Count {
    return _rondas.where((r) => r.equipo == 2).length;
  }

  int get ganador {
    if (totalE1 >= _metaPuntos) return 1;
    if (totalE2 >= _metaPuntos) return 2;
    return 0; // en juego
  }

  bool get isGameOver => ganador != 0;

  String get ganadorNombre {
    if (ganador == 1) return _nombreE1;
    if (ganador == 2) return _nombreE2;
    return '';
  }

  void setMetaPuntos(int nuevaMeta) {
    if (nuevaMeta > 0 && nuevaMeta != _metaPuntos) {
      _metaPuntos = nuevaMeta;
      _saveToPrefs();
      _checkAndRecordMatch();
      notifyListeners();
    }
  }

  void setNombreE1(String nombre) {
    final clean = nombre.trim();
    if (clean.isNotEmpty && clean != _nombreE1) {
      _nombreE1 = clean;
      _saveToPrefs();
      notifyListeners();
    }
  }

  void setNombreE2(String nombre) {
    final clean = nombre.trim();
    if (clean.isNotEmpty && clean != _nombreE2) {
      _nombreE2 = clean;
      _saveToPrefs();
      notifyListeners();
    }
  }

  void agregarRonda(int equipo, int puntos) {
    if (puntos <= 0) return;
    _rondas.add(Round(equipo: equipo, puntos: puntos));
    _saveToPrefs();
    _checkAndRecordMatch();
    notifyListeners();
  }

  void editarRonda(int index, int puntos) {
    if (index >= 0 && index < _rondas.length && puntos > 0) {
      _rondas[index].puntos = puntos;
      _saveToPrefs();
      _checkAndRecordMatch();
      notifyListeners();
    }
  }

  void eliminarRonda(int index) {
    if (index >= 0 && index < _rondas.length) {
      _rondas.removeAt(index);
      _saveToPrefs();
      notifyListeners();
    }
  }

  void reiniciarPartida() {
    _rondas.clear();
    _matchRecorded = false;
    _saveToPrefs();
    notifyListeners();
  }

  void _checkAndRecordMatch() {
    if (isGameOver && !_matchRecorded) {
      _matchRecorded = true;
      LeaderboardService().recordMatch(
        rawTeam1: _nombreE1,
        rawTeam2: _nombreE2,
        score1: totalE1,
        score2: totalE2,
        winnerTeam: ganador,
      );
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefKey);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        _metaPuntos = data['metaPuntos'] as int? ?? 200;
        _nombreE1 = data['nombreE1'] as String? ?? 'Pareja 1';
        _nombreE2 = data['nombreE2'] as String? ?? 'Pareja 2';
        _matchRecorded = data['matchRecorded'] as bool? ?? false;
        final rawRondas = data['rondas'] as List<dynamic>? ?? [];
        _rondas = rawRondas.map((r) => Round.fromMap(r as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'metaPuntos': _metaPuntos,
        'nombreE1': _nombreE1,
        'nombreE2': _nombreE2,
        'matchRecorded': _matchRecorded,
        'rondas': _rondas.map((r) => r.toMap()).toList(),
      };
      await prefs.setString(_prefKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }
}
