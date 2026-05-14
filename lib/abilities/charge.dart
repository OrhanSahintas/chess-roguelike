import 'ability.dart';
import '../models/board.dart';
import '../models/position.dart';
import '../models/move.dart';

/// Passive-active. Upon drafting, all your non-pawn pieces immediately
/// move one square towards the enemy. One-time effect.
class Charge extends Ability {
  @override
  String get id => 'charge';

  @override
  String get name => 'CHARGE';

  @override
  String get description =>
      'Upon drafting, ALL your open pieces immediately move one square '
      'towards the enemy. One-time effect — aggressive opener!';

  @override
  String get iconName => 'flash_on';

  /// Whether this ability has already fired (one-time use).
  bool _hasFired = false;

  @override
  List<Move> onTurnStart(Board board) {
    // Only fires once, right after being drafted
    if (_hasFired || owner == null) return [];
    _hasFired = true;

    final extraMoves = <Move>[];
    final direction = owner == PlayerColor.white ? -1 : 1; // White moves up (row-1), Black down (row+1)
    final pieces = board.piecesOf(owner!);

    // Sort pieces from farthest to nearest the enemy (so farthest move first,
    // avoiding blocking issues)
    pieces.sort((a, b) {
      if (owner == PlayerColor.white) {
        return a.position.row.compareTo(b.position.row); // Lower row = closer to enemy
      } else {
        return b.position.row.compareTo(a.position.row); // Higher row = closer to enemy
      }
    });

    for (final piece in pieces) {
      if (piece.type == PieceType.king) continue; // Don't charge the king

      final target = Position(piece.position.row + direction, piece.position.col);
      if (!target.isValid) continue;

      final occupant = board.pieceAt(target);
      if (occupant != null && occupant.color == owner) continue; // Blocked by friend

      extraMoves.add(Move(
        from: piece.position,
        to: target,
        piece: piece,
        capturedPiece: occupant?.color != owner ? occupant : null,
      ));
    }

    return extraMoves;
  }

  @override
  void reset() {
    super.reset();
    _hasFired = false;
  }
}
