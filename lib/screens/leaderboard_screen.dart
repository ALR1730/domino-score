import 'package:flutter/material.dart';
import '../models/leaderboard_entry.dart';
import '../services/api_client.dart';
import '../services/leaderboard_service.dart';
import '../services/league_service.dart';
import '../theme/app_colors.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final LeaderboardService _service = LeaderboardService();
  String _searchQuery = '';

  bool _useServer = false;
  bool _isLoadingServer = false;
  List<TeamStats>? _serverTeams;
  List<PlayerStats>? _serverPlayers;

  Future<void> _fetchServerRankings() async {
    setState(() => _isLoadingServer = true);
    final teams = await ApiClient().fetchGlobalTeams();
    final players = await ApiClient().fetchGlobalPlayers();
    if (mounted) {
      setState(() {
        _serverTeams = teams;
        _serverPlayers = players;
        _isLoadingServer = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.slate900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.slate800),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rose950.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.rose600.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.delete_forever, color: AppColors.rose300, size: 28),
              ),
              const SizedBox(height: 14),
              const Text(
                '¿Borrar Clasificación?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Esta acción eliminará de forma permanente el historial de victorias de todos los equipos y jugadores.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.slate400,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.slate800,
                        foregroundColor: AppColors.slate300,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _service.resetLeaderboard();
                        Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rose600,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Borrar Todo', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPositionBadge(int position) {
    Color bgColor;
    Color textColor;
    IconData? icon;

    if (position == 1) {
      bgColor = const Color(0xFFD97706); // Oro ámbar
      textColor = Colors.white;
      icon = Icons.emoji_events;
    } else if (position == 2) {
      bgColor = const Color(0xFF64748B); // Plata Slate
      textColor = Colors.white;
      icon = Icons.military_tech;
    } else if (position == 3) {
      bgColor = const Color(0xFF92400E); // Bronce
      textColor = Colors.white;
      icon = Icons.military_tech_outlined;
    } else {
      bgColor = AppColors.slate800;
      textColor = AppColors.slate400;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: position <= 3 ? Colors.white.withValues(alpha: 0.25) : AppColors.slate700,
        ),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, size: 16, color: textColor)
          : Text(
              '#$position',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate950,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.slate300),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tabla de Clasificación',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, size: 20, color: AppColors.emerald400),
            tooltip: 'Sincronizar clasificaciones con el servidor',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sincronizando todas las ligas con el servidor...')),
              );
              await LeagueService().syncAllLeaguesWithServer();
              await _fetchServerRankings();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Clasificaciones sincronizadas en el servidor Render.'),
                    backgroundColor: AppColors.emerald600,
                  ),
                );
              }
            },
          ),
          if (!_useServer)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.rose300),
              tooltip: 'Reiniciar clasificación local',
              onPressed: _confirmReset,
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: AppColors.slate300),
              tooltip: 'Actualizar del servidor',
              onPressed: _fetchServerRankings,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Equipos / Parejas'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_outline, size: 16),
                      SizedBox(width: 6),
                      Text('Individuales'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          return Column(
            children: [
              // Switch between Local and Server
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _useServer = false),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: !_useServer ? AppColors.emerald600 : AppColors.slate900,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: !_useServer ? AppColors.emerald500 : AppColors.slate800),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone_android, size: 14, color: !_useServer ? Colors.white : AppColors.slate400),
                              const SizedBox(width: 6),
                              Text(
                                'En este Dispositivo',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: !_useServer ? Colors.white : AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => _useServer = true);
                          if (_serverTeams == null) _fetchServerRankings();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _useServer ? AppColors.emerald600 : AppColors.slate900,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _useServer ? AppColors.emerald500 : AppColors.slate800),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_outlined, size: 14, color: _useServer ? Colors.white : AppColors.slate400),
                              const SizedBox(width: 6),
                              Text(
                                'En el Servidor 🌐',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _useServer ? Colors.white : AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13, color: AppColors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.slate900,
                    hintText: 'Buscar por nombre o pareja...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.slate500),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.slate400),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: AppColors.slate400),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.slate800),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.slate800),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.emerald500),
                    ),
                  ),
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTeamsTab(),
                    _buildPlayersTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTeamsTab() {
    if (_useServer && _isLoadingServer) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.emerald400),
            SizedBox(height: 12),
            Text('Consultando clasificaciones del servidor Render...', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
          ],
        ),
      );
    }
    final localLeagueTeams = LeagueService().getGlobalTeamsRanked();
    final allTeams = _useServer
        ? (_serverTeams ?? [])
        : (localLeagueTeams.isNotEmpty ? localLeagueTeams : _service.teamsRanked);
    final filtered = allTeams.where((t) {
      if (_searchQuery.isEmpty) return true;
      final matchDisplay = t.displayName.toLowerCase().contains(_searchQuery);
      final matchMembers = t.members.any((m) => m.toLowerCase().contains(_searchQuery));
      return matchDisplay || matchMembers;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_outlined, size: 48, color: AppColors.slate700),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isEmpty
                    ? 'Aún no hay partidas registradas.'
                    : 'No se encontraron equipos con "$_searchQuery"',
                style: const TextStyle(color: AppColors.slate400, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Al finalizar una partida se guardarán automáticamente aquí.',
                style: TextStyle(color: AppColors.slate500, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final team = filtered[index];
        final rank = index + 1;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.slate900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: rank == 1 ? AppColors.amber600.withValues(alpha: 0.6) : AppColors.slate800,
            ),
          ),
          child: Row(
            children: [
              _buildPositionBadge(rank),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${team.matchesPlayed} ${team.matchesPlayed == 1 ? 'partida' : 'partidas'} • ${team.totalPoints} pts acumulados',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Stats Chip
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emerald950.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${team.wins} V',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.emerald400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${team.winRate.toStringAsFixed(0)}% victoria',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayersTab() {
    if (_useServer && _isLoadingServer) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.emerald400),
            SizedBox(height: 12),
            Text('Consultando jugadores del servidor Render...', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
          ],
        ),
      );
    }
    final localLeaguePlayers = LeagueService().getGlobalPlayersRanked();
    final allPlayers = _useServer
        ? (_serverPlayers ?? [])
        : (localLeaguePlayers.isNotEmpty ? localLeaguePlayers : _service.playersRanked);
    final filtered = allPlayers.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_search_outlined, size: 48, color: AppColors.slate700),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isEmpty
                    ? 'Aún no hay jugadores registrados.'
                    : 'No se encontraron jugadores con "$_searchQuery"',
                style: const TextStyle(color: AppColors.slate400, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final player = filtered[index];
        final rank = index + 1;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.slate900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: rank == 1 ? AppColors.amber600.withValues(alpha: 0.6) : AppColors.slate800,
            ),
          ),
          child: Row(
            children: [
              _buildPositionBadge(rank),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${player.matchesPlayed} ${player.matchesPlayed == 1 ? 'partida' : 'partidas'} jugadas',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.indigo950.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.indigo500.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${player.wins} V',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.indigo400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${player.winRate.toStringAsFixed(0)}% victoria',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
