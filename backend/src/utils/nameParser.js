/**
 * Utilidades para normalización y parseo de nombres de parejas y jugadores de dominó
 */

function removeDiacritics(str) {
  return str.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

function capitalize(s) {
  if (!s) return "";
  return s
    .split(" ")
    .map((word) =>
      word ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ""
    )
    .join(" ");
}

/**
 * Extrae los miembros individuales de un equipo/pareja:
 * "Carlos y Juan" -> ["Carlos", "Juan"]
 * "Pedro / Luis" -> ["Pedro", "Luis"]
 */
function extractMembers(rawName) {
  const clean = (rawName || "").trim();
  if (!clean) return [];

  // Separadores comunes: ' y ', ' e ', ' & ', ' / ', ' - ', ',', ' + ', ' and '
  const regex = /\s+(?:y|e|and|&|\+|\/|-)\s+|[,/+\-&]/i;
  const parts = clean
    .split(regex)
    .map((p) => p.trim())
    .filter(Boolean);

  if (parts.length === 0) {
    return [capitalize(clean)];
  }

  return parts.map((p) => capitalize(p));
}

/**
 * Genera una clave única e independiente del orden de los integrantes.
 * "Carlos y Juan" y "Juan & Carlos" producen ambas: "carlos_juan"
 */
function generateTeamKey(members) {
  if (!members || members.length === 0) return "";
  const normalized = members
    .map((m) => removeDiacritics(m.trim().toLowerCase()))
    .sort();
  return normalized.join("_");
}

function formatTeamDisplayName(members) {
  if (!members || members.length === 0) return "Equipo";
  if (members.length === 1) return members[0];
  if (members.length === 2) return `${members[0]} & ${members[1]}`;
  return members.join(", ");
}

module.exports = {
  removeDiacritics,
  capitalize,
  extractMembers,
  generateTeamKey,
  formatTeamDisplayName,
};
