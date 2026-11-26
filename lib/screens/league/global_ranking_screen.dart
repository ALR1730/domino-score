import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/leaderboard_entry.dart';
import '../../services/leaderboard_service.dart';
import '../../services/league_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/league/month_filter_bar.dart';
import '../../widgets/league/ranking_controls.dart';
import '../../widgets/league/ranking_list_tile.dart';
import '../../widgets/league/ranking_podium.dart';

class GlobalRankingScreen extends StatefulWidget {
  final String? leagueId;
  final String? leagueName;
  final RankingSource initialSource;
  final LeagueService? leagueService;
  final LeaderboardService? leaderboardService;

  const GlobalRankingScreen({
    super.key,
    this.leagueId,
    this.leagueName,
    this.initialSource = RankingSource.server,
    this.leagueService,
    this.leaderboardService,
  });

  @override
  State<GlobalRankingScreen> createState() => _GlobalRankingScreenState();
}

class _GlobalRankingScreenState extends State<GlobalRankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final LeagueService _leagueService =
      widget.leagueService ?? LeagueService();
  late final LeaderboardService _leaderboardService =
      widget.leaderboardService ?? LeaderboardService();
  final TextEditingController _searchController = TextEditingController();

  late RankingSource _source;
  String _searchQuery = '';

  // null significa "Histórico Completo"
  DateTime? _selectedMonth;
  bool _isLoadingServer = false;
  bool _isFromServer = false;
  bool _hasLoadedServerOnce = false;
  List<TeamStats> _serverTeams = const [];
  List<PlayerStats> _serverPlayers = const [];
  List<DateTime> _serverAvailableMonths = const [];

  bool get _isLeagueSpecific => widget.leagueId != null;
  bool get _isServerMode =>
      _isLeagueSpecific || _source == RankingSource.server;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _source = _isLeagueSpecific ? RankingSource.server : widget.initialSource;
    _isLoadingServer = _isServerMode;

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    unawaited(_initAndLoad());
  }

  Future<void> _initAndLoad() async {
    await Future.wait([
      _leagueService.ensureLoaded(),
      _leaderboardService.ensureLoaded(),
    ]);
    if (!mounted) return;
    if (_isServerMode) {
      await _loadFromServer(pickDefaultMonth: true);
    }
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
    return _leagueService.getAvailableMonths(leagueId: widget.leagueId);
  }

  Future<void> _loadFromServer({bool pickDefaultMonth = false}) async {
    if (mounted && !_isLoadingServer) {
      setState(() => _isLoadingServer = true);
    }

    final tzOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    var result = await _leagueService.fetchRankings(
      leagueId: widget.leagueId,
      year: pickDefaultMonth ? null : _selectedMonth?.year,
      month: pickDefaultMonth ? null : _selectedMonth?.month,
      tzOffsetMinutes: tzOffsetMinutes,
    );

    if (!mounted) return;

    if (result != null) {
      if (pickDefaultMonth) {
        final defaultMonth = _resolveDefaultMonth(result.availableMonths);
        _selectedMonth = defaultMonth;
        if (defaultMonth != null) {
          final monthly = await _leagueService.fetchRankings(
            leagueId: widget.leagueId,
            year: defaultMonth.year,
            month: defaultMonth.month,
            tzOffsetMinutes: tzOffsetMinutes,
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
        _hasLoadedServerOnce = true;
      });
      return;
    }

    if (pickDefaultMonth) {
      _selectedMonth = _resolveDefaultMonth(
        _leagueService.getAvailableMonths(leagueId: widget.leagueId),
      );
    }
    setState(() {
      _isFromServer = false;
      _isLoadingServer = false;
      _hasLoadedServerOnce = true;
    });
  }

  Future<void> _syncAllAndRefresh() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sincronizando todas las ligas con el servidor...'),
      ),
    );
    final synced = await _leagueService.syncAllLeaguesWithServer();
    await _loadFromServer();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? '✅ Clasificaciones sincronizadas en el servidor.'
              : '⚠️ No se pudieron sincronizar todas las ligas.',
        ),
        backgroundColor: synced ? AppColors.emerald600 : AppColors.amber600,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSourceChanged(RankingSource next) {
    if (_source == next) return;
    setState(() => _source = next);
    if (next == RankingSource.server &&
        !_hasLoadedServerOnce &&
        !_isLoadingServer) {
      unawaited(_loadFromServer(pickDefaultMonth: true));
    }
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
    final title = _isLeagueSpecific
        ? 'Ranking: ${widget.leagueName}'
        : (_source == RankingSource.device
            ? 'Tabla de Clasificación'
            : 'Ranking General');
    final available = _availableMonths();
    final showMonthBar = _isServerMode;

    return Scaffold(
      backgroundColor: AppColors.slate950,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: AppColors.slate300,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              color: AppColors.amber400,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isServerMode && !_isLoadingServer)
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
          if (!_isLeagueSpecific)
            IconButton(
              icon: const Icon(
                Icons.cloud_upload_outlined,
                size: 20,
                color: AppColors.emerald400,
              ),
              tooltip: 'Sincronizar clasificaciones con el servidor',
              onPressed: () => unawaited(_syncAllAndRefresh()),
            ),
          if (_isServerMode)
            IconButton(
              icon: const Icon(
                Icons.refresh,
                size: 20,
                color: AppColors.slate300,
              ),
              tooltip: 'Actualizar del servidor',
              onPressed:
                  _isLoadingServer ? null : () => unawaited(_loadFromServer()),
            )
          else
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.rose300,
              ),
              tooltip: 'Reiniciar clasificación local',
              onPressed: () => showResetLeaderboardDialog(
                context,
                onConfirmReset: _leaderboardService.resetLeaderboard,
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(showMonthBar ? 102 : 52),
          child: Column(
            children: [
              if (showMonthBar)
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
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
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
        animation: Listenable.merge([_leagueService, _leaderboardService]),
        builder: (context, _) {
          return Column(
            children: [
              if (!_isLeagueSpecific)
                RankingSourceSelector(
                  selected: _source,
                  onChanged: _onSourceChanged,
                ),
              RankingSearchField(
                controller: _searchController,
                query: _searchQuery,
              ),
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

  List<TeamStats> _resolveTeams() {
    final List<TeamStats> base;
    if (!_isServerMode) {
      base = _leaderboardService.teamsRanked;
    } else if (_isFromServer) {
      base = _serverTeams;
    } else if (widget.leagueId != null) {
      base = _leagueService.getLeague(widget.leagueId!)?.getTeamsRankedForMonth(
                year: _selectedMonth?.year,
                month: _selectedMonth?.month,
              ) ??
          const [];
    } else {
      base = _leagueService.getGlobalTeamsRanked(
        year: _selectedMonth?.year,
        month: _selectedMonth?.month,
      );
    }

    if (_searchQuery.isEmpty) return base;
    return base.where((t) {
      final matchDisplay = t.displayName.toLowerCase().contains(_searchQuery);
      final matchMembers =
          t.members.any((m) => m.toLowerCase().contains(_searchQuery));
      return matchDisplay || matchMembers;
    }).toList();
  }

  List<PlayerStats> _resolvePlayers() {
    final List<PlayerStats> base;
    if (!_isServerMode) {
      base = _leaderboardService.playersRanked;
    } else if (_isFromServer) {
      base = _serverPlayers;
    } else if (widget.leagueId != null) {
      base =
          _leagueService.getLeague(widget.leagueId!)?.getPlayersRankedForMonth(
                    year: _selectedMonth?.year,
                    month: _selectedMonth?.month,
                  ) ??
              const [];
    } else {
      base = _leagueService.getGlobalPlayersRanked(
        year: _selectedMonth?.year,
        month: _selectedMonth?.month,
      );
    }

    if (_searchQuery.isEmpty) return base;
    return base
        .where((p) => p.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  Widget _buildTeamsTab() {
    if (_isServerMode && _isLoadingServer) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.emerald400),
      );
    }

    final teams = _resolveTeams();

    if (teams.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return Center(
          child: Text(
            'No se encontraron equipos con "$_searchQuery"',
            style: const TextStyle(color: AppColors.slate400, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        );
      }
      return RankingEmptyState(
        isTeams: true,
        periodText: _isServerMode ? _currentPeriodText() : 'este dispositivo',
        showResetButton: _isServerMode && _selectedMonth != null,
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
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.emerald400,
                ),
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
    if (_isServerMode && _isLoadingServer) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.emerald400),
      );
    }

    final players = _resolvePlayers();

    if (players.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return Center(
          child: Text(
            'No se encontraron jugadores con "$_searchQuery"',
            style: const TextStyle(color: AppColors.slate400, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        );
      }
      return RankingEmptyState(
        isTeams: false,
        periodText: _isServerMode ? _currentPeriodText() : 'este dispositivo',
        showResetButton: _isServerMode && _selectedMonth != null,
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
