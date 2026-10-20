const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const mongo = require("../db/mongo");
const rankingsUtil = require("../utils/rankings");
const {
  generateTeamKey,
  formatTeamDisplayName,
  removeDiacritics,
} = require("../utils/nameParser");

const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, "../../data");
const DATA_FILE = path.join(DATA_DIR, "leagues.json");

class Store {
  constructor() {
    this.leagues = new Map();
    this.init();
  }

  init() {
    try {
      if (!fs.existsSync(DATA_DIR)) {
        fs.mkdirSync(DATA_DIR, { recursive: true });
      }

      if (fs.existsSync(DATA_FILE)) {
        const raw = fs.readFileSync(DATA_FILE, "utf-8");
        const list = JSON.parse(raw);
        for (const item of list) {
          if (item && item.id) {
            this.leagues.set(item.id, item);
          }
        }
      }

      this.saveLocal();
    } catch (err) {
      console.error("Error cargando store:", err);
    }
  }

  async loadFromMongo() {
    if (!mongo.connected) return;
    try {
      const col = mongo.getCollection("leagues");
      if (!col) return;
      const docs = await col.find({}).toArray();
      if (docs && docs.length > 0) {
        console.log(`📦 Cargando ${docs.length} ligas desde MongoDB...`);
        for (const doc of docs) {
          const { _id, ...leagueData } = doc;
          leagueData.id = leagueData.id || _id;
          if (leagueData.id) {
            this.leagues.set(leagueData.id, leagueData);
          }
        }
        console.log(`✅ ${this.leagues.size} ligas activas disponibles en memoria.`);
      } else if (this.leagues.size > 0) {
        console.log(`📤 Sembrando ${this.leagues.size} ligas existentes en MongoDB...`);
        for (const league of this.leagues.values()) {
          await this._upsertInMongo(col, league);
        }
      }
    } catch (err) {
      console.error("Error cargando ligas de MongoDB:", err.message);
      throw err; // que el arranque decida si esto es fatal (server.js)
    }
  }

