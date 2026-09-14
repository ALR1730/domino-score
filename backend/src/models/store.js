const fs = require("fs");
const path = require("path");
const {
  extractMembers,
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
          this.leagues.set(item.id, item);
        }
      } else {
        // Inicializar con una liga demo
        const demoId = "LIG-1001";
        const demoLeague = {
          id: demoId,
          name: "Liga de Campeones Dominó",
          pin: "7777",
          createdAt: new Date().toISOString(),
          participants: [
            "Carlos",
            "Juan",
            "Pedro",
            "Luis",
            "Andrés",
            "Marcos",
          ],
          teams: {},
          players: {
            carlos: { key: "carlos", name: "Carlos", wins: 0, matchesPlayed: 0 },
            juan: { key: "juan", name: "Juan", wins: 0, matchesPlayed: 0 },
            pedro: { key: "pedro", name: "Pedro", wins: 0, matchesPlayed: 0 },
            luis: { key: "luis", name: "Luis", wins: 0, matchesPlayed: 0 },
          },
          matches: [],
        };
        this.leagues.set(demoId, demoLeague);
        this.save();
      }
    } catch (err) {
      console.error("Error cargando store:", err);
    }
  }

  save() {
    try {
      if (!fs.existsSync(DATA_DIR)) {
        fs.mkdirSync(DATA_DIR, { recursive: true });
      }
      const data = Array.from(this.leagues.values());
      fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), "utf-8");
    } catch (err) {
      console.error("Error guardando store:", err);
    }
  }

  getAllLeaguesPublic() {
    return Array.from(this.leagues.values()).map((l) => ({
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

  deleteLeague(id, pin) {
    const league = this.getLeagueById(id);
    if (!league) {
      return { success: false, error: "Liga no encontrada." };
    }
    if (!pin || String(pin).trim() !== league.pin) {
      return { success: false, error: "PIN incorrecto para eliminar la liga." };
    }
    this.leagues.delete(id);
    this.save();
    return { success: true };
  }

  createLeague({ name, pin, initialParticipants = [] }) {
    const randomDigits = Math.floor(1000 + Math.random() * 9000);
    const id = `LIG-${randomDigits}`;

    const cleanParticipants = Array.isArray(initialParticipants)
      ? initialParticipants.map((p) => p.trim()).filter(Boolean)
      : [];

    const playersMap = {};
    for (const p of cleanParticipants) {
      const key = removeDiacritics(p.toLowerCase());
      playersMap[key] = {
        key,
        name: p,
        wins: 0,
        matchesPlayed: 0,
      };
    }

    const league = {
      id,
      name: name.trim() || `Liga ${randomDigits}`,
      pin: pin.trim() || "1234",
      createdAt: new Date().toISOString(),
      participants: cleanParticipants,
      teams: {},
      players: playersMap,
      matches: [],
    };

    this.leagues.set(id, league);
    this.save();
    return league;
  }

  addParticipant(leagueId, participantName) {
    const league = this.getLeagueById(leagueId);
    if (!league) return null;

    const clean = participantName.trim();
    if (!clean) return league;

    if (!league.participants.some((p) => p.toLowerCase() === clean.toLowerCase())) {
      league.participants.push(clean);
      const key = removeDiacritics(clean.toLowerCase());
      if (!league.players[key]) {
        league.players[key] = { key, name: clean, wins: 0, matchesPlayed: 0 };
      }
      this.save();
    }
    return league;
  }

  removeParticipant(leagueId, participantName) {
    const league = this.getLeagueById(leagueId);
    if (!league) return null;

    const target = participantName.trim().toLowerCase();
    league.participants = league.participants.filter(
      (p) => p.toLowerCase() !== target
    );
    this.save();
    return league;
  }

  recordMatch(leagueId, matchData) {
    const league = this.getLeagueById(leagueId);
    if (!league) return null;

    const {
      team1DisplayName,
      team2DisplayName,
      team1Members = [],
      team2Members = [],
      score1 = 0,
      score2 = 0,
      winnerTeam = 1,
    } = matchData;

    const matchId = `match_${Date.now()}`;
    const match = {
      id: matchId,
      date: new Date().toISOString(),
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
      const key = removeDiacritics(m.trim().toLowerCase());
      if (!league.players[key]) {
        league.players[key] = { key, name: m, wins: 0, matchesPlayed: 0 };
      }
      league.players[key].matchesPlayed += 1;
      if (winnerTeam === 1) league.players[key].wins += 1;
    }

    for (const m of team2Members) {
      const key = removeDiacritics(m.trim().toLowerCase());
      if (!league.players[key]) {
        league.players[key] = { key, name: m, wins: 0, matchesPlayed: 0 };
      }
      league.players[key].matchesPlayed += 1;
      if (winnerTeam === 2) league.players[key].wins += 1;
    }

    this.save();
    return match;
  }

  getGlobalTeamsRanked() {
    const aggregate = new Map();

    for (const league of this.leagues.values()) {
      for (const team of Object.values(league.teams || {})) {
        if (!aggregate.has(team.key)) {
          aggregate.set(team.key, {
            key: team.key,
            displayName: team.displayName,
            members: [...team.members],
            wins: team.wins,
            matchesPlayed: team.matchesPlayed,
            totalPoints: team.totalPoints,
          });
        } else {
          const existing = aggregate.get(team.key);
          existing.wins += team.wins;
          existing.matchesPlayed += team.matchesPlayed;
          existing.totalPoints += team.totalPoints;
        }
      }
    }

    const list = Array.from(aggregate.values()).map((t) => ({
      ...t,
      winRate: t.matchesPlayed > 0 ? (t.wins / t.matchesPlayed) * 100 : 0,
    }));

    list.sort((a, b) => {
      if (b.wins !== a.wins) return b.wins - a.wins;
      if (b.winRate !== a.winRate) return b.winRate - a.winRate;
      return b.totalPoints - a.totalPoints;
    });

    return list;
  }

  getGlobalPlayersRanked() {
    const aggregate = new Map();

    for (const league of this.leagues.values()) {
      for (const player of Object.values(league.players || {})) {
        if (!aggregate.has(player.key)) {
          aggregate.set(player.key, {
            key: player.key,
            name: player.name,
            wins: player.wins,
            matchesPlayed: player.matchesPlayed,
          });
        } else {
          const existing = aggregate.get(player.key);
          existing.wins += player.wins;
          existing.matchesPlayed += player.matchesPlayed;
        }
      }
    }

    const list = Array.from(aggregate.values()).map((p) => ({
      ...p,
      winRate: p.matchesPlayed > 0 ? (p.wins / p.matchesPlayed) * 100 : 0,
    }));

    list.sort((a, b) => {
      if (b.wins !== a.wins) return b.wins - a.wins;
      return b.winRate - a.winRate;
    });

    return list;
  }
}

module.exports = new Store();
