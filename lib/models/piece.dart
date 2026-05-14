import 'package:equatable/equatable.dart';
import 'position.dart';

/// An immutable chess piece on the board.
class Piece extends Equatable {
  final PieceType type;
  final PlayerColor color;
  final Position position;
  final bool hasMoved;

  /// If this piece is frozen (Martyrdom ability), it cannot move this turn.
  final bool isFrozen;

  /// Tracks how many turns this piece has been unable to move.
  final int frozenTurnsRemaining;

  /// Unique identifier for this piece instance (for ability tracking).
  final int id;

  static int _nextId = 0;

  Piece({
    required this.type,
    required this.color,
    required this.position,
    this.hasMoved = false,
    this.isFrozen = false,
    this.frozenTurnsRemaining = 0,
    int? id,
  }) : id = id ?? _nextId++;

  /// Reset the global ID counter (used when starting a new game).
  static void resetIdCounter() {
    _nextId = 0;
  }

  /// Unicode symbol with color: ♔ ♕ ♖ ♗ ♘ ♙ / ♚ ♛ ♜ ♝ ♞ ♟
  String get unicode {
    const whiteSymbols = {
      PieceType.king: '♔',
      PieceType.queen: '♕',
      PieceType.rook: '♖',
      PieceType.bishop: '♗',
      PieceType.knight: '♘',
      PieceType.pawn: '♙',
    };
    const blackSymbols = {
      PieceType.king: '♚',
      PieceType.queen: '♛',
      PieceType.rook: '♜',
      PieceType.bishop: '♝',
      PieceType.knight: '♞',
      PieceType.pawn: '♟',
    };
    return color == PlayerColor.white ? whiteSymbols[type]! : blackSymbols[type]!;
  }

  /// Create a copy with updated fields.
  Piece copyWith({
    PieceType? type,
    PlayerColor? color,
    Position? position,
    bool? hasMoved,
    bool? isFrozen,
    int? frozenTurnsRemaining,
  }) {
    return Piece(
      type: type ?? this.type,
      color: color ?? this.color,
      position: position ?? this.position,
      hasMoved: hasMoved ?? this.hasMoved,
      isFrozen: isFrozen ?? this.isFrozen,
      frozenTurnsRemaining: frozenTurnsRemaining ?? this.frozenTurnsRemaining,
      id: id,
    );
  }

  /// For JSON serialization (Supabase JSONB column).
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'color': color.name,
        'row': position.row,
        'col': position.col,
        'hasMoved': hasMoved,
        'isFrozen': isFrozen,
        'frozenTurnsRemaining': frozenTurnsRemaining,
      };

  factory Piece.fromJson(Map<String, dynamic> json) {
    return Piece(
      id: json['id'] as int,
      type: PieceType.values.byName(json['type'] as String),
      color: PlayerColor.values.byName(json['color'] as String),
      position: Position(json['row'] as int, json['col'] as int),
      hasMoved: json['hasMoved'] as bool? ?? false,
      isFrozen: json['isFrozen'] as bool? ?? false,
      frozenTurnsRemaining: json['frozenTurnsRemaining'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        color,
        position,
        hasMoved,
        isFrozen,
        frozenTurnsRemaining,
      ];
}
