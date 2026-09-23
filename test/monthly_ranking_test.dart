import 'package:flutter_test/flutter_test.dart';
import 'package:domino_score/models/league.dart';

void main() {
  test('Calcula correctamente rankings mensuales por parejas e individual', () {
    final league = League(
      id: 'LIG-TEST',
      name: 'Liga de Prueba',
      pin: '1234',
      createdAt: DateTime(2026, 8, 1),
    );

    // Partida 1 en Agosto 2026: Equipo A (Carlos, Juan) gana a Equipo B (Pedro, Luis)
    league.recordMatch(
      LeagueMatch(
        id: 'm-1',
        date: DateTime(2026, 8, 15, 14, 30),
        team1DisplayName: 'Carlos & Juan',
        team2DisplayName: 'Pedro & Luis',
        team1Members: ['Carlos', 'Juan'],
        team2Members: ['Pedro', 'Luis'],
        score1: 100,
        score2: 45,
        winnerTeam: 1,
      ),
    );

    // Partida 2 en Septiembre 2026: Equipo B (Pedro, Luis) gana a Equipo A (Carlos, Juan)
    league.recordMatch(
      LeagueMatch(
        id: 'm-2',
        date: DateTime(2026, 9, 10, 16, 0),
        team1DisplayName: 'Carlos & Juan',
        team2DisplayName: 'Pedro & Luis',
        team1Members: ['Carlos', 'Juan'],
        team2Members: ['Pedro', 'Luis'],
        score1: 70,
        score2: 100,
        winnerTeam: 2,
      ),
    );

    // Partida 3 en Septiembre 2026: Equipo B (Pedro, Luis) gana a Equipo C (Ana, Maria)
    league.recordMatch(
      LeagueMatch(
        id: 'm-3',
        date: DateTime(2026, 9, 20, 18, 0),
        team1DisplayName: 'Pedro & Luis',
        team2DisplayName: 'Ana & Maria',
        team1Members: ['Pedro', 'Luis'],
        team2Members: ['Ana', 'Maria'],
        score1: 100,
        score2: 50,
        winnerTeam: 1,
      ),
    );

    // 1. Probar meses disponibles
    final months = league.getAvailableMonths();
    expect(months.length, 2);
    expect(months[0].year, 2026);
    expect(months[0].month, 9);
    expect(months[1].year, 2026);
    expect(months[1].month, 8);

    // 2. Ranking de Parejas en Septiembre 2026
    final sepTeams = league.getTeamsRankedForMonth(year: 2026, month: 9);
    expect(sepTeams.length, 3);
    // En Septiembre: Equipo B tiene 2 victorias (2 PJ, 2 PG)
    expect(sepTeams[0].displayName, 'Pedro & Luis');
    expect(sepTeams[0].wins, 2);
    expect(sepTeams[0].matchesPlayed, 2);

    // 3. Ranking de Parejas en Agosto 2026
    final augTeams = league.getTeamsRankedForMonth(year: 2026, month: 8);
    expect(augTeams.length, 2);
    // En Agosto: Equipo A tiene 1 victoria (1 PJ, 1 PG)
    expect(augTeams[0].displayName, 'Carlos & Juan');
    expect(augTeams[0].wins, 1);

    // 4. Ranking Individual en Septiembre 2026
    final sepPlayers = league.getPlayersRankedForMonth(year: 2026, month: 9);
    final pedro = sepPlayers.firstWhere((p) => p.name == 'Pedro');
    final carlos = sepPlayers.firstWhere((p) => p.name == 'Carlos');
    expect(pedro.wins, 2);
    expect(carlos.wins, 0);

    // 5. Histórico Total (sin mes/año)
    final allTeams = league.getTeamsRankedForMonth();
    expect(allTeams.firstWhere((t) => t.displayName == 'Pedro & Luis').wins, 2);
    expect(allTeams.firstWhere((t) => t.displayName == 'Carlos & Juan').wins, 1);

    // 6. Histórico Total cuando teams/players están vacíos (ej. tras sincronización del servidor)
    final syncedLeague = League(
      id: 'LIG-SYNC',
      name: 'Liga Sincronizada',
      pin: '1234',
      createdAt: DateTime(2026, 8, 1),
      teams: {},
      players: {},
      matches: [
        LeagueMatch(
          id: 'm-sync-1',
          date: DateTime(2026, 9, 1),
          team1DisplayName: 'Alvaro & Roberto',
          team2DisplayName: 'Luis & Manuel',
          team1Members: ['Alvaro', 'Roberto'],
          team2Members: ['Luis', 'Manuel'],
          score1: 200,
          score2: 120,
          winnerTeam: 1,
        ),
      ],
    );
    final historicalTeams = syncedLeague.getTeamsRankedForMonth();
    expect(historicalTeams.length, 2);
    expect(historicalTeams.first.displayName, 'Alvaro & Roberto');
    expect(historicalTeams.first.wins, 1);
    expect(historicalTeams.first.totalPoints, 200);

    final historicalPlayers = syncedLeague.getPlayersRankedForMonth();
    expect(historicalPlayers.length, 4);
    expect(historicalPlayers.firstWhere((p) => p.name == 'Alvaro').wins, 1);
  });
}
