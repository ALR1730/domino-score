require("dotenv").config();
const mongo = require("../src/db/mongo");
const {
  hashPin,
  hasHashedPin,
  isLegacyPlaintextPin,
} = require("../src/utils/pinCrypto");

/**
 * Migra de forma idempotente ligas con PIN en texto plano a `pinHash` + `pinSalt`
 * (sin modificar ningún otro campo). Por defecto `apply = false` (--dry-run).
 */
async function migratePinsCollection(col, { apply = false } = {}) {
  const docs = await col.find({}).toArray();
  const candidates = [];
  const unexpectedIds = [];
  let alreadyHashedCount = 0;

  for (const doc of docs) {
    if (hasHashedPin(doc)) {
      alreadyHashedCount += 1;
      continue;
    }
    if (isLegacyPlaintextPin(doc)) {
      candidates.push(doc);
      continue;
    }
    unexpectedIds.push(doc.id || String(doc._id));
  }

  let migratedCount = 0;
  if (apply) {
    const now = new Date().toISOString();
    for (const doc of candidates) {
      const { pinHash, pinSalt } = await hashPin(doc.pin);
      const res = await col.updateOne(
        { _id: doc._id, pinHash: { $exists: false } },
        {
          $set: { pinHash, pinSalt, updatedAt: now },
          $unset: { pin: "" },
        }
      );
      if (!res || res.modifiedCount === undefined || res.modifiedCount > 0) {
        migratedCount += 1;
      }
    }
  }

  return {
    apply,
    totalDocs: docs.length,
    alreadyHashedCount,
    candidatesCount: candidates.length,
    candidateIds: candidates.map((d) => d.id || String(d._id)),
    unexpectedCount: unexpectedIds.length,
    unexpectedIds,
    migratedCount,
  };
}

async function main() {
  const apply = process.argv.includes("--apply");
  const uri = (process.env.MONGODB_URI || "").trim();
  if (!uri) {
    console.error("❌ Falta MONGODB_URI para ejecutar migrate-pins.");
    process.exit(1);
  }

  const connected = await mongo.connect(uri);
  if (!connected) {
    console.error("❌ No se pudo conectar a MongoDB.");
    process.exit(1);
  }

  try {
    const col = mongo.getCollection("leagues");
    const report = await migratePinsCollection(col, { apply });
    console.log(
      apply
        ? "✅ Migración de PINs ejecutada (--apply):"
        : "🔍 Simulación read-only (--dry-run, sin escrituras en MongoDB):"
    );
    console.log(`   Total documentos: ${report.totalDocs}`);
    console.log(`   Ya con scrypt:    ${report.alreadyHashedCount}`);
    console.log(
      `   Candidatos:       ${report.candidatesCount} ${report.candidateIds.length ? `(${report.candidateIds.join(", ")})` : ""}`
    );
    console.log(`   Formato atípico:  ${report.unexpectedCount}`);
    console.log(`   Migrados ahora:   ${report.migratedCount}`);
  } finally {
    await mongo.close();
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error("❌ Error en migrate-pins:", err.message);
    process.exit(1);
  });
}

module.exports = { migratePinsCollection };
