const express = require("express");
const router = express.Router();
const store = require("../models/store");

// GET /api/leagues - Lista pública de ligas
router.get("/", (req, res) => {
  const leagues = store.getAllLeaguesPublic();
  res.json({ success: true, leagues });
});

// POST /api/leagues - Crear nueva liga
router.post("/", (req, res) => {
  const { name, pin, initialParticipants } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ success: false, error: "El nombre de la liga es obligatorio." });
  }

  const league = store.createLeague({
    name,
    pin: pin || "1234",
    initialParticipants: initialParticipants || [],
  });

  res.status(201).json({ success: true, league });
});

// POST /api/leagues/join - Validar PIN y unirse a liga desde otro dispositivo
router.post("/join", (req, res) => {
  const { nameOrId, pin } = req.body;
  if (!nameOrId || !pin) {
    return res.status(400).json({ success: false, error: "Nombre/código de liga y PIN son requeridos." });
  }

  const league = store.findLeagueByNameOrId(nameOrId);
  if (!league) {
    return res.status(404).json({ success: false, error: "Liga no encontrada con el nombre o código ingresado." });
  }

  if (league.pin !== String(pin).trim()) {
    return res.status(401).json({ success: false, error: "Clave de acceso (PIN) incorrecta." });
  }

  res.json({ success: true, league });
});

// GET /api/leagues/:id - Obtener liga completa con participantes y rankings
router.get("/:id", (req, res) => {
  const league = store.getLeagueById(req.params.id);
  if (!league) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }
  res.json({ success: true, league });
});

// POST /api/leagues/:id/participants - Agregar participante
router.post("/:id/participants", (req, res) => {
  const { name } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ success: false, error: "Nombre de participante requerido." });
  }

  const updated = store.addParticipant(req.params.id, name);
  if (!updated) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }

  res.json({ success: true, participants: updated.participants });
});

// DELETE /api/leagues/:id/participants/:name - Eliminar participante
router.delete("/:id/participants/:name", (req, res) => {
  const updated = store.removeParticipant(req.params.id, decodeURIComponent(req.params.name));
  if (!updated) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }

  res.json({ success: true, participants: updated.participants });
});

// POST /api/leagues/:id/matches - Registrar partida oficial
router.post("/:id/matches", (req, res) => {
  const { team1DisplayName, team2DisplayName, team1Members, team2Members, score1, score2, winnerTeam } = req.body;

  if (!team1Members || !team2Members || team1Members.length === 0 || team2Members.length === 0) {
    return res.status(400).json({ success: false, error: "Se requieren los miembros de ambos equipos." });
  }

  const match = store.recordMatch(req.params.id, {
    team1DisplayName,
    team2DisplayName,
    team1Members,
    team2Members,
    score1: Number(score1) || 0,
    score2: Number(score2) || 0,
    winnerTeam: Number(winnerTeam) || 1,
  });

  if (!match) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }

  const league = store.getLeagueById(req.params.id);
  res.status(201).json({ success: true, match, league });
});

module.exports = router;
