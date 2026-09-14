# Imagen base ligera de Node.js LTS
FROM node:20-alpine

# Directorio de trabajo
WORKDIR /app

# Copiar dependencias
COPY package*.json ./

# Instalar dependencias para producción
RUN npm ci --only=production

# Copiar código fuente
COPY . .

# Crear directorio de datos para persistencia
RUN mkdir -p /app/data

# Exponer puerto del servicio
EXPOSE 3000

# Variable de entorno de puerto por defecto
ENV PORT=3000
ENV NODE_ENV=production

# Comando de inicio
CMD ["node", "src/server.js"]
