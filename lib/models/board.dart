import 'package:equatable/equatable.dart';
import 'position.dart';
import 'piece.dart';
import 'move.dart';

/// A board state result after executing a move.
class BoardResult extends Equatable {
  final List<List<Piece?>> grid;
  final Move lastMove;
  final bool isCheck;
  final bool isCheckmate;
  final bool isStalemate;
  final Piece? capturedPiece;
  final bool enPassantTargetSet;

  const BoardResult({
    required this.grid,
    required this.lastMove,
    this.isCheck = false,
    this.isCheckmate = false,
    this.isStalemate = false,
    this.capturedPiece,
    this.enPassantTargetSet = false,
  });

  @override
  List<Object?> get props => [grid, lastMove, isCheck, isCheckmate, isStalemate];
}

/// Custom 8x8 chess board with full move generation and validation.
/// Does NOT use any third-party chess engine — all rules are implemented
/// here so we can modify them for ability interactions.
class Board {
  /// 8x8 grid: grid[row][col], row 0 = top (Black's back rank), row 7 = bottom (White's back rank).
  final List<List<Piece?>> grid;

  /// The color whose turn it is next.
  final PlayerColor turn;

  /// The position of the en passant target square, if applicable.
  final Position? enPassantTarget;

  /// Half-move clock (for 50-move rule).
  final int halfMoveClock;

  /// Full move number.
  final int fullMoveNumber;

  /// Castling rights: [whiteCanCastleKingside, whiteCanCastleQueenside,
  /// blackCanCastleKingside, blackCanCastleQueenside].
  final List<bool> castlingRights;

  /// Reference to the last move made (for en passant validation).
  final Move? lastMove;

  const Board({
    required this.grid,
    this.turn = PlayerColor.white,
    this.enPassantTarget,
    this.halfMoveClock = 0,
    this.fullMoveNumber = 1,
    this.castlingRights = const [true, true, true, true],
    this.lastMove,
  });

  // ─── Factory: Initial Position ───────────────────────────────────────────

  /// Creates the standard starting position.
  factory Board.initial() {
    Piece.resetIdCounter();
    final grid = List.generate(8, (_) => List<Piece?>.filled(8, null));
    final backRank = [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.queen,
      PieceType.king,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];

    for (int col = 0; col < 8; col++) {
      // Black pieces at row 0
      grid[0][col] = Piece(
        type: backRank[col],
        color: PlayerColor.black,
        position: Position(0, col),
      );
      // Black pawns at row 1
      grid[1][col] = Piece(
        type: PieceType.pawn,
        color: PlayerColor.black,
        position: Position(1, col),
      );
      // White pawns at row 6
      grid[6][col] = Piece(
        type: PieceType.pawn,
        color: PlayerColor.white,
        position: Position(6, col),
      );
      // White pieces at row 7
      grid[7][col] = Piece(
        type: backRank[col],
        color: PlayerColor.white,
        position: Position(7, col),
      );
    }
    return Board(grid: grid);
  }

  // ─── Grid Access ─────────────────────────────────────────────────────────

  /// Returns the piece at [pos], or null if empty.
  Piece? pieceAt(Position pos) {
    if (!pos.isValid) return null;
    return grid[pos.row][pos.col];
  }

