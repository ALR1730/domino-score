import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/league.dart';
import '../../services/api_client.dart';
import '../../services/league_service.dart';
import '../../theme/app_colors.dart';
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
    _loadServerLeagues();
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

    try {
      final list = await _apiClient.fetchServerLeagues();
      setState(() {
        _serverLeagues = list;
        _isLoadingServer = false;
      });
    } catch (e) {
      setState(() {
        _serverError = 'No se pudieron cargar las ligas del servidor.';
        _isLoadingServer = false;
      });
    }
  }

  void _showJoinDialogForServerLeague(String leagueId, String leagueName) {
    showJoinLeagueDialog(
      context,
      leagueId: leagueId,
      leagueName: leagueName,
      onJoin: (nameOrId, pin) =>
          _leagueService.joinLeague(nameOrId: nameOrId, pin: pin),
      onJoined: () {
        _loadServerLeagues();
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
        _loadServerLeagues();
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
        _loadServerLeagues();
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
      onCreated: _loadServerLeagues,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _leagueService,
      builder: (context, _) {
        final localLeagues = _leagueService.allLeagues;
        final activeId = _leagueService.activeLeagueId;

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
              // PESTAÑA 1: Ligas en este Dispositivo
              _buildLocalLeaguesTab(localLeagues, activeId),

              // PESTAÑA 2: Ligas en el Servidor
              _buildServerLeaguesTab(localLeagues, activeId),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocalLeaguesTab(List<League> localLeagues, String? activeId) {
    if (localLeagues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_esports_outlined,
                  size: 54, color: AppColors.slate600),
              const SizedBox(height: 16),
              const Text(
                'No tienes ligas registradas en este dispositivo',
                style: TextStyle(
                    color: AppColors.slate300,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Crea una liga nueva o explora la pestaña "En el Servidor" para unirte con tu PIN.',
                style: TextStyle(color: AppColors.slate500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showCreateLeagueDialog,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Crear Primera Liga',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: localLeagues.length + 2,
      itemBuilder: (ctx, index) {
        if (index == 0) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIGAS REGISTRADAS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate400,
                    letterSpacing: 1),
              ),
              TextButton.icon(
                onPressed: _showCreateLeagueDialog,
                icon: const Icon(Icons.add,
                    size: 15, color: AppColors.emerald400),
                label: const Text('Nueva Liga',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.emerald400,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
        if (index == 1) return const SizedBox(height: 8);

        final league = localLeagues[index - 2];
        final isActive = league.id == activeId;

        return Container(
          key: ValueKey('local_league_${league.id}'),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.slate900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? AppColors.emerald500 : AppColors.slate800,
              width: isActive ? 1.8 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isActive
                                ? AppColors.emerald500
                                : AppColors.slate700)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.emoji_events,
                        color: isActive
                            ? AppColors.emerald400
                            : AppColors.slate400,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            league.name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.slate800,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '# ${league.id}',
                                  style: const TextStyle(
                                      color: AppColors.slate300,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.amber950.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'PIN: ${league.pin}',
                                  style: const TextStyle(
                                      color: AppColors.amber300,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emerald500.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.emerald500),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                size: 13, color: AppColors.emerald400),
                            SizedBox(width: 4),
                            Text('ACTIVA',
                                style: TextStyle(
                                    color: AppColors.emerald300,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.slate800, height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 14, color: AppColors.slate400),
                    const SizedBox(width: 4),
                    Text(
                      '${league.participants.length} participantes',
                      style: const TextStyle(
                          color: AppColors.slate400, fontSize: 11),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.history,
                        size: 14, color: AppColors.slate400),
                    const SizedBox(width: 4),
                    Text(
                      '${league.matches.length} partidas',
                      style: const TextStyle(
                          color: AppColors.slate400, fontSize: 11),
                    ),
                    const Spacer(),
                    if (!isActive) ...[
                      ElevatedButton(
                        onPressed: () {
                          _leagueService.setActiveLeague(league.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Liga activa cambiada a "${league.name}"'),
                              backgroundColor: AppColors.emerald600,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.slate800,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Activar',
                            style: TextStyle(
                                color: AppColors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    InkWell(
                      onTap: () => _showDeleteLocalLeagueDialog(league),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline,
                                size: 14, color: Colors.redAccent),
                            SizedBox(width: 4),
                            Text(
                              'Eliminar',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServerLeaguesTab(List<League> localLeagues, String? activeId) {
    if (_isLoadingServer) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.emerald400),
              SizedBox(height: 18),
              Text(
                'Consultando ligas en el servidor en la nube...',
                style: TextStyle(
                    color: AppColors.slate300,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Si el servidor estaba en reposo por inactividad, puede tomar unos segundos en reactivarse.',
                style: TextStyle(color: AppColors.slate500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_serverError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _serverError!,
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadServerLeagues,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                label: const Text('Reintentar',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.slate800),
              ),
            ],
          ),
        ),
      );
    }

    final localIds = localLeagues.map((l) => l.id.toLowerCase()).toSet();

    final filtered = _serverLeagues.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final id = (item['id'] ?? '').toString().toLowerCase();
      final q = _serverSearchQuery.toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadServerLeagues,
      color: AppColors.emerald400,
      backgroundColor: AppColors.slate900,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        // 4 fijos (búsqueda, spacing, título, spacing) + ítems (o vacío)
        itemCount: filtered.isEmpty ? 5 : filtered.length + 4,
        itemBuilder: (ctx, index) {
          if (index == 0) {
            // Barra de búsqueda
            return Container(
              decoration: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate800),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _serverSearchQuery = val),
                style: const TextStyle(color: AppColors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre o código (ej. LIG-1001)...',
                  prefixIcon:
                      Icon(Icons.search, color: AppColors.slate400, size: 18),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            );
          }
          if (index == 1) return const SizedBox(height: 16);
          if (index == 2) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LIGAS EN LA NUBE (${filtered.length})',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate400,
                      letterSpacing: 1),
                ),
                const Text(
                  'Servidor: Render',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.emerald400,
                      fontWeight: FontWeight.bold),
                ),
              ],
            );
          }
          if (index == 3) return const SizedBox(height: 10);

          if (filtered.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(28),
              margin: const EdgeInsets.only(top: 20),
              decoration: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate800),
              ),
              child: const Column(
                children: [
                  Icon(Icons.search_off, size: 36, color: AppColors.slate500),
                  SizedBox(height: 10),
                  Text(
                    'No se encontraron ligas con ese filtro.',
                    style: TextStyle(color: AppColors.slate400, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          final item = filtered[index - 4];
          final id = (item['id'] ?? '').toString();
          final name = (item['name'] ?? 'Liga sin nombre').toString();
          final participantsCount = item['participantsCount'] ?? 0;
          final matchesCount = item['matchesCount'] ?? 0;
          final isAlreadyLocal = localIds.contains(id.toLowerCase());
          final isActive = id.toLowerCase() == (activeId ?? '').toLowerCase();

          return Container(
            key: ValueKey('server_league_$id'),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.slate900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? AppColors.emerald500
                    : (isAlreadyLocal
                        ? AppColors.slate700
                        : AppColors.slate800),
                width: isActive ? 1.8 : 1.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isAlreadyLocal
                                  ? AppColors.emerald500
                                  : AppColors.indigo500)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isAlreadyLocal ? Icons.check : Icons.public,
                          color: isAlreadyLocal
                              ? AppColors.emerald400
                              : AppColors.indigo400,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.slate800,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '# $id',
                                    style: const TextStyle(
                                        color: AppColors.slate300,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.copy,
                                      size: 12, color: AppColors.slate400),
                                  tooltip: 'Copiar código',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: id));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Código "$id" copiado'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isAlreadyLocal)
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.emerald500.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.emerald500),
                            ),
                            child: const Text('ACTIVA',
                                style: TextStyle(
                                    color: AppColors.emerald300,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          )
                        else
                          ElevatedButton(
                            onPressed: () {
                              _leagueService.setActiveLeague(id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Liga cambiada a "$name"'),
                                  backgroundColor: AppColors.emerald600,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.slate800,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              minimumSize: Size.zero,
                            ),
                            child: const Text('Activar',
                                style: TextStyle(
                                    color: AppColors.white, fontSize: 11)),
                          )
                      else
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showJoinDialogForServerLeague(id, name),
                          icon: const Icon(Icons.vpn_key,
                              size: 12, color: Colors.white),
                          label: const Text('Unirse',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.amber600,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.slate800, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.people_outline,
                          size: 14, color: AppColors.slate400),
                      const SizedBox(width: 4),
                      Text(
                        '$participantsCount participantes',
                        style: const TextStyle(
                            color: AppColors.slate400, fontSize: 11),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.history,
                          size: 14, color: AppColors.slate400),
                      const SizedBox(width: 4),
                      Text(
                        '$matchesCount partidas',
                        style: const TextStyle(
                            color: AppColors.slate400, fontSize: 11),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _showDeleteServerLeagueDialog(id, name),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 14, color: Colors.redAccent),
                              SizedBox(width: 4),
                              Text(
                                'Eliminar (Admin)',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
