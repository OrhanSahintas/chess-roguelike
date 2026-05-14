import 'ability.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';

/// When one of your pieces is captured, the enemy piece that captured it
/// is frozen and cannot move for its next turn.
class Martyrdom extends Ability {
  @override
  String get id => 'martyrdom';

  @override
  String get name => 'Martyrdom';

  @override
  String get description =>
      'When your piece is captured, the enemy piece that took it is FROZEN '
      'and cannot move for its next turn.';

  @override
  String get iconName => 'ac_unit';

  @override
  CaptureModification? onPieceCaptured(
    Board board,
    Piece captured,
    Piece capturer,
    Position capturePos,
  ) {
    if (captured.color != owner) return null;
    if (capturer.type == PieceType.king) return null; // Can't freeze a king

    return const CaptureModification(freezeCapturer: true, freezeTurns: 1);
  }
}
