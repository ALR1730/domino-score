import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/league.dart';
import '../../services/league_service.dart';
import '../../theme/app_colors.dart';
import 'league_manager_screen.dart';
import 'match_setup_screen.dart';

class LeagueHomeScreen extends StatefulWidget {
  const LeagueHomeScreen({super.key});

  @override
  State<LeagueHomeScreen> createState() => _LeagueHomeScreenState();
}

class _LeagueHomeScreenState extends State<LeagueHomeScreen>
    with SingleTickerProviderStateMixin {
  final LeagueService _service = LeagueService();
  late TabController _tabController;
  bool _isSyncing = false;
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.syncActiveLeagueWithServer();
    });
    // Auto-sincronización periódica cada 10s para reflejar partidas de otros dispositivos
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_isSyncing) {
        _service.syncActiveLeagueWithServer();
      }
    });
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sincronizando rankings con el servidor Render...'),
        duration: Duration(milliseconds: 900),
      ),
    );
    final ok = await _service.syncActiveLeagueWithServer();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? '✅ Rankings sincronizados con el servidor correctamente.'
              : '⚠️ No se pudo conectar al servidor Render.'),
          backgroundColor: ok ? AppColors.emerald600 : AppColors.amber600,
        ),
      );
    }
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateLeagueDialog() {
    final nameController = TextEditingController();
    final pinController = TextEditingController(text: '1234');
    final participantsController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: AppColors.slate900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.slate800),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: AppColors.emerald400),
                      SizedBox(width: 8),
                      Text(
                        'Crear Nueva Liga',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    enabled: !isSubmitting,
                    style: const TextStyle(color: AppColors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la Liga',
                      hintText: 'Ej. Liga de los Viernes',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinController,
                    enabled: !isSubmitting,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Clave de Acceso (PIN)',
                      hintText: 'Para entrar desde otros dispositivos',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: participantsController,
                    enabled: !isSubmitting,
                    maxLines: 2,
                    style: const TextStyle(color: AppColors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Participantes iniciales (separados por coma)',
                      hintText: 'Carlos, Juan, Pedro, Luis, Maria',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                          child: const Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final name = nameController.text.trim();
                                  final pin = pinController.text.trim();
                                  final parts = participantsController.text
                                      .split(',')
                                      .map((p) => p.trim())
                                      .where((p) => p.isNotEmpty)
                                      .toList();

                                  if (name.isEmpty) return;

                                  setModalState(() => isSubmitting = true);

                                  try {
                                    await _service.createLeague(
                                      name: name,
                                      pin: pin.isNotEmpty ? pin : '1234',
                                      initialParticipants: parts,
                                    );
                                  } finally {
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                  }
                                },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald600),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Crear', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showJoinLeagueDialog() {
    final searchController = TextEditingController();
    final pinController = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: AppColors.slate900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.slate800),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.vpn_key_outlined, color: AppColors.amber300),
                      SizedBox(width: 8),
                      Text(
                        'Unirse a una Liga',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ingresa el nombre o código de la liga y la clave de acceso compartida.',
                    style: TextStyle(fontSize: 11, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: AppColors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Nombre o Código de la Liga (ej. LIG-1001)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Clave de Acceso (PIN)',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: const TextStyle(color: AppColors.rose300, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final err = await _service.joinLeague(
                              nameOrId: searchController.text,
                              pin: pinController.text,
                            );
                            if (!ctx.mounted) return;
                            if (err != null) {
                              setModalState(() => error = err);
                            } else {
                              Navigator.of(ctx).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber600),
                          child: const Text('Entrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _showAddParticipantDialog(League league) {
    final controller = TextEditingController();

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nuevo Participante',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.white),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: AppColors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Nombre del jugador (ej. María)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final name = controller.text.trim();
                        if (name.isNotEmpty) {
                          _service.addParticipantToActiveLeague(name);
                          Navigator.of(ctx).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald600),
                      child: const Text('Agregar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _showDeleteActiveLeagueDialog(League league) {
    bool deleteOnServer = true;
    final pinController = TextEditingController(text: league.pin);
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: AppColors.slate900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.slate800),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.redAccent, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Eliminar Liga Activa',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '¿Deseas eliminar "${league.name}" (ID: ${league.id})?',
                  style: const TextStyle(color: AppColors.slate200, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Esta acción removerá la liga de tu dispositivo y opcionalmente del servidor si eres administrador.',
                  style: TextStyle(color: AppColors.slate400, fontSize: 11),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: deleteOnServer,
                  onChanged: (val) => setModalState(() => deleteOnServer = val ?? false),
                  title: const Text(
                    'Eliminar también del servidor en la nube',
                    style: TextStyle(color: AppColors.white, fontSize: 12),
                  ),
                  activeColor: Colors.redAccent,
                ),
                if (deleteOnServer) ...[
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Clave/PIN para confirmar',
                      hintText: 'PIN de la liga',
                    ),
                  ),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final err = await _service.deleteLeague(
                            league.id,
                            pin: deleteOnServer ? pinController.text.trim() : null,
                            deleteOnServer: deleteOnServer,
                          );
                          if (!ctx.mounted) return;
                          if (err != null) {
                            setModalState(() => errorText = err);
                          } else {
                            Navigator.of(ctx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Liga "${league.name}" eliminada.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.slate300),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              active != null ? active.name : 'Modo Liga',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.white),
            ),
            actions: [
              if (active != null)
                IconButton(
                  tooltip: 'Sincronizar rankings con el servidor',
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald400),
                        )
                      : const Icon(Icons.cloud_sync, color: AppColors.emerald400, size: 21),
                  onPressed: _handleSync,
                ),
              IconButton(
                tooltip: 'Explorar Ligas (Dispositivo y Servidor)',
                icon: const Icon(Icons.format_list_bulleted, color: AppColors.emerald400, size: 21),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LeagueManagerScreen()),
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.slate300),
                color: AppColors.slate900,
                onSelected: (val) {
                  if (val == 'sync') _handleSync();
                  if (val == 'manage') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LeagueManagerScreen()),
                    );
                  }
                  if (val == 'create') _showCreateLeagueDialog();
                  if (val == 'join') _showJoinLeagueDialog();
                  if (val == 'delete' && active != null) _showDeleteActiveLeagueDialog(active);
                },
                itemBuilder: (ctx) => [
                  if (active != null)
                    const PopupMenuItem(
                      value: 'sync',
                      child: Row(
                        children: [
                          Icon(Icons.cloud_sync, size: 18, color: AppColors.emerald400),
                          SizedBox(width: 8),
                          Text('Sincronizar con Servidor', style: TextStyle(color: AppColors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'manage',
                    child: Row(
                      children: [
                        Icon(Icons.list_alt, size: 18, color: AppColors.indigo400),
                        SizedBox(width: 8),
                        Text('Gestor de Ligas', style: TextStyle(color: AppColors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'create',
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 18, color: AppColors.emerald400),
                        SizedBox(width: 8),
                        Text('Crear otra liga', style: TextStyle(color: AppColors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'join',
                    child: Row(
                      children: [
                        Icon(Icons.vpn_key_outlined, size: 18, color: AppColors.amber300),
                        SizedBox(width: 8),
                        Text('Unirse con clave', style: TextStyle(color: AppColors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (active != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Eliminar esta liga', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
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
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
          body: active == null ? _buildNoActiveLeagueView() : _buildActiveLeagueView(active),
          floatingActionButton: active != null
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => MatchSetupScreen(league: active)),
                    );
                  },
                  backgroundColor: AppColors.emerald600,
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: const Text(
                    'Nueva Partida',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildNoActiveLeagueView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slate900,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.slate800),
              ),
              child: const Icon(Icons.emoji_events_outlined, size: 48, color: AppColors.amber300),
            ),
            const SizedBox(height: 16),
            const Text(
              'No tienes ninguna liga activa',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea una liga para registrar participantes o únete a una existente con su clave.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.slate400),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showJoinLeagueDialog,
                    icon: const Icon(Icons.vpn_key_outlined, size: 16, color: AppColors.amber300),
                    label: const Text('Unirse con Clave', style: TextStyle(color: AppColors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.slate700),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showCreateLeagueDialog,
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text('Crear Liga', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLeagueView(League league) {
    return Column(
      children: [
        // League info banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.slate900.withValues(alpha: 0.6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tag, size: 14, color: AppColors.slate400),
                  const SizedBox(width: 4),
                  Text(
                    'ID: ${league.id}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.slate400),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.amber950.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.amber600.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.key, size: 12, color: AppColors.amber300),
                        const SizedBox(width: 4),
                        Text(
                          'PIN: ${league.pin}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.amber300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showDeleteActiveLeagueDialog(league),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.delete_outline, size: 13, color: Colors.redAccent),
                          SizedBox(width: 4),
                          Text(
                            'Eliminar Liga',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
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

        // Tabs Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLeagueRankingsTab(league),
              _buildLeagueParticipantsTab(league),
              _buildLeagueMatchesHistoryTab(league),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeagueRankingsTab(League league) {
    final teams = league.teamsRanked;
    final players = league.playersRanked;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RANKING DE PAREJAS / EQUIPOS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.emerald400, letterSpacing: 0.8),
              ),
              InkWell(
                onTap: _handleSync,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emerald500.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_upload_outlined, size: 12, color: AppColors.emerald400),
                      const SizedBox(width: 4),
                      Text(
                        _isSyncing ? 'Sincronizando...' : 'Sincronizar Servidor',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.emerald400),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (teams.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.slate800),
              ),
              child: const Text(
                'Aún no hay partidas jugadas en esta liga. Inicia una partida para generar la clasificación.',
                style: TextStyle(fontSize: 12, color: AppColors.slate400),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: teams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) {
                final t = teams[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.slate900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slate800),
                  ),
                  child: Row(
                    children: [
                      Text('#${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate400)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(t.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.emerald950,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.3)),
                        ),
                        child: Text('${t.wins} V', style: const TextStyle(color: AppColors.emerald400, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          const Text(
            'RANKING INDIVIDUAL DE JUGADORES',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.indigo400, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          if (players.isEmpty)
            const Text('Sin datos individuales aún.', style: TextStyle(fontSize: 12, color: AppColors.slate500))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: players.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) {
                final p = players[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.slate900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slate800),
                  ),
                  child: Row(
                    children: [
                      Text('#${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate400)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      Text('${p.matchesPlayed} jugadas • ', style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.indigo950,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.indigo500.withValues(alpha: 0.3)),
                        ),
                        child: Text('${p.wins} V', style: const TextStyle(color: AppColors.indigo400, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLeagueParticipantsTab(League league) {
    final participants = league.participants;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${participants.length} PARTICIPANTES REGISTRADOS',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate400),
            ),
            TextButton.icon(
              onPressed: () => _showAddParticipantDialog(league),
              icon: const Icon(Icons.person_add, size: 14),
              label: const Text('Agregar', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (participants.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No hay participantes en la liga. Agrega jugadores para armar las partidas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate500, fontSize: 12),
            ),
          )
        else
          ...participants.map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate800),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.slate800,
                        child: Icon(Icons.person, size: 16, color: AppColors.slate300),
                      ),
                      const SizedBox(width: 10),
                      Text(p, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.slate500),
                    onPressed: () => _service.removeParticipantFromActiveLeague(p),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildLeagueMatchesHistoryTab(League league) {
    final matches = league.matches;

    if (matches.isEmpty) {
      return const Center(
        child: Text(
          'Sin partidas jugadas aún en esta liga.',
          style: TextStyle(color: AppColors.slate500, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final m = matches[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.slate900,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${m.date.day}/${m.date.month}/${m.date.year}',
                    style: const TextStyle(color: AppColors.slate500, fontSize: 11),
                  ),
                  Text(
                    m.winnerTeam == 1 ? 'Ganó ${m.team1DisplayName}' : 'Ganó ${m.team2DisplayName}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: m.winnerTeam == 1 ? AppColors.emerald400 : AppColors.indigo400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('${m.team1DisplayName}: ${m.score1} pts', style: const TextStyle(color: AppColors.slate300, fontSize: 12)),
                  const Text('vs', style: TextStyle(color: AppColors.slate600, fontSize: 11)),
                  Text('${m.team2DisplayName}: ${m.score2} pts', style: const TextStyle(color: AppColors.slate300, fontSize: 12)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
