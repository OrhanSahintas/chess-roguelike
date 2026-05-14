import 'ability.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';
import '../models/move.dart';

/// Once per game, instead of making a normal move, swap the board positions
/// of any friendly Knight and any friendly Pawn.
class TrojanHorse extends Ability {
  @override
  String get id => 'trojan_horse';

  @override
  String get name => 'Trojan Horse';

  @override
  String get description =>
      'Once per game, instead of a normal move, swap the exact board positions '
      'of any friendly Knight and any friendly Pawn.';

  @override
  String get iconName => 'swap_horiz';

  @override
  int get maxUses => 1;

  @override
  Move? onSpecialAction(
    Board board,
    Piece actor, {
    required List<Piece> friendlyPieces,
  }) {
    if (actor.color != owner) return null;
    if (!isReady) return null;

    // The engine calls this and provides the two pieces to swap.
    // The actual selection happens in the UI layer.
    // Here we just validate and return the swap move.
    // This returns null to indicate "not a standard move" — the engine
    // handles the swap differently (see TrojanHorseSwap).
    return null;
  }
}

/// Represents the actual knight-pawn swap operation.
class TrojanHorseSwap {
  final Piece knight;
  final Piece pawn;

  const TrojanHorseSwap({required this.knight, required this.pawn});

  bool isValid(Board board, PlayerColor owner) {
    return knight.color == owner &&
        pawn.color == owner &&
        knight.type == PieceType.knight &&
        pawn.type == PieceType.pawn;
  }
}
