const crypto = require("crypto");
const defaultRepository = require("../repositories/leagueRepository");
const rankingsUtil = require("../utils/rankings");
const { generateRandomPin } = require("../utils/pin");
const { hashPin, verifyPin } = require("../utils/pinCrypto");
const {
  extractMembers,
  generateTeamKey,
  formatTeamDisplayName,
  removeDiacritics,
} = require("../utils/nameParser");

const MAX_ID_ATTEMPTS = 20;

class LeagueService {
  constructor(repository = defaultRepository) {
    this.repository = repository;
  }

  async initializeStorage() {
    await this.repository.seedIfMongoEmpty();
  }

  async _generateUniqueLeagueId(requestedId = null) {
    const cleanRequested =
      typeof requestedId === "string" ? requestedId.trim() : "";
    if (cleanRequested && !(await this.repository.hasId(cleanRequested))) {
      return cleanRequested;
    }

    for (let i = 0; i < MAX_ID_ATTEMPTS; i++) {
      const candidate = `LIG-${crypto.randomInt(1000, 10000)}`;
      if (!(await this.repository.hasId(candidate))) return candidate;
    }

    for (let i = 0; i < MAX_ID_ATTEMPTS; i++) {
      const candidate = `LIG-${crypto.randomBytes(3).toString("hex").toUpperCase()}`;
      if (!(await this.repository.hasId(candidate))) return candidate;
    }

    return `LIG-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
  }

  async _buildNewLeague({ id, name, pin, initialParticipants = [] }) {
    const leagueId = await this._generateUniqueLeagueId(id);
    const suffix = leagueId.replace(/^LIG-/, "");
    const cleanName = typeof name === "string" ? name.trim() : "";
    const cleanPin = typeof pin === "string" ? pin.trim() : "";
    const resolvedPin = cleanPin || generateRandomPin();
    const { pinHash, pinSalt } = await hashPin(resolvedPin);

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
      pinHash,
      pinSalt,
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

  _prepareMatchPayload(matchData) {
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
    const numericWinner = Number(winnerTeam);

    const match = {
      id: matchId,
      date: date || new Date().toISOString(),
      team1DisplayName: team1DisplayName || formatTeamDisplayName(members1),
      team2DisplayName: team2DisplayName || formatTeamDisplayName(members2),
      team1Members: members1,
      team2Members: members2,
      score1,
      score2,
      winnerTeam: numericWinner,
    };

    const teamEntries = [];
    const key1 = generateTeamKey(members1);
    if (key1) {
      teamEntries.push({
        key: key1,
        displayName: match.team1DisplayName,
        members: members1,
        points: score1,
        won: numericWinner === 1,
      });
    }
    const key2 = generateTeamKey(members2);
    if (key2) {
      teamEntries.push({
        key: key2,
        displayName: match.team2DisplayName,
        members: members2,
        points: score2,
        won: numericWinner === 2,
      });
    }

    const playerEntries = [];
    for (const m of members1) {
      const key = removeDiacritics(String(m).trim().toLowerCase());
      if (!key) continue;
      playerEntries.push({ key, name: m, won: numericWinner === 1 });
    }
    for (const m of members2) {
      const key = removeDiacritics(String(m).trim().toLowerCase());
      if (!key) continue;
      playerEntries.push({ key, name: m, won: numericWinner === 2 });
    }

    return { match, teamEntries, playerEntries };
  }

  _applyRecordMatch(league, matchData) {
    const { match, teamEntries, playerEntries } =
      this._prepareMatchPayload(matchData);

    const duplicated = league.matches.find(
      (m) => String(m.id) === String(match.id)
    );
    if (duplicated) {
      return { match: duplicated, added: false };
    }

    league.matches.unshift(match);

    for (const team of teamEntries) {
      if (!league.teams[team.key]) {
        league.teams[team.key] = {
          key: team.key,
          displayName: team.displayName,
          members: team.members,
          wins: 0,
          matchesPlayed: 0,
          totalPoints: 0,
        };
      }
      league.teams[team.key].matchesPlayed += 1;
      league.teams[team.key].totalPoints += team.points;
      if (team.won) league.teams[team.key].wins += 1;
    }

    for (const player of playerEntries) {
      if (!league.players[player.key]) {
        league.players[player.key] = {
          key: player.key,
          name: player.name,
          wins: 0,
          matchesPlayed: 0,
        };
      }
      league.players[player.key].matchesPlayed += 1;
      if (player.won) league.players[player.key].wins += 1;
    }

    return { match, added: true };
  }

  async getAllLeaguesPublic() {
    return await this.repository.findAllPublicSummaries(
      rankingsUtil.CASUAL_LEAGUE_ID
    );
  }

  async getLeagueById(id) {
    return await this.repository.findById(id);
  }

  async findLeagueByNameOrId(nameOrId) {
    return await this.repository.findByNameOrId(nameOrId);
  }

  async upgradeLegacyPin(leagueId, plainPin) {
    const existing = await this.repository.findById(leagueId);
    if (!existing || existing.pinHash) return existing;
    const { pinHash, pinSalt } = await hashPin(plainPin);
    return await this.repository.upgradePinAtomic(leagueId, pinHash, pinSalt);
  }

  async verifyLeaguePin(
    leagueOrId,
    candidatePin,
    { upgradeLegacy = true } = {}
  ) {
    const league =
      typeof leagueOrId === "string"
        ? await this.repository.findById(leagueOrId)
        : leagueOrId;
    if (!league) return false;
    const { valid, needsUpgrade } = await verifyPin(league, candidatePin);
    if (!valid) return false;
    if (needsUpgrade && upgradeLegacy) {
      try {
        await this.upgradeLegacyPin(league.id, String(candidatePin).trim());
      } catch (err) {
        console.warn(
          `⚠️ No se pudo actualizar PIN legado de ${league.id}:`,
          err.message
        );
      }
    }
    return true;
  }

  async deleteLeague(id, pin) {
    const league = await this.repository.findById(id);
    if (!league) {
      return { success: false, error: "Liga no encontrada." };
    }
    if (
      !(await this.verifyLeaguePin(league, pin, { upgradeLegacy: false }))
    ) {
      return { success: false, error: "PIN incorrecto para eliminar la liga." };
    }

    await this.repository.deleteById(id);
    return { success: true };
  }

  async createLeague({ id, name, pin, initialParticipants = [] }) {
    const hasCustomId = typeof id === "string" && id.trim().length > 0;
    for (let attempt = 0; attempt < 3; attempt++) {
      const candidate = await this._buildNewLeague({
        id: hasCustomId ? id : undefined,
        name,
        pin,
        initialParticipants,
      });
      const inserted = await this.repository.insertLeague(candidate);
      if (inserted || hasCustomId) {
        return candidate;
      }
    }
    const fallback = await this._buildNewLeague({
      id: `LIG-${crypto.randomUUID().slice(0, 8).toUpperCase()}`,
      name,
      pin,
      initialParticipants,
    });
    return await this.repository.commitLeague(fallback);
  }

  async syncLeague(leagueData) {
    if (
      !leagueData ||
      typeof leagueData.id !== "string" ||
      !leagueData.id.trim()
    ) {
      return null;
    }
    const id = leagueData.id.trim();
    const existing = await this.repository.findById(id);

    let candidate;
    if (!existing) {
      const cleanPin =
        typeof leagueData.pin === "string" ? leagueData.pin.trim() : "";
      if (!cleanPin) {
        const err = new Error(
          "Se requiere un PIN para crear la liga al sincronizar."
        );
        err.statusCode = 401;
        throw err;
      }
      candidate = await this._buildNewLeague({
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

    return await this.repository.commitLeague(candidate);
  }

  async addParticipant(leagueId, participantName, { persist = true } = {}) {
    const existing = await this.repository.findById(leagueId);
    if (!existing) return null;

    if (typeof participantName !== "string") return existing;
    const clean = participantName.trim();
    const targetKey = removeDiacritics(clean.toLowerCase());
    if (!clean || !targetKey) return existing;

    const alreadyExists = (existing.participants || []).some(
      (p) => removeDiacritics(String(p).trim().toLowerCase()) === targetKey
    );
    if (alreadyExists) return existing;

    if (persist && this.repository.isDirectMongoEnabled()) {
      return await this.repository.addParticipantAtomic(
        leagueId,
        clean,
        targetKey
      );
    }

    if (!persist) {
      this._applyAddParticipant(existing, clean);
      return existing;
    }

    const candidate = structuredClone(existing);
    this._applyAddParticipant(candidate, clean);
    return await this.repository.commitLeague(candidate);
  }

  async removeParticipant(leagueId, participantName, { persist = true } = {}) {
    const existing = await this.repository.findById(leagueId);
    if (!existing) return null;

    if (typeof participantName !== "string") return existing;
    const targetKey = removeDiacritics(participantName.trim().toLowerCase());
    if (!targetKey) return existing;

    const namesToPull = (existing.participants || []).filter(
      (p) => removeDiacritics(String(p).trim().toLowerCase()) === targetKey
    );
    if (namesToPull.length === 0) return existing;

    if (persist && this.repository.isDirectMongoEnabled()) {
      return await this.repository.removeParticipantAtomic(
        leagueId,
        namesToPull
      );
    }

    if (!persist) {
      this._applyRemoveParticipant(existing, participantName);
      return existing;
    }

    const candidate = structuredClone(existing);
    this._applyRemoveParticipant(candidate, participantName);
    return await this.repository.commitLeague(candidate);
  }

  async recordMatch(leagueId, matchData, { persist = true } = {}) {
    const existing = await this.repository.findById(leagueId);

    if (!existing) {
      const cleanPin =
        typeof matchData.pin === "string" ? matchData.pin.trim() : "";
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
      const candidate = await this._buildNewLeague({
        id: leagueId,
        name: matchData.leagueName || `Liga ${leagueId}`,
        pin: cleanPin,
        initialParticipants: members,
      });
      const { match } = this._applyRecordMatch(candidate, matchData);
      if (persist) {
        await this.repository.commitLeague(candidate);
      } else {
        this.repository.localLeagues.set(candidate.id, candidate);
      }
      return match;
    }

    if (persist && this.repository.isDirectMongoEnabled()) {
      const { match, teamEntries, playerEntries } =
        this._prepareMatchPayload(matchData);
      const res = await this.repository.recordMatchAtomic(
        leagueId,
        match,
        teamEntries,
        playerEntries
      );
      return res.match;
    }

    const candidate = structuredClone(existing);
    const { match, added } = this._applyRecordMatch(candidate, matchData);
    if (!added) return match;

    if (persist) {
      await this.repository.commitLeague(candidate);
    } else {
      this.repository.localLeagues.set(candidate.id, candidate);
    }
    return match;
  }

  async getAvailableMonths(leagueId = null, tzOffsetMinutes = 0) {
    const targetLeagues = await this.repository.findAllForRankings(leagueId);
    return rankingsUtil.availableMonths(targetLeagues, tzOffsetMinutes);
  }

  async getGlobalTeamsRanked(options = {}) {
    const leagues = await this.repository.findAllForRankings();
    return rankingsUtil.rankGlobal(leagues, options).teams;
  }

  async getGlobalPlayersRanked(options = {}) {
    const leagues = await this.repository.findAllForRankings();
    return rankingsUtil.rankGlobal(leagues, options).players;
  }
}

module.exports = new LeagueService();
module.exports.LeagueService = LeagueService;
