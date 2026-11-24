/**
 * Pruebas unitarias e integración para Fase 4:
 * hashing scrypt (Expand -> Dual-Read -> Lazy Upgrade),
 * backup solo-lectura y script idempotente de migración.
 */
const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const fs = require("node:fs");

const DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), "domino-pin-crypto-"));
process.env.DATA_DIR = DATA_DIR;
process.env.ALLOW_LOCAL_FALLBACK = "true";

const app = require("../src/server");
const store = require("../src/models/store");
const pinCrypto = require("../src/utils/pinCrypto");
const { exportLeaguesBackup } = require("../scripts/backup-leagues");
const { migratePinsCollection } = require("../scripts/migrate-pins");

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

async function api(method, endpoint, body) {
  const res = await fetch(`${baseUrl}${endpoint}`, {
    method,
    headers: { "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, body: JSON.parse(text) };
}

test("pinCrypto: hashPin genera salts aleatorios de 16 bytes y verifyPin valida correctamente", async () => {
  const first = await pinCrypto.hashPin("4829");
  const second = await pinCrypto.hashPin("4829");

  assert.match(first.pinSalt, /^[0-9a-f]{32}$/);
  assert.match(first.pinHash, /^[0-9a-f]{64}$/);
  assert.notEqual(first.pinSalt, second.pinSalt);
  assert.notEqual(first.pinHash, second.pinHash);

  const hashedLeague = { pinHash: first.pinHash, pinSalt: first.pinSalt };
  assert.deepEqual(await pinCrypto.verifyPin(hashedLeague, "4829"), {
    valid: true,
    needsUpgrade: false,
  });
  assert.deepEqual(await pinCrypto.verifyPin(hashedLeague, " 4829 "), {
    valid: true,
    needsUpgrade: false,
  });
  assert.deepEqual(await pinCrypto.verifyPin(hashedLeague, "0000"), {
    valid: false,
    needsUpgrade: false,
  });
});

test("pinCrypto: soporta documentos legados en texto plano y rechaza entradas corruptas", async () => {
  const legacyLeague = { pin: "9876" };
  assert.deepEqual(await pinCrypto.verifyPin(legacyLeague, "9876"), {
    valid: true,
    needsUpgrade: true,
  });
  assert.deepEqual(await pinCrypto.verifyPin(legacyLeague, "1111"), {
    valid: false,
    needsUpgrade: false,
  });

  for (const invalid of [null, undefined, "", "   ", 1234]) {
    const res = await pinCrypto.verifyPin(legacyLeague, invalid);
    assert.deepEqual(res, { valid: false, needsUpgrade: false });
  }

  const corruptHash = { pinHash: "not-hex", pinSalt: "bad-salt" };
  assert.deepEqual(await pinCrypto.verifyPin(corruptHash, "9876"), {
    valid: false,
    needsUpgrade: false,
  });
  await assert.rejects(() => pinCrypto.hashPin("   "));
  await assert.rejects(() => pinCrypto.hashPin(1234));
});

test("HTTP: POST /api/leagues guarda pinHash + pinSalt sin pin plano y mantiene contrato retrocompatible", async () => {
  const create = await api("POST", "/api/leagues", {
    name: "Liga Scrypt Nueva",
    pin: "7712",
    initialParticipants: ["Ana", "Beto"],
  });
  assert.equal(create.status, 201);
  assert.equal(create.body.pin, "7712");
  assert.equal(create.body.league.pin, undefined);
  assert.equal(create.body.league.pinHash, undefined);
  assert.equal(create.body.league.pinSalt, undefined);

  const id = create.body.league.id;
  const stored = store.getLeagueById(id);
  assert.equal(stored.pin, undefined);
  assert.match(stored.pinHash, /^[0-9a-f]{64}$/);
  assert.match(stored.pinSalt, /^[0-9a-f]{32}$/);

  const publicList = await api("GET", "/api/leagues");
  assert.doesNotMatch(JSON.stringify(publicList.body), /pinHash|pinSalt|"pin"/);

  const getOne = await api("GET", `/api/leagues/${id}`);
  assert.equal(getOne.status, 200);
  assert.equal(getOne.body.league.pin, undefined);
  assert.equal(getOne.body.league.pinHash, undefined);
  assert.equal(getOne.body.league.pinSalt, undefined);

  const joinOk = await api("POST", "/api/leagues/join", {
    nameOrId: id,
    pin: "7712",
  });
  assert.equal(joinOk.status, 200);
  assert.equal(joinOk.body.league.pin, "7712");
  assert.equal(joinOk.body.league.pinHash, undefined);
  assert.equal(joinOk.body.league.pinSalt, undefined);
});

test("Dual-Read + Lazy Upgrade: liga legada se actualiza a scrypt en /join conservando toda la data", async () => {
  const legacyMatch = {
    id: "match_leg_1",
    date: "2026-06-01T12:00:00.000Z",
    team1DisplayName: "Ana & Luis",
    team2DisplayName: "Beto & Carlos",
    team1Members: ["Ana", "Luis"],
    team2Members: ["Beto", "Carlos"],
    score1: 200,
    score2: 140,
    winnerTeam: 1,
  };
  store.leagues.set("LIG-LEG98", {
    id: "LIG-LEG98",
    name: "Liga Legada 98",
    pin: "9876",
    createdAt: "2026-01-01T00:00:00.000Z",
    participants: ["Ana", "Luis", "Beto", "Carlos"],
    teams: { ana_luis: { key: "ana_luis", wins: 1, matchesPlayed: 1, totalPoints: 200 } },
    players: { ana: { key: "ana", name: "Ana", wins: 1, matchesPlayed: 1 } },
    matches: [legacyMatch],
  });

  const badJoin = await api("POST", "/api/leagues/join", {
    nameOrId: "LIG-LEG98",
    pin: "0000",
  });
  assert.equal(badJoin.status, 401);
  assert.equal(store.getLeagueById("LIG-LEG98").pin, "9876");

  const joinOk = await api("POST", "/api/leagues/join", {
    nameOrId: "LIG-LEG98",
    pin: "9876",
  });
  assert.equal(joinOk.status, 200);
  assert.equal(joinOk.body.league.pin, "9876");
  assert.equal(joinOk.body.league.pinHash, undefined);
  assert.equal(joinOk.body.league.pinSalt, undefined);

  const upgraded = store.getLeagueById("LIG-LEG98");
  assert.equal(upgraded.pin, undefined);
  assert.match(upgraded.pinHash, /^[0-9a-f]{64}$/);
  assert.match(upgraded.pinSalt, /^[0-9a-f]{32}$/);
  assert.deepEqual(upgraded.participants, ["Ana", "Luis", "Beto", "Carlos"]);
  assert.equal(upgraded.matches.length, 1);
  assert.equal(upgraded.matches[0].id, "match_leg_1");
  assert.equal(upgraded.teams.ana_luis.wins, 1);
  assert.equal(upgraded.players.ana.wins, 1);
});

test("store._upsertInMongo emite $unset de pin cuando hay pinHash", async () => {
  const calls = [];
  const fakeCol = {
    async updateOne(filter, update, options) {
      calls.push({ filter, update, options });
    },
  };
  await store._upsertInMongo(fakeCol, {
    id: "LIG-MONGO-1",
    name: "Mongo Hash",
    pinHash: "ab".repeat(32),
    pinSalt: "cd".repeat(16),
  });

  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].update.$unset, { pin: "" });
  assert.equal(calls[0].update.$set.pin, undefined);
  assert.equal(calls[0].update.$set.pinHash, "ab".repeat(32));
});

test("endpoints sync, participants, matches y DELETE autentican con pinHash", async () => {
  const create = await api("POST", "/api/leagues", {
    name: "Auth Scrypt Endpoints",
    pin: "6161",
    initialParticipants: ["Ana"],
  });
  const id = create.body.league.id;

  const badSync = await api("POST", "/api/leagues/sync", {
    id,
    name: "Auth Scrypt Endpoints",
    pin: "9999",
    matches: [],
  });
  assert.equal(badSync.status, 401);

  const okSync = await api("POST", "/api/leagues/sync", {
    id,
    name: "Auth Scrypt v2",
    pin: "6161",
    matches: [],
  });
  assert.equal(okSync.status, 200);
  assert.equal(okSync.body.league.pinHash, undefined);

  const okPart = await api("POST", `/api/leagues/${id}/participants`, {
    name: "Beto",
    pin: "6161",
  });
  assert.equal(okPart.status, 200);

  const badMatch = await api("POST", `/api/leagues/${id}/matches`, {
    pin: "1111",
    team1Members: ["Ana"],
    team2Members: ["Beto"],
    score1: 200,
    score2: 100,
    winnerTeam: 1,
  });
  assert.equal(badMatch.status, 401);

  const okMatch = await api("POST", `/api/leagues/${id}/matches`, {
    pin: "6161",
    team1Members: ["Ana"],
    team2Members: ["Beto"],
    score1: 200,
    score2: 100,
    winnerTeam: 1,
  });
  assert.equal(okMatch.status, 201);
  assert.equal(okMatch.body.league.pinHash, undefined);

  const delPart = await api("DELETE", `/api/leagues/${id}/participants/Beto`, {
    pin: "6161",
  });
  assert.equal(delPart.status, 200);

  const badDel = await api("DELETE", `/api/leagues/${id}`, { pin: "0000" });
  assert.equal(badDel.status, 401);

  const okDel = await api("DELETE", `/api/leagues/${id}`, { pin: "6161" });
  assert.equal(okDel.status, 200);
});

test("scripts backup-leagues y migrate-pins (--dry-run y --apply idempotente)", async () => {
  const hashed = await pinCrypto.hashPin("4321");
  const docs = [
    {
      _id: "LIG-L1",
      id: "LIG-L1",
      name: "Legada Uno",
      pin: "9876",
      participants: ["Julito"],
      matches: [{ id: "m1" }, { id: "m2" }],
    },
    {
      _id: "LIG-H1",
      id: "LIG-H1",
      name: "Ya Hasheada",
      pinHash: hashed.pinHash,
      pinSalt: hashed.pinSalt,
      participants: ["Ana"],
      matches: [],
    },
  ];
  let updateCalls = 0;

  const mockCol = {
    find() {
      return {
        async toArray() {
          return docs.map((d) => structuredClone(d));
        },
      };
    },
    async updateOne(filter, update) {
      updateCalls += 1;
      const target = docs.find((d) => d._id === filter._id && !d.pinHash);
      if (!target) return { modifiedCount: 0 };
      if (update.$set) Object.assign(target, update.$set);
      if (update.$unset && "pin" in update.$unset) delete target.pin;
      return { modifiedCount: 1 };
    },
  };

  const backupPath = path.join(DATA_DIR, "backup-test.json");
  const backupReport = await exportLeaguesBackup(mockCol, backupPath);
  assert.equal(backupReport.count, 2);
  assert.equal(backupReport.legacyPinCount, 1);
  assert.equal(backupReport.hashedPinCount, 1);
  assert.match(backupReport.sha256, /^[0-9a-f]{64}$/);
  assert.equal(updateCalls, 0);

  const fileContent = fs.readFileSync(backupPath, "utf8");
  const actualSha = crypto.createHash("sha256").update(fileContent).digest("hex");
  assert.equal(backupReport.sha256, actualSha);

  const dryRun = await migratePinsCollection(mockCol, { apply: false });
  assert.equal(dryRun.apply, false);
  assert.equal(dryRun.candidatesCount, 1);
  assert.equal(dryRun.migratedCount, 0);
  assert.equal(updateCalls, 0);
  assert.equal(docs[0].pin, "9876");

  const applyRun = await migratePinsCollection(mockCol, { apply: true });
  assert.equal(applyRun.apply, true);
  assert.equal(applyRun.migratedCount, 1);
  assert.equal(updateCalls, 1);
  assert.equal(docs[0].pin, undefined);
  assert.match(docs[0].pinHash, /^[0-9a-f]{64}$/);
  assert.deepEqual(docs[0].participants, ["Julito"]);
  assert.equal(docs[0].matches.length, 2);

  const verified = await pinCrypto.verifyPin(docs[0], "9876");
  assert.deepEqual(verified, { valid: true, needsUpgrade: false });

  const secondRun = await migratePinsCollection(mockCol, { apply: true });
  assert.equal(secondRun.candidatesCount, 0);
  assert.equal(secondRun.migratedCount, 0);
});
