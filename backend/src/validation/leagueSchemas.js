const { extractMembers } = require("../utils/nameParser");

const MAX_LEAGUE_ID_LEN = 40;
const MAX_LEAGUE_NAME_LEN = 80;
const MAX_PARTICIPANT_LEN = 60;
const MAX_PIN_LEN = 32;
const MAX_DISPLAY_NAME_LEN = 120;
const MAX_MATCH_ID_LEN = 100;
const MAX_DATE_LEN = 64;
const MAX_PARTICIPANTS = 200;
const MAX_TEAM_MEMBERS = 10;
const MAX_SCORE = 10000;
const MAX_SYNC_MATCHES = 2000;
const MIN_YEAR = 1970;
const MAX_YEAR = 2100;
const MIN_MONTH = 1;
const MAX_MONTH = 12;
const LEAGUE_ID_REGEX = /^[A-Za-z0-9_-]+$/;

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function cleanString(
  value,
  { min = 1, max = 120, required = false, label = "Campo" } = {}
) {
  if (value === undefined || value === null) {
    return required
      ? { ok: false, error: `${label} es obligatorio.`, status: 400 }
      : { ok: true, value: undefined };
  }
  if (typeof value !== "string") {
    return { ok: false, error: `${label} debe ser texto.`, status: 400 };
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return required
      ? { ok: false, error: `${label} es obligatorio.`, status: 400 }
      : { ok: true, value: undefined };
  }
  if (trimmed.length < min || trimmed.length > max) {
    return {
      ok: false,
      error: `${label} debe tener entre ${min} y ${max} caracteres.`,
      status: 400,
    };
  }
  return { ok: true, value: trimmed };
}

function validateLeagueId(rawId) {
  const checked = cleanString(rawId, {
    min: 1,
    max: MAX_LEAGUE_ID_LEN,
    required: true,
    label: "El ID de la liga",
  });
  if (!checked.ok) {
    return { ok: false, error: checked.error, status: 400 };
  }
  if (!LEAGUE_ID_REGEX.test(checked.value)) {
    return { ok: false, error: "El ID de la liga contiene caracteres inválidos.", status: 400 };
  }
  return { ok: true, data: checked.value };
}

function validatePin(rawPin, { required = true } = {}) {
  if (rawPin === undefined || rawPin === null) {
    return required
      ? { ok: false, error: "El PIN es requerido.", status: 400 }
      : { ok: true, data: null };
  }
  if (typeof rawPin !== "string") {
    return { ok: false, error: "El PIN debe ser una cadena de texto.", status: 400 };
  }
  const trimmed = rawPin.trim();
  if (!trimmed) {
    return required
      ? { ok: false, error: "El PIN es requerido.", status: 400 }
      : { ok: true, data: null };
  }
  if (trimmed.length > MAX_PIN_LEN) {
    return {
      ok: false,
      error: `El PIN no puede superar ${MAX_PIN_LEN} caracteres.`,
      status: 400,
    };
  }
  return { ok: true, data: trimmed };
}

function validateParticipantList(rawList, label = "Participantes") {
  if (rawList === undefined || rawList === null) {
    return { ok: true, data: [] };
  }
  if (!Array.isArray(rawList)) {
    return { ok: false, error: `${label} debe ser una lista.`, status: 400 };
  }
  if (rawList.length > MAX_PARTICIPANTS) {
    return {
      ok: false,
      error: `${label} no puede superar ${MAX_PARTICIPANTS} elementos.`,
      status: 400,
    };
  }

  const cleaned = [];
  for (const item of rawList) {
    if (typeof item !== "string") {
      return { ok: false, error: `Cada elemento de ${label} debe ser texto.`, status: 400 };
    }
    const trimmed = item.trim();
    if (!trimmed) continue;
    if (trimmed.length > MAX_PARTICIPANT_LEN) {
      return {
        ok: false,
        error: `Cada nombre en ${label} debe tener máximo ${MAX_PARTICIPANT_LEN} caracteres.`,
        status: 400,
      };
    }
    cleaned.push(trimmed);
  }
  return { ok: true, data: cleaned };
}

