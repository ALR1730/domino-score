/**
 * Limitador de intentos simple en memoria (sin dependencias externas).
 *
 * Su objetivo es frenar fuerza bruta contra los endpoints que validan PIN
 * (unirse / eliminar / sincronizar ligas). Cada instancia del servidor cuenta
 * sus propios intentos; para el despliegue actual (una sola instancia en
 * Render) eso es suficiente.
 */
function rateLimit({
  windowMs = 15 * 60 * 1000,
  max = 10,
  message = "Demasiados intentos. Espera un momento y vuelve a intentarlo.",
} = {}) {
  // ip -> lista de timestamps de intentos dentro de la ventana
  const attempts = new Map();

  const prune = (list, now) => list.filter((t) => now - t < windowMs);

  // Limpieza periódica para no acumular claves muertas en memoria
  const timer = setInterval(
    () => {
      const now = Date.now();
      for (const [key, list] of attempts) {
        if (prune(list, now).length === 0) attempts.delete(key);
      }
    },
    Math.max(windowMs, 60 * 1000)
  );
  if (typeof timer.unref === "function") timer.unref();

  return (req, res, next) => {
    const now = Date.now();
    const key = req.ip || "unknown";
    const list = prune(attempts.get(key) || [], now);

    if (list.length >= max) {
      attempts.set(key, list);
      const retryAfterSeconds = Math.ceil((list[0] + windowMs - now) / 1000);
      res.set("Retry-After", String(retryAfterSeconds));
      return res.status(429).json({ success: false, error: message, retryAfterSeconds });
    }

    list.push(now);
    attempts.set(key, list);
    next();
  };
}

module.exports = rateLimit;
