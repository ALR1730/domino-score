import 'package:flutter/material.dart';
import '../../models/leaderboard_entry.dart';
import '../../services/league_service.dart';
import '../../theme/app_colors.dart';

class GlobalRankingScreen extends StatefulWidget {
  final String? leagueId;
  final String? leagueName;

  const GlobalRankingScreen({
    super.key,
    this.leagueId,
    this.leagueName,
  });

  @override
  State<GlobalRankingScreen> createState() => _GlobalRankingScreenState();
}

class _GlobalRankingScreenState extends State<GlobalRankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LeagueService _service = LeagueService();

  // null significa "Histórico Completo"
  DateTime? _selectedMonth;

  static const List<String> _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initDefaultMonth();
  }

  void _initDefaultMonth() {
    final now = DateTime.now();
    final available = _service.getAvailableMonths(leagueId: widget.leagueId);
    if (available.any((d) => d.year == now.year && d.month == now.month)) {
      _selectedMonth = DateTime(now.year, now.month);
    } else if (available.isNotEmpty) {
      _selectedMonth = available.first;
    } else {
      _selectedMonth = null; // Histórico
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatMonthYear(DateTime dt) {
    final name = _monthNames[dt.month - 1];
    return '$name ${dt.year}';
  }

  void _prevMonth() {
    final available = _service.getAvailableMonths(leagueId: widget.leagueId);
    if (available.isEmpty) return;

    if (_selectedMonth == null) {
      setState(() => _selectedMonth = available.first);
      return;
    }

    final currentIndex = available.indexWhere(
      (d) => d.year == _selectedMonth!.year && d.month == _selectedMonth!.month,
    );

    if (currentIndex >= 0 && currentIndex < available.length - 1) {
      setState(() => _selectedMonth = available[currentIndex + 1]);
    }
  }

  void _nextMonth() {
    final available = _service.getAvailableMonths(leagueId: widget.leagueId);
    if (available.isEmpty) return;

    if (_selectedMonth == null) return;

    final currentIndex = available.indexWhere(
      (d) => d.year == _selectedMonth!.year && d.month == _selectedMonth!.month,
    );

    if (currentIndex > 0) {
      setState(() => _selectedMonth = available[currentIndex - 1]);
    } else if (currentIndex == 0) {
      // Avanzar después del más reciente vuelve a Histórico
      setState(() => _selectedMonth = null);
    }
  }

  void _showMonthPickerSheet(BuildContext context, List<DateTime> available) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.slate900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, color: AppColors.emerald400, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Seleccionar Período de Ranking',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.slate800),
                ListTile(
                  leading: const Icon(Icons.all_inclusive, color: AppColors.amber400),
                  title: const Text(
                    'Histórico Total (Todas las partidas)',
                    style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
                  ),
                  trailing: _selectedMonth == null
                      ? const Icon(Icons.check_circle, color: AppColors.emerald400)
                      : null,
                  onTap: () {
                    setState(() => _selectedMonth = null);
                    Navigator.pop(ctx);
                  },
                ),
                if (available.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No hay meses con partidas registradas aún.',
                      style: TextStyle(color: AppColors.slate400, fontSize: 13),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: available.length,
                      itemBuilder: (context, i) {
                        final dt = available[i];
                        final isSelected = _selectedMonth != null &&
                            _selectedMonth!.year == dt.year &&
                            _selectedMonth!.month == dt.month;

                        return ListTile(
                          leading: Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: isSelected ? AppColors.emerald400 : AppColors.slate400,
                          ),
                          title: Text(
                            _formatMonthYear(dt),
                            style: TextStyle(
                              color: isSelected ? AppColors.emerald400 : AppColors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: AppColors.emerald400)
                              : null,
                          onTap: () {
                            setState(() => _selectedMonth = dt);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.leagueName != null
        ? 'Ranking: ${widget.leagueName}'
        : 'Ranking General';

    return Scaffold(
      backgroundColor: AppColors.slate950,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.slate300),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.emoji_events_outlined, color: AppColors.amber400, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(102),
          child: Column(
            children: [
              // Selector de Mes Interactivo
              _buildMonthFilterBar(),
              // Pestañas Parejas / Individual
              Container(
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
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group, size: 16),
                          SizedBox(width: 6),
                          Text('Por Parejas'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person, size: 16),
                          SizedBox(width: 6),
                          Text('Individual'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildTeamsTab(),
              _buildPlayersTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthFilterBar() {
    final available = _service.getAvailableMonths(leagueId: widget.leagueId);

    final currentIndex = _selectedMonth == null
        ? -1
        : available.indexWhere(
            (d) => d.year == _selectedMonth!.year && d.month == _selectedMonth!.month,
          );

    final canGoPrev = available.isNotEmpty &&
        (_selectedMonth == null || currentIndex < available.length - 1);
    final canGoNext = _selectedMonth != null;

    final displayText = _selectedMonth != null
        ? _formatMonthYear(_selectedMonth!)
        : 'Histórico Total';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.slate800.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate700.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            color: canGoPrev ? AppColors.white : AppColors.slate600,
            onPressed: canGoPrev ? _prevMonth : null,
            tooltip: 'Mes anterior',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _showMonthPickerSheet(context, available),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selectedMonth != null ? Icons.calendar_month : Icons.history,
                      size: 16,
                      color: AppColors.emerald400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayText,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.slate400),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            color: canGoNext ? AppColors.white : AppColors.slate600,
            onPressed: canGoNext ? _nextMonth : null,
            tooltip: 'Mes siguiente',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsTab() {
    final teams = widget.leagueId != null
        ? (_service.getLeague(widget.leagueId!)?.getTeamsRankedForMonth(
                year: _selectedMonth?.year,
                month: _selectedMonth?.month,
              ) ??
            [])
        : _service.getGlobalTeamsRanked(
            year: _selectedMonth?.year,
            month: _selectedMonth?.month,
          );

    if (teams.isEmpty) {
      return _buildEmptyState(isTeams: true);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Podio Top 3 si hay equipos
        if (teams.length >= 2) _buildTeamsPodium(teams.take(3).toList()),
        const SizedBox(height: 12),
        // Lista completa
        ...List.generate(teams.length, (i) {
          final t = teams[i];
          final rank = i + 1;
          final losses = t.matchesPlayed - t.wins;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.slate900,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: rank == 1
                    ? AppColors.amber500.withValues(alpha: 0.6)
                    : rank == 2
                        ? const Color(0xFF94A3B8).withValues(alpha: 0.4)
                        : rank == 3
                            ? const Color(0xFFB45309).withValues(alpha: 0.4)
                            : AppColors.slate800,
              ),
            ),
            child: Row(
              children: [
                _buildRankBadge(rank),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        children: [
                          Text(
                            '${t.matchesPlayed} PJ (${t.wins}G - ${losses >= 0 ? losses : 0}P)',
                            style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                          ),
                          Text(
                            '•  ${t.totalPoints} pts',
                            style: const TextStyle(fontSize: 11, color: AppColors.emerald400),
                          ),
                        ],
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
                        '${t.wins} Vic',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.emerald400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${t.winRate.toStringAsFixed(0)}% efectividad',
                      style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPlayersTab() {
    final players = widget.leagueId != null
        ? (_service.getLeague(widget.leagueId!)?.getPlayersRankedForMonth(
                year: _selectedMonth?.year,
                month: _selectedMonth?.month,
              ) ??
            [])
        : _service.getGlobalPlayersRanked(
            year: _selectedMonth?.year,
            month: _selectedMonth?.month,
          );

    if (players.isEmpty) {
      return _buildEmptyState(isTeams: false);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (players.length >= 2) _buildPlayersPodium(players.take(3).toList()),
        const SizedBox(height: 12),
        ...List.generate(players.length, (i) {
          final p = players[i];
          final rank = i + 1;
          final losses = p.matchesPlayed - p.wins;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.slate900,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: rank == 1
                    ? AppColors.amber500.withValues(alpha: 0.6)
                    : rank == 2
                        ? const Color(0xFF94A3B8).withValues(alpha: 0.4)
                        : rank == 3
                            ? const Color(0xFFB45309).withValues(alpha: 0.4)
                            : AppColors.slate800,
              ),
            ),
            child: Row(
              children: [
                _buildRankBadge(rank),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${p.matchesPlayed} partidas (${p.wins}G - ${losses >= 0 ? losses : 0}P)',
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
                        color: AppColors.indigo950,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.indigo500.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${p.wins} Vic',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.indigo400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.winRate.toStringAsFixed(0)}% efectividad',
                      style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRankBadge(int rank) {
    Color bg;
    Color border;
    IconData? icon;

    if (rank == 1) {
      bg = const Color(0xFFD97706);
      border = const Color(0xFFFDE68A);
      icon = Icons.emoji_events;
    } else if (rank == 2) {
      bg = const Color(0xFF475569);
      border = const Color(0xFFCBD5E1);
      icon = Icons.looks_two;
    } else if (rank == 3) {
      bg = const Color(0xFF92400E);
      border = const Color(0xFFFBBF24);
      icon = Icons.looks_3;
    } else {
      bg = AppColors.slate800;
      border = AppColors.slate700;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: icon != null && rank == 1
          ? const Icon(Icons.emoji_events, size: 16, color: Colors.white)
          : Text(
              '#$rank',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
    );
  }

  Widget _buildTeamsPodium(List<TeamStats> top3) {
    if (top3.length < 2) return const SizedBox.shrink();

    final t1 = top3[0];
    final t2 = top3[1];
    final t3 = top3.length > 2 ? top3[2] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.slate900,
            AppColors.slate900.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate800),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // #2 Plata
          _buildPodiumStep(
            rank: 2,
            name: t2.displayName,
            wins: t2.wins,
            color: const Color(0xFF94A3B8),
            height: 65,
          ),
          // #1 Oro
          _buildPodiumStep(
            rank: 1,
            name: t1.displayName,
            wins: t1.wins,
            color: AppColors.amber400,
            height: 85,
            isCenter: true,
          ),
          // #3 Bronce (si existe)
          if (t3 != null)
            _buildPodiumStep(
              rank: 3,
              name: t3.displayName,
              wins: t3.wins,
              color: const Color(0xFFD97706),
              height: 52,
            )
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildPlayersPodium(List<PlayerStats> top3) {
    if (top3.length < 2) return const SizedBox.shrink();

    final p1 = top3[0];
    final p2 = top3[1];
    final p3 = top3.length > 2 ? top3[2] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.slate900,
            AppColors.slate900.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate800),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // #2 Plata
          _buildPodiumStep(
            rank: 2,
            name: p2.name,
            wins: p2.wins,
            color: const Color(0xFF94A3B8),
            height: 65,
          ),
          // #1 Oro
          _buildPodiumStep(
            rank: 1,
            name: p1.name,
            wins: p1.wins,
            color: AppColors.amber400,
            height: 85,
            isCenter: true,
          ),
          // #3 Bronce
          if (p3 != null)
            _buildPodiumStep(
              rank: 3,
              name: p3.name,
              wins: p3.wins,
              color: const Color(0xFFD97706),
              height: 52,
            )
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildPodiumStep({
    required int rank,
    required String name,
    required int wins,
    required Color color,
    required double height,
    bool isCenter = false,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rank == 1 ? Icons.emoji_events : Icons.military_tech,
            size: isCenter ? 26 : 20,
            color: color,
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: TextStyle(
              fontSize: isCenter ? 12 : 11,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$wins Vic',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: isCenter ? 20 : 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool isTeams}) {
    final periodText = _selectedMonth != null
        ? _formatMonthYear(_selectedMonth!)
        : 'el período seleccionado';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTeams ? Icons.groups_outlined : Icons.person_search_outlined,
              size: 48,
              color: AppColors.slate600,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin partidas en $periodText',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'No se registraron juegos durante este mes.\nPuedes explorar otros meses o consultar el histórico general.',
              style: TextStyle(fontSize: 12, color: AppColors.slate400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_selectedMonth != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.history, size: 16, color: AppColors.emerald400),
                label: const Text(
                  'Ver Histórico Total',
                  style: TextStyle(color: AppColors.emerald400),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.emerald600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  setState(() => _selectedMonth = null);
                },
              ),
          ],
        ),
      ),
    );
  }
}

