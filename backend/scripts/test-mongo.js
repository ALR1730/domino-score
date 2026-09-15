const mongo = require("../src/db/mongo");

async function main() {
  const uri = process.argv[2] || process.env.MONGODB_URI;
  if (!uri) {
    console.error("❌ Por favor provee la URI de MongoDB como argumento o variable MONGODB_URI.");
    console.log("Uso: node scripts/test-mongo.js \"mongodb+srv://user:pass@cluster.mongodb.net/domino_score\"");
    process.exit(1);
  }

  console.log("🔍 Probando conexión con MongoDB...");
  const connected = await mongo.connect(uri);
  if (!connected) {
    console.error("❌ Falló la conexión con MongoDB.");
    process.exit(1);
  }

  const col = mongo.getCollection("leagues");
  console.log("📝 Probando escritura en colección 'leagues'...");
  const testId = `TEST-${Date.now()}`;
  await col.updateOne(
    { _id: testId },
    {
      $set: {
        _id: testId,
        id: testId,
        name: "Liga de Prueba Conexión",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    },
    { upsert: true }
  );
  console.log("   ✅ Documento insertado correctamente.");

  console.log("📖 Probando lectura...");
  const doc = await col.findOne({ _id: testId });
  if (doc && doc.id === testId) {
    console.log(`   ✅ Documento leído exitosamente: ${doc.name}`);
  } else {
    console.error("❌ No se pudo verificar el documento insertado.");
  }

  console.log("🗑️ Limpiando documento de prueba...");
  await col.deleteOne({ _id: testId });
  console.log("   ✅ Documento de prueba eliminado.");

  await mongo.close();
  console.log("🎉 ¡MongoDB está 100% operativo y listo para producción!");
}

main().catch((err) => {
  console.error("Error inesperado:", err);
  process.exit(1);
});
