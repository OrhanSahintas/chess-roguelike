import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../models/game_state.dart';
import '../abilities/abilities.dart';
import '../services/supabase_service.dart';

/// The core game state notifier. Manages the full match lifecycle:
/// move execution, draft triggers, ability management.
class GameNotifier extends StateNotifier<GameState?> {
  GameNotifier() : super(null);

  /// Start a new game.
  void newGame({required String gameId, String? whitePlayerId, bool startPlaying = false}) {
    state = GameState.newGame(gameId: gameId, whitePlayerId: whitePlayerId);
    if (startPlaying) {
      state = state!.copyWith(status: GameStatus.playing);
    }
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

    // Check if this is a Sniper's Nest snipe
    final piece = currentState.board.pieceAt(move.from);
    if (piece != null && piece.type == PieceType.rook) {
      final sniperAbility = currentState.currentPlayerAbilities
          .whereType<SnipersNest>()
          .firstOrNull;
      if (sniperAbility != null &&
          sniperAbility.isReady &&
          move.from != move.to &&
          (move.from.row == move.to.row || move.from.col == move.to.col)) {
        state = currentState.executeSnipe(piece, move.to);
        _checkDraft();
        _syncState();
        return;
      }
    }

    // Normal move execution
    state = currentState.executeMove(move);

    // Check draft BEFORE syncing
    _checkDraft();

    // Sync to Supabase
    _syncState();
  }

  void _syncState() {
    if (state == null) return;
    try {
      SupabaseService.instance.updateBoardState(
        gameId: state!.gameId,
        state: state!,
      );
    } catch (_) {}
  }

  void executeSwap(Piece knight, Piece pawn) {
    if (state == null) return;
    state = state!.executeSwap(knight, pawn);

    final ability = state!.currentPlayerAbilities
        .whereType<TrojanHorse>()
        .firstOrNull;
    if (ability != null) {
      ability.useCount++;
    }

    _checkDraft();
    _syncState();
  }

  /// Check if it's time for a draft (every 3 full turns).
  void _checkDraft() {
    if (state == null) return;

    // Draft triggers after both players have moved 3 full turns
    // and it's white's turn (black just completed the 3rd full turn)
    if (state!.fullTurnCount > 0 &&
        state!.fullTurnCount % 3 == 0 &&
        state!.board.turn == PlayerColor.white &&
        state!.status != GameStatus.drafting) {
      // Trigger draft: white drafts first for this cycle
      state = state!.copyWith(
        status: GameStatus.drafting,
        whiteDrafted: false,
        blackDrafted: false,
        draftingPlayer: PlayerColor.white,
      );
    }
  }

  /// Player selects an ability from the draft.
  void selectDraftAbility(PlayerColor player, Ability ability) {
    if (state == null) return;
    state = state!.addAbility(player, ability);

    // Mark this player as drafted
    if (player == PlayerColor.white) {
      state = state!.copyWith(whiteDrafted: true);
    } else {
      state = state!.copyWith(blackDrafted: true);
    }

    // Check if both have drafted (or offline where one player does both)
    final bothDrafted = state!.whiteDrafted && state!.blackDrafted;

    if (bothDrafted) {
      // Both done — resume playing
      state = state!.copyWith(
        status: GameStatus.playing,
        draftingPlayer: null,
      );

      // Trigger CHARGE if selected
      if (ability is Charge) {
        final chargeMoves = ability.onTurnStart(state!.board);
        for (final move in chargeMoves) {
          state = state!.executeMove(move);
        }
      }
    } else {
      // Switch drafting player to the one who hasn't drafted yet
      state = state!.copyWith(
        draftingPlayer: state!.whiteDrafted ? PlayerColor.black : PlayerColor.white,
      );
    }

    _syncState();
  }

  /// Whether the given player currently needs to draft.
  bool needsDraft(PlayerColor player) {
    if (state == null) return false;
    return state!.needsDraft(player);
  }

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

/// Derived provider: is the game in a drafting state for the current player?
final isDraftingProvider = Provider<bool>((ref) {
  final game = ref.watch(gameProvider);
  final myColor = ref.watch(myColorProvider);
  final isOffline = ref.watch(isOfflineGameProvider);

  if (game == null || game.status != GameStatus.drafting) return false;

  if (isOffline) {
    // Offline: one person drafts for both, so always show draft until both done
    return !game.whiteDrafted || !game.blackDrafted;
  } else {
    // Online: show draft only if THIS player hasn't drafted yet
    if (myColor == null) return false;
    return game.needsDraft(myColor);
  }
});

/// Derived provider: current player's color (from local perspective).
final myColorProvider = StateProvider<PlayerColor?>((ref) => null);

/// Whether this is an offline (local) game where both sides can move.
final isOfflineGameProvider = StateProvider<bool>((ref) => false);
