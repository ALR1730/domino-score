require("dotenv").config();
const mongo = require("../src/db/mongo");
const store = require("../src/models/store");

async function main() {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    console.error("❌ MONGODB_URI no encontrada en .env");
    process.exit(1);
  }

  console.log("🔄 Conectando a MongoDB Atlas...");
  const connected = await mongo.connect(uri);
  if (!connected) {
    console.error("❌ No se pudo conectar a MongoDB");
    process.exit(1);
  }

  const leagueName = "EL MUNDO DE JULITO";
  const leaguePin = "9876";
  const leagueId = "LIG-9876";

  const col = mongo.getCollection("leagues");

  // Verificar si ya existe
  const existing = await col.findOne({
    $or: [
      { id: leagueId },
      { name: leagueName }
    ]
  });

  const now = new Date().toISOString();

  const leagueDoc = {
    _id: existing ? existing._id : leagueId,
    id: existing ? existing.id : leagueId,
    name: leagueName,
    pin: leaguePin,
    createdAt: existing ? existing.createdAt : now,
    updatedAt: now,
    participants: existing && existing.participants && existing.participants.length > 0
      ? existing.participants
      : ["Julito"],
    players: existing && existing.players && Object.keys(existing.players).length > 0
      ? existing.players
      : {
          julito: {
            key: "julito",
            name: "Julito",
            wins: 0,
            matchesPlayed: 0
          }
        },
    teams: existing && existing.teams ? existing.teams : {},
    matches: existing && existing.matches ? existing.matches : []
  };

  await col.updateOne(
    { _id: leagueDoc._id },
    { $set: leagueDoc },
    { upsert: true }
  );

  console.log("✅ Liga guardada exitosamente en MongoDB Atlas:");
  console.log("----------------------------------------");
  console.log(`🏆 ID:           ${leagueDoc.id}`);
  console.log(`📛 Nombre:       ${leagueDoc.name}`);
  console.log(`🔑 PIN:          ${leagueDoc.pin}`);
  console.log(`👥 Participantes: ${leagueDoc.participants.join(", ")}`);
  console.log("----------------------------------------");

  await mongo.close();
}

main().catch((err) => {
  console.error("Error cargando liga:", err);
  process.exit(1);
});
