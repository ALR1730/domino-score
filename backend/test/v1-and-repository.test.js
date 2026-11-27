/**
 * Pruebas para Fase 5C:
 * - Contratos /api/v1/* con errores RFC 7807 (application/problem+json)
 * - Retrocompatibilidad intacta en /api/*
 * - Operaciones directas/atómicas de LeagueRepository y LeagueService
 */
const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const fs = require("node:fs");

const DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), "domino-v1-test-"));
process.env.DATA_DIR = DATA_DIR;
process.env.ALLOW_LOCAL_FALLBACK = "true";

const app = require("../src/server");
const mongo = require("../src/db/mongo");
const leagueRepository = require("../src/repositories/leagueRepository");
const leagueService = require("../src/services/leagueService");

let server;
let baseUrl;

test.before(async () => {
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

test.after(() => {
  leagueRepository.localLeagues.clear();
  leagueRepository.saveLocal();
  if (server) server.close();
  fs.rmSync(DATA_DIR, { recursive: true, force: true });
});

async function api(method, endpoint, body, headers = {}) {
  const res = await fetch(`${baseUrl}${endpoint}`, {
    method,
    headers: { "Content-Type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return {
    status: res.status,
    contentType: res.headers.get("content-type") || "",
    headers: res.headers,
    body: JSON.parse(text),
  };
}

test("/api/v1: paridad funcional de ciclo de vida de ligas y rankings", async () => {
  const ip = { "X-Forwarded-For": "203.0.113.60" };

  const created = await api(
    "POST",
    "/api/v1/leagues",
    {
      name: "Liga V1",
      pin: "4821",
      initialParticipants: ["Ana", "Luis"],
    },
    ip
  );
  assert.equal(created.status, 201);
  assert.equal(created.body.success, true);
  assert.equal(created.body.pin, "4821");
  const id = created.body.league.id;

  const list = await api("GET", "/api/v1/leagues", undefined, ip);
  assert.equal(list.status, 200);
  assert.ok(list.body.leagues.some((l) => l.id === id));

  const added = await api(
    "POST",
    `/api/v1/leagues/${id}/participants`,
    { name: "Carlos", pin: "4821" },
    ip
  );
  assert.equal(added.status, 200);
  assert.deepEqual(added.body.participants, ["Ana", "Luis", "Carlos"]);

  const matchRes = await api(
    "POST",
    `/api/v1/leagues/${id}/matches`,
    {
      id: "m-v1-1",
      pin: "4821",
      date: "2026-11-15T20:00:00.000Z",
      team1Members: ["Ana", "Luis"],
      team2Members: ["Carlos", "Pedro"],
      score1: 205,
      score2: 120,
      winnerTeam: 1,
    },
    ip
  );
  assert.equal(matchRes.status, 201);
  assert.equal(matchRes.body.match.id, "m-v1-1");

  const globalTeams = await api(
    "GET",
    "/api/v1/rankings/global/teams?year=2026&month=11&tzOffsetMinutes=-240",
    undefined,
    ip
  );
  assert.equal(globalTeams.status, 200);
  assert.ok(globalTeams.body.teams.some((t) => t.key === "ana_luis"));

  const leagueRankings = await api(
    "GET",
    `/api/v1/rankings/league/${id}`,
    undefined,
    ip
  );
  assert.equal(leagueRankings.status, 200);
  assert.equal(leagueRankings.body.leagueName, "Liga V1");

  const deleted = await api(
    "DELETE",
    `/api/v1/leagues/${id}`,
    { pin: "4821" },
    ip
  );
  assert.equal(deleted.status, 200);
});

test("/api/v1 emite RFC 7807 ProblemDetails en 400, 401, 404 y 429; /api/* mantiene contrato legado", async () => {
  const ip = { "X-Forwarded-For": "203.0.113.61" };

  // 400 validación
  const badV1 = await api("POST", "/api/v1/leagues", {}, ip);
  assert.equal(badV1.status, 400);
  assert.match(badV1.contentType, /application\/problem\+json/);
  assert.equal(badV1.body.status, 400);
  assert.ok(badV1.body.type);
  assert.ok(badV1.body.title);
  assert.ok(badV1.body.detail);
  assert.equal(badV1.body.instance, "/api/v1/leagues");

  const badLegacy = await api("POST", "/api/leagues", {}, ip);
  assert.equal(badLegacy.status, 400);
  assert.equal(badLegacy.body.success, false);
  assert.ok(badLegacy.body.error);

  // 404 ruta y recurso inexistente
  const notFoundV1 = await api("GET", "/api/v1/leagues/LIG-NOEXISTE", undefined, ip);
  assert.equal(notFoundV1.status, 404);
  assert.match(notFoundV1.contentType, /application\/problem\+json/);
  assert.equal(notFoundV1.body.status, 404);

  const notFoundRouteV1 = await api("GET", "/api/v1/desconocido", undefined, ip);
  assert.equal(notFoundRouteV1.status, 404);
  assert.match(notFoundRouteV1.contentType, /application\/problem\+json/);

  const notFoundLegacy = await api("GET", "/api/leagues/LIG-NOEXISTE", undefined, ip);
  assert.equal(notFoundLegacy.status, 404);
  assert.equal(notFoundLegacy.body.success, false);

  // 401 + 429 por fuerza bruta en IP dedicada
  const created = await api(
    "POST",
    "/api/v1/leagues",
    { name: "Liga Limit V1", pin: "7373" },
    { "X-Forwarded-For": "203.0.113.62" }
  );
  const id = created.body.league.id;

  const bruteIp = { "X-Forwarded-For": "203.0.113.63" };
  for (let i = 0; i < 10; i++) {
    const unauth = await api(
      "POST",
      "/api/v1/leagues/join",
      { nameOrId: id, pin: "0000" },
      bruteIp
    );
    assert.equal(unauth.status, 401);
    assert.match(unauth.contentType, /application\/problem\+json/);
    assert.equal(unauth.body.status, 401);
  }

  const limited = await api(
    "POST",
    "/api/v1/leagues/join",
    { nameOrId: id, pin: "7373" },
    bruteIp
  );
  assert.equal(limited.status, 429);
  assert.match(limited.contentType, /application\/problem\+json/);
  assert.equal(limited.body.status, 429);
  assert.ok(limited.body.retryAfterSeconds >= 1);
  assert.ok(limited.headers.get("retry-after"));
});

test("LeagueRepository: consultas directas sin RAM, regex escapada y operadores atómicos Mongo", async () => {
  const docs = new Map();
  const updateCalls = [];

  const getByPath = (obj, dotPath) =>
    dotPath.split(".").reduce((acc, k) => (acc == null ? undefined : acc[k]), obj);

  const getValuesByPath = (obj, dotPath) => {
    const parts = dotPath.split(".");
    let current = [obj];
    for (const part of parts) {
      const next = [];
      for (const item of current) {
        if (Array.isArray(item)) {
          for (const elem of item) {
            if (elem != null && typeof elem === "object" && part in elem) {
              next.push(elem[part]);
            }
          }
        } else if (item != null && typeof item === "object" && part in item) {
          next.push(item[part]);
        }
      }
      current = next;
    }
    return current;
  };

  const setByPath = (obj, dotPath, value) => {
    const parts = dotPath.split(".");
    let cur = obj;
    for (let i = 0; i < parts.length - 1; i++) {
      if (!cur[parts[i]] || typeof cur[parts[i]] !== "object") {
        cur[parts[i]] = {};
      }
      cur = cur[parts[i]];
    }
    cur[parts[parts.length - 1]] = value;
  };

  const unsetByPath = (obj, dotPath) => {
    const parts = dotPath.split(".");
    let cur = obj;
    for (let i = 0; i < parts.length - 1; i++) {
      if (!cur || typeof cur !== "object") return;
      cur = cur[parts[i]];
    }
    if (cur && typeof cur === "object") delete cur[parts[parts.length - 1]];
  };

  const matchesFilter = (doc, filter) => {
    if (!filter || Object.keys(filter).length === 0) return true;
    for (const [k, cond] of Object.entries(filter)) {
      if (k === "$or") {
        if (!cond.some((sub) => matchesFilter(doc, sub))) return false;
        continue;
      }
      const values = getValuesByPath(doc, k);
      if (cond instanceof RegExp) {
        if (!values.some((v) => typeof v === "string" && cond.test(v))) {
          return false;
        }
      } else if (cond && typeof cond === "object" && !Array.isArray(cond)) {
        if ("$ne" in cond && values.some((v) => v === cond.$ne)) return false;
        if ("$exists" in cond) {
          const exists = values.length > 0;
          if (exists !== cond.$exists) return false;
        }
      } else if (!values.some((v) => v === cond)) {
        return false;
      }
    }
    return true;
  };

  const fakeCol = {
    async countDocuments(filter = {}) {
      return Array.from(docs.values()).filter((d) => matchesFilter(d, filter))
        .length;
    },
    async findOne(filter) {
      for (const doc of docs.values()) {
        if (matchesFilter(doc, filter)) return structuredClone(doc);
      }
      return null;
    },
    find(filter = {}) {
      const matched = Array.from(docs.values())
        .filter((d) => matchesFilter(d, filter))
        .map((d) => structuredClone(d));
      return {
        async toArray() {
          return matched;
        },
      };
    },
    async insertOne(doc) {
      if (docs.has(doc._id)) {
        const err = new Error("duplicate");
        err.code = 11000;
        throw err;
      }
      docs.set(doc._id, structuredClone(doc));
    },
    async updateOne(filter, update, options = {}) {
      updateCalls.push({ filter, update, options });
      const target = await this.findOne(filter);
      if (!target) {
        if (options.upsert && filter._id) {
          const base = { _id: filter._id };
          if (update.$set) {
            for (const [k, v] of Object.entries(update.$set)) {
              setByPath(base, k, structuredClone(v));
            }
          }
          docs.set(base._id, base);
          return { matchedCount: 1, modifiedCount: 1 };
        }
        return { matchedCount: 0, modifiedCount: 0 };
      }

      if (update.$set) {
        for (const [k, v] of Object.entries(update.$set)) {
          setByPath(target, k, structuredClone(v));
        }
      }
      if (update.$unset) {
        for (const k of Object.keys(update.$unset)) {
          unsetByPath(target, k);
        }
      }
      if (update.$addToSet) {
        for (const [k, v] of Object.entries(update.$addToSet)) {
          const arr = getByPath(target, k) || [];
          if (!arr.includes(v)) arr.push(v);
          setByPath(target, k, arr);
        }
      }
      if (update.$pullAll) {
        for (const [k, vals] of Object.entries(update.$pullAll)) {
          const arr = getByPath(target, k) || [];
          setByPath(
            target,
            k,
            arr.filter((item) => !vals.includes(item))
          );
        }
      }
      if (update.$push) {
        for (const [k, spec] of Object.entries(update.$push)) {
          const arr = getByPath(target, k) || [];
          if (spec && Array.isArray(spec.$each) && spec.$position === 0) {
            arr.unshift(...structuredClone(spec.$each));
          }
          setByPath(target, k, arr);
        }
      }
      if (update.$inc) {
        for (const [k, delta] of Object.entries(update.$inc)) {
          const current = Number(getByPath(target, k) || 0);
          setByPath(target, k, current + delta);
        }
      }

      docs.set(target._id, target);
      return { matchedCount: 1, modifiedCount: 1 };
    },
    async deleteOne(filter) {
      const target = await this.findOne(filter);
      if (target) {
        docs.delete(target._id);
        return { deletedCount: 1 };
      }
      return { deletedCount: 0 };
    },
  };

  const prevConnected = mongo.connected;
  const prevGetCol = mongo.getCollection;

  try {
    mongo.connected = true;
    mongo.getCollection = () => fakeCol;

    // 1. Liga con caracteres especiales regex en el nombre
    const created = await leagueService.createLeague({
      id: "LIG-RX1",
      name: "Liga [A+B].*",
      pin: "1919",
      initialParticipants: ["Ana"],
    });
    assert.equal(created.id, "LIG-RX1");

    // 2. Vaciar caché en RAM para comprobar lectura directa desde Mongo
    leagueRepository.localLeagues.clear();
    const loaded = await leagueService.getLeagueById("LIG-RX1");
    assert.equal(loaded.name, "Liga [A+B].*");

    const foundBySpecialName =
      await leagueService.findLeagueByNameOrId("Liga [A+B].*");
    assert.equal(foundBySpecialName?.id, "LIG-RX1");
    const shouldNotMatch = await leagueService.findLeagueByNameOrId(".*");
    assert.equal(shouldNotMatch, null);

    // 3. Participantes atómicos ($addToSet / $pullAll)
    await leagueService.addParticipant("LIG-RX1", "Luis");
    assert.ok(updateCalls.some((c) => c.update.$addToSet));
    await leagueService.removeParticipant("LIG-RX1", "Luis");
    assert.ok(updateCalls.some((c) => c.update.$pullAll));

    // 4. Partida atómica ($push / $inc / $set hoja sin conflicto padre/hijo) + idempotencia
    await leagueService.recordMatch("LIG-RX1", {
      id: "atomic-m1",
      team1Members: ["Ana", "Beto"],
      team2Members: ["Carlos", "Diego"],
      score1: 200,
      score2: 90,
      winnerTeam: 1,
    });
    await leagueService.recordMatch("LIG-RX1", {
      id: "atomic-m1", // duplicada: no debe incrementar dos veces
      team1Members: ["Ana", "Beto"],
      team2Members: ["Carlos", "Diego"],
      score1: 200,
      score2: 90,
      winnerTeam: 1,
    });

    const afterMatch = docs.get("LIG-RX1");
    assert.equal(afterMatch.matches.length, 1);
    assert.equal(afterMatch.teams.ana_beto.wins, 1);
    assert.equal(afterMatch.teams.ana_beto.totalPoints, 200);
    assert.equal(afterMatch.players.ana.wins, 1);

    // 5. Lazy upgrade atómico ($unset: { pin: "" })
    docs.set("LIG-LEGACY-AT", {
      _id: "LIG-LEGACY-AT",
      id: "LIG-LEGACY-AT",
      name: "Legada Atómica",
      pin: "4321",
      participants: [],
      teams: {},
      players: {},
      matches: [],
    });
    const ok = await leagueService.verifyLeaguePin("LIG-LEGACY-AT", "4321");
    assert.equal(ok, true);
    assert.equal(docs.get("LIG-LEGACY-AT").pin, undefined);
    assert.ok(docs.get("LIG-LEGACY-AT").pinHash);
  } finally {
    mongo.connected = prevConnected;
    mongo.getCollection = prevGetCol;
    leagueRepository.localLeagues.clear();
  }
});