  /** Instantánea local en disco (best-effort): fallback de desarrollo. */
  saveLocal() {
    try {
      if (!fs.existsSync(DATA_DIR)) {
        fs.mkdirSync(DATA_DIR, { recursive: true });
      }
      const data = Array.from(this.leagues.values());
      fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), "utf-8");
    } catch (err) {
      console.error("Error guardando store en disco:", err.message);
    }
  }

  async _upsertInMongo(col, league) {
    const doc = { ...league, _id: league.id, updatedAt: new Date().toISOString() };
    await col.updateOne({ _id: league.id }, { $set: doc }, { upsert: true });
  }

  /**
   * Persiste el estado. Si MongoDB está conectado, la escritura se ESPERA
   * (awaited) y sus errores se propagan: la API responde 500 en vez de
   * dar por buena una persistencia que falló.
   * @param {object|null} targetLeague solo se persiste esa liga (default: todas)
   */
  async save(targetLeague = null) {
    this.saveLocal();
    if (!mongo.connected) return;
    const col = mongo.getCollection("leagues");
    if (!col) return;

    if (targetLeague && targetLeague.id) {
      await this._upsertInMongo(col, targetLeague);
    } else {
      for (const league of this.leagues.values()) {
        await this._upsertInMongo(col, league);
      }
    }
  }

  getAllLeaguesPublic() {
    return Array.from(this.leagues.values())
      .filter((l) => l.id !== rankingsUtil.CASUAL_LEAGUE_ID)
      .map((l) => ({
        id: l.id,
        name: l.name,
        createdAt: l.createdAt,
        participantsCount: (l.participants || []).length,
        matchesCount: (l.matches || []).length,
        teamsCount: Object.keys(l.teams || {}).length,
      }));
  }

  getLeagueById(id) {
    return this.leagues.get(id) || null;
  }

  findLeagueByNameOrId(nameOrId) {
    const search = (nameOrId || "").trim().toLowerCase();
    for (const l of this.leagues.values()) {
      if (
        l.id.toLowerCase() === search ||
        (l.name && l.name.trim().toLowerCase() === search)
      ) {
        return l;
      }
    }
    return null;
  }

  async deleteLeague(id, pin) {
    const league = this.getLeagueById(id);
    if (!league) {
      return { success: false, error: "Liga no encontrada." };
    }
    if (!pin || String(pin).trim() !== league.pin) {
      return { success: false, error: "PIN incorrecto para eliminar la liga." };
    }

    // Mongo primero (awaited): si falla, la liga sigue existiendo y el
    // cliente recibe 500 y puede reintentar, sin estados a medias.
    if (mongo.connected) {
      const col = mongo.getCollection("leagues");
      if (col) {
        await col.deleteOne({ _id: id });
      }
    }

    this.leagues.delete(id);
    this.saveLocal();
    return { success: true };
  }

  async createLeague({ id, name, pin, initialParticipants = [] }) {
    const randomDigits = Math.floor(1000 + Math.random() * 9000);
    let leagueId = (id && String(id).trim()) || `LIG-${randomDigits}`;

    // Colisión de ID: nunca sobrescribir una liga existente
    while (this.leagues.has(leagueId)) {
      leagueId = `LIG-${Math.floor(1000 + Math.random() * 9000)}`;
    }

    const cleanParticipants = Array.isArray(initialParticipants)
      ? initialParticipants.map((p) => String(p).trim()).filter(Boolean)
      : [];

    const playersMap = {};
    for (const p of cleanParticipants) {
      const key = removeDiacritics(p.toLowerCase());
      playersMap[key] = { key, name: p, wins: 0, matchesPlayed: 0 };
    }

    const league = {
      id: leagueId,
      name: (name && name.trim()) || `Liga ${randomDigits}`,
      pin: (pin && String(pin).trim()) || String(1000 + Math.floor(Math.random() * 9000)),
      createdAt: new Date().toISOString(),
      participants: cleanParticipants,
      teams: {},
      players: playersMap,
      matches: [],
    };

    this.leagues.set(leagueId, league);
    await this.save(league);
    return league;
  }

  async syncLeague(leagueData) {
    if (!leagueData || !leagueData.id) return null;
    const id = String(leagueData.id).trim();
    let league = this.getLeagueById(id);

    if (!league) {
      league = await this.createLeague({
        id,
        name: leagueData.name || id,
        pin: leagueData.pin || "1234",
        initialParticipants: leagueData.participants || [],
      });
    } else {
      // El PIN almacenado NUNCA se modifica desde sync: es el secreto que
      // autoriza a unirse/eliminar. (La validación del PIN ocurre en la ruta.)
      if (leagueData.name && leagueData.name.trim()) league.name = leagueData.name.trim();
      if (Array.isArray(leagueData.participants)) {
        for (const p of leagueData.participants) {
          this.addParticipant(id, p, { persist: false });
        }
      }
    }

    if (Array.isArray(leagueData.matches)) {
      for (const m of leagueData.matches) {
        if (!m) continue;
        const matchId = String(m.id || "");
        if (!league.matches.some((existing) => String(existing.id) === matchId)) {
          await this.recordMatch(id, {
            id: matchId,
            date: m.date,
            team1DisplayName: m.team1DisplayName,
            team2DisplayName: m.team2DisplayName,
            team1Members: m.team1Members,
            team2Members: m.team2Members,
            score1: Number(m.score1) || 0,
            score2: Number(m.score2) || 0,
            winnerTeam: Number(m.winnerTeam) || 1,
          }, { persist: false });
        }
      }
    }

    await this.save(league);
    return this.getLeagueById(id);
  }

  async addParticipant(leagueId, participantName, { persist = true } = {}) {
    const league = this.getLeagueById(leagueId);
    if (!league) return null;

    const clean = String(participantName).trim();
    if (!clean) return league;

    if (!league.participants.some((p) => p.toLowerCase() === clean.toLowerCase())) {
      league.participants.push(clean);
      const key = removeDiacritics(clean.toLowerCase());
      if (!league.players[key]) {
        league.players[key] = { key, name: clean, wins: 0, matchesPlayed: 0 };
      }
      if (persist) await this.save(league);
    }
    return league;
  }

  async removeParticipant(leagueId, participantName, { persist = true } = {}) {
    const league = this.getLeagueById(leagueId);
    if (!league) return null;

    const target = String(participantName).trim().toLowerCase();
    league.participants = league.participants.filter(
      (p) => p.toLowerCase() !== target
    );
    if (persist) await this.save(league);
    return league;
  }

  async recordMatch(leagueId, matchData, { persist = true } = {}) {
    let league = this.getLeagueById(leagueId);
    if (!league) {
      const members = [...(matchData.team1Members || []), ...(matchData.team2Members || [])];
      league = await this.createLeague({
        id: leagueId,
        name: matchData.leagueName || `Liga ${leagueId}`,
        pin: matchData.pin || "1234",
        initialParticipants: members,
      });
    }

    const {
      id: customMatchId,
      date,
      team1DisplayName,
      team2DisplayName,
      team1Members = [],
      team2Members = [],
      score1 = 0,
      score2 = 0,
      winnerTeam = 1,
    } = matchData;

    // crypto.randomUUID: sin colisiones prácticas (antes Date.now + aleatorio)
    const matchId = customMatchId || `match_${crypto.randomUUID()}`;

    // Evitar contar partidas duplicadas
    const duplicated = league.matches.find((m) => String(m.id) === String(matchId));
    if (duplicated) return duplicated;

    const match = {
      id: matchId,
      date: date || new Date().toISOString(),
      team1DisplayName: team1DisplayName || formatTeamDisplayName(team1Members),
      team2DisplayName: team2DisplayName || formatTeamDisplayName(team2Members),
      team1Members,
      team2Members,
      score1,
      score2,
      winnerTeam: Number(winnerTeam),
    };

    league.matches.unshift(match);

    // Update Team 1
    const key1 = generateTeamKey(team1Members);
    if (key1) {
      if (!league.teams[key1]) {
        league.teams[key1] = {
          key: key1,
          displayName: match.team1DisplayName,
          members: team1Members,
          wins: 0,
          matchesPlayed: 0,
          totalPoints: 0,
        };
      }
      league.teams[key1].matchesPlayed += 1;
      league.teams[key1].totalPoints += score1;
      if (winnerTeam === 1) league.teams[key1].wins += 1;
    }

    // Update Team 2
    const key2 = generateTeamKey(team2Members);
    if (key2) {
      if (!league.teams[key2]) {
        league.teams[key2] = {
          key: key2,
          displayName: match.team2DisplayName,
          members: team2Members,
          wins: 0,
          matchesPlayed: 0,
          totalPoints: 0,
        };
      }
      league.teams[key2].matchesPlayed += 1;
      league.teams[key2].totalPoints += score2;
      if (winnerTeam === 2) league.teams[key2].wins += 1;
    }

    // Update individual players
    for (const m of team1Members) {
      const key = removeDiacritics(String(m).trim().toLowerCase());
      if (!league.players[key]) {
        league.players[key] = { key, name: m, wins: 0, matchesPlayed: 0 };
      }
      league.players[key].matchesPlayed += 1;
      if (winnerTeam === 1) league.players[key].wins += 1;
    }

    for (const m of team2Members) {
      const key = removeDiacritics(String(m).trim().toLowerCase());
      if (!league.players[key]) {
        league.players[key] = { key, name: m, wins: 0, matchesPlayed: 0 };
      }
      league.players[key].matchesPlayed += 1;
      if (winnerTeam === 2) league.players[key].wins += 1;
    }

    if (persist) await this.save(league);
    return match;
  }

  getAvailableMonths(leagueId = null) {
    const targetLeagues = leagueId
      ? this.leagues.has(leagueId)
        ? [this.leagues.get(leagueId)]
        : []
      : Array.from(this.leagues.values());
    return rankingsUtil.availableMonths(targetLeagues);
  }

  getGlobalTeamsRanked(options = {}) {
    return rankingsUtil.rankGlobal(this.leagues.values(), options).teams;
  }

  getGlobalPlayersRanked(options = {}) {
    return rankingsUtil.rankGlobal(this.leagues.values(), options).players;
  }
}

module.exports = new Store();
