const fs = require("fs");
const path = require("path");
const mongo = require("../db/mongo");

const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, "../../data");
const DATA_FILE = path.join(DATA_DIR, "leagues.json");

function escapeRegex(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

class LeagueRepository {
  constructor() {
    this.localLeagues = new Map();
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
            this.localLeagues.set(item.id, item);
          }
        }
      }

      this.saveLocal();
    } catch (err) {
      console.error("Error cargando repositorio de ligas:", err);
    }
  }

  _mongoCol() {
    if (!mongo.connected) return null;
    return mongo.getCollection("leagues");
  }

  /**
   * Distingue una colección real de MongoDB (driver o fake completo) del mock
   * unitario mínimo (`{ updateOne }`) usado para verificar orden Mongo-first.
   */
  _isDirectMongo(col) {
    return Boolean(col && typeof col.findOne === "function");
  }

  _normalizeDoc(doc) {
    if (!doc) return null;
    const { _id, ...leagueData } = doc;
    leagueData.id = leagueData.id || _id;
    return leagueData.id ? leagueData : null;
  }

  /** Instantánea local en disco (best-effort): solo cuando no hay MongoDB activo. */
  saveLocal() {
    try {
      if (!fs.existsSync(DATA_DIR)) {
        fs.mkdirSync(DATA_DIR, { recursive: true });
      }
      const data = Array.from(this.localLeagues.values());
      fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), "utf-8");
    } catch (err) {
      console.error("Error guardando store en disco:", err.message);
    }
  }

  async _upsertInMongo(col, league) {
    const doc = { ...league, _id: league.id, updatedAt: new Date().toISOString() };
    const update = { $set: doc };
    if (doc.pinHash && doc.pin === undefined) {
      update.$unset = { pin: "" };
    }
    await col.updateOne({ _id: league.id }, update, { upsert: true });
  }

  isDirectMongoEnabled() {
    return this._isDirectMongo(this._mongoCol());
  }

  /**
   * Con MongoDB conectado evita volcar toda la colección a RAM; únicamente
   * siembra ligas locales si la colección está vacía.
   */
  async seedIfMongoEmpty() {
    const col = this._mongoCol();
    if (!col) return;

    if (this._isDirectMongo(col)) {
      const existingCount =
        typeof col.countDocuments === "function"
          ? await col.countDocuments({})
          : (await col.find({}).toArray()).length;

      if (existingCount === 0 && this.localLeagues.size > 0) {
        console.log(
          `📤 Sembrando ${this.localLeagues.size} ligas existentes en MongoDB...`
        );
        for (const league of this.localLeagues.values()) {
          await this._upsertInMongo(col, league);
        }
      }
      console.log(
        `✅ MongoDB listo (${existingCount} documentos en colección leagues; consultas directas activas).`
      );
    }
  }

  async hasId(id) {
    if (typeof id !== "string" || !id) return false;
    const col = this._mongoCol();
    if (this._isDirectMongo(col)) {
      const existing = await col.findOne(
        { $or: [{ _id: id }, { id }] },
        { projection: { _id: 1 } }
      );
      return Boolean(existing);
    }
    return this.localLeagues.has(id);
  }

  async findById(id) {
    if (typeof id !== "string" || !id) return null;
    const col = this._mongoCol();
    if (this._isDirectMongo(col)) {
      const doc = await col.findOne({ $or: [{ _id: id }, { id }] });
      const normalized = this._normalizeDoc(doc);
      if (normalized) {
        this.localLeagues.set(normalized.id, normalized);
      }
      return normalized;
    }
    return this.localLeagues.get(id) || null;
  }

  async findByNameOrId(nameOrId) {
    if (typeof nameOrId !== "string") return null;
    const trimmed = nameOrId.trim();
    if (!trimmed) return null;

    const col = this._mongoCol();
    if (this._isDirectMongo(col)) {
      const exactRegex = new RegExp(`^${escapeRegex(trimmed)}$`, "i");
      const doc = await col.findOne({
        $or: [{ _id: exactRegex }, { id: exactRegex }, { name: exactRegex }],
      });
      const normalized = this._normalizeDoc(doc);
      if (normalized) {
        this.localLeagues.set(normalized.id, normalized);
      }
      return normalized;
    }

    const search = trimmed.toLowerCase();
    for (const l of this.localLeagues.values()) {
      if (
        l.id.toLowerCase() === search ||
        (l.name && l.name.trim().toLowerCase() === search)
      ) {
        return l;
      }
    }
    return null;
  }

  async findAllPublicSummaries(excludeId) {
    const col = this._mongoCol();
    if (this._isDirectMongo(col)) {
      const docs = await col
        .find(
          { _id: { $ne: excludeId }, id: { $ne: excludeId } },
          {
            projection: {
              id: 1,
              name: 1,
              createdAt: 1,
              participants: 1,
              matches: 1,
              teams: 1,
            },
          }
        )
        .toArray();
      return docs.map((l) => ({
        id: l.id || l._id,
        name: l.name,
        createdAt: l.createdAt,
        participantsCount: (l.participants || []).length,
        matchesCount: (l.matches || []).length,
        teamsCount: Object.keys(l.teams || {}).length,
      }));
    }

    return Array.from(this.localLeagues.values())
      .filter((l) => l.id !== excludeId)
      .map((l) => ({
        id: l.id,
        name: l.name,
        createdAt: l.createdAt,
        participantsCount: (l.participants || []).length,
        matchesCount: (l.matches || []).length,
        teamsCount: Object.keys(l.teams || {}).length,
      }));
  }

  async findAllForRankings(leagueId = null) {
    if (leagueId) {
      const one = await this.findById(leagueId);
      return one ? [one] : [];
    }

    const col = this._mongoCol();
    if (this._isDirectMongo(col)) {
      const docs = await col
        .find(
          {},
          {
            projection: {
              id: 1,
              name: 1,
              matches: 1,
              teams: 1,
              players: 1,
            },
          }
        )
        .toArray();
      return docs.map((d) => this._normalizeDoc(d)).filter(Boolean);
    }

    return Array.from(this.localLeagues.values());
  }

  async insertLeague(league) {
    const col = this._mongoCol();
    if (this._isDirectMongo(col) && typeof col.insertOne === "function") {
      try {
        await col.insertOne({
          ...league,
          _id: league.id,
          updatedAt: new Date().toISOString(),
        });
        this.localLeagues.set(league.id, league);
        return true;
      } catch (err) {
        if (err && err.code === 11000) {
          return false;
        }
        throw err;
      }
    }

    await this.commitLeague(league);
    return true;
  }

  /**
   * Persiste una liga completa siguiendo orden Mongo-first: confirma Atlas
   * antes de mutar la caché local en RAM.
   */
  async commitLeague(candidate) {
    const col = this._mongoCol();
    if (mongo.connected && col) {
      await this._upsertInMongo(col, candidate);
      this.localLeagues.set(candidate.id, candidate);
      return candidate;
    }

    this.localLeagues.set(candidate.id, candidate);
    this.saveLocal();
    return candidate;
  }

  async upgradePinAtomic(leagueId, pinHash, pinSalt) {
    const col = this._mongoCol();
    if (this._isDirectMongo(col)) {
      await col.updateOne(
        { _id: leagueId },
        {
          $set: {
            pinHash,
            pinSalt,
            updatedAt: new Date().toISOString(),
          },
          $unset: { pin: "" },
        }
      );
      return await this.findById(leagueId);
    }

    const existing = this.localLeagues.get(leagueId);
    if (!existing || existing.pinHash) return existing;
    const candidate = structuredClone(existing);
    candidate.pinHash = pinHash;
    candidate.pinSalt = pinSalt;
    delete candidate.pin;
    return await this.commitLeague(candidate);
  }

  async addParticipantAtomic(leagueId, cleanName, playerKey) {
    const col = this._mongoCol();
    if (!this._isDirectMongo(col)) return null;

    await col.updateOne(
      { _id: leagueId },
      {
        $addToSet: { participants: cleanName },
        $set: { updatedAt: new Date().toISOString() },
      }
    );
    await col.updateOne(
      { _id: leagueId, [`players.${playerKey}`]: { $exists: false } },
      {
        $set: {
          [`players.${playerKey}`]: {
            key: playerKey,
            name: cleanName,
            wins: 0,
            matchesPlayed: 0,
          },
        },
      }
    );
    return await this.findById(leagueId);
  }

  async removeParticipantAtomic(leagueId, namesToPull) {
    const col = this._mongoCol();
    if (!this._isDirectMongo(col)) return null;

    await col.updateOne(
      { _id: leagueId },
      {
        $pullAll: { participants: namesToPull },
        $set: { updatedAt: new Date().toISOString() },
      }
    );
    return await this.findById(leagueId);
  }

  async recordMatchAtomic(leagueId, match, teamEntries, playerEntries) {
    const col = this._mongoCol();
    if (!this._isDirectMongo(col)) return null;

    const setFields = { updatedAt: new Date().toISOString() };
    const incFields = {};

    for (const team of teamEntries) {
      setFields[`teams.${team.key}.key`] = team.key;
      setFields[`teams.${team.key}.displayName`] = team.displayName;
      setFields[`teams.${team.key}.members`] = team.members;
      incFields[`teams.${team.key}.matchesPlayed`] = 1;
      incFields[`teams.${team.key}.totalPoints`] = team.points;
      incFields[`teams.${team.key}.wins`] = team.won ? 1 : 0;
    }

    for (const player of playerEntries) {
      setFields[`players.${player.key}.key`] = player.key;
      setFields[`players.${player.key}.name`] = player.name;
      incFields[`players.${player.key}.matchesPlayed`] = 1;
      incFields[`players.${player.key}.wins`] = player.won ? 1 : 0;
    }

    const res = await col.updateOne(
      { _id: leagueId, "matches.id": { $ne: match.id } },
      {
        $push: { matches: { $each: [match], $position: 0 } },
        $set: setFields,
        $inc: incFields,
      }
    );

    if (res && res.matchedCount === 0) {
      const current = await this.findById(leagueId);
      if (!current) return { found: false, match: null };
      const existingMatch = (current.matches || []).find(
        (m) => String(m.id) === String(match.id)
      );
      return { found: true, match: existingMatch || match };
    }

    await this.findById(leagueId);
    return { found: true, match };
  }

  async deleteById(id) {
    const col = this._mongoCol();
    if (mongo.connected && col) {
      await col.deleteOne({ _id: id });
      this.localLeagues.delete(id);
      return;
    }

    this.localLeagues.delete(id);
    this.saveLocal();
  }
}

module.exports = new LeagueRepository();
module.exports.LeagueRepository = LeagueRepository;
module.exports.escapeRegex = escapeRegex;
