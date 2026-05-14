import 'ability.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';

/// Any friendly piece that reaches the enemy backline can promote —
/// not just pawns. Promotion options: Queen, Rook, Bishop, Knight.
class CashGrab extends Ability {
  @override
  String get id => 'cash_grab';

  @override
  String get name => 'Cash Grab';

  @override
  String get description =>
      'Any friendly piece that reaches the enemy backline can promote to '
      'Queen, Rook, Bishop, or Knight — not just pawns.';

  @override
  String get iconName => 'monetization_on';

  @override
  List<PieceType>? onPromotionAvailable(Board board, Piece piece) {
    if (piece.color != owner) return null;

    // Check if this piece is on the enemy backrank
    final promotionRow = owner == PlayerColor.white ? 0 : 7;
    if (piece.position.row != promotionRow) return null;

    // Cash Grab lets anything promote from the back rank
    return [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight];
  }
}
