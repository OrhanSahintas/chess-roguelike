import 'package:equatable/equatable.dart';
import 'models.dart';
import '../abilities/abilities.dart';

/// The complete state of a chess roguelike match.
class GameState extends Equatable {
  final String gameId;
  final Board board;
  final GameStatus status;
  final String? whitePlayerId;
  final String? blackPlayerId;

  /// How many full turns have elapsed (White+Black move = 1 turn).
  final int fullTurnCount;

  /// Per-player draft tracking: has this player picked their ability?
  final bool whiteDrafted;
  final bool blackDrafted;

  /// Which color is currently drafting (set when draft triggers).
  final PlayerColor? draftingPlayer;

  /// Which player's turn it currently is (derived from board.turn).
  PlayerColor get currentTurn => board.turn;

  /// Abilities owned by each player.
  final List<Ability> whiteAbilities;
  final List<Ability> blackAbilities;

  /// The en passant target from the last move (for rendering).
  Position? get enPassantTarget => board.enPassantTarget;

  /// All pieces on the board.
  List<Piece> get pieces => [
        ...board.piecesOf(PlayerColor.white),
        ...board.piecesOf(PlayerColor.black),
      ];

  /// The last move made.
  Move? get lastMove => board.lastMove;

  /// Abilities for the current player.
  List<Ability> get currentPlayerAbilities =>
      currentTurn == PlayerColor.white ? whiteAbilities : blackAbilities;

  const GameState({
    required this.gameId,
    required this.board,
    this.status = GameStatus.waiting,
    this.whitePlayerId,
    this.blackPlayerId,
    this.fullTurnCount = 0,
    this.whiteAbilities = const [],
    this.blackAbilities = const [],
    this.whiteDrafted = false,
    this.blackDrafted = false,
    this.draftingPlayer,
  });

  /// Create a new game in waiting state.
  factory GameState.newGame({
    required String gameId,
    String? whitePlayerId,
  }) {
    return GameState(
      gameId: gameId,
      board: Board.initial(),
      status: GameStatus.waiting,
      whitePlayerId: whitePlayerId,
    );
  }

  // ─── Move Execution with Ability Hooks ───────────────────────────────────

  GameState executeMove(Move move) {
    for (final ability in currentPlayerAbilities) {
      final mod = ability.onBeforeMove(board, move);
      if (mod != null && mod.blocked) return this;
    }

    final result = board.executeMove(move);
    var newBoard = Board(
      grid: result.grid,
      turn: result.lastMove.piece.color.opponent,
      enPassantTarget: result.enPassantTargetSet ? _deriveEnPassant(move) : null,
      halfMoveClock: board.halfMoveClock +
          (move.piece.type == PieceType.pawn || result.capturedPiece != null ? 0 : 1),
      fullMoveNumber: board.turn == PlayerColor.black
          ? board.fullMoveNumber + 1
          : board.fullMoveNumber,
      castlingRights: _deriveCastlingRights(board, move),
      lastMove: result.lastMove,
    );

    var capturedPiece = result.capturedPiece;
    if (capturedPiece != null) {
      for (final ability in currentPlayerAbilities) {
        final mod = ability.onPieceCaptured(board, capturedPiece!, move.piece, move.to);
        if (mod != null) {
          if (mod.revive && mod.revivePosition != null) {
            newBoard = _revivePiece(newBoard, capturedPiece, mod.revivePosition!);
            capturedPiece = null;
          }
          if (mod.freezeCapturer) {
            newBoard = _freezePiece(newBoard, move.to, mod.freezeTurns);
          }
        }
      }
    }

    for (final ability in currentPlayerAbilities) {
      ability.onAfterMove(board, result);
      ability.tickCooldown();
    }

    final opponentAbilities =
        currentTurn == PlayerColor.white ? blackAbilities : whiteAbilities;
    for (final ability in opponentAbilities) {
      ability.tickCooldown();
    }

    final newTurnCount =
        currentTurn == PlayerColor.black ? fullTurnCount + 1 : fullTurnCount;

    var newStatus = status;
    if (result.isCheckmate) {
      newStatus = GameStatus.finished;
    } else if (result.isStalemate) {
      newStatus = GameStatus.finished;
    }

    return copyWith(
      board: newBoard,
      fullTurnCount: newTurnCount,
      status: newStatus,
    );
  }