function toScore(value, fallback = 0) {
  if (value === undefined || value === null || value === "") return fallback;
  if (typeof value !== "number" && typeof value !== "string") return null;
  if (typeof value === "string" && value.trim() === "") return fallback;

  const n = Number(value);
  if (!Number.isInteger(n) || n < 0 || n > MAX_SCORE) return null;
  return n;
}

function toMemberList(value, fallbackDisplayName, allowLegacyFallback) {
  if (value !== undefined && value !== null) {
    if (!Array.isArray(value)) return null;
    if (value.length === 0 || value.length > MAX_TEAM_MEMBERS) return null;

    const members = [];
    for (const item of value) {
      if (typeof item !== "string") return null;
      const trimmed = item.trim();
      if (!trimmed) continue;
      if (trimmed.length > MAX_PARTICIPANT_LEN) return null;
      members.push(trimmed);
    }
    return members.length > 0 && members.length <= MAX_TEAM_MEMBERS ? members : null;
  }

  if (allowLegacyFallback && typeof fallbackDisplayName === "string" && fallbackDisplayName.trim()) {
    const derived = extractMembers(fallbackDisplayName);
    if (derived.length === 0 || derived.length > MAX_TEAM_MEMBERS) return null;
    if (derived.some((m) => m.length > MAX_PARTICIPANT_LEN)) return null;
    return derived;
  }

  return null;
}

function validateDateString(rawDate) {
  if (rawDate === undefined || rawDate === null || rawDate === "") {
    return { ok: true, data: undefined };
  }
  if (typeof rawDate !== "string") {
    return { ok: false, error: "La fecha debe ser una cadena ISO válida.", status: 400 };
  }
  const trimmed = rawDate.trim();
  if (!trimmed || trimmed.length > MAX_DATE_LEN) {
    return { ok: false, error: "La fecha tiene un formato inválido.", status: 400 };
  }
  const parsed = new Date(trimmed);
  if (Number.isNaN(parsed.getTime())) {
    return { ok: false, error: "La fecha no es válida.", status: 400 };
  }
  return { ok: true, data: trimmed };
}

function validateCreateLeague(body) {
  if (!isPlainObject(body)) {
    return { ok: false, error: "El cuerpo de la petición debe ser un objeto JSON.", status: 400 };
  }

  const nameCheck = cleanString(body.name, {
    min: 1,
    max: MAX_LEAGUE_NAME_LEN,
    required: true,
    label: "El nombre de la liga",
  });
  if (!nameCheck.ok) return nameCheck;

  let id = undefined;
  if (body.id !== undefined && body.id !== null) {
    if (typeof body.id !== "string") {
      return { ok: false, error: "El ID de la liga debe ser texto.", status: 400 };
    }
    if (body.id.trim()) {
      const idCheck = validateLeagueId(body.id);
      if (!idCheck.ok) return idCheck;
      id = idCheck.data;
    }
  }

  const pinCheck = validatePin(body.pin, { required: false });
  if (!pinCheck.ok) return pinCheck;

  const participantsCheck = validateParticipantList(
    body.initialParticipants,
    "initialParticipants"
  );
  if (!participantsCheck.ok) return participantsCheck;

  return {
    ok: true,
    data: {
      id,
      name: nameCheck.value,
      pin: pinCheck.data,
      initialParticipants: participantsCheck.data,
    },
  };
}

