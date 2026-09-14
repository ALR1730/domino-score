import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/game_state.dart';
import 'theme/app_colors.dart';
import 'widgets/header_widget.dart';
import 'widgets/team_card_widget.dart';
import 'widgets/rounds_history_widget.dart';
import 'widgets/reset_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.slate950,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const DominoApp());
}

class DominoApp extends StatefulWidget {
  const DominoApp({super.key});

  @override
  State<DominoApp> createState() => _DominoAppState();
}

class _DominoAppState extends State<DominoApp> {
  final GameState _gameState = GameState();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dominó Score',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.slate950,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.emerald500,
          surface: AppColors.slate900,
        ),
      ),
      home: DominoHomeScreen(gameState: _gameState),
    );
  }
}

class DominoHomeScreen extends StatelessWidget {
  final GameState gameState;

  const DominoHomeScreen({
    super.key,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: gameState,
          builder: (context, _) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Encabezado
                      HeaderWidget(gameState: gameState),

                      const SizedBox(height: 12),

                      // Marcadores de Equipos (2 columnas)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TeamCardWidget(
                              teamNumber: 1,
                              gameState: gameState,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TeamCardWidget(
                              teamNumber: 2,
                              gameState: gameState,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Historial de Rondas
                      RoundsHistoryWidget(gameState: gameState),

                      const SizedBox(height: 14),

                      // Botón Reiniciar Partida Completa
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => ResetConfirmDialog(
                                onConfirm: () => gameState.reiniciarPartida(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: AppColors.rose950.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.rose800.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: 15,
                                  color: AppColors.rose300,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Reiniciar Partida Completa',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.rose300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
