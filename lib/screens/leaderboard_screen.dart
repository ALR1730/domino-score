import 'package:flutter/material.dart';

import '../services/leaderboard_service.dart';
import '../services/league_service.dart';
import '../widgets/league/ranking_controls.dart';
import 'league/global_ranking_screen.dart';

export '../widgets/league/ranking_controls.dart' show RankingSource;

class LeaderboardScreen extends StatelessWidget {
  final LeagueService? leagueService;
  final LeaderboardService? leaderboardService;

  const LeaderboardScreen({
    super.key,
    this.leagueService,
    this.leaderboardService,
  });

  @override
  Widget build(BuildContext context) {
    return GlobalRankingScreen(
      initialSource: RankingSource.device,
      leagueService: leagueService,
      leaderboardService: leaderboardService,
    );
  }
}