  GameState executeSwap(Piece knight, Piece pawn) {
    final newGrid =
        List.generate(8, (row) => List.generate(8, (col) => board.grid[row][col]));

    newGrid[knight.position.row][knight.position.col] = pawn.copyWith(
      position: knight.position,
      hasMoved: true,
    );
    newGrid[pawn.position.row][pawn.position.col] = knight.copyWith(
      position: pawn.position,
      hasMoved: true,
    );

    final newBoard = Board(
      grid: newGrid,
      turn: board.turn,
      enPassantTarget: null,
      halfMoveClock: board.halfMoveClock + 1,
      fullMoveNumber: board.fullMoveNumber,
      castlingRights: board.castlingRights,
    );

    return copyWith(board: newBoard);
  }

  GameState executeSnipe(Piece rook, Position target) {
    final newGrid =
        List.generate(8, (row) => List.generate(8, (col) => board.grid[row][col]));
    newGrid[target.row][target.col] = null;

    final updatedAbilities = currentPlayerAbilities.map((a) {
      if (a is SnipersNest) {
        a.cooldownRemaining = a.maxCooldown;
        a.useCount++;
      }
      return a;
    }).toList();

    final newBoard = Board(
      grid: newGrid,
      turn: board.turn.opponent,
      enPassantTarget: null,
      halfMoveClock: 0,
      fullMoveNumber: board.turn == PlayerColor.black
          ? board.fullMoveNumber + 1
          : board.fullMoveNumber,
      castlingRights: board.castlingRights,
    );

    final newTurnCount =
        currentTurn == PlayerColor.black ? fullTurnCount + 1 : fullTurnCount;

    return copyWith(
      board: newBoard,
      fullTurnCount: newTurnCount,
      whiteAbilities: currentTurn == PlayerColor.white ? updatedAbilities : whiteAbilities,
      blackAbilities: currentTurn == PlayerColor.black ? updatedAbilities : blackAbilities,
    );
  }

  GameState addAbility(PlayerColor player, Ability ability) {
    ability.owner = player;
    if (player == PlayerColor.white) {
      return copyWith(whiteAbilities: [...whiteAbilities, ability]);
    } else {
      return copyWith(blackAbilities: [...blackAbilities, ability]);
    }
  }

  // ─── Draft Helpers ──────────────────────────────────────────────────────

  /// Whether the given player still needs to draft.
  bool needsDraft(PlayerColor player) {
    if (status != GameStatus.drafting) return false;
    return player == PlayerColor.white ? !whiteDrafted : !blackDrafted;
  }

  // ─── Legal Moves ────────────────────────────────────────────────────────

  List<Move> getLegalMoves(Position pos) {
    final baseMoves = board.getLegalMoves(pos);
    final piece = board.pieceAt(pos);
    if (piece == null) return baseMoves;

    final abilityMoves = <Move>[];
    for (final ability in currentPlayerAbilities) {
      final extraTargets = ability.getAdditionalRawMoves(board, piece);
      if (extraTargets != null) {
        for (final target in extraTargets) {
          final targetPiece = board.pieceAt(target);
          abilityMoves.add(Move(
            from: pos, to: target, piece: piece, capturedPiece: targetPiece,
          ));
        }
      }
    }
    return [...baseMoves, ...abilityMoves];
  }

  List<Move> allLegalMoves(PlayerColor color) {
    final moves = <Move>[];
    for (final piece in board.piecesOf(color)) {
      moves.addAll(getLegalMoves(piece.position));
    }
    return moves;
  }

  // ─── Copy ───────────────────────────────────────────────────────────────

