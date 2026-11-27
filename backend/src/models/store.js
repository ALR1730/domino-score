const leagueRepository = require("../repositories/leagueRepository");
const leagueService = require("../services/leagueService");

/**
 * Fachada retrocompatible sobre `leagueRepository` + `leagueService` para tests
 * y scripts existentes mientras las rutas consumen `leagueService` directamente.
 */
const store = {
  get leagues() {
    return leagueRepository.localLeagues;
  },

  saveLocal() {
    return leagueRepository.saveLocal();
  },

  async _upsertInMongo(col, league) {
    return await leagueRepository._upsertInMongo(col, league);
  },

  async loadFromMongo() {
    return await leagueService.initializeStorage();
  },

  getLeagueById(id) {
    if (typeof id !== "string") return null;
    return leagueRepository.localLeagues.get(id) || null;
  },

  createLeague(args) {
    return leagueService.createLeague(args);
  },

  syncLeague(leagueData) {
    return leagueService.syncLeague(leagueData);
  },

  verifyLeaguePin(leagueOrId, candidatePin, opts) {
    return leagueService.verifyLeaguePin(leagueOrId, candidatePin, opts);
  },

  upgradeLegacyPin(leagueId, plainPin) {
    return leagueService.upgradeLegacyPin(leagueId, plainPin);
  },

  deleteLeague(id, pin) {
    return leagueService.deleteLeague(id, pin);
  },

  addParticipant(leagueId, participantName, opts) {
    return leagueService.addParticipant(leagueId, participantName, opts);
  },

  removeParticipant(leagueId, participantName, opts) {
    return leagueService.removeParticipant(leagueId, participantName, opts);
  },

  recordMatch(leagueId, matchData, opts) {
    return leagueService.recordMatch(leagueId, matchData, opts);
  },
};

module.exports = store;
