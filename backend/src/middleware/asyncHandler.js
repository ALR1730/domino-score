/**
 * Envuelve un handler async para que sus rechazos caigan en el manejador
 * global de errores de Express (Express 4 no los captura solo).
 */
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

module.exports = asyncHandler;
