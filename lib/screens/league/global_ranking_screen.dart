import 'package:flutter/material.dart';
import '../../services/league_service.dart';
import '../../theme/app_colors.dart';

class GlobalRankingScreen extends StatefulWidget {
  const GlobalRankingScreen({super.key});

  @override
  State<GlobalRankingScreen> createState() => _GlobalRankingScreenState();
}

class _GlobalRankingScreenState extends State<GlobalRankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LeagueService _service = LeagueService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: const Row(
          children: [
            Icon(Icons.public, color: AppColors.emerald400, size: 18),
            SizedBox(width: 8),
            Text(
              'Ranking General del Servidor',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.white),
            ),
          ],
        ),
        bottom: PreferredSize(
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
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: '🏆 Mejores Equipos'),
                Tab(text: '👤 Mejores Jugadores'),
              ],
            ),
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildGlobalTeamsTab(),
              _buildGlobalPlayersTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlobalTeamsTab() {
    final teams = _service.getGlobalTeamsRanked();

    if (teams.isEmpty) {
      return const Center(
        child: Text(
          'Aún no hay equipos registrados en ninguna liga del servidor.',
          style: TextStyle(color: AppColors.slate400, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: teams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final t = teams[i];
        final rank = i + 1;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.slate900,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: rank == 1 ? AppColors.amber600.withValues(alpha: 0.6) : AppColors.slate800,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: rank == 1
                      ? AppColors.amber600
                      : rank == 2
                          ? const Color(0xFF64748B)
                          : rank == 3
                              ? const Color(0xFF92400E)
                              : AppColors.slate800,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$rank',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${t.matchesPlayed} partidas • ${t.totalPoints} pts acumulados',
                      style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.emerald950,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${t.wins} Victorias',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.emerald400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${t.winRate.toStringAsFixed(0)}% victoria',
                    style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlobalPlayersTab() {
    final players = _service.getGlobalPlayersRanked();

    if (players.isEmpty) {
      return const Center(
        child: Text(
          'Aún no hay jugadores registrados en ninguna liga del servidor.',
          style: TextStyle(color: AppColors.slate400, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: players.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final p = players[i];
        final rank = i + 1;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.slate900,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: rank == 1 ? AppColors.amber600.withValues(alpha: 0.6) : AppColors.slate800,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: rank == 1
                      ? AppColors.amber600
                      : rank == 2
                          ? const Color(0xFF64748B)
                          : rank == 3
                              ? const Color(0xFF92400E)
                              : AppColors.slate800,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$rank',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.matchesPlayed} partidas jugadas en ligas',
                      style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.indigo950,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.indigo500.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${p.wins} Victorias',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.indigo400,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
