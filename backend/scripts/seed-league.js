require("dotenv").config();
const mongo = require("../src/db/mongo");
const { removeDiacritics } = require("../src/utils/nameParser");
const { hashPin } = require("../src/utils/pinCrypto");

function buildInitialPlayers(participants) {
  const players = {};
  for (const name of participants) {
    const key = removeDiacritics(name.toLowerCase());
    if (!key) continue;
    players[key] = {
      key,
      name,
      wins: 0,
      matchesPlayed: 0,
    };
  }
  return players;
}

async function main() {
  const uri = (process.env.MONGODB_URI || "").trim();
  const leagueId = (process.env.SEED_LEAGUE_ID || "").trim();
  const leagueName = (process.env.SEED_LEAGUE_NAME || "").trim();
  const leaguePin = (process.env.SEED_LEAGUE_PIN || "").trim();

  const missing = [];
  if (!uri) missing.push("MONGODB_URI");
  if (!leagueId) missing.push("SEED_LEAGUE_ID");
  if (!leagueName) missing.push("SEED_LEAGUE_NAME");
  if (!leaguePin) missing.push("SEED_LEAGUE_PIN");

  if (missing.length > 0) {
    console.error(`❌ Faltan variables de entorno requeridas: ${missing.join(", ")}`);
    console.error(
      "Uso: MONGODB_URI=... SEED_LEAGUE_ID=LIG-XXXX SEED_LEAGUE_NAME='Mi Liga' SEED_LEAGUE_PIN=XXXX [SEED_PARTICIPANTS='Ana,Beto'] node scripts/seed-league.js"
    );
    process.exit(1);
  }

  const seedParticipants = (process.env.SEED_PARTICIPANTS || "")
    .split(",")
    .map((p) => p.trim())
    .filter(Boolean);

  console.log("🔄 Conectando a MongoDB Atlas...");
  const connected = await mongo.connect(uri);
  if (!connected) {
    console.error("❌ No se pudo conectar a MongoDB");
    process.exit(1);
  }

  const col = mongo.getCollection("leagues");

  const existing = await col.findOne({
    $or: [{ id: leagueId }, { name: leagueName }],
  });

  const now = new Date().toISOString();
  const hasExistingParticipants =
    existing && Array.isArray(existing.participants) && existing.participants.length > 0;
  const hasExistingPlayers =
    existing && existing.players && Object.keys(existing.players).length > 0;

  const participants = hasExistingParticipants ? existing.participants : seedParticipants;
  const players = hasExistingPlayers ? existing.players : buildInitialPlayers(participants);

  const { pinHash, pinSalt } = await hashPin(leaguePin);

  const leagueDoc = {
    _id: existing ? existing._id : leagueId,
    id: existing ? existing.id : leagueId,
    name: leagueName,
    pinHash,
    pinSalt,
    createdAt: existing ? existing.createdAt : now,
    updatedAt: now,
    participants,
    players,
    teams: existing && existing.teams ? existing.teams : {},
    matches: existing && existing.matches ? existing.matches : [],
  };

  await col.updateOne(
    { _id: leagueDoc._id },
    { $set: leagueDoc, $unset: { pin: "" } },
    { upsert: true }
  );

  console.log("✅ Liga guardada exitosamente en MongoDB Atlas:");
  console.log("----------------------------------------");
  console.log(`🏆 ID:           ${leagueDoc.id}`);
  console.log(`📛 Nombre:       ${leagueDoc.name}`);
  console.log("🔑 PIN:          (configurado vía SEED_LEAGUE_PIN)");
  console.log(`👥 Participantes: ${leagueDoc.participants.join(", ")}`);
  console.log("----------------------------------------");

  await mongo.close();
}

main().catch((err) => {
  console.error("Error cargando liga:", err);
  process.exit(1);
});
