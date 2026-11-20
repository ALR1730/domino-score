# Imagen base ligera de Node.js LTS
FROM node:20-alpine

# Directorio de trabajo
WORKDIR /app

# Copiar dependencias
COPY --chown=node:node package*.json ./

# Instalar dependencias para producción
RUN npm ci --omit=dev

# Copiar código fuente
COPY --chown=node:node . .

# Crear directorio de datos para persistencia con permisos para usuario no-root
RUN mkdir -p /app/data && chown -R node:node /app/data

# Exponer puerto del servicio
EXPOSE 3000

# Variable de entorno de puerto por defecto
ENV PORT=3000
ENV NODE_ENV=production

# Ejecutar como usuario sin privilegios
USER node

# Comando de inicio
CMD ["node", "src/server.js"]
