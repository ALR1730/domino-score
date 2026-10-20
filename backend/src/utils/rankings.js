/**
 * Agregación de rankings — módulo puro y único.
 *
 * Antes esta lógica estaba duplicada en `store.js` y `routes/rankings.js`;
 * ahora ambas rutas comparten estas funciones. Todo el bucketing de meses
 * se hace en UTC para que el resultado no dependa de la zona horaria del
 * servidor.
 */
const {
  extractMembers,
  generateTeamKey,
  formatTeamDisplayName,
  removeDiacritics,
} = require("./nameParser");

const CASUAL_LEAGUE_ID = "LIG-CASUAL"; // las partidas casuales nunca puntúan

/** "2026-10" a partir de una fecha ISO; null si la fecha es inválida. */
function monthKey(dateInput) {
  const d = dateInput instanceof Date ? dateInput : new Date(dateInput);
  if (Number.isNaN(d.getTime())) return null;
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

function monthKeyOf(year, month) {
  const y = Number(year);
  const m = Number(month);
  if (!Number.isInteger(y) || !Number.isInteger(m)) return null;
  return `${y}-${String(m).padStart(2, "0")}`;
}

/** Meses con al menos una partida, en formato "YYYY-MM", orden desc. */
function availableMonths(leagues) {
  const set = new Set();
  for (const league of leagues) {
    for (const m of league.matches || []) {
      const key = monthKey(m.date);
      if (key) set.add(key);
    }
  }
  return Array.from(set).sort().reverse();
}

function sortTeams(list) {
  return list.sort(
    (a, b) =>
      b.wins - a.wins ||
      b.winRate - a.winRate ||
      b.totalPoints - a.totalPoints
  );
}

function sortPlayers(list) {
  return list.sort((a, b) => b.wins - a.wins || b.winRate - a.winRate);
}

/** Agrega estadísticas de equipos a partir de una lista de partidas. */
function aggregateTeamsFromMatches(matches) {
  const aggregate = new Map();

  for (const m of matches) {
    const t1Members = Array.isArray(m.team1Members)
      ? m.team1Members
      : extractMembers(m.team1DisplayName || "");
    const key1 = generateTeamKey(t1Members);
    if (!key1) continue;
    if (!aggregate.has(key1)) {
      aggregate.set(key1, {
        key: key1,
        displayName: m.team1DisplayName || formatTeamDisplayName(t1Members),
        members: t1Members,
        wins: 0,
        matchesPlayed: 0,
        totalPoints: 0,
      });
    }
    const t1 = aggregate.get(key1);
    t1.matchesPlayed += 1;
    t1.totalPoints += Number(m.score1 || 0);
    if (m.winnerTeam === 1) t1.wins += 1;

    const t2Members = Array.isArray(m.team2Members)
      ? m.team2Members
      : extractMembers(m.team2DisplayName || "");
    const key2 = generateTeamKey(t2Members);
    if (!key2) continue;
    if (!aggregate.has(key2)) {
      aggregate.set(key2, {
        key: key2,
        displayName: m.team2DisplayName || formatTeamDisplayName(t2Members),
        members: t2Members,
        wins: 0,
        matchesPlayed: 0,
        totalPoints: 0,
      });
    }
    const t2 = aggregate.get(key2);
    t2.matchesPlayed += 1;
    t2.totalPoints += Number(m.score2 || 0);
    if (m.winnerTeam === 2) t2.wins += 1;
  }

  const list = Array.from(aggregate.values()).map((t) => ({
    ...t,
    winRate: t.matchesPlayed > 0 ? (t.wins / t.matchesPlayed) * 100 : 0,
  }));
  return sortTeams(list);
}

/** Agrega estadísticas individuales a partir de una lista de partidas. */
function aggregatePlayersFromMatches(matches) {
  const aggregate = new Map();

  for (const m of matches) {
    const t1Members = Array.isArray(m.team1Members)
      ? m.team1Members
      : extractMembers(m.team1DisplayName || "");
    for (const name of t1Members) {
      const key = removeDiacritics(String(name).trim().toLowerCase());
      if (!key) continue;
      if (!aggregate.has(key)) {
        aggregate.set(key, { key, name, wins: 0, matchesPlayed: 0 });
      }
      const p = aggregate.get(key);
      p.matchesPlayed += 1;
      if (m.winnerTeam === 1) p.wins += 1;
    }

    const t2Members = Array.isArray(m.team2Members)
      ? m.team2Members
      : extractMembers(m.team2DisplayName || "");
    for (const name of t2Members) {
      const key = removeDiacritics(String(name).trim().toLowerCase());
      if (!key) continue;
      if (!aggregate.has(key)) {
        aggregate.set(key, { key, name, wins: 0, matchesPlayed: 0 });
      }
      const p = aggregate.get(key);
      p.matchesPlayed += 1;
      if (m.winnerTeam === 2) p.wins += 1;
    }
  }

  const list = Array.from(aggregate.values()).map((p) => ({
    ...p,
    winRate: p.matchesPlayed > 0 ? (p.wins / p.matchesPlayed) * 100 : 0,
  }));
  return sortPlayers(list);
}

/** Rankings globales (todas las ligas oficiales), opcionalmente de un mes. */
function rankGlobal(leagues, { year, month } = {}) {
  const targetMonth = monthKeyOf(year, month);
  const matches = [];

  for (const league of leagues) {
    if (league.id === CASUAL_LEAGUE_ID) continue;
    for (const m of league.matches || []) {
      if (!m) continue;
      if (targetMonth && monthKey(m.date) !== targetMonth) continue;
      matches.push(m);
    }
  }

  return {
    teams: aggregateTeamsFromMatches(matches),
    players: aggregatePlayersFromMatches(matches),
  };
}

/** Rankings de una liga específica. Histórico = mapas agregados almacenados. */
function rankLeague(league, { year, month } = {}) {
  const targetMonth = monthKeyOf(year, month);

  if (targetMonth) {
    const matches = (league.matches || []).filter(
      (m) => m && monthKey(m.date) === targetMonth
    );
    return {
      teams: aggregateTeamsFromMatches(matches),
      players: aggregatePlayersFromMatches(matches),
    };
  }

  const teams = Object.values(league.teams || {}).map((t) => ({
    ...t,
    winRate: t.matchesPlayed > 0 ? (t.wins / t.matchesPlayed) * 100 : 0,
  }));
  const players = Object.values(league.players || {}).map((p) => ({
    ...p,
    winRate: p.matchesPlayed > 0 ? (p.wins / p.matchesPlayed) * 100 : 0,
  }));
  return { teams: sortTeams(teams), players: sortPlayers(players) };
}

module.exports = {
  CASUAL_LEAGUE_ID,
  monthKey,
  monthKeyOf,
  availableMonths,
  aggregateTeamsFromMatches,
  aggregatePlayersFromMatches,
  rankGlobal,
  rankLeague,
  sortTeams,
  sortPlayers,
};
