const express = require("express");
const cors = require("cors");
const leaguesRouter = require("./routes/leagues");
const rankingsRouter = require("./routes/rankings");

const app = express();
const PORT = process.env.PORT || 3000;

// Middlewares
app.use(cors());
app.use(express.json());

// Healthcheck endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    service: "domino-score-backend",
    version: "1.1.0",
    features: ["delete-league", "global-rankings", "match-history"],
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

// Iniciar servidor solo si no es importado en tests
if (require.main === module) {
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Dominó Score Backend escuchando en http://0.0.0.0:${PORT}`);
    console.log(`📋 Healthcheck: http://localhost:${PORT}/health`);
    console.log(`🏆 Ligas API: http://localhost:${PORT}/api/leagues`);
  });
}

module.exports = app;
