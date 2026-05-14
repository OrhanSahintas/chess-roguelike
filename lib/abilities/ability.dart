import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';
import '../models/move.dart';

/// When an ability triggers during gameplay.
enum AbilityTrigger {
  /// Fires before any move is executed. Can modify or block the move.
  onBeforeMove,

  /// Fires after a move is fully executed.
  onAfterMove,

  /// Fires when a piece is captured. Returns whether to modify the capture.
  onPieceCaptured,

  /// Fires when a piece reaches the promotion rank.
  onPromotionAvailable,

  /// Fires at the start of a player's turn. Can add extra moves.
  onTurnStart,

  /// Fires once per game (or on cooldown). For active-use abilities.
  onSpecialAction,
}

/// Result of an ability hook intercepting a capture.
class CaptureModification {
  /// If true, the captured piece is revived instead.
  final bool revive;

  /// Where to revive the piece.
  final Position? revivePosition;

  /// If true, the capturing piece is frozen for [freezeTurns].
  final bool freezeCapturer;

  /// How many turns the capturer is frozen.
  final int freezeTurns;

  const CaptureModification({
    this.revive = false,
    this.revivePosition,
    this.freezeCapturer = false,
    this.freezeTurns = 1,
  });
}

/// Result of an ability modifying a move.
class MoveModification {
  /// If true, the move is blocked entirely.
  final bool blocked;

  /// An alternative target position the piece must move to instead.
  final Position? forcedTarget;

  const MoveModification({this.blocked = false, this.forcedTarget});
}

/// Base class for all draftable abilities (Perks/Augments).
/// Subclasses override only the hooks they need.
abstract class Ability {
  /// Unique identifier.
  String get id;

  /// Display name shown on the draft card.
  String get name;

  /// Flavor/mechanics description for the draft card.
  String get description;

  /// Icon identifier (uses Material Icons or custom asset path).
  String get iconName;

  /// Which player owns this ability.
  PlayerColor? owner;

  /// Cooldown remaining (in turns). 0 = ready to use.
  int cooldownRemaining = 0;

  /// Max cooldown between uses.
  int get maxCooldown => 0;

  /// How many times this ability has been used this game.
  int useCount = 0;

  /// Maximum uses per game (0 = unlimited).
  int get maxUses => 0;

  /// Whether this ability is ready to activate (no cooldown, uses remaining).
  bool get isReady => cooldownRemaining <= 0 && (maxUses == 0 || useCount < maxUses);

  // ─── Hook Methods (override as needed) ──────────────────────────────────

  /// Called at the start of the owner's turn. Return extra moves to inject.
  List<Move> onTurnStart(Board board) => [];

  /// Called before a move is executed. Return a modification or null.
  MoveModification? onBeforeMove(Board board, Move move) => null;

  /// Called after a move is executed.
  void onAfterMove(Board board, BoardResult result) {}

  /// Called when a piece owned by the ability owner is captured.
  /// Return a modification or null for no change.
  CaptureModification? onPieceCaptured(Board board, Piece captured, Piece capturer, Position capturePos) => null;

  /// Called when a piece reaches the promotion rank. Return allowed types.
  List<PieceType>? onPromotionAvailable(Board board, Piece piece) => null;

  /// Called when the player activates a special ability. Return a move or null.
  Move? onSpecialAction(Board board, Piece actor, {required List<Piece> friendlyPieces}) => null;

  /// Provides additional raw moves for a piece type (for Sniper's Nest).
  List<Position>? getAdditionalRawMoves(Board board, Piece piece) => null;

  /// Reset between games.
  void reset() {
    cooldownRemaining = 0;
    useCount = 0;
  }

  /// Decrement cooldown by one turn.
  void tickCooldown() {
    if (cooldownRemaining > 0) cooldownRemaining--;
  }
}
