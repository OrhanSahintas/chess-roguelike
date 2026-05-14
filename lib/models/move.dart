import 'package:equatable/equatable.dart';
import 'position.dart';
import 'piece.dart';

/// Represents a single chess move.
class Move extends Equatable {
  final Position from;
  final Position to;

  /// The piece being moved.
  final Piece piece;

  /// The captured piece, if any.
  final Piece? capturedPiece;

  /// If this move is a promotion, what type the piece becomes.
  final PieceType? promotionType;

  /// Was this a castling move?
  final bool isCastling;

  /// Was this an en passant capture?
  final bool isEnPassant;

  const Move({
    required this.from,
    required this.to,
    required this.piece,
    this.capturedPiece,
    this.promotionType,
    this.isCastling = false,
    this.isEnPassant = false,
  });

  /// Algebraic notation (e.g., "e2-e4", "Bf1-c4").
  String get notation {
    final fromStr = from.algebraic;
    final toStr = to.algebraic;
    final captureStr = capturedPiece != null ? 'x' : '-';
    if (piece.type == PieceType.pawn) {
      return '$fromStr$captureStr$toStr${promotionType != null ? '=${promotionType!.symbol}' : ''}';
    }
    return '${piece.type.symbol}$fromStr$captureStr$toStr';
  }

  /// For JSON serialization.
  Map<String, dynamic> toJson() => {
        'fromRow': from.row,
        'fromCol': from.col,
        'toRow': to.row,
        'toCol': to.col,
        'promotionType': promotionType?.name,
        'capturedPieceId': capturedPiece?.id,
      };

  @override
  List<Object?> get props => [
        from,
        to,
        piece.id,
        capturedPiece?.id,
        promotionType,
        isCastling,
        isEnPassant,
      ];

  @override
  String toString() => notation;
}
