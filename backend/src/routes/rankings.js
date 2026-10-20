const express = require("express");
const router = express.Router();
const store = require("../models/store");
const { rankLeague } = require("../utils/rankings");

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
// (mensual con ?year&month, o histórico completo sin parámetros)
router.get("/league/:id", (req, res) => {
  const league = store.getLeagueById(req.params.id);
  if (!league) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }

  const { year, month } = req.query;
  const availableMonths = store.getAvailableMonths(req.params.id);
  const { teams, players } = rankLeague(league, { year, month });

  res.json({
    success: true,
    leagueName: league.name,
    teams,
    players,
    availableMonths,
    selectedYear: year || null,
    selectedMonth: month || null,
  });
});

module.exports = router;
