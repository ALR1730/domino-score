const { MongoClient } = require("mongodb");

class MongoDB {
  constructor() {
    this.client = null;
    this.db = null;
    this.connected = false;
    this.uri = process.env.MONGODB_URI || null;
  }

  async connect(customUri = null) {
    const uri = customUri || this.uri || process.env.MONGODB_URI;
    if (!uri) {
      console.log("ℹ️ MONGODB_URI no configurada. Operando en modo local (disco/memoria).");
      return false;
    }

    try {
      this.client = new MongoClient(uri, {
        serverSelectionTimeoutMS: 5000,
        connectTimeoutMS: 10000,
      });

      await this.client.connect();
      // Si la URI contiene nombre de base de datos la usa, sino usa 'domino_score'
      this.db = this.client.db();
      this.connected = true;
      console.log(`✅ Conectado exitosamente a MongoDB (Base de datos: ${this.db.databaseName})`);

      await this.ensureIndexes();
      return true;
    } catch (err) {
      console.error("⚠️ Error conectando a MongoDB:", err.message);
      this.connected = false;
      return false;
    }
  }

  async ensureIndexes() {
    if (!this.connected || !this.db) return;
    try {
      const leaguesCol = this.db.collection("leagues");
      await leaguesCol.createIndex({ name: 1 });
      await leaguesCol.createIndex({ updatedAt: -1 });
    } catch (err) {
      console.warn("Aviso al crear índices en MongoDB:", err.message);
    }
  }

  getCollection(name = "leagues") {
    if (!this.connected || !this.db) return null;
    return this.db.collection(name);
  }

  async close() {
    if (this.client) {
      await this.client.close();
      this.connected = false;
      this.db = null;
    }
  }
}

module.exports = new MongoDB();
