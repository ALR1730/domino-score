const PROBLEM_BY_STATUS = {
  400: {
    type: "https://domino-score.alr.dev/problems/validation-error",
    title: "Solicitud inválida",
  },
  401: {
    type: "https://domino-score.alr.dev/problems/unauthorized",
    title: "No autorizado",
  },
  404: {
    type: "https://domino-score.alr.dev/problems/not-found",
    title: "Recurso no encontrado",
  },
  429: {
    type: "https://domino-score.alr.dev/problems/rate-limit-exceeded",
    title: "Demasiadas solicitudes",
  },
  500: {
    type: "https://domino-score.alr.dev/problems/internal-error",
    title: "Error interno del servidor",
  },
};

function isV1Request(req) {
  return Boolean(
    req &&
      typeof req.originalUrl === "string" &&
      (req.originalUrl === "/api/v1" || req.originalUrl.startsWith("/api/v1/"))
  );
}

function sendApiError(
  req,
  res,
  { status = 500, detail, type, title, extensions = {} }
) {
  if (isV1Request(req)) {
    const mapped = PROBLEM_BY_STATUS[status] || PROBLEM_BY_STATUS[500];
    return res
      .status(status)
      .type("application/problem+json")
      .json({
        type: type || mapped.type,
        title: title || mapped.title,
        status,
        detail,
        instance: req.originalUrl,
        ...extensions,
      });
  }

  return res.status(status).json({
    success: false,
    error: detail,
    ...extensions,
  });
}

module.exports = {
  PROBLEM_BY_STATUS,
  isV1Request,
  sendApiError,
};
