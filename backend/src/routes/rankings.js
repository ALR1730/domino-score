const express = require("express");
const router = express.Router();
const store = require("../models/store");

// GET /api/rankings/global/teams - Mejores equipos de todas las ligas del servidor
router.get("/global/teams", (req, res) => {
  const { year, month } = req.query;
  const teams = store.getGlobalTeamsRanked({ year, month });
  const availableMonths = store.getAvailableMonths();
  res.json({ success: true, teams, availableMonths, selectedYear: year || null, selectedMonth: month || null });
});

// GET /api/rankings/global/players - Mejores jugadores individuales de todas las ligas
router.get("/global/players", (req, res) => {
  const { year, month } = req.query;
  const players = store.getGlobalPlayersRanked({ year, month });
  const availableMonths = store.getAvailableMonths();
  res.json({ success: true, players, availableMonths, selectedYear: year || null, selectedMonth: month || null });
});

// GET /api/rankings/league/:id - Rankings específicos de una liga
router.get("/league/:id", (req, res) => {
  const league = store.getLeagueById(req.params.id);
  if (!league) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }

  const { year, month } = req.query;
  const availableMonths = store.getAvailableMonths(req.params.id);

  if (year && month) {
    const { extractMembers, generateTeamKey, formatTeamDisplayName, removeDiacritics } = require("../utils/nameParser");
    const matches = (league.matches || []).filter((m) => {
      if (!m.date) return false;
      const d = new Date(m.date);
      return d.getFullYear() === Number(year) && d.getMonth() + 1 === Number(month);
    });

    const teamsMap = new Map();
    const playersMap = new Map();

    for (const m of matches) {
      const t1Members = Array.isArray(m.team1Members) ? m.team1Members : extractMembers(m.team1DisplayName || "");
      const key1 = generateTeamKey(t1Members);
      if (!teamsMap.has(key1)) {
        teamsMap.set(key1, {
          key: key1,
          displayName: m.team1DisplayName || formatTeamDisplayName(t1Members),
          members: t1Members,
          wins: 0,
          matchesPlayed: 0,
          totalPoints: 0,
        });
      }
      const t1 = teamsMap.get(key1);
      t1.matchesPlayed += 1;
      t1.totalPoints += Number(m.score1 || 0);
      if (Number(m.winnerTeam) === 1) t1.wins += 1;

      const t2Members = Array.isArray(m.team2Members) ? m.team2Members : extractMembers(m.team2DisplayName || "");
      const key2 = generateTeamKey(t2Members);
      if (!teamsMap.has(key2)) {
        teamsMap.set(key2, {
          key: key2,
          displayName: m.team2DisplayName || formatTeamDisplayName(t2Members),
          members: t2Members,
          wins: 0,
          matchesPlayed: 0,
          totalPoints: 0,
        });
      }
      const t2 = teamsMap.get(key2);
      t2.matchesPlayed += 1;
      t2.totalPoints += Number(m.score2 || 0);
      if (Number(m.winnerTeam) === 2) t2.wins += 1;

      // Players
      for (const name of t1Members) {
        const key = removeDiacritics(name.trim().toLowerCase());
        if (!playersMap.has(key)) playersMap.set(key, { key, name, wins: 0, matchesPlayed: 0 });
        const p = playersMap.get(key);
        p.matchesPlayed += 1;
        if (Number(m.winnerTeam) === 1) p.wins += 1;
      }
      for (const name of t2Members) {
        const key = removeDiacritics(name.trim().toLowerCase());
        if (!playersMap.has(key)) playersMap.set(key, { key, name, wins: 0, matchesPlayed: 0 });
        const p = playersMap.get(key);
        p.matchesPlayed += 1;
        if (Number(m.winnerTeam) === 2) p.wins += 1;
      }
    }

    const teams = Array.from(teamsMap.values()).map((t) => ({
      ...t,
      winRate: t.matchesPlayed > 0 ? (t.wins / t.matchesPlayed) * 100 : 0,
    }));
    teams.sort((a, b) => b.wins - a.wins || b.winRate - a.winRate || b.totalPoints - a.totalPoints);

    const players = Array.from(playersMap.values()).map((p) => ({
      ...p,
      winRate: p.matchesPlayed > 0 ? (p.wins / p.matchesPlayed) * 100 : 0,
    }));
    players.sort((a, b) => b.wins - a.wins || b.winRate - a.winRate);

    return res.json({
      success: true,
      leagueName: league.name,
      teams,
      players,
      availableMonths,
      selectedYear: year,
      selectedMonth: month,
    });
  }

  // Histórico completo
  const teams = Object.values(league.teams || {}).map((t) => ({
    ...t,
    winRate: t.matchesPlayed > 0 ? (t.wins / t.matchesPlayed) * 100 : 0,
  }));
  teams.sort((a, b) => b.wins - a.wins || b.winRate - a.winRate || b.totalPoints - a.totalPoints);

  const players = Object.values(league.players || {}).map((p) => ({
    ...p,
    winRate: p.matchesPlayed > 0 ? (p.wins / p.matchesPlayed) * 100 : 0,
  }));
  players.sort((a, b) => b.wins - a.wins || b.winRate - a.winRate);

  res.json({ success: true, leagueName: league.name, teams, players, availableMonths });
});

module.exports = router;
