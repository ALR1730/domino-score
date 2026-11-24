const crypto = require("crypto");
const { pinMatches } = require("./pin");

const SALT_BYTES = 16;
const KEY_LEN = 32;
const SCRYPT_OPTIONS = { N: 16384, r: 8, p: 1 };
const PIN_HASH_HEX_REGEX = /^[0-9a-f]{64}$/i;

function deriveKey(pin, salt) {
  return new Promise((resolve, reject) => {
    crypto.scrypt(pin, salt, KEY_LEN, SCRYPT_OPTIONS, (err, derivedKey) => {
      if (err) return reject(err);
      resolve(derivedKey);
    });
  });
}

function hasHashedPin(league) {
  return Boolean(
    league &&
      typeof league.pinHash === "string" &&
      typeof league.pinSalt === "string" &&
      PIN_HASH_HEX_REGEX.test(league.pinHash.trim()) &&
      league.pinSalt.trim().length >= 16
  );
}

function isLegacyPlaintextPin(league) {
  return Boolean(league && typeof league.pin === "string" && league.pin.trim().length > 0);
}

/** Genera { pinHash, pinSalt } con scrypt y salt criptográfico de 16 bytes. */
async function hashPin(pin) {
  if (typeof pin !== "string") {
    throw new Error("El PIN debe ser texto.");
  }
  const clean = pin.trim();
  if (!clean) {
    throw new Error("El PIN no puede estar vacío.");
  }

  const pinSalt = crypto.randomBytes(SALT_BYTES).toString("hex");
  const derived = await deriveKey(clean, pinSalt);
  return {
    pinHash: derived.toString("hex"),
    pinSalt,
  };
}

/**
 * Verificación Dual-Read:
 * - Si existe `pinHash` + `pinSalt`: verifica vía scrypt + timingSafeEqual.
 * - Si solo existe `pin` legado en texto plano: verifica vía SHA-256 + timingSafeEqual
 *   y señala `needsUpgrade: true` cuando coincide.
 */
async function verifyPin(league, candidatePin) {
  if (!league || typeof candidatePin !== "string") {
    return { valid: false, needsUpgrade: false };
  }
  const cleanCandidate = candidatePin.trim();
  if (!cleanCandidate) {
    return { valid: false, needsUpgrade: false };
  }

  if (hasHashedPin(league)) {
    try {
      const expected = Buffer.from(league.pinHash.trim(), "hex");
      const derived = await deriveKey(cleanCandidate, league.pinSalt.trim());
      if (derived.length !== expected.length) {
        return { valid: false, needsUpgrade: false };
      }
      const valid = crypto.timingSafeEqual(derived, expected);
      return { valid, needsUpgrade: false };
    } catch {
      return { valid: false, needsUpgrade: false };
    }
  }

  if (isLegacyPlaintextPin(league)) {
    const valid = pinMatches(league.pin, cleanCandidate);
    return { valid, needsUpgrade: valid };
  }

  return { valid: false, needsUpgrade: false };
}

module.exports = {
  SALT_BYTES,
  KEY_LEN,
  SCRYPT_OPTIONS,
  hashPin,
  verifyPin,
  hasHashedPin,
  isLegacyPlaintextPin,
};
