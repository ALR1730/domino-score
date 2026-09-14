const assert = require("assert");
const http = require("http");
const app = require("../src/server");
const {
  extractMembers,
  generateTeamKey,
} = require("../src/utils/nameParser");

// Helper para hacer requests HTTP locales contra la app Express
function request(server, options, body = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        host: "127.0.0.1",
        port: server.address().port,
        ...options,
        headers: {
          "Content-Type": "application/json",
          ...(options.headers || {}),
        },
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          let json = null;
          try {
            json = JSON.parse(data);
          } catch (_) {
            json = data;
          }
          resolve({ status: res.statusCode, body: json });
        });
      }
    );
    req.on("error", reject);
    if (body) {
      req.write(typeof body === "string" ? body : JSON.stringify(body));
    }
    req.end();
  });
}

async function runTests() {
  console.log("🧪 Iniciando pruebas automatizadas del Backend REST...\n");

  // 1. Test unitario de nameParser
  console.log("1. Test NameParser: normalización independiente del orden...");
  const teamA = extractMembers("Carlos y Juan");
  const teamB = extractMembers("Juan & Carlos");
  const keyA = generateTeamKey(teamA);
  const keyB = generateTeamKey(teamB);
  assert.strictEqual(keyA, "carlos_juan");
  assert.strictEqual(keyB, "carlos_juan");
  assert.strictEqual(keyA, keyB, "Las dos combinaciones deben generar la misma clave");
  console.log("   ✅ NameParser pasó correctamente.\n");

  // 2. Iniciar servidor temporal para pruebas de integración
  const server = http.createServer(app);
  await new Promise((res) => server.listen(0, "127.0.0.1", res));

  try {
    // 3. Test Healthcheck
    console.log("2. Test GET /health...");
    const health = await request(server, { method: "GET", path: "/health" });
    assert.strictEqual(health.status, 200);
    assert.strictEqual(health.body.status, "ok");
    console.log("   ✅ Healthcheck OK.\n");

    // 4. Test Crear Liga
    console.log("3. Test POST /api/leagues (Crear Liga)...");
    const createRes = await request(
      server,
      { method: "POST", path: "/api/leagues" },
      {
        name: "Liga de Prueba CI",
        pin: "8888",
        initialParticipants: ["Ana", "Beto", "Carlos", "Diana"],
      }
    );
    assert.strictEqual(createRes.status, 201);
    assert.strictEqual(createRes.body.success, true);
    const createdLeague = createRes.body.league;
    assert.ok(createdLeague.id.startsWith("LIG-"));
    console.log(`   ✅ Liga creada con ID: ${createdLeague.id}\n`);

    // 5. Test Unirse con PIN
    console.log("4. Test POST /api/leagues/join (Unirse con PIN correcto)...");
    const joinOk = await request(
      server,
      { method: "POST", path: "/api/leagues/join" },
      { nameOrId: createdLeague.id, pin: "8888" }
    );
    assert.strictEqual(joinOk.status, 200);
    assert.strictEqual(joinOk.body.league.name, "Liga de Prueba CI");
    console.log("   ✅ Unirse con PIN correcto OK.\n");

    console.log("5. Test POST /api/leagues/join (Rechazo con PIN erróneo)...");
    const joinFail = await request(
      server,
      { method: "POST", path: "/api/leagues/join" },
      { nameOrId: createdLeague.id, pin: "0000" }
    );
    assert.strictEqual(joinFail.status, 401);
    console.log("   ✅ Rechazo con PIN inválido OK.\n");

    // 6. Test Registrar Partida y Verificar Rankings
    console.log("6. Test POST /api/leagues/:id/matches (Registrar Partida)...");
    const matchRes = await request(
      server,
      { method: "POST", path: `/api/leagues/${createdLeague.id}/matches` },
      {
        team1DisplayName: "Ana & Beto",
        team2DisplayName: "Carlos & Diana",
        team1Members: ["Ana", "Beto"],
        team2Members: ["Carlos", "Diana"],
        score1: 205,
        score2: 150,
        winnerTeam: 1,
      }
    );
    assert.strictEqual(matchRes.status, 201);
    assert.strictEqual(matchRes.body.match.winnerTeam, 1);
    console.log("   ✅ Partida registrada y estadísticas recalculadas.\n");

    // 7. Test Rankings Globales
    console.log("7. Test GET /api/rankings/global/teams...");
    const rankingsTeams = await request(server, { method: "GET", path: "/api/rankings/global/teams" });
    assert.strictEqual(rankingsTeams.status, 200);
    assert.ok(Array.isArray(rankingsTeams.body.teams));
    assert.ok(rankingsTeams.body.teams.length > 0);
    console.log(`   ✅ Ranking global de equipos OK (${rankingsTeams.body.teams.length} equipos).\n`);

    console.log("8. Test GET /api/rankings/global/players...");
    const rankingsPlayers = await request(server, { method: "GET", path: "/api/rankings/global/players" });
    assert.strictEqual(rankingsPlayers.status, 200);
    assert.ok(Array.isArray(rankingsPlayers.body.players));
    console.log(`   ✅ Ranking global de jugadores OK (${rankingsPlayers.body.players.length} jugadores).\n`);

    console.log("🎉 ¡TODAS LAS PRUEBAS AUTOMATIZADAS PASARON CON ÉXITO!");
    process.exit(0);
  } catch (err) {
    console.error("❌ Error en las pruebas:", err);
    process.exit(1);
  } finally {
    server.close();
  }
}

runTests();
