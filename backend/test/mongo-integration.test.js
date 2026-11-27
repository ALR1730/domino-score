/**
 * Suite de integración real contra MongoDB (`mongo:7` en CI).
 * Se omite en local cuando `MONGODB_TEST_URI` no está configurada.
 */
const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");

const MONGODB_TEST_URI = process.env.MONGODB_TEST_URI;

test(
  "integración real con MongoDB: lectura directa sin RAM, concurrencia atómica, /api/v1 y lazy upgrade",
  {
    skip:
      !MONGODB_TEST_URI &&
      "MONGODB_TEST_URI no definida (se ejecuta en CI con mongo:7)",
  },
  async (t) => {
    process.env.MONGODB_URI = MONGODB_TEST_URI;
    const app = require("../src/server");
    const mongo = require("../src/db/mongo");
    const leagueRepository = require("../src/repositories/leagueRepository");

    const connected = await mongo.connect(MONGODB_TEST_URI);
    assert.equal(connected, true, "Debe conectarse a MongoDB CI");

    const col = mongo.getCollection("leagues");
    await col.deleteMany({});

    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
    const baseUrl = `http://127.0.0.1:${server.address().port}`;

    t.after(async () => {
      await col.deleteMany({});
      leagueRepository.localLeagues.clear();
      await mongo.close();
      server.close();
    });

    async function api(method, endpoint, body) {
      const res = await fetch(`${baseUrl}${endpoint}`, {
        method,
        headers: { "Content-Type": "application/json" },
        body: body === undefined ? undefined : JSON.stringify(body),
      });
      return { status: res.status, body: await res.json() };
    }

    // 1. Verificar índices en MongoDB (incluyendo matches.id de Fase 5C)
    const indexes = await col.indexes();
    assert.ok(
      indexes.some((idx) => idx.key && idx.key["matches.id"] === 1),
      "Debe existir índice aditivo en matches.id"
    );

    // 2. Crear liga vía /api/v1 y verificar lectura directa tras limpiar RAM
    const created = await api("POST", "/api/v1/leagues", {
      name: "Mongo CI League",
      pin: "6262",
      initialParticipants: ["Ana", "Luis"],
    });
    assert.equal(created.status, 201);
    const id = created.body.league.id;

    leagueRepository.localLeagues.clear();
    const fetched = await api("GET", `/api/v1/leagues/${id}`);
    assert.equal(fetched.status, 200);
    assert.equal(fetched.body.league.name, "Mongo CI League");

    // 3. Participantes atómicos
    await api("POST", `/api/v1/leagues/${id}/participants`, {
      name: "Carlos",
      pin: "6262",
    });
    leagueRepository.localLeagues.clear();
    const afterAdd = await api("GET", `/api/v1/leagues/${id}`);
    assert.deepEqual(afterAdd.body.league.participants, [
      "Ana",
      "Luis",
      "Carlos",
    ]);

    // 4. Concurrencia e idempotencia al registrar partidas en paralelo
    const matchResults = await Promise.all([
      api("POST", `/api/v1/leagues/${id}/matches`, {
        id: "ci-match-1",
        pin: "6262",
        date: "2026-10-01T01:00:00.000Z",
        team1Members: ["Ana", "Luis"],
        team2Members: ["Carlos", "Pedro"],
        score1: 200,
        score2: 140,
        winnerTeam: 1,
      }),
      api("POST", `/api/v1/leagues/${id}/matches`, {
        id: "ci-match-1", // duplicada concurrente
        pin: "6262",
        date: "2026-10-01T01:00:00.000Z",
        team1Members: ["Ana", "Luis"],
        team2Members: ["Carlos", "Pedro"],
        score1: 200,
        score2: 140,
        winnerTeam: 1,
      }),
      api("POST", `/api/v1/leagues/${id}/matches`, {
        id: "ci-match-2",
        pin: "6262",
        date: "2026-10-15T18:00:00.000Z",
        team1Members: ["Ana", "Luis"],
        team2Members: ["Carlos", "Pedro"],
        score1: 210,
        score2: 100,
        winnerTeam: 1,
      }),
    ]);
    assert.ok(matchResults.every((r) => r.status === 201));

    const docAfterMatches = await col.findOne({ _id: id });
    assert.equal(docAfterMatches.matches.length, 2);
    assert.equal(docAfterMatches.teams.ana_luis.wins, 2);
    assert.equal(docAfterMatches.teams.ana_luis.matchesPlayed, 2);
    assert.equal(docAfterMatches.teams.ana_luis.totalPoints, 410);

    // 5. Rankings mensuales con tzOffsetMinutes
    leagueRepository.localLeagues.clear();
    const sepRankings = await api(
      "GET",
      `/api/v1/rankings/league/${id}?year=2026&month=9&tzOffsetMinutes=-240`
    );
    assert.equal(sepRankings.status, 200);
    assert.equal(sepRankings.body.teams[0].wins, 1);

    // 6. Lazy upgrade de documento legado directo en Mongo
    await col.insertOne({
      _id: "LIG-MLEG",
      id: "LIG-MLEG",
      name: "Liga Legada Mongo",
      pin: "5432",
      createdAt: new Date().toISOString(),
      participants: [],
      teams: {},
      players: {},
      matches: [],
    });
    leagueRepository.localLeagues.clear();

    const joined = await api("POST", "/api/v1/leagues/join", {
      nameOrId: "LIG-MLEG",
      pin: "5432",
    });
    assert.equal(joined.status, 200);
    assert.equal(joined.body.league.pin, "5432");

    const upgradedDoc = await col.findOne({ _id: "LIG-MLEG" });
    assert.equal(upgradedDoc.pin, undefined);
    assert.match(upgradedDoc.pinHash, /^[0-9a-f]{64}$/);
    assert.match(upgradedDoc.pinSalt, /^[0-9a-f]{32}$/);

    // 7. Eliminar liga
    const del = await api("DELETE", `/api/v1/leagues/${id}`, { pin: "6262" });
    assert.equal(del.status, 200);
    const gone = await api("GET", `/api/v1/leagues/${id}`);
    assert.equal(gone.status, 404);
  }
);
