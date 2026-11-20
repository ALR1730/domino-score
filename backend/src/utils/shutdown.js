/**
 * Crea un manejador idempotente de apagado limpio (graceful shutdown)
 * para cerrar primero el servidor HTTP y luego la conexión a la BD.
 */
function createShutdownHandler({
  server,
  closeDb,
  exit = (code) => process.exit(code),
  timeoutMs = 10000,
  logger = console,
}) {
  let shuttingDown = false;
  let exited = false;

  const safeExit = (code) => {
    if (exited) return;
    exited = true;
    exit(code);
  };

  return (signal) => {
    if (shuttingDown) return;
    shuttingDown = true;

    logger.log(`🛑 Señal ${signal} recibida. Cerrando servidor limpiamente...`);

    const forceTimer = setTimeout(() => {
      logger.error("⏱️ Timeout de apagado alcanzado. Forzando cierre.");
      safeExit(1);
    }, timeoutMs);
    if (typeof forceTimer.unref === "function") forceTimer.unref();

    server.close(async (closeErr) => {
      try {
        if (closeErr) throw closeErr;
        if (typeof closeDb === "function") await closeDb();
        clearTimeout(forceTimer);
        safeExit(0);
      } catch (err) {
        logger.error("Error durante el apagado:", err);
        clearTimeout(forceTimer);
        safeExit(1);
      }
    });
  };
}

module.exports = { createShutdownHandler };
