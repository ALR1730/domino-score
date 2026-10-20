require("dotenv").config();
const express = require("express");
const cors = require("cors");
const mongo = require("./db/mongo");
const store = require("./models/store");
const leaguesRouter = require("./routes/leagues");
const rankingsRouter = require("./routes/rankings");

const app = express();
const PORT = process.env.PORT || 3000;

// El servicio vive detrás del proxy de Render: confiar en el primer hop
// para que req.ip (usado por el rate limiter) sea la IP real del cliente.
app.set("trust proxy", 1);

// --- CORS: lista blanca de orígenes ---
// Las peticiones sin cabecera Origin (APK Flutter, curl, Postman) no están
// sujetas a CORS y siguen funcionando igual. Los navegadores solo pueden
// leer respuestas desde los orígenes listados.
const allowedOrigins = (process.env.CORS_ORIGINS || "https://alr1730.github.io")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const isOriginAllowed = (origin) => {
  if (!origin) return true; // clientes no-navegador
  if (allowedOrigins.includes(origin)) return true;
  // Desarrollo local: flutter run -d web-server / npm run dev
  return /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
};

// Nota: `origin` DEBE recibir el callback (estilo (origin, cb)); con retorno
// síncrono el middleware de cors no continuaría y la petición se colgaría.
app.use(
  cors({
    origin: (origin, cb) => {
      cb(null, isOriginAllowed(origin) ? origin || false : false);
    },
  })
);

// --- Cabeceras de seguridad básicas (sin dependencia de helmet) ---
app.disable("x-powered-by");
app.use((req, res, next) => {
  res.set({
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "no-referrer",
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  });
  next();
});

app.use(express.json({ limit: "1mb" }));

// Healthcheck endpoint (información mínima para ops)
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    service: "domino-score-backend",
    version: "1.3.0",
    database: mongo.connected ? "mongodb" : "local_storage",
    timestamp: new Date().toISOString(),
  });
});

// Rutas de API
app.use("/api/leagues", leaguesRouter);
app.use("/api/rankings", rankingsRouter);

// Manejador de 404
app.use((req, res) => {
  res.status(404).json({ success: false, error: "Endpoint no encontrado" });
});

// Manejador global de errores: ningún 500 devuelve HTML con stack trace
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error("Error no controlado:", err);
  res.status(500).json({ success: false, error: "Error interno del servidor." });
});

// Inicialización de base de datos y servidor
async function startServer() {
  if (process.env.MONGODB_URI) {
    console.log("🔄 Conectando a MongoDB...");
    const connected = await mongo.connect();
    if (connected) {
      await store.loadFromMongo();
    }
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Dominó Score Backend escuchando en http://0.0.0.0:${PORT}`);
    console.log(`📋 Healthcheck: http://localhost:${PORT}/health`);
    console.log(`🏆 Ligas API: http://localhost:${PORT}/api/leagues`);
  });
}

// Iniciar servidor solo si no es importado en tests
if (require.main === module) {
  startServer().catch((err) => {
    console.error("Error al iniciar el servidor:", err);
  });
}

module.exports = app;
