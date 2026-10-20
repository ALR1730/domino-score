/**
 * Pruebas del backend con el runner integrado de Node (`node:test` + `fetch`).
 *
 * No requieren dependencias nuevas: usan el `fetch` global de Node 18+.
 * El servidor se levanta en un puerto efímero y los datos se aíslan en un
 * DATA_DIR temporal, para no tocar backend/data/leagues.json.
 */
const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const fs = require("node:fs");

// Aislar el almacenamiento ANTES de cargar la app.
const DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), "domino-test-"));
process.env.DATA_DIR = DATA_DIR;
process.env.ALLOW_LOCAL_FALLBACK = "true";

const app = require("../src/server");
const store = require("../src/models/store");
const {
  extractMembers,
  generateTeamKey,
} = require("../src/utils/nameParser");
const rankingsUtil = require("../src/utils/rankings");

let server;
let baseUrl;

test.before(async () => {
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

test.after(() => {
  store.leagues.clear();
  store.saveLocal();
  if (server) server.close();
  fs.rmSync(DATA_DIR, { recursive: true, force: true });
});

/** Atajo de fetch que devuelve { status, body } con JSON parseado. */
async function api(method, endpoint, body, headers = {}) {
  const res = await fetch(`${baseUrl}${endpoint}`, {
    method,
    headers: { "Content-Type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = text;
  }
  return { status: res.status, body: parsed, headers: res.headers };
}

// ---------------------------------------------------------------------------
// NameParser
// ---------------------------------------------------------------------------

test("nameParser: la clave de equipo no depende del orden", () => {
  assert.equal(generateTeamKey(extractMembers("Carlos y Juan")), "carlos_juan");
  assert.equal(generateTeamKey(extractMembers("Juan & Carlos")), "carlos_juan");
});

test("nameParser: quita diacríticos y normaliza", () => {
  assert.equal(generateTeamKey(extractMembers("Efraín y Ana")), "ana_efrain");
});

// ---------------------------------------------------------------------------
// Utilidades puras de rankings (bucketing UTC)
// ---------------------------------------------------------------------------

test("rankings: monthKey usa UTC", () => {
  // 2026-09-30T23:30:00Z sigue siendo septiembre en UTC.
  assert.equal(rankingsUtil.monthKey("2026-09-30T23:30:00.000Z"), "2026-09");
  assert.equal(rankingsUtil.monthKey("nope"), null);
});

test("rankings: availableMonths ordena descendente y sin duplicados", () => {
  const months = rankingsUtil.availableMonths([
    { matches: [{ date: "2026-03-01T00:00:00Z" }, { date: "2026-05-01T00:00:00Z" }] },
    { matches: [{ date: "2026-05-20T00:00:00Z" }] },
  ]);
  assert.deepEqual(months, ["2026-05", "2026-03"]);
});

test("rankings: la liga casual se excluye del ranking global", () => {
  const { teams } = rankingsUtil.rankGlobal([
    {
      id: rankingsUtil.CASUAL_LEAGUE_ID,
      matches: [
        {
          team1Members: ["X"],
          team2Members: ["Y"],
          score1: 200,
          score2: 0,
          winnerTeam: 1,
          date: "2026-05-01T00:00:00Z",
        },
      ],
    },
  ]);
  assert.equal(teams.length, 0);
});

// ---------------------------------------------------------------------------
// Healthcheck y cabeceras
// ---------------------------------------------------------------------------

test("GET /health responde ok sin exponer detalles internos", async () => {
  const res = await api("GET", "/health");
  assert.equal(res.status, 200);
  assert.equal(res.body.status, "ok");
  assert.ok(res.body.version);
  assert.equal(res.body.features, undefined, "ya no se listan features públicas");
});

test("cabeceras de seguridad presentes; X-Powered-By ausente", async () => {
  const res = await api("GET", "/health");
  assert.equal(res.headers.get("x-powered-by"), null);
  assert.equal(res.headers.get("x-content-type-options"), "nosniff");
  assert.equal(res.headers.get("x-frame-options"), "DENY");
  assert.ok(res.headers.get("referrer-policy"));
});

test("CORS: refleja el origen permitido y bloquea uno no listado", async () => {
  const allowed = await api("GET", "/health", undefined, {
    Origin: "https://alr1730.github.io",
  });
  assert.equal(allowed.headers.get("access-control-allow-origin"), "https://alr1730.github.io");

  const blocked = await api("GET", "/health", undefined, {
    Origin: "https://evil.example.com",
  });
  assert.equal(blocked.headers.get("access-control-allow-origin"), null);
});

test("404 en endpoint inexistente devuelve JSON", async () => {
  const res = await api("GET", "/ruta-que-no-existe");
  assert.equal(res.status, 404);
  assert.equal(res.body.success, false);
});

// ---------------------------------------------------------------------------
// Ciclo de vida de ligas
// ---------------------------------------------------------------------------

test("flujo completo de liga: crear, unirse, registrar partida, rankings, eliminar", async () => {
  const create = await api("POST", "/api/leagues", {
    name: "Liga Flujo Completo",
    pin: "8888",
    initialParticipants: ["Ana", "Beto", "Carlos", "Diana"],
  });
  assert.equal(create.status, 201);
  assert.equal(create.body.success, true);
  const league = create.body.league;
  assert.match(league.id, /^LIG-\d{4}$/);
  assert.equal(league.players && Object.keys(league.players).length, 4);
  assert.doesNotMatch(JSON.stringify(create.body), /"pin"/, "la creación no devuelve el PIN");

  const joinOk = await api("POST", "/api/leagues/join", {
    nameOrId: league.id,
    pin: "8888",
  });
  assert.equal(joinOk.status, 200);
  assert.equal(joinOk.body.league.name, "Liga Flujo Completo");
  assert.equal(joinOk.body.league.pin, "8888", "join es el único endpoint que devuelve el PIN");

  const joinFail = await api("POST", "/api/leagues/join", {
    nameOrId: league.id,
    pin: "0000",
  });
  assert.equal(joinFail.status, 401);

  const match = await api("POST", `/api/leagues/${league.id}/matches`, {
    pin: "8888",
    team1DisplayName: "Ana & Beto",
    team2DisplayName: "Carlos & Diana",
    team1Members: ["Ana", "Beto"],
    team2Members: ["Carlos", "Diana"],
    score1: 205,
    score2: 150,
    winnerTeam: 1,
  });
  assert.equal(match.status, 201);
  assert.equal(match.body.match.winnerTeam, 1);
  assert.ok(match.body.match.id, "el servidor genera un id de partida");

  const leagueRes = await api("GET", `/api/leagues/${league.id}`);
  assert.equal(leagueRes.body.league.pin, undefined, "GET /:id no expone el PIN");
  assert.equal(leagueRes.body.league.matches.length, 1);

  const globalTeams = await api("GET", "/api/rankings/global/teams");
  assert.equal(globalTeams.status, 200);
  const ana = globalTeams.body.teams.find((t) => t.key === "ana_beto");
  assert.ok(ana, "el equipo debe aparecer en el ranking global");
  assert.equal(ana.wins, 1);

  const leagueRanking = await api("GET", `/api/rankings/league/${league.id}`);
  assert.equal(leagueRanking.status, 200);
  assert.ok(Array.isArray(leagueRanking.body.teams));

  const delFail = await api("DELETE", `/api/leagues/${league.id}`, { pin: "wrong" });
  assert.equal(delFail.status, 401);

  const delOk = await api("DELETE", `/api/leagues/${league.id}`, { pin: "8888" });
  assert.equal(delOk.status, 200);
  assert.equal(delOk.body.success, true);

  const gone = await api("GET", `/api/leagues/${league.id}`);
  assert.equal(gone.status, 404);
});

test("crear liga sin nombre devuelve 400", async () => {
  const res = await api("POST", "/api/leagues", { name: "   ", pin: "1234" });
  assert.equal(res.status, 400);
});

test("registrar partida sin PIN devuelve 401", async () => {
  const create = await api("POST", "/api/leagues", { name: "Sin PIN Match", pin: "4321" });
  const id = create.body.league.id;
  const res = await api("POST", `/api/leagues/${id}/matches`, {
    team1Members: ["Ana"],
    team2Members: ["Beto"],
    score1: 100,
    score2: 50,
    winnerTeam: 1,
  });
  assert.equal(res.status, 401);
});

test("registrar partida sin miembros devuelve 400", async () => {
  const create = await api("POST", "/api/leagues", { name: "Sin Miembros", pin: "4321" });
  const id = create.body.league.id;
  const res = await api("POST", `/api/leagues/${id}/matches`, {
    pin: "4321",
    team1Members: [],
    team2Members: ["Beto"],
    score1: 100,
    score2: 50,
    winnerTeam: 1,
  });
  assert.equal(res.status, 400);
});

test("puntajes inválidos devuelven 400", async () => {
  const create = await api("POST", "/api/leagues", { name: "Puntajes Malos", pin: "4321" });
  const id = create.body.league.id;
  for (const body of [
    { score1: "banana", score2: -5 },
    { score1: 1.5, score2: 0 },
  ]) {
    const res = await api("POST", `/api/leagues/${id}/matches`, {
      pin: "4321",
      team1Members: ["Ana"],
      team2Members: ["Beto"],
      winnerTeam: 1,
      ...body,
    });
    assert.equal(res.status, 400, `debe rechazar ${JSON.stringify(body)}`);
  }
});

test("winnerTeam inválido devuelve 400", async () => {
  const create = await api("POST", "/api/leagues", { name: "Ganador Invalido", pin: "4321" });
  const id = create.body.league.id;
  const res = await api("POST", `/api/leagues/${id}/matches`, {
    pin: "4321",
    team1Members: ["Ana"],
    team2Members: ["Beto"],
    score1: 100,
    score2: 50,
    winnerTeam: 3,
  });
  assert.equal(res.status, 400);
});

// ---------------------------------------------------------------------------
// Sincronización y seguridad del PIN
// ---------------------------------------------------------------------------

test("sync con PIN incorrecto devuelve 401 y no sobrescribe el PIN guardado", async () => {
  const create = await api("POST", "/api/leagues", { name: "Sync Segura", pin: "4321" });
  const id = create.body.league.id;

  const badSync = await api("POST", "/api/leagues/sync", {
    id,
    name: "Sync Segura",
    pin: "0000",
    matches: [],
  });
  assert.equal(badSync.status, 401);

  const okSync = await api("POST", "/api/leagues/sync", {
    id,
    name: "Sync Segura v2",
    pin: "4321",
    matches: [],
  });
  assert.equal(okSync.status, 200);

  const join = await api("POST", "/api/leagues/join", { nameOrId: id, pin: "4321" });
  assert.equal(join.status, 200, "el PIN original debe seguir vigente");

  const joinOldName = await api("POST", "/api/leagues/join", { nameOrId: id, pin: "4321" });
  assert.equal(joinOldName.body.league.name, "Sync Segura v2", "el nombre sí se actualiza");
});

test("sync crea la liga cuando no existe y agrega sus partidas", async () => {
  const res = await api("POST", "/api/leagues/sync", {
    id: "LIG-SYNC-NUEVA",
    name: "Sincronizada Nueva",
    pin: "5555",
    participants: ["Hugo", "Paco"],
    matches: [
      {
        id: "match_sync_1",
        date: "2026-06-10T12:00:00.000Z",
        team1DisplayName: "Hugo y Paco",
        team2DisplayName: "Luis y Extra",
        team1Members: ["Hugo", "Paco"],
        team2Members: ["Luis", "Extra"],
        score1: 200,
        score2: 120,
        winnerTeam: 1,
      },
    ],
  });
  assert.equal(res.status, 200);
  assert.equal(res.body.league.matches.length, 1);

  // Reenviar el mismo match no lo duplica.
  const again = await api("POST", "/api/leagues/sync", {
    id: "LIG-SYNC-NUEVA",
    name: "Sincronizada Nueva",
    pin: "5555",
    matches: [
      {
        id: "match_sync_1",
        date: "2026-06-10T12:00:00.000Z",
        team1Members: ["Hugo", "Paco"],
        team2Members: ["Luis", "Extra"],
        score1: 200,
        score2: 120,
        winnerTeam: 1,
      },
    ],
  });
  assert.equal(again.body.league.matches.length, 1, "no se duplica la misma partida");
});

test("sync sin id devuelve 400", async () => {
  const res = await api("POST", "/api/leagues/sync", { name: "Sin id" });
  assert.equal(res.status, 400);
});

// ---------------------------------------------------------------------------
// Participantes
// ---------------------------------------------------------------------------

test("agregar y eliminar participantes requiere PIN y maneja nombres con '%'", async () => {
  const create = await api("POST", "/api/leagues", { name: "Participantes", pin: "4321" });
  const id = create.body.league.id;

  const noPin = await api("POST", `/api/leagues/${id}/participants`, { name: "Efraín" });
  assert.equal(noPin.status, 401);

  const addPercent = await api("POST", `/api/leagues/${id}/participants`, {
    name: "50% Juan",
    pin: "4321",
  });
  assert.equal(addPercent.status, 200);
  assert.ok(addPercent.body.participants.includes("50% Juan"));

  // Sin volver a codificar el '%' dos veces (regresión de decodeURIComponent).
  const del = await api(
    "DELETE",
    `/api/leagues/${id}/participants/${encodeURIComponent("50% Juan")}`,
    { pin: "4321" }
  );
  assert.equal(del.status, 200);
  assert.ok(!del.body.participants.some((p) => p.includes("%")));
});

test("la lista pública de ligas no expone el PIN", async () => {
  await api("POST", "/api/leagues", { name: "Lista Publica", pin: "9999" });
  const res = await api("GET", "/api/leagues");
  assert.equal(res.status, 200);
  assert.doesNotMatch(JSON.stringify(res.body), /"pin"/);
  const entry = res.body.leagues.find((l) => l.name === "Lista Publica");
  assert.ok(entry);
  assert.equal(typeof entry.participantsCount, "number");
  assert.equal(typeof entry.matchesCount, "number");
});

// ---------------------------------------------------------------------------
// Rankings por mes (bucketing UTC en el endpoint real)
// ---------------------------------------------------------------------------

test("los rankings mensuales agrupan por mes en UTC", async () => {
  const create = await api("POST", "/api/leagues", {
    name: "Ranking Mensual",
    pin: "2468",
    initialParticipants: ["Ana", "Beto"],
  });
  const id = create.body.league.id;

  // 2026-09-30T23:30Z => septiembre UTC; 2026-10-01T01:00Z => octubre UTC.
  await api("POST", `/api/leagues/${id}/matches`, {
    pin: "2468",
    date: "2026-09-30T23:30:00.000Z",
    team1Members: ["Ana"],
    team2Members: ["Beto"],
    score1: 200,
    score2: 100,
    winnerTeam: 1,
  });
  await api("POST", `/api/leagues/${id}/matches`, {
    pin: "2468",
    date: "2026-10-01T01:00:00.000Z",
    team1Members: ["Ana"],
    team2Members: ["Beto"],
    score1: 100,
    score2: 200,
    winnerTeam: 2,
  });

  const sep = await api("GET", "/api/rankings/global/teams?year=2026&month=9");
  const anaSep = sep.body.teams.find((t) => t.key === "ana");
  assert.equal(anaSep.matchesPlayed, 1);
  assert.equal(anaSep.wins, 1);
  assert.ok(sep.body.availableMonths.includes("2026-09"));
  assert.ok(sep.body.availableMonths.includes("2026-10"));

  const oct = await api("GET", "/api/rankings/global/players?year=2026&month=10");
  const betoOct = oct.body.players.find((p) => p.key === "beto");
  assert.equal(betoOct.wins, 1);
});
