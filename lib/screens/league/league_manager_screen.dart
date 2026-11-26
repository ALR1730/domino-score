import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../services/api_client.dart';
import '../../services/league_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/league/local_leagues_tab.dart';
import '../../widgets/league/server_leagues_tab.dart';
import '../../widgets/league_dialogs.dart';

class LeagueManagerScreen extends StatefulWidget {
  const LeagueManagerScreen({super.key});

  @override
  State<LeagueManagerScreen> createState() => _LeagueManagerScreenState();
}

class _LeagueManagerScreenState extends State<LeagueManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LeagueService _leagueService = LeagueService();
  final ApiClient _apiClient = ApiClient();

  List<Map<String, dynamic>> _serverLeagues = [];
  bool _isLoadingServer = false;
  String? _serverError;
  String _serverSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    unawaited(_loadServerLeagues());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadServerLeagues() async {
    setState(() {
      _isLoadingServer = true;
      _serverError = null;
    });

    final list = await _apiClient.fetchServerLeagues();
    if (!mounted) return;

    if (list == null) {
      setState(() {
        _serverError = 'No se pudieron cargar las ligas del servidor.';
        _isLoadingServer = false;
      });
      return;
    }

    setState(() {
      _serverLeagues = list;
      _isLoadingServer = false;
    });
  }

  void _showJoinDialogForServerLeague(String leagueId, String leagueName) {
    showJoinLeagueDialog(
      context,
      leagueId: leagueId,
      leagueName: leagueName,
      onJoin: (nameOrId, pin) =>
          _leagueService.joinLeague(nameOrId: nameOrId, pin: pin),
      onJoined: () {
        unawaited(_loadServerLeagues());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Te has unido a "$leagueName"!'),
              backgroundColor: AppColors.emerald600,
            ),
          );
        }
      },
    );
  }

  void _showDeleteLocalLeagueDialog(League league) {
    showDeleteLeagueDialog(
      context,
      leagueId: league.id,
      leagueName: league.name,
      description:
          '¿Deseas eliminar "${league.name}" (# ${league.id}) de este dispositivo?',
      deleteOnServerDefault: false,
      prefillPin: league.pin,
      onDelete: (id, {String? pin, bool deleteOnServer = false}) =>
          _leagueService.deleteLeague(id,
              pin: pin, deleteOnServer: deleteOnServer),
      onDeleted: () {
        unawaited(_loadServerLeagues());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Liga "${league.name}" eliminada.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
    );
  }

  void _showDeleteServerLeagueDialog(String leagueId, String leagueName) {
    showDeleteServerLeagueDialog(
      context,
      leagueId: leagueId,
      leagueName: leagueName,
      onDeleteOnServer: (id, pin) async {
        final res = await _apiClient.deleteLeague(id, pin: pin);
        if (res['success'] != true) {
          return res['error'] ?? 'PIN incorrecto o error al eliminar';
        }
        // Quitar también la copia local (si existe) sin repetir la llamada al server
        await _leagueService.deleteLeague(id, deleteOnServer: false);
        return null;
      },
      onDeleted: () {
        unawaited(_loadServerLeagues());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Liga "$leagueName" eliminada del servidor.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
    );
  }

  void _showCreateLeagueDialog() {
    showCreateLeagueDialog(
      context,
      onCreate: (
              {required String name,
              required String pin,
              required List<String> participants}) =>
          _leagueService.createLeague(
              name: name, pin: pin, initialParticipants: participants),
      onCreated: () => unawaited(_loadServerLeagues()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _leagueService,
      builder: (context, _) {
        final localLeagues = _leagueService.allLeagues;
        final activeId = _leagueService.activeLeagueId;
        final localIds = localLeagues.map((l) => l.id.toLowerCase()).toSet();

        return Scaffold(
          backgroundColor: AppColors.slate950,
          appBar: AppBar(
            backgroundColor: AppColors.slate900,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  size: 18, color: AppColors.slate300),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Gestor de Ligas',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh,
                    color: AppColors.slate300, size: 20),
                tooltip: 'Actualizar ligas del servidor',
                onPressed: _loadServerLeagues,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.slate950,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate800),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.emerald600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.slate400,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.phone_android, size: 15),
                          const SizedBox(width: 6),
                          Text('En este Dispositivo (${localLeagues.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_outlined, size: 15),
                          const SizedBox(width: 6),
                          Text('En el Servidor (${_serverLeagues.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              LocalLeaguesTab(
                localLeagues: localLeagues,
                activeId: activeId,
                onCreateLeague: _showCreateLeagueDialog,
                onActivateLeague: (league) {
                  unawaited(_leagueService.setActiveLeague(league.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Liga activa cambiada a "${league.name}"'),
                      backgroundColor: AppColors.emerald600,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                onDeleteLeague: _showDeleteLocalLeagueDialog,
              ),
              ServerLeaguesTab(
                isLoading: _isLoadingServer,
                error: _serverError,
                serverLeagues: _serverLeagues,
                searchQuery: _serverSearchQuery,
                localIds: localIds,
                activeId: activeId,
                onSearchChanged: (val) =>
                    setState(() => _serverSearchQuery = val),
                onRefresh: _loadServerLeagues,
                onActivateLocal: (id, name) {
                  unawaited(_leagueService.setActiveLeague(id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Liga cambiada a "$name"'),
                      backgroundColor: AppColors.emerald600,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                onJoinServerLeague: _showJoinDialogForServerLeague,
                onDeleteServerLeague: _showDeleteServerLeagueDialog,
              ),
            ],
          ),
        );
      },
    );
  }
}
