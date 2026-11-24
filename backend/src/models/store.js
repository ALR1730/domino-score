const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const mongo = require("../db/mongo");
const rankingsUtil = require("../utils/rankings");
const { generateRandomPin, pinMatches } = require("../utils/pin");
const {
  extractMembers,
  generateTeamKey,
  formatTeamDisplayName,
  removeDiacritics,
} = require("../utils/nameParser");

const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, "../../data");
const DATA_FILE = path.join(DATA_DIR, "leagues.json");
const MAX_ID_ATTEMPTS = 20;

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
      throw err;
    }
  }

  /** Instantánea local en disco (best-effort): solo cuando no hay MongoDB activo. */
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
   * Persiste una liga candidata siguiendo orden Mongo-first: primero
   * confirma la escritura en Atlas y recién después actualiza la caché en RAM.
   */
  async _commitLeague(candidate) {
    if (mongo.connected) {
      const col = mongo.getCollection("leagues");
      if (col) {
        await this._upsertInMongo(col, candidate);
      }
      this.leagues.set(candidate.id, candidate);
      return candidate;
    }

    this.leagues.set(candidate.id, candidate);
    this.saveLocal();
    return candidate;
  }

  /**
   * Persiste el estado. Con MongoDB activo omite escritura síncrona a disco
   * para no bloquear el event loop.
   */
  async save(targetLeague = null) {
    if (!mongo.connected) {
      this.saveLocal();
      return;
    }
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

  _generateUniqueLeagueId(requestedId = null) {
    const cleanRequested =
      typeof requestedId === "string" ? requestedId.trim() : "";
    if (cleanRequested && !this.leagues.has(cleanRequested)) {
      return cleanRequested;
    }

    for (let i = 0; i < MAX_ID_ATTEMPTS; i++) {
      const candidate = `LIG-${crypto.randomInt(1000, 10000)}`;
      if (!this.leagues.has(candidate)) return candidate;
    }

    for (let i = 0; i < MAX_ID_ATTEMPTS; i++) {
      const candidate = `LIG-${crypto.randomBytes(3).toString("hex").toUpperCase()}`;
      if (!this.leagues.has(candidate)) return candidate;
    }

    return `LIG-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
  }

  _buildNewLeague({ id, name, pin, initialParticipants = [] }) {
    const leagueId = this._generateUniqueLeagueId(id);
    const suffix = leagueId.replace(/^LIG-/, "");
    const cleanName = typeof name === "string" ? name.trim() : "";
    const cleanPin = typeof pin === "string" ? pin.trim() : "";

    const rawParticipants = Array.isArray(initialParticipants)
      ? initialParticipants
      : [];
    const cleanParticipants = [];
    const playersMap = {};

    for (const raw of rawParticipants) {
      if (typeof raw !== "string") continue;
      const trimmed = raw.trim();
      if (!trimmed) continue;
      const key = removeDiacritics(trimmed.toLowerCase());
      if (!key || playersMap[key]) continue;
      cleanParticipants.push(trimmed);
      playersMap[key] = { key, name: trimmed, wins: 0, matchesPlayed: 0 };
    }

    return {
      id: leagueId,
      name: cleanName || `Liga ${suffix}`,
      pin: cleanPin || generateRandomPin(),
      createdAt: new Date().toISOString(),
      participants: cleanParticipants,
      teams: {},
      players: playersMap,
      matches: [],
    };
  }

  _applyAddParticipant(league, participantName) {
    if (typeof participantName !== "string") return false;
    const clean = participantName.trim();
    if (!clean) return false;

    const targetKey = removeDiacritics(clean.toLowerCase());
    if (!targetKey) return false;

    const alreadyExists = (league.participants || []).some(
      (p) => removeDiacritics(String(p).trim().toLowerCase()) === targetKey
    );
    if (alreadyExists) return false;

    league.participants.push(clean);
    if (!league.players[targetKey]) {
      league.players[targetKey] = {
        key: targetKey,
        name: clean,
        wins: 0,
        matchesPlayed: 0,
      };
    }
    return true;
  }

  _applyRemoveParticipant(league, participantName) {
    if (typeof participantName !== "string") return false;
    const targetKey = removeDiacritics(participantName.trim().toLowerCase());
    if (!targetKey) return false;

    const prevLength = league.participants.length;
    league.participants = league.participants.filter(
      (p) => removeDiacritics(String(p).trim().toLowerCase()) !== targetKey
    );
    return league.participants.length !== prevLength;
  }

  _applyRecordMatch(league, matchData) {
    const {
      id: customMatchId,
      date,
      team1DisplayName,
      team2DisplayName,
      team1Members,
      team2Members,
      score1 = 0,
      score2 = 0,
      winnerTeam = 1,
    } = matchData;

    const members1 =
      Array.isArray(team1Members) && team1Members.length > 0
        ? team1Members
        : extractMembers(team1DisplayName || "");
    const members2 =
      Array.isArray(team2Members) && team2Members.length > 0
        ? team2Members
        : extractMembers(team2DisplayName || "");

    const matchId = customMatchId || `match_${crypto.randomUUID()}`;
    const duplicated = league.matches.find((m) => String(m.id) === String(matchId));
    if (duplicated) {
      return { match: duplicated, added: false };
    }

    const match = {
      id: matchId,
      date: date || new Date().toISOString(),
      team1DisplayName: team1DisplayName || formatTeamDisplayName(members1),
      team2DisplayName: team2DisplayName || formatTeamDisplayName(members2),
      team1Members: members1,
      team2Members: members2,
      score1,
      score2,
      winnerTeam: Number(winnerTeam),
    };

    league.matches.unshift(match);

    const key1 = generateTeamKey(members1);
    if (key1) {
      if (!league.teams[key1]) {
        league.teams[key1] = {
          key: key1,
          displayName: match.team1DisplayName,
          members: members1,
          wins: 0,
          matchesPlayed: 0,
          totalPoints: 0,
        };
      }
      league.teams[key1].matchesPlayed += 1;
      league.teams[key1].totalPoints += score1;
      if (match.winnerTeam === 1) league.teams[key1].wins += 1;
    }

    const key2 = generateTeamKey(members2);
    if (key2) {
      if (!league.teams[key2]) {
        league.teams[key2] = {
          key: key2,
          displayName: match.team2DisplayName,
          members: members2,
          wins: 0,
          matchesPlayed: 0,
          totalPoints: 0,
        };
      }
      league.teams[key2].matchesPlayed += 1;
      league.teams[key2].totalPoints += score2;
      if (match.winnerTeam === 2) league.teams[key2].wins += 1;
    }

    for (const m of members1) {
      const key = removeDiacritics(String(m).trim().toLowerCase());
      if (!key) continue;
      if (!league.players[key]) {
        league.players[key] = { key, name: m, wins: 0, matchesPlayed: 0 };
      }
      league.players[key].matchesPlayed += 1;
      if (match.winnerTeam === 1) league.players[key].wins += 1;
    }

    for (const m of members2) {
      const key = removeDiacritics(String(m).trim().toLowerCase());
      if (!key) continue;
      if (!league.players[key]) {
        league.players[key] = { key, name: m, wins: 0, matchesPlayed: 0 };
      }
      league.players[key].matchesPlayed += 1;
      if (match.winnerTeam === 2) league.players[key].wins += 1;
    }

    return { match, added: true };
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
    if (typeof id !== "string") return null;
    return this.leagues.get(id) || null;
  }

  findLeagueByNameOrId(nameOrId) {
    if (typeof nameOrId !== "string") return null;
    const search = nameOrId.trim().toLowerCase();
    if (!search) return null;

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
    if (!pinMatches(league.pin, pin)) {
      return { success: false, error: "PIN incorrecto para eliminar la liga." };
    }

    if (mongo.connected) {
      const col = mongo.getCollection("leagues");
      if (col) {
        await col.deleteOne({ _id: id });
      }
      this.leagues.delete(id);
      return { success: true };
    }

    this.leagues.delete(id);
    this.saveLocal();
    return { success: true };
  }

  async createLeague({ id, name, pin, initialParticipants = [] }) {
    const candidate = this._buildNewLeague({
      id,
      name,
      pin,
      initialParticipants,
    });
    return await this._commitLeague(candidate);
  }

  async syncLeague(leagueData) {
    if (!leagueData || typeof leagueData.id !== "string" || !leagueData.id.trim()) {
      return null;
    }
    const id = leagueData.id.trim();
    const existing = this.getLeagueById(id);

    let candidate;
    if (!existing) {
      const cleanPin = typeof leagueData.pin === "string" ? leagueData.pin.trim() : "";
      if (!cleanPin) {
        const err = new Error("Se requiere un PIN para crear la liga al sincronizar.");
        err.statusCode = 401;
        throw err;
      }
      candidate = this._buildNewLeague({
        id,
        name: leagueData.name || id,
        pin: cleanPin,
        initialParticipants: leagueData.participants || [],
      });
    } else {
      // El PIN almacenado NUNCA se modifica desde sync.
      candidate = structuredClone(existing);
      if (typeof leagueData.name === "string" && leagueData.name.trim()) {
        candidate.name = leagueData.name.trim();
      }
      if (Array.isArray(leagueData.participants)) {
        for (const p of leagueData.participants) {
          this._applyAddParticipant(candidate, p);
        }
      }
    }

    if (Array.isArray(leagueData.matches)) {
      for (const m of leagueData.matches) {
        if (!m) continue;
        this._applyRecordMatch(candidate, {
          id: m.id,
          date: m.date,
          team1DisplayName: m.team1DisplayName,
          team2DisplayName: m.team2DisplayName,
          team1Members: m.team1Members,
          team2Members: m.team2Members,
          score1: Number(m.score1) || 0,
          score2: Number(m.score2) || 0,
          winnerTeam: Number(m.winnerTeam) || 1,
        });
      }
    }

    return await this._commitLeague(candidate);
  }

  async addParticipant(leagueId, participantName, { persist = true } = {}) {
    const existing = this.getLeagueById(leagueId);
    if (!existing) return null;

    if (!persist) {
      this._applyAddParticipant(existing, participantName);
      return existing;
    }

    const candidate = structuredClone(existing);
    const changed = this._applyAddParticipant(candidate, participantName);
    if (!changed) return existing;

    return await this._commitLeague(candidate);
  }

  async removeParticipant(leagueId, participantName, { persist = true } = {}) {
    const existing = this.getLeagueById(leagueId);
    if (!existing) return null;

    if (!persist) {
      this._applyRemoveParticipant(existing, participantName);
      return existing;
    }

    const candidate = structuredClone(existing);
    const changed = this._applyRemoveParticipant(candidate, participantName);
    if (!changed) return existing;

    return await this._commitLeague(candidate);
  }

  async recordMatch(leagueId, matchData, { persist = true } = {}) {
    const existing = this.getLeagueById(leagueId);
    let candidate;

    if (!existing) {
      const cleanPin = typeof matchData.pin === "string" ? matchData.pin.trim() : "";
      if (!cleanPin) {
        const err = new Error(
          "Se requiere un PIN para crear la liga al registrar la partida."
        );
        err.statusCode = 401;
        throw err;
      }
      const members = [
        ...(matchData.team1Members || []),
        ...(matchData.team2Members || []),
      ];
      candidate = this._buildNewLeague({
        id: leagueId,
        name: matchData.leagueName || `Liga ${leagueId}`,
        pin: cleanPin,
        initialParticipants: members,
      });
    } else {
      candidate = structuredClone(existing);
    }

    const { match, added } = this._applyRecordMatch(candidate, matchData);
    if (!added) return match;

    if (persist) {
      await this._commitLeague(candidate);
    } else {
      this.leagues.set(candidate.id, candidate);
    }
    return match;
  }

  getAvailableMonths(leagueId = null, tzOffsetMinutes = 0) {
    const targetLeagues = leagueId
      ? this.leagues.has(leagueId)
        ? [this.leagues.get(leagueId)]
        : []
      : Array.from(this.leagues.values());
    return rankingsUtil.availableMonths(targetLeagues, tzOffsetMinutes);
  }

  getGlobalTeamsRanked(options = {}) {
    return rankingsUtil.rankGlobal(this.leagues.values(), options).teams;
  }

  getGlobalPlayersRanked(options = {}) {
    return rankingsUtil.rankGlobal(this.leagues.values(), options).players;
  }
}

module.exports = new Store();
