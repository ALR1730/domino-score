import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

class ServerLeaguesTab extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> serverLeagues;
  final String searchQuery;
  final Set<String> localIds;
  final String? activeId;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;
  final void Function(String id, String name) onActivateLocal;
  final void Function(String id, String name) onJoinServerLeague;
  final void Function(String id, String name) onDeleteServerLeague;

  const ServerLeaguesTab({
    super.key,
    required this.isLoading,
    required this.error,
    required this.serverLeagues,
    required this.searchQuery,
    required this.localIds,
    required this.activeId,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onActivateLocal,
    required this.onJoinServerLeague,
    required this.onDeleteServerLeague,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
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

    if (error != null) {
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
                error!,
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRefresh,
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

    final q = searchQuery.toLowerCase();
    final filtered = serverLeagues.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final id = (item['id'] ?? '').toString().toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.emerald400,
      backgroundColor: AppColors.slate900,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.isEmpty ? 5 : filtered.length + 4,
        itemBuilder: (ctx, index) {
          if (index == 0) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate800),
              ),
              child: TextField(
                onChanged: onSearchChanged,
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
                  'Servidor en la nube',
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
          final participantsCount =
              (item['participantsCount'] as num?)?.toInt() ?? 0;
          final matchesCount = (item['matchesCount'] as num?)?.toInt() ?? 0;
          final isAlreadyLocal = localIds.contains(id.toLowerCase());
          final isActive = id.toLowerCase() == (activeId ?? '').toLowerCase();

          return ServerLeagueCard(
            key: ValueKey('server_league_$id'),
            id: id,
            name: name,
            participantsCount: participantsCount,
            matchesCount: matchesCount,
            isAlreadyLocal: isAlreadyLocal,
            isActive: isActive,
            onActivateLocal: () => onActivateLocal(id, name),
            onJoin: () => onJoinServerLeague(id, name),
            onDeleteOnServer: () => onDeleteServerLeague(id, name),
          );
        },
      ),
    );
  }
}

class ServerLeagueCard extends StatelessWidget {
  final String id;
  final String name;
  final int participantsCount;
  final int matchesCount;
  final bool isAlreadyLocal;
  final bool isActive;
  final VoidCallback onActivateLocal;
  final VoidCallback onJoin;
  final VoidCallback onDeleteOnServer;

  const ServerLeagueCard({
    super.key,
    required this.id,
    required this.name,
    required this.participantsCount,
    required this.matchesCount,
    required this.isAlreadyLocal,
    required this.isActive,
    required this.onActivateLocal,
    required this.onJoin,
    required this.onDeleteOnServer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.emerald500
              : (isAlreadyLocal ? AppColors.slate700 : AppColors.slate800),
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
                        color: AppColors.emerald500.withValues(alpha: 0.15),
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
                      onPressed: onActivateLocal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.slate800,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Activar',
                          style:
                              TextStyle(color: AppColors.white, fontSize: 11)),
                    )
                else
                  ElevatedButton.icon(
                    onPressed: onJoin,
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
                  style:
                      const TextStyle(color: AppColors.slate400, fontSize: 11),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.history, size: 14, color: AppColors.slate400),
                const SizedBox(width: 4),
                Text(
                  '$matchesCount partidas',
                  style:
                      const TextStyle(color: AppColors.slate400, fontSize: 11),
                ),
                const Spacer(),
                InkWell(
                  onTap: onDeleteOnServer,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
  }
}
