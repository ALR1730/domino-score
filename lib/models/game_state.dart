import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'round.dart';

class GameState extends ChangeNotifier {
  final String storageKey;
  final bool isLeagueMode;

  int _metaPuntos = 200;
  String _nombreE1 = 'Nosotros';
  String _nombreE2 = 'Ellos';
  List<Round> _rondas = [];
  bool _isLoaded = false;
  bool _matchRecorded = false;

  GameState({
    this.storageKey = 'domino_casual_game_state_v2',
    String? initialNombreE1,
    String? initialNombreE2,
    int? initialMetaPuntos,
    this.isLeagueMode = false,
  }) {
    if (initialNombreE1 != null && initialNombreE1.trim().isNotEmpty) {
      _nombreE1 = initialNombreE1.trim();
    } else {
      _nombreE1 = isLeagueMode ? 'Equipo 1' : 'Nosotros';
    }

    if (initialNombreE2 != null && initialNombreE2.trim().isNotEmpty) {
      _nombreE2 = initialNombreE2.trim();
    } else {
      _nombreE2 = isLeagueMode ? 'Equipo 2' : 'Ellos';
    }

    if (initialMetaPuntos != null && initialMetaPuntos > 0) {
      _metaPuntos = initialMetaPuntos;
    }

    _loadFromPrefs(preserveCustomNames: initialNombreE1 != null || initialNombreE2 != null);
  }

  factory GameState.casual() {
    return GameState(
      storageKey: 'domino_casual_game_state_v2',
      initialNombreE1: 'Nosotros',
      initialNombreE2: 'Ellos',
      isLeagueMode: false,
    );
  }

  factory GameState.league({
    required String leagueId,
    required String team1Name,
    required String team2Name,
    int metaPuntos = 200,
  }) {
    return GameState(
      storageKey: 'domino_league_game_state_${leagueId.replaceAll('-', '_')}',
      initialNombreE1: team1Name,
      initialNombreE2: team2Name,
      initialMetaPuntos: metaPuntos,
      isLeagueMode: true,
    );
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
    // Las partidas casuales no afectan el ranking.
    // Solo las ligas oficiales registradas a través de LeagueService afectan el ranking.
  }

  Future<void> _loadFromPrefs({bool preserveCustomNames = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(storageKey);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (!preserveCustomNames) {
          _metaPuntos = data['metaPuntos'] as int? ?? _metaPuntos;
          _nombreE1 = data['nombreE1'] as String? ?? _nombreE1;
          _nombreE2 = data['nombreE2'] as String? ?? _nombreE2;
        }
        _matchRecorded = data['matchRecorded'] as bool? ?? false;
        final rawRondas = data['rondas'] as List<dynamic>? ?? [];
        _rondas = rawRondas.map((r) => Round.fromMap(r as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading preferences for $storageKey: $e');
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
      await prefs.setString(storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving preferences for $storageKey: $e');
    }
  }
}
