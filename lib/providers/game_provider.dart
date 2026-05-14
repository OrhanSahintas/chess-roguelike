import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../models/game_state.dart';
import '../models/ability_pool.dart';
import '../abilities/abilities.dart';
import '../services/supabase_service.dart';

/// The core game state notifier. Manages the full match lifecycle:
/// move execution, draft triggers, ability management.
class GameNotifier extends StateNotifier<GameState?> {
  GameNotifier() : super(null);

  /// Start a new game.
  void newGame({required String gameId, String? whitePlayerId}) {
    state = GameState.newGame(gameId: gameId, whitePlayerId: whitePlayerId);
  }

  /// Join an existing game as black.
  void joinGame(String blackPlayerId) {
    if (state == null) return;
    state = state!.copyWith(
      blackPlayerId: blackPlayerId,
      status: GameStatus.playing,
    );
  }

  /// Load game state from Supabase JSON, preserving local abilities.
  void loadFromJson(Map<String, dynamic> json) {
    final remoteState = GameState.fromJson(json);
    state = remoteState.copyWith(
      whiteAbilities: state?.whiteAbilities ?? remoteState.whiteAbilities,
      blackAbilities: state?.blackAbilities ?? remoteState.blackAbilities,
    );
  }

  /// Get all legal moves for a position.
  List<Move> getLegalMoves(Position pos) {
    if (state == null) return [];
    return state!.getLegalMoves(pos);
  }

  /// Execute a move and handle draft triggers.
  void executeMove(Move move) {
    if (state == null) return;
    final currentState = state!;

    // Check if this is a special ability action
    // (Sniper's Nest snipe — rook doesn't change position)
    final piece = currentState.board.pieceAt(move.from);
    if (piece != null && piece.type == PieceType.rook) {
      // Check if this is a snipe (target is same row/col, rook stays)
      final sniperAbility = currentState.currentPlayerAbilities
          .whereType<SnipersNest>()
          .firstOrNull;
      if (sniperAbility != null && sniperAbility.isReady &&
          move.from != move.to &&
          (move.from.row == move.to.row || move.from.col == move.to.col)) {
        // This is a snipe!
        state = currentState.executeSnipe(piece, move.to);
        _checkDraft();
        return;
      }
    }

    // Normal move execution
    state = currentState.executeMove(move);

    // Sync to Supabase for multiplayer
    _syncState();

    // After executing, check if we need to trigger the draft
    _checkDraft();
  }

  /// Try to sync state to Supabase (no-op if offline).
  void _syncState() {
    if (state == null) return;
    try {
      SupabaseService.instance.updateBoardState(
        gameId: state!.gameId,
        state: state!,
      );
    } catch (_) {
      // Silently ignore sync failures (offline mode, no connection, etc.)
    }
  }

  /// Execute a Trojan Horse swap.
  void executeSwap(Piece knight, Piece pawn) {
    if (state == null) return;
    state = state!.executeSwap(knight, pawn);

    // Mark Trojan Horse as used
    final ability = state!.currentPlayerAbilities
        .whereType<TrojanHorse>()
        .firstOrNull;
    if (ability != null) {
      ability.useCount++;
    }

    _checkDraft();
  }

  /// Check if it's time for a draft (every 3 full turns).
  void _checkDraft() {
    if (state == null) return;

    // Draft triggers after both players have moved 3 times
    // (i.e., fullTurnCount is a multiple of 3, and we just finished a black move)
    if (state!.fullTurnCount > 0 &&
        state!.fullTurnCount % 3 == 0 &&
        state!.board.turn == PlayerColor.white) {
      // Trigger draft for both players
      state = state!.copyWith(status: GameStatus.drafting);
    }
  }

  /// Get draft choices for a player.
  List<Ability> getDraftChoices(PlayerColor player) {
    if (state == null) return [];
    final owned = player == PlayerColor.white
        ? state!.whiteAbilities
        : state!.blackAbilities;
    return AbilityPool.draftChoices(count: 3, alreadyOwned: owned);
  }

  /// Player selects an ability from the draft.
  void selectDraftAbility(PlayerColor player, Ability ability) {
    if (state == null) return;
    state = state!.addAbility(player, ability);

    // If both players have drafted (or in single-player/testing), resume
    // For now, auto-resume after selection
    state = state!.copyWith(status: GameStatus.playing);

    // Trigger CHARGE immediately if selected
    if (ability is Charge) {
      final chargeMoves = ability.onTurnStart(state!.board);
      for (final move in chargeMoves) {
        state = state!.executeMove(move);
      }
    }
  }

  /// Reset the game.
  void reset() {
    state = null;
  }
}

/// The game state provider.
final gameProvider = StateNotifierProvider<GameNotifier, GameState?>((ref) {
  return GameNotifier();
});

/// Derived provider: all legal moves for the currently selected position.
final selectedPositionProvider = StateProvider<Position?>((ref) => null);

final legalMovesProvider = Provider<List<Move>>((ref) {
  final pos = ref.watch(selectedPositionProvider);
  final game = ref.watch(gameProvider);
  if (pos == null || game == null) return [];
  return game.getLegalMoves(pos);
});

/// Derived provider: is the game in a drafting state?
final isDraftingProvider = Provider<bool>((ref) {
  final game = ref.watch(gameProvider);
  return game?.status == GameStatus.drafting;
});

/// Derived provider: current player's color (from local perspective).
/// This will be set when the player joins a game.
final myColorProvider = StateProvider<PlayerColor?>((ref) => null);
