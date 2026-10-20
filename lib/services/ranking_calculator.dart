import '../models/leaderboard_entry.dart';
import '../models/league.dart';

/// Agregación y ordenamiento de rankings — implementación única.
///
/// Antes esta lógica estaba duplicada en `League`, `LeagueService` y
/// `LeaderboardService` (más una copia parcial en las pantallas). Ahora
/// todos delegan aquí. Funciones puras: no tocan estado ni persistencia.
class RankingCalculator {
  RankingCalculator._();

  // --- Ordenamiento ---

  /// Equipos: victorias desc → winRate desc → puntos totales desc.
  static List<TeamStats> sortTeams(Iterable<TeamStats> teams) {
    final list = teams.toList();
    list.sort((a, b) {
      final winsCmp = b.wins.compareTo(a.wins);
      if (winsCmp != 0) return winsCmp;
      final rateCmp = b.winRate.compareTo(a.winRate);
      if (rateCmp != 0) return rateCmp;
      return b.totalPoints.compareTo(a.totalPoints);
    });
    return list;
  }

  /// Jugadores: victorias desc → winRate desc.
  static List<PlayerStats> sortPlayers(Iterable<PlayerStats> players) {
    final list = players.toList();
    list.sort((a, b) {
      final winsCmp = b.wins.compareTo(a.wins);
      if (winsCmp != 0) return winsCmp;
      return b.winRate.compareTo(a.winRate);
    });
    return list;
  }

  // --- Agregación desde partidas ---

  /// Acumula en [target] las estadísticas de equipos derivadas de [matches].
  /// Si una clave ya existe en [target] (p. ej. al combinar varias ligas),
  /// sus contadores se suman.
  static void aggregateTeamsInto(
    Map<String, TeamStats> target,
    Iterable<LeagueMatch> matches,
  ) {
    for (final m in matches) {
      final key1 = NameParser.generateTeamKey(m.team1Members);
      final t1 = target.putIfAbsent(
        key1,
        () => TeamStats(
          key: key1,
          displayName: m.team1DisplayName,
          members: List.from(m.team1Members),
        ),
      );
      t1.matchesPlayed += 1;
      t1.totalPoints += m.score1;
      if (m.winnerTeam == 1) t1.wins += 1;

      final key2 = NameParser.generateTeamKey(m.team2Members);
      final t2 = target.putIfAbsent(
        key2,
        () => TeamStats(
          key: key2,
          displayName: m.team2DisplayName,
          members: List.from(m.team2Members),
        ),
      );
      t2.matchesPlayed += 1;
      t2.totalPoints += m.score2;
      if (m.winnerTeam == 2) t2.wins += 1;
    }
  }

  /// Acumula en [target] las estadísticas individuales de [matches].
  static void aggregatePlayersInto(
    Map<String, PlayerStats> target,
    Iterable<LeagueMatch> matches,
  ) {
    for (final m in matches) {
      for (final name in m.team1Members) {
        final key = NameParser.removeDiacritics(name.trim().toLowerCase());
        if (key.isEmpty) continue;
        final p =
            target.putIfAbsent(key, () => PlayerStats(key: key, name: name));
        p.matchesPlayed += 1;
        if (m.winnerTeam == 1) p.wins += 1;
      }

      for (final name in m.team2Members) {
        final key = NameParser.removeDiacritics(name.trim().toLowerCase());
        if (key.isEmpty) continue;
        final p =
            target.putIfAbsent(key, () => PlayerStats(key: key, name: name));
        p.matchesPlayed += 1;
        if (m.winnerTeam == 2) p.wins += 1;
      }
    }
  }

  // --- Fusión de agregados preexistentes (estadísticas ya calculadas) ---

  /// Fusiona en [target] las estadísticas almacenadas en [source].
  /// Se usa como fallback histórico cuando una liga no tiene partidas.
  static void mergeTeamsInto(
    Map<String, TeamStats> target,
    Map<String, TeamStats> source,
  ) {
    source.forEach((key, team) {
      final existing = target[key];
      if (existing == null) {
        target[key] = TeamStats(
          key: team.key,
          displayName: team.displayName,
          members: List.from(team.members),
          wins: team.wins,
          matchesPlayed: team.matchesPlayed,
          totalPoints: team.totalPoints,
        );
      } else {
        existing.wins += team.wins;
        existing.matchesPlayed += team.matchesPlayed;
        existing.totalPoints += team.totalPoints;
      }
    });
  }

  /// Igual que [mergeTeamsInto] pero para estadísticas individuales.
  static void mergePlayersInto(
    Map<String, PlayerStats> target,
    Map<String, PlayerStats> source,
  ) {
    source.forEach((key, player) {
      final existing = target[key];
      if (existing == null) {
        target[key] = PlayerStats(
          key: player.key,
          name: player.name,
          wins: player.wins,
          matchesPlayed: player.matchesPlayed,
        );
      } else {
        existing.wins += player.wins;
        existing.matchesPlayed += player.matchesPlayed;
      }
    });
  }

  // --- Atajos: agregar + ordenar ---

  static List<TeamStats> rankTeamsFromMatches(Iterable<LeagueMatch> matches) {
    final aggregate = <String, TeamStats>{};
    aggregateTeamsInto(aggregate, matches);
    return sortTeams(aggregate.values);
  }

  static List<PlayerStats> rankPlayersFromMatches(
      Iterable<LeagueMatch> matches) {
    final aggregate = <String, PlayerStats>{};
    aggregatePlayersInto(aggregate, matches);
    return sortPlayers(aggregate.values);
  }
}