  /// Returns all pieces of a given color.
  List<Piece> piecesOf(PlayerColor color) {
    final pieces = <Piece>[];
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final p = grid[row][col];
        if (p != null && p.color == color) pieces.add(p);
      }
    }
    return pieces;
  }

  /// Returns the king of [color].
  Piece findKing(PlayerColor color) {
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final p = grid[row][col];
        if (p != null && p.type == PieceType.king && p.color == color) {
          return p;
        }
      }
    }
    throw StateError('King not found for $color');
  }

  // ─── Move Generation ─────────────────────────────────────────────────────

  /// Returns all raw moves for the piece at [pos], WITHOUT checking for
  /// leaving own king in check. Abilities override this for custom rules.
  List<Position> getRawMoves(Position pos) {
    final piece = pieceAt(pos);
    if (piece == null) return [];
    if (piece.isFrozen && piece.frozenTurnsRemaining > 0) return [];

    return switch (piece.type) {
      PieceType.pawn => _pawnMoves(piece),
      PieceType.knight => _knightMoves(piece),
      PieceType.bishop => _slidingMoves(piece, _bishopDirections),
      PieceType.rook => _slidingMoves(piece, _rookDirections),
      PieceType.queen => _slidingMoves(piece, [..._bishopDirections, ..._rookDirections]),
      PieceType.king => _kingMoves(piece),
    };
  }

  /// Returns legal moves (filtered to avoid leaving own king in check).
  List<Move> getLegalMoves(Position pos) {
    final piece = pieceAt(pos);
    if (piece == null || piece.color != turn) return [];

    final rawPositions = getRawMoves(pos);
    final legalMoves = <Move>[];

    for (final target in rawPositions) {
      final captured = pieceAt(target);
      // Can't capture own pieces
      if (captured != null && captured.color == piece.color) continue;

      // Simulate the move
      final simBoard = _simulateMove(pos, target, piece);
      if (!simBoard.isInCheck(piece.color)) {
        legalMoves.add(Move(
          from: pos,
          to: target,
          piece: piece,
          capturedPiece: captured,
          promotionType: _isPromotion(piece, target) ? PieceType.queen : null,
          isEnPassant: target == enPassantTarget && piece.type == PieceType.pawn,
        ));
      }
    }

    // Castling
    if (piece.type == PieceType.king) {
      legalMoves.addAll(_castlingMoves(piece));
    }

    return legalMoves;
  }

  /// Returns all legal moves for [color].
  List<Move> allLegalMoves(PlayerColor color) {
    final moves = <Move>[];
    for (final piece in piecesOf(color)) {
      moves.addAll(getLegalMoves(piece.position));
    }
    return moves;
  }

  // ─── Move Execution ──────────────────────────────────────────────────────

  /// Execute a move and return the new Board state.
  BoardResult executeMove(Move move) {
    final newGrid = _copyGrid();
    final piece = pieceAt(move.from)!;
    Piece? capturedPiece;

    // Handle en passant capture
    if (move.isEnPassant && enPassantTarget != null) {
      final capturedRow = piece.color == PlayerColor.white
          ? enPassantTarget!.row + 1
          : enPassantTarget!.row - 1;
      capturedPiece = newGrid[capturedRow][enPassantTarget!.col];
      newGrid[capturedRow][enPassantTarget!.col] = null;
    } else {
      capturedPiece = newGrid[move.to.row][move.to.col];
    }

    // Move piece
    newGrid[move.from.row][move.from.col] = null;

    final newPiece = piece.copyWith(
      position: move.to,
      hasMoved: true,
      type: move.promotionType ?? piece.type,
    );
    newGrid[move.to.row][move.to.col] = newPiece;

    // Handle castling rook movement
    Move? executedMove = move;
    if (move.isCastling) {
      executedMove = _executeCastling(newGrid, move);
    }

    // Update castling rights
    final newCastlingRights = _updateCastlingRights(move, List.from(castlingRights));

    // Set en passant target
    Position? newEnPassant;
    if (piece.type == PieceType.pawn &&
        (move.from.row - move.to.row).abs() == 2) {
      newEnPassant = Position(
        (move.from.row + move.to.row) ~/ 2,
        move.from.col,
      );
    }

    // Clock updates
    final newHalfMove = (piece.type == PieceType.pawn || capturedPiece != null)
        ? 0
        : halfMoveClock + 1;
    final newFullMove =
        turn == PlayerColor.black ? fullMoveNumber + 1 : fullMoveNumber;

    final nextBoard = Board(
      grid: newGrid,
      turn: turn.opponent,
      enPassantTarget: newEnPassant,
      halfMoveClock: newHalfMove,
      fullMoveNumber: newFullMove,
      castlingRights: newCastlingRights,
      lastMove: executedMove,
    );

    final isCheck = nextBoard.isInCheck(turn.opponent);
    final hasLegalMoves = nextBoard.allLegalMoves(turn.opponent).isNotEmpty;

    return BoardResult(
      grid: newGrid,
      lastMove: executedMove,
      isCheck: isCheck,
      isCheckmate: isCheck && !hasLegalMoves,
      isStalemate: !isCheck && !hasLegalMoves,
      capturedPiece: capturedPiece,
      enPassantTargetSet: newEnPassant != null,
    );
  }

  // ─── Check Detection ─────────────────────────────────────────────────────

  /// Is [color]'s king in check?
  bool isInCheck(PlayerColor color) {
    final king = findKing(color);
    final opponentColor = color.opponent;

    for (final attacker in piecesOf(opponentColor)) {
      final rawMoves = getRawMoves(attacker.position);
      if (rawMoves.any((pos) => pos == king.position)) {
        return true;
      }
    }
    return false;
  }

  // ─── Private Helpers ─────────────────────────────────────────────────────

  List<List<Piece?>> _copyGrid() {
    return List.generate(
        8, (row) => List.generate(8, (col) => grid[row][col]));
  }

  /// Simulate a move on a copy of the board (for legality checking).
  Board _simulateMove(Position from, Position to, Piece piece) {
    final newGrid = _copyGrid();
    newGrid[from.row][from.col] = null;
    newGrid[to.row][to.col] = piece.copyWith(position: to);
    return Board(
      grid: newGrid,
      turn: turn,
      castlingRights: List.from(castlingRights),
      enPassantTarget: enPassantTarget,
    );
  }

  bool _isPromotion(Piece piece, Position to) {
    if (piece.type != PieceType.pawn) return false;
    return to.row == piece.color.promotionRow;
  }

  // ─── Piece-Specific Move Generators ──────────────────────────────────────

  static const _knightOffsets = [
    [-2, -1], [-2, 1], [-1, -2], [-1, 2],
    [1, -2], [1, 2], [2, -1], [2, 1],
  ];

  static const _bishopDirections = [
    [-1, -1], [-1, 1], [1, -1], [1, 1],
  ];

  static const _rookDirections = [
    [-1, 0], [1, 0], [0, -1], [0, 1],
  ];

  List<Position> _pawnMoves(Piece pawn) {
    final moves = <Position>[];
    final dir = pawn.color.pawnDirection;
    final startRow = pawn.color.pawnStartRank;

    // Forward one
    final one = Position(pawn.position.row + dir, pawn.position.col);
    if (one.isValid && grid[one.row][one.col] == null) {
      moves.add(one);

      // Forward two from start
      if (pawn.position.row == startRow) {
        final two = Position(pawn.position.row + 2 * dir, pawn.position.col);
        if (two.isValid && grid[two.row][two.col] == null) {
          moves.add(two);
        }
      }
    }

    // Captures
    for (final dc in [-1, 1]) {
      final cap = Position(pawn.position.row + dir, pawn.position.col + dc);
      if (!cap.isValid) continue;
      final target = grid[cap.row][cap.col];
      if (target != null && target.color != pawn.color) {
        moves.add(cap);
      }
      // En passant
      if (cap == enPassantTarget) {
        moves.add(cap);
      }
    }

    return moves;
  }

  List<Position> _knightMoves(Piece knight) {
    return _knightOffsets
        .map((o) => Position(knight.position.row + o[0], knight.position.col + o[1]))
        .where((p) => p.isValid)
        .where((p) {
          final target = grid[p.row][p.col];
          return target == null || target.color != knight.color;
        })
        .toList();
  }

  List<Position> _slidingMoves(Piece piece, List<List<int>> directions) {
    final moves = <Position>[];
    for (final dir in directions) {
      for (int i = 1; i < 8; i++) {
        final p = Position(
          piece.position.row + dir[0] * i,
          piece.position.col + dir[1] * i,
        );
        if (!p.isValid) break;
        final target = grid[p.row][p.col];
        if (target == null) {
          moves.add(p);
        } else {
          if (target.color != piece.color) moves.add(p);
          break;
        }
      }
    }
    return moves;
  }

  List<Position> _kingMoves(Piece king) {
    return king.position.adjacent
        .where((p) {
          final target = grid[p.row][p.col];
          return target == null || target.color != king.color;
        })
        .toList();
  }

  // ─── Castling ────────────────────────────────────────────────────────────

  List<Move> _castlingMoves(Piece king) {
    final moves = <Move>[];
    if (isInCheck(king.color)) return moves; // Can't castle out of check

    final row = king.color.backRank;
    final kingsideIdx = king.color == PlayerColor.white ? 0 : 2;
    final queensideIdx = king.color == PlayerColor.white ? 1 : 3;

    // Kingside
    if (castlingRights[kingsideIdx]) {
      if (grid[row][5] == null && grid[row][6] == null) {
        final rook = grid[row][7];
        if (rook != null && rook.type == PieceType.rook && !rook.hasMoved) {
          // Squares king passes through can't be attacked
          final sim1 = _simulateMove(king.position, Position(row, 5), king);
          final sim2 = _simulateMove(king.position, Position(row, 6), king);
          if (!sim1.isInCheck(king.color) && !sim2.isInCheck(king.color)) {
            moves.add(Move(
              from: king.position,
              to: Position(row, 6),
              piece: king,
              isCastling: true,
            ));
          }
        }
      }
    }

    // Queenside
    if (castlingRights[queensideIdx]) {
      if (grid[row][3] == null && grid[row][2] == null && grid[row][1] == null) {
        final rook = grid[row][0];
        if (rook != null && rook.type == PieceType.rook && !rook.hasMoved) {
          final sim1 = _simulateMove(king.position, Position(row, 3), king);
          final sim2 = _simulateMove(king.position, Position(row, 2), king);
          if (!sim1.isInCheck(king.color) && !sim2.isInCheck(king.color)) {
            moves.add(Move(
              from: king.position,
              to: Position(row, 2),
              piece: king,
              isCastling: true,
            ));
          }
        }
      }
    }

    return moves;
  }

  Move _executeCastling(List<List<Piece?>> g, Move move) {
    final row = move.piece.color.backRank;
    if (move.to.col == 6) {
      // Kingside: rook from col 7 to col 5
      final rook = g[row][7];
      g[row][7] = null;
      g[row][5] = rook?.copyWith(position: Position(row, 5), hasMoved: true);
    } else if (move.to.col == 2) {
      // Queenside: rook from col 0 to col 3
      final rook = g[row][0];
      g[row][0] = null;
      g[row][3] = rook?.copyWith(position: Position(row, 3), hasMoved: true);
    }
    return move;
  }

  List<bool> _updateCastlingRights(Move move, List<bool> rights) {
    final piece = pieceAt(move.from);
    if (piece == null) return rights;

    // If king moves, lose all castling rights
    if (piece.type == PieceType.king) {
      if (piece.color == PlayerColor.white) {
        rights[0] = false;
        rights[1] = false;
      } else {
        rights[2] = false;
        rights[3] = false;
      }
    }

    // If rook moves from its starting corner, lose that side's right
    if (piece.type == PieceType.rook) {
      if (move.from == Position(7, 7)) rights[0] = false; // White kingside
      if (move.from == Position(7, 0)) rights[1] = false; // White queenside
      if (move.from == Position(0, 7)) rights[2] = false; // Black kingside
      if (move.from == Position(0, 0)) rights[3] = false; // Black queenside
    }

    // If rook is captured on its starting square
    if (move.to == Position(7, 7)) rights[0] = false;
    if (move.to == Position(7, 0)) rights[1] = false;
    if (move.to == Position(0, 7)) rights[2] = false;
    if (move.to == Position(0, 0)) rights[3] = false;

    return rights;
  }

  // ─── Serialization ───────────────────────────────────────────────────────

  /// Serialize board to JSON for Supabase storage.
  Map<String, dynamic> toJson() => {
        'turn': turn.name,
        'enPassantTarget': enPassantTarget != null
            ? {'row': enPassantTarget!.row, 'col': enPassantTarget!.col}
            : null,
        'halfMoveClock': halfMoveClock,
        'fullMoveNumber': fullMoveNumber,
        'castlingRights': castlingRights,
        'pieces': piecesOf(PlayerColor.white)
            .map((p) => p.toJson())
            .followedBy(piecesOf(PlayerColor.black).map((p) => p.toJson()))
            .toList(),
      };

  factory Board.fromJson(Map<String, dynamic> json) {
    final grid = List.generate(8, (_) => List<Piece?>.filled(8, null));
    final piecesJson = json['pieces'] as List<dynamic>;
    for (final pJson in piecesJson) {
      final piece = Piece.fromJson(pJson as Map<String, dynamic>);
      grid[piece.position.row][piece.position.col] = piece;
    }

    Position? enPassant;
    if (json['enPassantTarget'] != null) {
      final ep = json['enPassantTarget'] as Map<String, dynamic>;
      enPassant = Position(ep['row'] as int, ep['col'] as int);
    }

    return Board(
      grid: grid,
      turn: PlayerColor.values.byName(json['turn'] as String),
      enPassantTarget: enPassant,
      halfMoveClock: json['halfMoveClock'] as int? ?? 0,
      fullMoveNumber: json['fullMoveNumber'] as int? ?? 1,
      castlingRights: (json['castlingRights'] as List<dynamic>?)
              ?.map((e) => e as bool)
              .toList() ??
          [true, true, true, true],
    );
  }
}
