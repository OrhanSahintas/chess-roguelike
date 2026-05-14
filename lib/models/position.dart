/// Core data types for the chess roguelike.
/// Position is (row, col) where row 0 = top of board (Black's starting side),
/// row 7 = bottom (White's starting side) when viewed from White's perspective.
library chess_core;

import 'package:equatable/equatable.dart';

/// Chess piece types.
enum PieceType {
  king,
  queen,
  rook,
  bishop,
  knight,
  pawn;

  /// Standard display character: ♔♕♖♗♘♙
  String get symbol {
    return switch (this) {
      PieceType.king => 'K',
      PieceType.queen => 'Q',
      PieceType.rook => 'R',
      PieceType.bishop => 'B',
      PieceType.knight => 'N',
      PieceType.pawn => 'P',
    };
  }

  /// Material value for basic evaluation.
  int get value {
    return switch (this) {
      PieceType.king => 0,
      PieceType.queen => 9,
      PieceType.rook => 5,
      PieceType.bishop => 3,
      PieceType.knight => 3,
      PieceType.pawn => 1,
    };
  }
}

/// Player colors.
enum PlayerColor {
  white,
  black;

  PlayerColor get opponent => this == white ? black : white;

  /// Direction pawns move: White moves down (row +1), Black moves up (row -1).
  int get pawnDirection => this == white ? 1 : -1;

  /// Row where this color's pawns promote.
  int get promotionRow => this == white ? 0 : 7;

  /// Row where this color's pieces start (back rank).
  int get backRank => this == white ? 7 : 0;

  /// Row where this color's pawns start.
  int get pawnStartRank => this == white ? 6 : 1;
}

/// A position on the 8x8 board. Immutable.
class Position extends Equatable {
  final int row;
  final int col;

  const Position(this.row, this.col);

  /// Whether this position is within the 8x8 board.
  bool get isValid => row >= 0 && row < 8 && col >= 0 && col < 8;

  /// Algebraic notation (e.g., Position(7, 0) → "a1").
  String get algebraic {
    final file = String.fromCharCode(97 + col); // 'a' through 'h'
    final rank = (8 - row).toString();
    return '$file$rank';
  }

  factory Position.fromAlgebraic(String notation) {
    final file = notation.codeUnitAt(0) - 97; // 'a' = 0
    final rank = 8 - int.parse(notation[1]); // '1' → 7, '8' → 0
    return Position(rank, file);
  }

  Position operator +(Position other) => Position(row + other.row, col + other.col);
  Position operator -(Position other) => Position(row - other.row, col - other.col);
  Position operator *(int scalar) => Position(row * scalar, col * scalar);

  /// All positions one king-move away.
  List<Position> get adjacent {
    return [
      Position(row - 1, col - 1), Position(row - 1, col), Position(row - 1, col + 1),
      Position(row, col - 1),                           Position(row, col + 1),
      Position(row + 1, col - 1), Position(row + 1, col), Position(row + 1, col + 1),
    ].where((p) => p.isValid).toList();
  }

  @override
  List<Object?> get props => [row, col];

  @override
  String toString() => algebraic;
}