function validateJoin(body) {
  if (!isPlainObject(body)) {
    return { ok: false, error: "El cuerpo de la petición debe ser un objeto JSON.", status: 400 };
  }

  const targetCheck = cleanString(body.nameOrId, {
    min: 1,
    max: MAX_LEAGUE_NAME_LEN,
    required: true,
    label: "Nombre/código de liga",
  });
  if (!targetCheck.ok) return targetCheck;

  const pinCheck = validatePin(body.pin, { required: true });
  if (!pinCheck.ok) {
    return { ok: false, error: "Nombre/código de liga y PIN son requeridos.", status: 400 };
  }

  return {
    ok: true,
    data: {
      nameOrId: targetCheck.value,
      pin: pinCheck.data,
    },
  };
}

function validateParticipant(body) {
  if (!isPlainObject(body)) {
    return { ok: false, error: "El cuerpo de la petición debe ser un objeto JSON.", status: 400 };
  }

  const nameCheck = cleanString(body.name, {
    min: 1,
    max: MAX_PARTICIPANT_LEN,
    required: true,
    label: "Nombre de participante",
  });
  if (!nameCheck.ok) return nameCheck;

  const pinCheck = validatePin(body.pin, { required: false });
  if (!pinCheck.ok) return pinCheck;

  return {
    ok: true,
    data: {
      name: nameCheck.value,
      pin: pinCheck.data,
    },
  };
}

function validateMatchPayload(body, { allowLegacyFallback = false } = {}) {
  if (!isPlainObject(body)) {
    return { ok: false, error: "La partida debe ser un objeto JSON válido.", status: 400 };
  }

  const idCheck = cleanString(body.id, {
    min: 1,
    max: MAX_MATCH_ID_LEN,
    required: false,
    label: "ID de partida",
  });
  if (!idCheck.ok) return idCheck;

  const dateCheck = validateDateString(body.date);
  if (!dateCheck.ok) return dateCheck;

  const t1NameCheck = cleanString(body.team1DisplayName, {
    min: 1,
    max: MAX_DISPLAY_NAME_LEN,
    required: false,
    label: "team1DisplayName",
  });
  if (!t1NameCheck.ok) return t1NameCheck;

  const t2NameCheck = cleanString(body.team2DisplayName, {
    min: 1,
    max: MAX_DISPLAY_NAME_LEN,
    required: false,
    label: "team2DisplayName",
  });
  if (!t2NameCheck.ok) return t2NameCheck;

  const members1 = toMemberList(
    body.team1Members,
    t1NameCheck.value,
    allowLegacyFallback
  );
  const members2 = toMemberList(
    body.team2Members,
    t2NameCheck.value,
    allowLegacyFallback
  );
  if (!members1 || !members2) {
    return {
      ok: false,
      error: "Se requieren los miembros válidos de ambos equipos (1 a 10 jugadores).",
      status: 400,
    };
  }

  const score1 = toScore(body.score1);
  const score2 = toScore(body.score2);
  if (score1 === null || score2 === null) {
    return {
      ok: false,
      error: `Los puntajes deben ser enteros entre 0 y ${MAX_SCORE}.`,
      status: 400,
    };
  }

  const rawWinner = body.winnerTeam;
  if (typeof rawWinner !== "number" && typeof rawWinner !== "string") {
    return { ok: false, error: "winnerTeam debe ser 1 o 2.", status: 400 };
  }
  const winnerTeam = Number(rawWinner);
  if (winnerTeam !== 1 && winnerTeam !== 2) {
    return { ok: false, error: "winnerTeam debe ser 1 o 2.", status: 400 };
  }

  const leagueNameCheck = cleanString(body.leagueName, {
    min: 1,
    max: MAX_LEAGUE_NAME_LEN,
    required: false,
    label: "leagueName",
  });
  if (!leagueNameCheck.ok) return leagueNameCheck;

  return {
    ok: true,
    data: {
      id: idCheck.value,
      date: dateCheck.data,
      team1DisplayName: t1NameCheck.value,
      team2DisplayName: t2NameCheck.value,
      team1Members: members1,
      team2Members: members2,
      score1,
      score2,
      winnerTeam,
      leagueName: leagueNameCheck.value,
    },
  };
}

