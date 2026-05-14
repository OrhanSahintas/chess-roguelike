import 'ability.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';

/// Rooks can capture without moving. Once every 4 turns, a Rook can snipe
/// an enemy piece in its line of sight, removing it without leaving its square.
class SnipersNest extends Ability {
  @override
  String get id => 'snipers_nest';

  @override
  String get name => "Sniper's Nest";

  @override
  String get description =>
      'Your Rooks no longer need to move to capture. Once every 4 turns, '
      'a Rook can eliminate an enemy piece in its line of sight — without '
      'leaving its square.';

  @override
  String get iconName => 'gps_fixed';

  @override
  int get maxCooldown => 4;

  /// Returns additional "snipe" target positions for each rook.
  /// These are enemy pieces in the rook's line of sight.
  @override
  List<Position>? getAdditionalRawMoves(Board board, Piece piece) {
    if (!isReady) return null;
    if (piece.color != owner) return null;
    if (piece.type != PieceType.rook) return null;

    final targets = <Position>[];
    const directions = [
      [-1, 0], [1, 0], [0, -1], [0, 1], // Cardinal directions
    ];

    for (final dir in directions) {
      for (int i = 1; i < 8; i++) {
        final target = Position(
          piece.position.row + dir[0] * i,
          piece.position.col + dir[1] * i,
        );
        if (!target.isValid) break;

        final occupant = board.pieceAt(target);
        if (occupant == null) continue;

        if (occupant.color != owner && occupant.type != PieceType.king) {
          targets.add(target);
        }
        break; // Stop at first piece in this direction
      }
    }

    return targets.isNotEmpty ? targets : null;
  }

  /// The snipe is a "capture without moving" — we mark it as a special action
  /// so the engine knows the rook doesn't change position.
  bool isSnipeAction(Board board, Piece piece, Position target) {
    if (piece.type != PieceType.rook || piece.color != owner) return false;
    if (!isReady) return false;

    // Target must be in the same row or column
    if (piece.position.row != target.row && piece.position.col != target.col) {
      return false;
    }

    // Check line of sight is clear
    return _piecesBetween(board, piece.position, target);
  }
}

/// Check if there are pieces between two positions on the same rank/file.
bool _piecesBetween(Board board, Position from, Position to) {
  if (from.row == to.row) {
    final minCol = from.col < to.col ? from.col : to.col;
    final maxCol = from.col > to.col ? from.col : to.col;
    for (int col = minCol + 1; col < maxCol; col++) {
      if (board.pieceAt(Position(from.row, col)) != null) return false;
    }
  } else if (from.col == to.col) {
    final minRow = from.row < to.row ? from.row : to.row;
    final maxRow = from.row > to.row ? from.row : to.row;
    for (int row = minRow + 1; row < maxRow; row++) {
      if (board.pieceAt(Position(row, from.col)) != null) return false;
    }
  } else {
    return false; // Not aligned
  }
  return true;
}
