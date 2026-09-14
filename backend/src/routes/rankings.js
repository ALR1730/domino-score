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

// POST /api/rankings/record-match - Registrar partida casual en ranking global
router.post("/record-match", (req, res) => {
  const { rawTeam1, rawTeam2, score1, score2, winnerTeam } = req.body;
  if (!rawTeam1 || !rawTeam2) {
    return res.status(400).json({ success: false, error: "Nombres de equipos requeridos." });
  }

  const match = store.recordCasualMatch({
    team1DisplayName: rawTeam1,
    team2DisplayName: rawTeam2,
    team1Members: [rawTeam1],
    team2Members: [rawTeam2],
    score1: Number(score1) || 0,
    score2: Number(score2) || 0,
    winnerTeam: Number(winnerTeam) || 1,
  });

  res.status(201).json({ success: true, match });
});

module.exports = router;
