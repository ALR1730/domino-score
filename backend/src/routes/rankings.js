const express = require("express");
const router = express.Router();
const store = require("../models/store");

// GET /api/rankings/global/teams - Mejores equipos de todas las ligas del servidor
router.get("/global/teams", (req, res) => {
  const teams = store.getGlobalTeamsRanked();
  res.json({ success: true, teams });
});

// GET /api/rankings/global/players - Mejores jugadores individuales de todas las ligas
router.get("/global/players", (req, res) => {
  const players = store.getGlobalPlayersRanked();
  res.json({ success: true, players });
});

// GET /api/rankings/league/:id - Rankings específicos de una liga
router.get("/league/:id", (req, res) => {
  const league = store.getLeagueById(req.params.id);
  if (!league) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }

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

  res.json({ success: true, leagueName: league.name, teams, players });
});

module.exports = router;
