import 'dart:convert';
import 'leaderboard_entry.dart';

class LeagueMatch {
  final String id;
  final DateTime date;
  final String team1DisplayName;
  final String team2DisplayName;
  final List<String> team1Members;
  final List<String> team2Members;
  final int score1;
  final int score2;
  final int winnerTeam; // 1 or 2

  LeagueMatch({
    required this.id,
    required this.date,
    required this.team1DisplayName,
    required this.team2DisplayName,
    required this.team1Members,
    required this.team2Members,
    required this.score1,
    required this.score2,
    required this.winnerTeam,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'team1DisplayName': team1DisplayName,
      'team2DisplayName': team2DisplayName,
      'team1Members': team1Members,
      'team2Members': team2Members,
      'score1': score1,
      'score2': score2,
      'winnerTeam': winnerTeam,
    };
  }

  factory LeagueMatch.fromMap(Map<String, dynamic> map) {
    return LeagueMatch(
      id: map['id'] as String? ?? '',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      team1DisplayName: map['team1DisplayName'] as String? ?? '',
      team2DisplayName: map['team2DisplayName'] as String? ?? '',
      team1Members: (map['team1Members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      team2Members: (map['team2Members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      score1: map['score1'] as int? ?? 0,
      score2: map['score2'] as int? ?? 0,
      winnerTeam: map['winnerTeam'] as int? ?? 1,
    );
  }
}

class League {
  final String id;
  String name;
  String pin; // Clave de acceso para unirse desde otros dispositivos
  final DateTime createdAt;
  List<String> participants;
  Map<String, TeamStats> teams;
  Map<String, PlayerStats> players;
  List<LeagueMatch> matches;

  League({
    required this.id,
    required this.name,
    required this.pin,
    required this.createdAt,
    List<String>? participants,
    Map<String, TeamStats>? teams,
    Map<String, PlayerStats>? players,
    List<LeagueMatch>? matches,
  })  : participants = participants ?? [],
        teams = teams ?? {},
        players = players ?? {},
        matches = matches ?? [];

  List<TeamStats> get teamsRanked {
    final list = teams.values.toList();
    list.sort((a, b) {
      final winsCmp = b.wins.compareTo(a.wins);
      if (winsCmp != 0) return winsCmp;
      final rateCmp = b.winRate.compareTo(a.winRate);
      if (rateCmp != 0) return rateCmp;
      return b.totalPoints.compareTo(a.totalPoints);
    });
    return list;
  }

  List<PlayerStats> get playersRanked {
    final list = players.values.toList();
    list.sort((a, b) {
      final winsCmp = b.wins.compareTo(a.wins);
      if (winsCmp != 0) return winsCmp;
      return b.winRate.compareTo(a.winRate);
    });
    return list;
  }

  void addParticipant(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    if (!participants.any((p) => p.toLowerCase() == clean.toLowerCase())) {
      participants.add(clean);
      // Ensure player stat entry exists
      final key = NameParser.removeDiacritics(clean.toLowerCase());
      players.putIfAbsent(key, () => PlayerStats(key: key, name: clean));
    }
  }

  void removeParticipant(String name) {
    participants.removeWhere((p) => p.toLowerCase() == name.trim().toLowerCase());
  }

  void recordMatch(LeagueMatch match) {
    matches.insert(0, match);

    // Update Team 1
    final key1 = NameParser.generateTeamKey(match.team1Members);
    final team1 = teams.putIfAbsent(
      key1,
      () => TeamStats(
        key: key1,
        displayName: match.team1DisplayName,
        members: match.team1Members,
      ),
    );
    team1.matchesPlayed += 1;
    team1.totalPoints += match.score1;
    if (match.winnerTeam == 1) {
      team1.wins += 1;
    }

    // Update Team 2
    final key2 = NameParser.generateTeamKey(match.team2Members);
    final team2 = teams.putIfAbsent(
      key2,
      () => TeamStats(
        key: key2,
        displayName: match.team2DisplayName,
        members: match.team2Members,
      ),
    );
    team2.matchesPlayed += 1;
    team2.totalPoints += match.score2;
    if (match.winnerTeam == 2) {
      team2.wins += 1;
    }

    // Update individual players
    for (final m in match.team1Members) {
      final key = NameParser.removeDiacritics(m.trim().toLowerCase());
      final player = players.putIfAbsent(key, () => PlayerStats(key: key, name: m));
      player.matchesPlayed += 1;
      if (match.winnerTeam == 1) player.wins += 1;
    }

    for (final m in match.team2Members) {
      final key = NameParser.removeDiacritics(m.trim().toLowerCase());
      final player = players.putIfAbsent(key, () => PlayerStats(key: key, name: m));
      player.matchesPlayed += 1;
      if (match.winnerTeam == 2) player.wins += 1;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pin': pin,
      'createdAt': createdAt.toIso8601String(),
      'participants': participants,
      'teams': teams.map((k, v) => MapEntry(k, v.toMap())),
      'players': players.map((k, v) => MapEntry(k, v.toMap())),
      'matches': matches.map((m) => m.toMap()).toList(),
    };
  }

  factory League.fromMap(Map<String, dynamic> map) {
    final teamsMap = <String, TeamStats>{};
    if (map['teams'] != null) {
      (map['teams'] as Map<String, dynamic>).forEach((k, v) {
        teamsMap[k] = TeamStats.fromMap(v as Map<String, dynamic>);
      });
    }

    final playersMap = <String, PlayerStats>{};
    if (map['players'] != null) {
      (map['players'] as Map<String, dynamic>).forEach((k, v) {
        playersMap[k] = PlayerStats.fromMap(v as Map<String, dynamic>);
      });
    }

    final matchesList = <LeagueMatch>[];
    if (map['matches'] != null) {
      for (final m in (map['matches'] as List<dynamic>)) {
        matchesList.add(LeagueMatch.fromMap(m as Map<String, dynamic>));
      }
    }

    return League(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Liga',
      pin: map['pin'] as String? ?? '1234',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      participants: (map['participants'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      teams: teamsMap,
      players: playersMap,
      matches: matchesList,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory League.fromJson(String source) => League.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