  GameState copyWith({
    String? gameId,
    Board? board,
    GameStatus? status,
    String? whitePlayerId,
    String? blackPlayerId,
    int? fullTurnCount,
    List<Ability>? whiteAbilities,
    List<Ability>? blackAbilities,
    bool? whiteDrafted,
    bool? blackDrafted,
    PlayerColor? draftingPlayer,
  }) {
    return GameState(
      gameId: gameId ?? this.gameId,
      board: board ?? this.board,
      status: status ?? this.status,
      whitePlayerId: whitePlayerId ?? this.whitePlayerId,
      blackPlayerId: blackPlayerId ?? this.blackPlayerId,
      fullTurnCount: fullTurnCount ?? this.fullTurnCount,
      whiteAbilities: whiteAbilities ?? this.whiteAbilities,
      blackAbilities: blackAbilities ?? this.blackAbilities,
      whiteDrafted: whiteDrafted ?? this.whiteDrafted,
      blackDrafted: blackDrafted ?? this.blackDrafted,
      draftingPlayer: draftingPlayer ?? this.draftingPlayer,
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  Board _revivePiece(Board b, Piece piece, Position at) {
    final newGrid =
        List.generate(8, (row) => List.generate(8, (col) => b.grid[row][col]));
    newGrid[at.row][at.col] = piece.copyWith(position: at, hasMoved: false);
    return Board(
      grid: newGrid, turn: b.turn, enPassantTarget: b.enPassantTarget,
      halfMoveClock: b.halfMoveClock, fullMoveNumber: b.fullMoveNumber,
      castlingRights: b.castlingRights,
    );
  }

  Board _freezePiece(Board b, Position at, int turns) {
    final newGrid =
        List.generate(8, (row) => List.generate(8, (col) => b.grid[row][col]));
    final piece = newGrid[at.row][at.col];
    if (piece != null) {
      newGrid[at.row][at.col] =
          piece.copyWith(isFrozen: true, frozenTurnsRemaining: turns);
    }
    return Board(
      grid: newGrid, turn: b.turn, enPassantTarget: b.enPassantTarget,
      halfMoveClock: b.halfMoveClock, fullMoveNumber: b.fullMoveNumber,
      castlingRights: b.castlingRights,
    );
  }

  Position? _deriveEnPassant(Move move) {
    if (move.piece.type == PieceType.pawn &&
        (move.from.row - move.to.row).abs() == 2) {
      return Position((move.from.row + move.to.row) ~/ 2, move.from.col);
    }
    return null;
  }

  List<bool> _deriveCastlingRights(Board b, Move move) {
    final rights = List<bool>.from(b.castlingRights);
    final piece = b.pieceAt(move.from);
    if (piece == null) return rights;
    if (piece.type == PieceType.king) {
      if (piece.color == PlayerColor.white) {
        rights[0] = false; rights[1] = false;
      } else {
        rights[2] = false; rights[3] = false;
      }
    }
    if (piece.type == PieceType.rook) {
      if (move.from == const Position(7, 7)) rights[0] = false;
      if (move.from == const Position(7, 0)) rights[1] = false;
      if (move.from == const Position(0, 7)) rights[2] = false;
      if (move.from == const Position(0, 0)) rights[3] = false;
    }
    if (move.to == const Position(7, 7)) rights[0] = false;
    if (move.to == const Position(7, 0)) rights[1] = false;
    if (move.to == const Position(0, 7)) rights[2] = false;
    if (move.to == const Position(0, 0)) rights[3] = false;
    return rights;
  }

  // ─── JSON Serialization ─────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'board': board.toJson(),
        'status': status.name,
        'whitePlayerId': whitePlayerId,
        'blackPlayerId': blackPlayerId,
        'fullTurnCount': fullTurnCount,
        'whiteDrafted': whiteDrafted,
        'blackDrafted': blackDrafted,
        'draftingPlayer': draftingPlayer?.name,
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final stateJson = json.containsKey('board_state') && json['board_state'] is Map
        ? Map<String, dynamic>.from(json['board_state'] as Map)
        : json;

    final boardJson = stateJson['board'];
    if (boardJson == null || boardJson is! Map) {
      throw ArgumentError('Missing or invalid "board" in game state JSON');
    }

    return GameState(
      gameId: (stateJson['gameId'] ?? json['id'] ?? '') as String,
      board: Board.fromJson(Map<String, dynamic>.from(boardJson)),
      status: GameStatus.values.byName(
          (stateJson['status'] ?? json['status'] ?? 'waiting') as String),
      whitePlayerId: (stateJson['whitePlayerId'] ?? json['white_player_id']) as String?,
      blackPlayerId: (stateJson['blackPlayerId'] ?? json['black_player_id']) as String?,
      fullTurnCount: (stateJson['fullTurnCount'] ?? json['full_turn_count'] ?? 0) as int,
      whiteDrafted: (stateJson['whiteDrafted'] ?? false) as bool,
      blackDrafted: (stateJson['blackDrafted'] ?? false) as bool,
      draftingPlayer: stateJson['draftingPlayer'] != null
          ? PlayerColor.values.byName(stateJson['draftingPlayer'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        gameId, board.grid, board.turn, status,
        whitePlayerId, blackPlayerId, fullTurnCount,
        whiteAbilities.length, blackAbilities.length,
        whiteDrafted, blackDrafted, draftingPlayer,
      ];
}

/// Game status enum.
enum GameStatus { waiting, playing, drafting, finished }
