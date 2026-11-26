import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../services/league_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/league/league_empty_state.dart';
import '../../widgets/league/league_info_banner.dart';
import '../../widgets/league/league_matches_history_tab.dart';
import '../../widgets/league/league_participants_tab.dart';
import '../../widgets/league/league_rankings_tab.dart';
import '../../widgets/league_dialogs.dart';
import 'global_ranking_screen.dart';
import 'league_manager_screen.dart';
import 'match_setup_screen.dart';

class LeagueHomeScreen extends StatefulWidget {
  final LeagueService? leagueService;

  const LeagueHomeScreen({super.key, this.leagueService});

  @override
  State<LeagueHomeScreen> createState() => _LeagueHomeScreenState();
}

class _LeagueHomeScreenState extends State<LeagueHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _autoSyncInterval = Duration(seconds: 45);

  late final LeagueService _service = widget.leagueService ?? LeagueService();
  late TabController _tabController;
  bool _isSyncing = false;
  Timer? _autoSyncTimer;
  bool _isServerOnline = true;
  bool _isAppResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkServerStatus());
    });
    // Auto-sincronización y monitoreo periódico de conexión
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) {
      if (mounted && _isAppResumed && !_isSyncing) {
        if (!_isServerOnline) {
          unawaited(_checkServerStatus());
        } else {
          unawaited(_service.syncActiveLeagueWithServer());
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
    if (_isAppResumed && mounted && !_isSyncing) {
      unawaited(_checkServerStatus());
    }
  }

  Future<void> _checkServerStatus() async {
    try {
      final available = await _service.isServerAvailable();
      if (mounted) setState(() => _isServerOnline = available);
      if (available && _service.allLeagues.isNotEmpty) {
        await _service.syncAllLeaguesWithServer();
      }
    } catch (_) {
      if (mounted) setState(() => _isServerOnline = false);
    }
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sincronizando rankings con el servidor...'),
        duration: Duration(milliseconds: 900),
      ),
    );
    final ok = await _service.syncActiveLeagueWithServer();
    if (mounted) {
      setState(() {
        _isSyncing = false;
        _isServerOnline = ok;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? '✅ Conectado y sincronizado con el servidor correctamente.'
              : '⚠️ No se pudo conectar al servidor.'),
          backgroundColor: ok ? AppColors.emerald600 : AppColors.amber600,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSyncTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _openLeagueManager() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeagueManagerScreen(leagueService: _service),
      ),
    );
  }

  void _showCreateLeagueDialog() {
    showCreateLeagueDialog(
      context,
      onCreate: (
              {required String name,
              required String pin,
              required List<String> participants}) =>
          _service.createLeague(
              name: name, pin: pin, initialParticipants: participants),
    );
  }

  void _showJoinLeagueDialog() {
    showJoinLeagueDialog(
      context,
      onJoin: (nameOrId, pin) =>
          _service.joinLeague(nameOrId: nameOrId, pin: pin),
    );
  }

  void _showAddParticipantDialog() {
    showAddParticipantDialog(
      context,
      onAdd: (name) => _service.addParticipantToActiveLeague(name),
    );
  }

  void _showDeleteActiveLeagueDialog(League league) {
    showDeleteLeagueDialog(
      context,
      leagueId: league.id,
      leagueName: league.name,
      title: 'Eliminar Liga Activa',
      description:
          '¿Deseas eliminar "${league.name}" (ID: ${league.id})?\nEsta acción removerá la liga de tu dispositivo y opcionalmente del servidor si eres administrador.',
      deleteOnServerDefault: true,
      prefillPin: league.pin,
      onDelete: (id, {String? pin, bool deleteOnServer = false}) =>
          _service.deleteLeague(id, pin: pin, deleteOnServer: deleteOnServer),
      onDeleted: () {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final active = _service.activeLeague;

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
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    active != null ? active.name : 'Modo Liga',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Verificando conexión con el servidor en la nube...'),
                        duration: Duration(milliseconds: 900),
                      ),
                    );
                    unawaited(_checkServerStatus());
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isServerOnline
                          ? AppColors.emerald500.withValues(alpha: 0.15)
                          : AppColors.amber600.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isServerOnline
                            ? AppColors.emerald500.withValues(alpha: 0.4)
                            : AppColors.amber600.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _isServerOnline
                                ? AppColors.emerald400
                                : AppColors.amber300,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isServerOnline ? 'Servidor OK' : 'Conectando...',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _isServerOnline
                                ? AppColors.emerald300
                                : AppColors.amber300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (active != null)
                IconButton(
                  tooltip: 'Sincronizar rankings con el servidor',
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.emerald400),
                        )
                      : const Icon(Icons.cloud_sync,
                          color: AppColors.emerald400, size: 21),
                  onPressed: _handleSync,
                ),
              IconButton(
                tooltip: 'Explorar Ligas (Dispositivo y Servidor)',
                icon: const Icon(Icons.format_list_bulleted,
                    color: AppColors.emerald400, size: 21),
                onPressed: _openLeagueManager,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.slate300),
                color: AppColors.slate900,
                onSelected: (val) {
                  if (val == 'sync') _handleSync();
                  if (val == 'manage') _openLeagueManager();
                  if (val == 'create') _showCreateLeagueDialog();
                  if (val == 'join') _showJoinLeagueDialog();
                  if (val == 'delete' && active != null) {
                    _showDeleteActiveLeagueDialog(active);
                  }
                },
                itemBuilder: (ctx) => [
                  if (active != null)
                    const PopupMenuItem(
                      value: 'sync',
                      child: Row(
                        children: [
                          Icon(Icons.cloud_sync,
                              size: 18, color: AppColors.emerald400),
                          SizedBox(width: 8),
                          Text('Sincronizar con Servidor',
                              style: TextStyle(
                                  color: AppColors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'manage',
                    child: Row(
                      children: [
                        Icon(Icons.list_alt,
                            size: 18, color: AppColors.indigo400),
                        SizedBox(width: 8),
                        Text('Gestor de Ligas',
                            style: TextStyle(
                                color: AppColors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'create',
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 18, color: AppColors.emerald400),
                        SizedBox(width: 8),
                        Text('Crear otra liga',
                            style: TextStyle(
                                color: AppColors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'join',
                    child: Row(
                      children: [
                        Icon(Icons.vpn_key_outlined,
                            size: 18, color: AppColors.amber300),
                        SizedBox(width: 8),
                        Text('Unirse con clave',
                            style: TextStyle(
                                color: AppColors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (active != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever,
                              size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Eliminar esta liga',
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            bottom: active != null
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
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
                            fontSize: 11, fontWeight: FontWeight.bold),
                        tabs: const [
                          Tab(text: '🏆 Clasificación'),
                          Tab(text: '👥 Participantes'),
                          Tab(text: '📜 Partidas'),
                        ],
                      ),
                    ),
                  )
                : null,
          ),
          body: active == null
              ? LeagueEmptyState(
                  onJoin: _showJoinLeagueDialog,
                  onCreate: _showCreateLeagueDialog,
                  onExplore: _openLeagueManager,
                )
              : Column(
                  children: [
                    LeagueInfoBanner(
                      league: active,
                      onDelete: () => _showDeleteActiveLeagueDialog(active),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          LeagueRankingsTab(
                            league: active,
                            isSyncing: _isSyncing,
                            onSync: _handleSync,
                            onOpenMonthlyRanking: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GlobalRankingScreen(
                                    leagueId: active.id,
                                    leagueName: active.name,
                                    leagueService: _service,
                                  ),
                                ),
                              );
                            },
                          ),
                          LeagueParticipantsTab(
                            participants: active.participants,
                            onAddParticipant: _showAddParticipantDialog,
                            onRemoveParticipant: (name) => unawaited(
                              _service.removeParticipantFromActiveLeague(name),
                            ),
                          ),
                          LeagueMatchesHistoryTab(
                            matches: active.matchesByDateDesc,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          floatingActionButton: active != null
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => MatchSetupScreen(
                          league: active,
                          leagueService: _service,
                        ),
                      ),
                    );
                  },
                  backgroundColor: AppColors.emerald600,
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: const Text(
                    'Nueva Partida',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                )
              : null,
        );
      },
    );
  }
}
