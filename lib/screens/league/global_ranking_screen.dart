import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/leaderboard_entry.dart';
import '../../services/api_client.dart';
import '../../services/league_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/league/month_filter_bar.dart';
import '../../widgets/league/ranking_list_tile.dart';
import '../../widgets/league/ranking_podium.dart';

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
  bool _isLoadingServer = true;
  bool _isFromServer = false;
  List<TeamStats> _serverTeams = const [];
  List<PlayerStats> _serverPlayers = const [];
  List<DateTime> _serverAvailableMonths = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    unawaited(_initAndLoad());
  }

  Future<void> _initAndLoad() async {
    if (!_service.isLoaded) {
      await _service.ensureLoaded();
    }
    await _loadFromServer(pickDefaultMonth: true);
  }

  DateTime? _resolveDefaultMonth(List<DateTime> available) {
    final now = DateTime.now();
    if (available.any((d) => d.year == now.year && d.month == now.month)) {
      return DateTime(now.year, now.month);
    }
    if (available.isNotEmpty) {
      return available.first;
    }
    return null;
  }

  List<DateTime> _availableMonths() {
    if (_isFromServer && _serverAvailableMonths.isNotEmpty) {
      return _serverAvailableMonths;
    }
    return _service.getAvailableMonths(leagueId: widget.leagueId);
  }

  Future<ServerRankingResult?> _fetchRankingPeriod({int? year, int? month}) {
    final tzOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    if (widget.leagueId != null) {
      return ApiClient().fetchLeagueRankings(
        widget.leagueId!,
        year: year,
        month: month,
        tzOffsetMinutes: tzOffsetMinutes,
      );
    }
    return ApiClient().fetchGlobalRankings(
      year: year,
      month: month,
      tzOffsetMinutes: tzOffsetMinutes,
    );
  }

  Future<void> _loadFromServer({bool pickDefaultMonth = false}) async {
    if (mounted && !_isLoadingServer) {
      setState(() => _isLoadingServer = true);
    }

    var result = await _fetchRankingPeriod(
      year: pickDefaultMonth ? null : _selectedMonth?.year,
      month: pickDefaultMonth ? null : _selectedMonth?.month,
    );

    if (!mounted) return;

    if (result != null) {
      if (pickDefaultMonth) {
        final defaultMonth = _resolveDefaultMonth(result.availableMonths);
        _selectedMonth = defaultMonth;
        if (defaultMonth != null) {
          final monthly = await _fetchRankingPeriod(
            year: defaultMonth.year,
            month: defaultMonth.month,
          );
          if (!mounted) return;
          if (monthly != null) {
            result = monthly;
          }
        }
      }

      setState(() {
        _serverTeams = result!.teams;
        _serverPlayers = result.players;
        _serverAvailableMonths = result.availableMonths;
        _isFromServer = true;
        _isLoadingServer = false;
      });
      return;
    }

    if (pickDefaultMonth) {
      _selectedMonth = _resolveDefaultMonth(
        _service.getAvailableMonths(leagueId: widget.leagueId),
      );
    }
    setState(() {
      _isFromServer = false;
      _isLoadingServer = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _selectMonth(DateTime? month) {
    setState(() => _selectedMonth = month);
    unawaited(_loadFromServer());
  }

  void _prevMonth() {
    final available = _availableMonths();
    if (available.isEmpty) return;

    if (_selectedMonth == null) {
      _selectMonth(available.first);
      return;
    }

    final currentIndex = available.indexWhere(
      (d) => d.year == _selectedMonth!.year && d.month == _selectedMonth!.month,
    );

    if (currentIndex >= 0 && currentIndex < available.length - 1) {
      _selectMonth(available[currentIndex + 1]);
    }
  }

  void _nextMonth() {
    final available = _availableMonths();
    if (available.isEmpty || _selectedMonth == null) return;

    final currentIndex = available.indexWhere(
      (d) => d.year == _selectedMonth!.year && d.month == _selectedMonth!.month,
    );

    if (currentIndex > 0) {
      _selectMonth(available[currentIndex - 1]);
    } else if (currentIndex == 0) {
      _selectMonth(null);
    }
  }

  String _currentPeriodText() => _selectedMonth != null
      ? formatMonthYear(_selectedMonth!)
      : 'el período seleccionado';

  @override
  Widget build(BuildContext context) {
    final title = widget.leagueName != null
        ? 'Ranking: ${widget.leagueName}'
        : 'Ranking General';
    final available = _availableMonths();

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
            const Icon(Icons.emoji_events_outlined,
                color: AppColors.amber400, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!_isLoadingServer)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (_isFromServer
                          ? AppColors.emerald500
                          : AppColors.amber600)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (_isFromServer
                            ? AppColors.emerald500
                            : AppColors.amber600)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _isFromServer ? 'Servidor' : 'Solo local',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isFromServer
                        ? AppColors.emerald300
                        : AppColors.amber300,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.refresh, size: 20, color: AppColors.slate300),
            tooltip: 'Actualizar del servidor',
            onPressed:
                _isLoadingServer ? null : () => unawaited(_loadFromServer()),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(102),
          child: Column(
            children: [
              MonthFilterBar(
                selectedMonth: _selectedMonth,
                availableMonths: available,
                onPrevMonth: _prevMonth,
                onNextMonth: _nextMonth,
                onOpenPicker: () => showMonthPickerSheet(
                  context,
                  selectedMonth: _selectedMonth,
                  availableMonths: available,
                  onSelectMonth: _selectMonth,
                ),
              ),
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
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
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

  Widget _buildTeamsTab() {
    if (_isLoadingServer) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.emerald400),
      );
    }

    final teams = _isFromServer
        ? _serverTeams
        : (widget.leagueId != null
            ? (_service.getLeague(widget.leagueId!)?.getTeamsRankedForMonth(
                      year: _selectedMonth?.year,
                      month: _selectedMonth?.month,
                    ) ??
                [])
            : _service.getGlobalTeamsRanked(
                year: _selectedMonth?.year,
                month: _selectedMonth?.month,
              ));

    if (teams.isEmpty) {
      return RankingEmptyState(
        isTeams: true,
        periodText: _currentPeriodText(),
        showResetButton: _selectedMonth != null,
        onResetToAllTime: () => _selectMonth(null),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: teams.length + 2,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return RankingPodium(
            entries: teams
                .take(3)
                .map((t) => PodiumEntry(name: t.displayName, wins: t.wins))
                .toList(),
          );
        }
        if (i == 1) return const SizedBox(height: 12);

        final t = teams[i - 2];
        final rank = i - 1;
        final losses = t.matchesPlayed - t.wins;

        return RankingListTile(
          key: ValueKey('rank_team_${t.key}'),
          rank: rank,
          title: t.displayName,
          subtitle: Wrap(
            spacing: 8,
            children: [
              Text(
                '${t.matchesPlayed} PJ (${t.wins}G - ${losses >= 0 ? losses : 0}P)',
                style: const TextStyle(fontSize: 11, color: AppColors.slate400),
              ),
              Text(
                '•  ${t.totalPoints} pts',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.emerald400),
              ),
            ],
          ),
          wins: t.wins,
          winRate: t.winRate,
          badgeBgColor: AppColors.emerald950,
          badgeBorderColor: AppColors.emerald500,
          badgeTextColor: AppColors.emerald400,
        );
      },
    );
  }

  Widget _buildPlayersTab() {
    if (_isLoadingServer) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.emerald400),
      );
    }

    final players = _isFromServer
        ? _serverPlayers
        : (widget.leagueId != null
            ? (_service.getLeague(widget.leagueId!)?.getPlayersRankedForMonth(
                      year: _selectedMonth?.year,
                      month: _selectedMonth?.month,
                    ) ??
                [])
            : _service.getGlobalPlayersRanked(
                year: _selectedMonth?.year,
                month: _selectedMonth?.month,
              ));

    if (players.isEmpty) {
      return RankingEmptyState(
        isTeams: false,
        periodText: _currentPeriodText(),
        showResetButton: _selectedMonth != null,
        onResetToAllTime: () => _selectMonth(null),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: players.length + 2,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return RankingPodium(
            entries: players
                .take(3)
                .map((p) => PodiumEntry(name: p.name, wins: p.wins))
                .toList(),
          );
        }
        if (i == 1) return const SizedBox(height: 12);

        final p = players[i - 2];
        final rank = i - 1;
        final losses = p.matchesPlayed - p.wins;

        return RankingListTile(
          key: ValueKey('rank_player_${p.key}'),
          rank: rank,
          title: p.name,
          subtitle: Text(
            '${p.matchesPlayed} partidas (${p.wins}G - ${losses >= 0 ? losses : 0}P)',
            style: const TextStyle(fontSize: 11, color: AppColors.slate400),
          ),
          wins: p.wins,
          winRate: p.winRate,
          badgeBgColor: AppColors.indigo950,
          badgeBorderColor: AppColors.indigo500,
          badgeTextColor: AppColors.indigo400,
        );
      },
    );
  }
}