function validateSyncPayload(body) {
  if (!isPlainObject(body)) {
    return { ok: false, error: "Datos de liga requeridos (incluyendo id).", status: 400 };
  }

  const idCheck = validateLeagueId(body.id);
  if (!idCheck.ok) {
    return { ok: false, error: "Datos de liga requeridos (incluyendo id válido).", status: 400 };
  }

  const nameCheck = cleanString(body.name, {
    min: 1,
    max: MAX_LEAGUE_NAME_LEN,
    required: false,
    label: "El nombre de la liga",
  });
  if (!nameCheck.ok) return nameCheck;

  const pinCheck = validatePin(body.pin, { required: false });
  if (!pinCheck.ok) return pinCheck;

  const participantsCheck = validateParticipantList(body.participants, "participants");
  if (!participantsCheck.ok) return participantsCheck;

  let matches = [];
  if (body.matches !== undefined && body.matches !== null) {
    if (!Array.isArray(body.matches)) {
      return { ok: false, error: "matches debe ser una lista.", status: 400 };
    }
    if (body.matches.length > MAX_SYNC_MATCHES) {
      return {
        ok: false,
        error: `No se pueden sincronizar más de ${MAX_SYNC_MATCHES} partidas por solicitud.`,
        status: 400,
      };
    }

    matches = [];
    for (const rawMatch of body.matches) {
      const checked = validateMatchPayload(rawMatch, { allowLegacyFallback: true });
      if (!checked.ok) return checked;
      matches.push(checked.data);
    }
  }

  return {
    ok: true,
    data: {
      id: idCheck.data,
      name: nameCheck.value,
      pin: pinCheck.data,
      participants: body.participants !== undefined ? participantsCheck.data : undefined,
      matches,
    },
  };
}

function validateMonthQuery(query) {
  const q = isPlainObject(query) ? query : {};
  const hasYear = q.year !== undefined && q.year !== "";
  const hasMonth = q.month !== undefined && q.month !== "";

  if (!hasYear && !hasMonth) {
    return { ok: true, data: { year: null, month: null } };
  }

  if (hasYear !== hasMonth) {
    return {
      ok: false,
      error: "Debes proporcionar ambos parámetros: year y month.",
      status: 400,
    };
  }

  if (typeof q.year !== "string" || typeof q.month !== "string") {
    return { ok: false, error: "year y month deben ser parámetros simples.", status: 400 };
  }

  const yearStr = q.year.trim();
  const monthStr = q.month.trim();
  if (!/^\d{4}$/.test(yearStr) || !/^\d{1,2}$/.test(monthStr)) {
    return { ok: false, error: "year y month deben ser enteros válidos.", status: 400 };
  }

  const year = Number(yearStr);
  const month = Number(monthStr);
  if (year < MIN_YEAR || year > MAX_YEAR || month < MIN_MONTH || month > MAX_MONTH) {
    return {
      ok: false,
      error: `year debe estar entre ${MIN_YEAR}-${MAX_YEAR} y month entre ${MIN_MONTH}-${MAX_MONTH}.`,
      status: 400,
    };
  }

  return { ok: true, data: { year, month } };
}

module.exports = {
  MAX_LEAGUE_ID_LEN,
  MAX_LEAGUE_NAME_LEN,
  MAX_PARTICIPANT_LEN,
  MAX_PIN_LEN,
  MAX_DISPLAY_NAME_LEN,
  MAX_MATCH_ID_LEN,
  MAX_PARTICIPANTS,
  MAX_TEAM_MEMBERS,
  MAX_SCORE,
  MAX_SYNC_MATCHES,
  cleanString,
  validateLeagueId,
  validatePin,
  validateCreateLeague,
  validateJoin,
  validateParticipant,
  validateMatchPayload,
  validateSyncPayload,
  validateMonthQuery,
};
