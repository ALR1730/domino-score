const crypto = require("crypto");

const FORBIDDEN_DEFAULT_PIN = "1234";

/** Genera un PIN aleatorio criptográfico de 4 dígitos evitando el obvio "1234". */
function generateRandomPin() {
  let pin = FORBIDDEN_DEFAULT_PIN;
  while (pin === FORBIDDEN_DEFAULT_PIN) {
    pin = String(crypto.randomInt(1000, 10000));
  }
  return pin;
}

/**
 * Compara dos PINs en tiempo constante usando SHA-256 + timingSafeEqual.
 * Exige que ambos valores sean strings no vacíos tras trim().
 */
function pinMatches(storedPin, candidatePin) {
  if (typeof storedPin !== "string" || typeof candidatePin !== "string") {
    return false;
  }
  const cleanStored = storedPin.trim();
  const cleanCandidate = candidatePin.trim();
  if (!cleanStored || !cleanCandidate) return false;

  const hashA = crypto.createHash("sha256").update(cleanStored, "utf8").digest();
  const hashB = crypto.createHash("sha256").update(cleanCandidate, "utf8").digest();
  return crypto.timingSafeEqual(hashA, hashB);
}

module.exports = {
  generateRandomPin,
  pinMatches,
};
