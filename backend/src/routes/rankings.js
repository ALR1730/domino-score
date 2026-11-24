const express = require("express");
const router = express.Router();
const store = require("../models/store");
const { rankLeague } = require("../utils/rankings");
const {
  validateMonthQuery,
  validateLeagueId,
} = require("../validation/leagueSchemas");

// GET /api/rankings/global/teams - Mejores equipos de todas las ligas del servidor
router.get("/global/teams", (req, res) => {
  const q = validateMonthQuery(req.query);
  if (!q.ok) {
    return res.status(q.status).json({ success: false, error: q.error });
  }

  const filter = {
    tzOffsetMinutes: q.data.tzOffsetMinutes,
    ...(q.data.year !== null ? { year: q.data.year, month: q.data.month } : {}),
  };
  const teams = store.getGlobalTeamsRanked(filter);
  const availableMonths = store.getAvailableMonths(null, q.data.tzOffsetMinutes);
  res.json({
    success: true,
    teams,
    availableMonths,
    selectedYear: q.data.year !== null ? String(q.data.year) : null,
    selectedMonth: q.data.month !== null ? String(q.data.month) : null,
  });
});

// GET /api/rankings/global/players - Mejores jugadores individuales de todas las ligas
router.get("/global/players", (req, res) => {
  const q = validateMonthQuery(req.query);
  if (!q.ok) {
    return res.status(q.status).json({ success: false, error: q.error });
  }

  const filter = {
    tzOffsetMinutes: q.data.tzOffsetMinutes,
    ...(q.data.year !== null ? { year: q.data.year, month: q.data.month } : {}),
  };
  const players = store.getGlobalPlayersRanked(filter);
  const availableMonths = store.getAvailableMonths(null, q.data.tzOffsetMinutes);
  res.json({
    success: true,
    players,
    availableMonths,
    selectedYear: q.data.year !== null ? String(q.data.year) : null,
    selectedMonth: q.data.month !== null ? String(q.data.month) : null,
  });
});

// GET /api/rankings/league/:id - Rankings específicos de una liga
router.get("/league/:id", (req, res) => {
  const idCheck = validateLeagueId(req.params.id);
  if (!idCheck.ok) {
    return res.status(idCheck.status).json({ success: false, error: idCheck.error });
  }

  const q = validateMonthQuery(req.query);
  if (!q.ok) {
    return res.status(q.status).json({ success: false, error: q.error });
  }

  const league = store.getLeagueById(idCheck.data);
  if (!league) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }

  const filter = {
    tzOffsetMinutes: q.data.tzOffsetMinutes,
    ...(q.data.year !== null ? { year: q.data.year, month: q.data.month } : {}),
  };
  const availableMonths = store.getAvailableMonths(
    idCheck.data,
    q.data.tzOffsetMinutes
  );
  const { teams, players } = rankLeague(league, filter);

  res.json({
    success: true,
    leagueName: league.name,
    teams,
    players,
    availableMonths,
    selectedYear: q.data.year !== null ? String(q.data.year) : null,
    selectedMonth: q.data.month !== null ? String(q.data.month) : null,
  });
});

module.exports = router;
