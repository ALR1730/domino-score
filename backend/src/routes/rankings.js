const express = require("express");
const router = express.Router();
const leagueService = require("../services/leagueService");
const asyncHandler = require("../middleware/asyncHandler");
const { rankLeague } = require("../utils/rankings");
const { sendApiError } = require("../utils/problemDetails");
const {
  validateMonthQuery,
  validateLeagueId,
} = require("../validation/leagueSchemas");

// GET /api/rankings/global/teams - Mejores equipos de todas las ligas del servidor
router.get(
  "/global/teams",
  asyncHandler(async (req, res) => {
    const q = validateMonthQuery(req.query);
    if (!q.ok) {
      return sendApiError(req, res, { status: q.status, detail: q.error });
    }

    const filter = {
      tzOffsetMinutes: q.data.tzOffsetMinutes,
      ...(q.data.year !== null
        ? { year: q.data.year, month: q.data.month }
        : {}),
    };
    const [teams, availableMonths] = await Promise.all([
      leagueService.getGlobalTeamsRanked(filter),
      leagueService.getAvailableMonths(null, q.data.tzOffsetMinutes),
    ]);
    res.json({
      success: true,
      teams,
      availableMonths,
      selectedYear: q.data.year !== null ? String(q.data.year) : null,
      selectedMonth: q.data.month !== null ? String(q.data.month) : null,
    });
  })
);

// GET /api/rankings/global/players - Mejores jugadores individuales de todas las ligas
router.get(
  "/global/players",
  asyncHandler(async (req, res) => {
    const q = validateMonthQuery(req.query);
    if (!q.ok) {
      return sendApiError(req, res, { status: q.status, detail: q.error });
    }

    const filter = {
      tzOffsetMinutes: q.data.tzOffsetMinutes,
      ...(q.data.year !== null
        ? { year: q.data.year, month: q.data.month }
        : {}),
    };
    const [players, availableMonths] = await Promise.all([
      leagueService.getGlobalPlayersRanked(filter),
      leagueService.getAvailableMonths(null, q.data.tzOffsetMinutes),
    ]);
    res.json({
      success: true,
      players,
      availableMonths,
      selectedYear: q.data.year !== null ? String(q.data.year) : null,
      selectedMonth: q.data.month !== null ? String(q.data.month) : null,
    });
  })
);

// GET /api/rankings/league/:id - Rankings específicos de una liga
router.get(
  "/league/:id",
  asyncHandler(async (req, res) => {
    const idCheck = validateLeagueId(req.params.id);
    if (!idCheck.ok) {
      return sendApiError(req, res, {
        status: idCheck.status,
        detail: idCheck.error,
      });
    }

    const q = validateMonthQuery(req.query);
    if (!q.ok) {
      return sendApiError(req, res, { status: q.status, detail: q.error });
    }

    const league = await leagueService.getLeagueById(idCheck.data);
    if (!league) {
      return sendApiError(req, res, {
        status: 404,
        detail: "Liga no encontrada.",
      });
    }

    const filter = {
      tzOffsetMinutes: q.data.tzOffsetMinutes,
      ...(q.data.year !== null
        ? { year: q.data.year, month: q.data.month }
        : {}),
    };
    const availableMonths = await leagueService.getAvailableMonths(
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
  })
);

module.exports = router;
