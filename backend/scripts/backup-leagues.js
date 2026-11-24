require("dotenv").config();
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const mongo = require("../src/db/mongo");
const { hasHashedPin, isLegacyPlaintextPin } = require("../src/utils/pinCrypto");

function parseOutArg(argv) {
  const idx = argv.indexOf("--out");
  if (idx !== -1 && argv[idx + 1]) {
    return path.resolve(argv[idx + 1]);
  }
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  return path.resolve(
    __dirname,
    "../../../domino-backups",
    `leagues-backup-${stamp}.json`
  );
}

/**
 * Exporta en modo estricto solo-lectura todos los documentos de `leagues`
 * a `outputPath` y devuelve conteos + checksum SHA-256.
 */
async function exportLeaguesBackup(col, outputPath) {
  const docs = await col.find({}).toArray();
  const dir = path.dirname(outputPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  const payload = JSON.stringify(
    {
      exportedAt: new Date().toISOString(),
      count: docs.length,
      leagues: docs,
    },
    null,
    2
  );

  fs.writeFileSync(outputPath, payload, "utf8");
  const sha256 = crypto.createHash("sha256").update(payload, "utf8").digest("hex");

  let hashedPinCount = 0;
  let legacyPinCount = 0;
  let withoutPinCount = 0;
  const leaguesSummary = [];

  for (const doc of docs) {
    const hasHash = hasHashedPin(doc);
    const hasLegacy = isLegacyPlaintextPin(doc);
    if (hasHash) {
      hashedPinCount += 1;
    } else if (hasLegacy) {
      legacyPinCount += 1;
    } else {
      withoutPinCount += 1;
    }
    leaguesSummary.push({
      id: doc.id || String(doc._id),
      name: doc.name || "",
      matchesCount: Array.isArray(doc.matches) ? doc.matches.length : 0,
      participantsCount: Array.isArray(doc.participants)
        ? doc.participants.length
        : 0,
      authMode: hasHash ? "scrypt" : hasLegacy ? "legacy-plaintext" : "missing",
    });
  }

  return {
    outputPath,
    count: docs.length,
    hashedPinCount,
    legacyPinCount,
    withoutPinCount,
    sha256,
    leaguesSummary,
  };
}

async function main() {
  const uri = (process.env.MONGODB_URI || "").trim();
  if (!uri) {
    console.error("❌ Falta MONGODB_URI para ejecutar el backup.");
    process.exit(1);
  }

  const outputPath = parseOutArg(process.argv);
  const connected = await mongo.connect(uri);
  if (!connected) {
    console.error("❌ No se pudo conectar a MongoDB.");
    process.exit(1);
  }

  try {
    const col = mongo.getCollection("leagues");
    const report = await exportLeaguesBackup(col, outputPath);
    console.log("✅ Backup read-only completado:");
    console.log(`   Archivo:   ${report.outputPath}`);
    console.log(`   SHA-256:   ${report.sha256}`);
    console.log(
      `   Ligas:     ${report.count} (scrypt: ${report.hashedPinCount}, legado: ${report.legacyPinCount}, sin PIN: ${report.withoutPinCount})`
    );
    for (const item of report.leaguesSummary) {
      console.log(
        `   - ${item.id} | "${item.name}" | ${item.participantsCount} part. | ${item.matchesCount} partidas | auth=${item.authMode}`
      );
    }
  } finally {
    await mongo.close();
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error("❌ Error ejecutando backup:", err.message);
    process.exit(1);
  });
}

module.exports = { exportLeaguesBackup };
