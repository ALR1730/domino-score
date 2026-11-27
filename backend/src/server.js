require("dotenv").config();
const express = require("express");
const cors = require("cors");
const mongo = require("./db/mongo");
const leagueService = require("./services/leagueService");
const leaguesRouter = require("./routes/leagues");
const rankingsRouter = require("./routes/rankings");
const { createShutdownHandler } = require("./utils/shutdown");
const { sendApiError } = require("./utils/problemDetails");

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
    version: "1.4.0",
    database: mongo.connected ? "mongodb" : "local_storage",
    timestamp: new Date().toISOString(),
  });
});

// Rutas de API: alias retrocompatible (/api/*) + versión estándar RFC 7807 (/api/v1/*)
app.use("/api/leagues", leaguesRouter);
app.use("/api/rankings", rankingsRouter);
app.use("/api/v1/leagues", leaguesRouter);
app.use("/api/v1/rankings", rankingsRouter);

// Manejador de 404
app.use((req, res) => {
  return sendApiError(req, res, {
    status: 404,
    detail: "Endpoint no encontrado",
  });
});

// Manejador global de errores: ningún 500 devuelve HTML con stack trace
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error("Error no controlado:", err);
  return sendApiError(req, res, {
    status: 500,
    detail: "Error interno del servidor.",
  });
});

// Inicialización de base de datos y servidor
async function startServer() {
  if (process.env.MONGODB_URI) {
    console.log("🔄 Conectando a MongoDB...");
    const connected = await mongo.connect();
    if (connected) {
      await leagueService.initializeStorage();
    } else if (process.env.ALLOW_LOCAL_FALLBACK === "true") {
      // Única forma de arrancar sin BD con MONGODB_URI configurado.
      console.warn(
        "⚠️  MongoDB no disponible y ALLOW_LOCAL_FALLBACK=true: arrancando en modo local. " +
          "Los datos se guardarán en un archivo EFÍMERO (se pierde en cada redeploy)."
      );
    } else {
      // Mejor no arrancar que arrancar escribiendo en el disco efímero de
      // Render: cada partido registrado se perdería silenciosamente.
      console.error(
        "❌ MONGODB_URI está configurado pero la conexión a MongoDB falló.\n" +
          "   Abortando el arranque para no perder datos en almacenamiento efímero.\n" +
          "   Revisa las credenciales de Atlas o define ALLOW_LOCAL_FALLBACK=true para forzar modo local."
      );
      process.exit(1);
    }
  }

  const server = app.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Dominó Score Backend escuchando en http://0.0.0.0:${PORT}`);
    console.log(`📋 Healthcheck: http://localhost:${PORT}/health`);
    console.log(`🏆 Ligas API: http://localhost:${PORT}/api/leagues`);
    console.log(`🏆 Ligas API v1: http://localhost:${PORT}/api/v1/leagues`);
  });

  const shutdown = createShutdownHandler({
    server,
    closeDb: () => mongo.close(),
  });
  process.once("SIGTERM", () => shutdown("SIGTERM"));
  process.once("SIGINT", () => shutdown("SIGINT"));

  return server;
}

// Iniciar servidor solo si no es importado en tests
if (require.main === module) {
  startServer().catch((err) => {
    console.error("Error al iniciar el servidor:", err);
    process.exit(1);
  });
}

module.exports = app;
