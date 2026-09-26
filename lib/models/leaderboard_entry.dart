class NameParser {
  static String removeDiacritics(String str) {
    const withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    const defaultDia = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';

    var result = str;
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], defaultDia[i]);
    }
    return result;
  }

  /// Extrae los miembros individuales de un equipo a partir de nombres como:
  /// "Juan y Pedro", "Carlos / Marcos", "Ana & Luis", "Maria, Pedro", etc.
  static List<String> extractMembers(String rawName) {
    final clean = rawName.trim();
    if (clean.isEmpty) return [];

    // Separadores comunes: ' y ', ' e ', ' & ', ' / ', ' - ', ',', ' + ', ' and '
    final regex = RegExp(r'\s+(?:y|e|and|&|\+|\/|-)\s+|[,/+\-&]', caseSensitive: false);
    final parts = clean
        .split(regex)
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return [_capitalize(clean)];
    }

    return parts.map((p) => _capitalize(p)).toList();
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Genera una clave única normalizada e independiente del orden de los miembros.
  /// Ej: "Juan y Pedro" y "Pedro y Juan" devuelven ambas: "juan_pedro"
  static String generateTeamKey(List<String> members) {
    if (members.isEmpty) return '';
    final normalized = members
        .map((m) => removeDiacritics(m.trim().toLowerCase()))
        .toList()
      ..sort();
    return normalized.join('_');
  }

  /// Genera un nombre de visualización estandarizado para la pareja / equipo
  static String formatTeamDisplayName(List<String> members) {
    if (members.isEmpty) return 'Equipo';
    if (members.length == 1) return members.first;
    if (members.length == 2) return '${members[0]} & ${members[1]}';
    return members.join(', ');
  }
}

class TeamStats {
  final String key;
  String displayName;
  final List<String> members;
  int wins;
  int matchesPlayed;
  int totalPoints;

  TeamStats({
    required this.key,
    required this.displayName,
    required this.members,
    this.wins = 0,
    this.matchesPlayed = 0,
    this.totalPoints = 0,
  });

  int get losses => matchesPlayed - wins;

  double get winRate {
    if (matchesPlayed == 0) return 0.0;
    return (wins / matchesPlayed) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'displayName': displayName,
      'members': members,
      'wins': wins,
      'matchesPlayed': matchesPlayed,
      'totalPoints': totalPoints,
    };
  }

  factory TeamStats.fromMap(Map<String, dynamic> map) {
    return TeamStats(
      key: map['key'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      members: (map['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      matchesPlayed: (map['matchesPlayed'] as num?)?.toInt() ?? 0,
      totalPoints: (map['totalPoints'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlayerStats {
  final String key;
  String name;
  int wins;
  int matchesPlayed;

  PlayerStats({
    required this.key,
    required this.name,
    this.wins = 0,
    this.matchesPlayed = 0,
  });

  int get losses => matchesPlayed - wins;

  double get winRate {
    if (matchesPlayed == 0) return 0.0;
    return (wins / matchesPlayed) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'name': name,
      'wins': wins,
      'matchesPlayed': matchesPlayed,
    };
  }

  factory PlayerStats.fromMap(Map<String, dynamic> map) {
    return PlayerStats(
      key: map['key'] as String? ?? '',
      name: map['name'] as String? ?? '',
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      matchesPlayed: (map['matchesPlayed'] as num?)?.toInt() ?? 0,
    );
  }
}
