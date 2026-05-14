import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../models/game_state.dart';
import '../../providers/game_provider.dart';
import '../../services/supabase_service.dart';
import '../widgets/chess_board_widget.dart';
import 'draft_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String gameId;
  final bool isOffline;

  const GameScreen({super.key, required this.gameId, this.isOffline = false});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    // Initialize game if not already loaded
    final gameNotifier = ref.read(gameProvider.notifier);
    if (ref.read(gameProvider) == null) {
      gameNotifier.newGame(gameId: widget.gameId);
    }

    // Subscribe to realtime updates when playing online
    if (!widget.isOffline) {
      _subscribeToGame();
    }
  }

  void _subscribeToGame() {
    try {
      _channel = SupabaseService.instance.subscribeToGame(
        widget.gameId,
        (updatedState) {
          // Sync remote board state into our provider
          ref.read(gameProvider.notifier).loadFromJson(updatedState.toJson());
        },
      );
    } catch (e) {
      debugPrint('Realtime subscription failed: $e');
    }
  }

  /// Push current game state to Supabase after a move.
  void _syncToSupabase(GameState state) {
    if (widget.isOffline) return;
    try {
      SupabaseService.instance.updateBoardState(
        gameId: widget.gameId,
        state: state,
      );
    } catch (e) {
      debugPrint('Failed to sync game state: $e');
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final isDrafting = ref.watch(isDraftingProvider);

    if (gameState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      body: SafeArea(
        child: Stack(
          children: [
            // Main game board
            Column(
              children: [
                // Top bar
                _GameTopBar(gameState: gameState),
                // Chess board
                const Expanded(
                  child: Center(
                    child: ChessBoardWidget(),
                  ),
                ),
                // Bottom info
                _GameBottomBar(gameState: gameState),
              ],
            ),
            // Draft overlay
            if (isDrafting)
              DraftScreen(
                onAbilitySelected: (ability) {
                  final myColor = ref.read(myColorProvider);
                  if (myColor != null) {
                    ref
                        .read(gameProvider.notifier)
                        .selectDraftAbility(myColor, ability);
                    _syncToSupabase(ref.read(gameProvider)!);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _GameTopBar extends StatelessWidget {
  final GameState gameState;
  const _GameTopBar({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1F2833),
        border: Border(bottom: BorderSide(color: Color(0x2066FCF1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Opponent info
          _PlayerChip(
            name: gameState.blackPlayerId ?? 'Opponent',
            color: PlayerColor.black,
            isActive: gameState.board.turn == PlayerColor.black,
          ),
          // Turn indicator
          Column(
            children: [
              Text(
                'TURN ${gameState.fullTurnCount + 1}',
                style: const TextStyle(
                  color: Color(0xFF66FCF1),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          // You
          _PlayerChip(
            name: gameState.whitePlayerId ?? 'You',
            color: PlayerColor.white,
            isActive: gameState.board.turn == PlayerColor.white,
          ),
        ],
      ),
    );
  }
}

class _GameBottomBar extends StatelessWidget {
  final GameState gameState;
  const _GameBottomBar({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final abilities = gameState.currentPlayerAbilities;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF1F2833),
        border: Border(top: BorderSide(color: Color(0x2066FCF1))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (abilities.isNotEmpty) ...[
            const Text(
              'YOUR ABILITIES',
              style: TextStyle(
                color: Color(0xFFC77DFF),
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: abilities.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final ability = abilities[index];
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A3441),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ability.isReady
                            ? const Color(0xFF66FCF1)
                            : Colors.grey[700]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _iconForAbility(ability.id),
                          color: ability.isReady
                              ? const Color(0xFF66FCF1)
                              : Colors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ability.name,
                          style: TextStyle(
                            color:
                                ability.isReady ? Colors.white : Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else
            const Text(
              'No abilities yet — draft at turn 3!',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
        ],
      ),
    );
  }

  IconData _iconForAbility(String id) {
    return switch (id) {
      'second_chance' => Icons.replay,
      'cash_grab' => Icons.monetization_on,
      'charge' => Icons.flash_on,
      'martyrdom' => Icons.ac_unit,
      'trojan_horse' => Icons.swap_horiz,
      'snipers_nest' => Icons.gps_fixed,
      _ => Icons.auto_awesome,
    };
  }
}

class _PlayerChip extends StatelessWidget {
  final String name;
  final PlayerColor color;
  final bool isActive;

  const _PlayerChip({
    required this.name,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor =
        color == PlayerColor.white ? const Color(0xFF66FCF1) : const Color(0xFFFF0055);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:
            isActive ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? accentColor : Colors.grey[700]!,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 8)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? accentColor : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
