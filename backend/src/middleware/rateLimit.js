const { sendApiError } = require("../utils/problemDetails");

/**
 * Limitador de intentos en memoria con tope acotado de claves (anti-OOM).
 *
 * Soporta contar todas las solicitudes o únicamente respuestas con un código
 * de estado específico (p. ej. 401 para frenar fuerza bruta de PIN sin
 * bloquear tráfico válido de sincronización).
 */
function rateLimit({
  windowMs = 15 * 60 * 1000,
  max = 10,
  maxKeys = 10000,
  keyGenerator = (req) => req.ip || "unknown",
  countOnlyStatus = null,
  message = "Demasiados intentos. Espera un momento y vuelve a intentarlo.",
} = {}) {
  const attempts = new Map();

  const prune = (list, now) => list.filter((t) => now - t < windowMs);

  const setBounded = (key, list) => {
    if (!attempts.has(key) && attempts.size >= maxKeys) {
      const oldestKey = attempts.keys().next().value;
      if (oldestKey !== undefined) attempts.delete(oldestKey);
    }
    attempts.set(key, list);
  };

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
    const key = keyGenerator(req);
    if (!key) return next();

    const now = Date.now();
    const list = prune(attempts.get(key) || [], now);

    if (list.length >= max) {
      setBounded(key, list);
      const retryAfterSeconds = Math.max(
        1,
        Math.ceil((list[0] + windowMs - now) / 1000)
      );
      res.set("Retry-After", String(retryAfterSeconds));
      return sendApiError(req, res, {
        status: 429,
        detail: message,
        extensions: { retryAfterSeconds },
      });
    }

    if (countOnlyStatus === null) {
      list.push(now);
      setBounded(key, list);
      return next();
    }

    res.on("finish", () => {
      if (res.statusCode !== countOnlyStatus) return;
      const finishedAt = Date.now();
      const current = prune(attempts.get(key) || [], finishedAt);
      current.push(finishedAt);
      setBounded(key, current);
    });

    next();
  };
}

module.exports = rateLimit;
