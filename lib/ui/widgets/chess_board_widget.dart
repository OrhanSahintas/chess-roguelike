import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../models/game_state.dart';
import '../../providers/game_provider.dart';


/// The futuristic chess board with frosted glass tiles, neon glow effects,
/// and smooth piece movement animations.
class ChessBoardWidget extends ConsumerStatefulWidget {
  const ChessBoardWidget({super.key});

  @override
  ConsumerState<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends ConsumerState<ChessBoardWidget>
    with TickerProviderStateMixin {
  Position? _selectedPosition;
  List<Position> _legalMoves = [];

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    if (gameState == null) return const SizedBox.shrink();

    final board = gameState.board;
    final myColor = ref.watch(myColorProvider) ?? PlayerColor.white;

    // Board orientation: flip if viewing as black
    final isFlipped = myColor == PlayerColor.black;

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF66FCF1).withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF66FCF1).withValues(alpha: 0.1),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CustomPaint(
            painter: _BoardGradientPainter(),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
              ),
              itemCount: 64,
              itemBuilder: (context, index) {
                final row = index ~/ 8;
                final col = index % 8;
                final displayRow = isFlipped ? 7 - row : row;
                final displayCol = isFlipped ? 7 - col : col;
                final position = Position(displayRow, displayCol);
                final piece = board.pieceAt(position);

                final isLight = (row + col) % 2 == 0;
                final isSelected = position == _selectedPosition;
                final isLegalTarget = _legalMoves.contains(position);
                final isLastMoveFrom = gameState.lastMove?.from == position;
                final isLastMoveTo = gameState.lastMove?.to == position;

                return GestureDetector(
                  onTap: () => _onSquareTap(position, gameState),
                  child: _BoardSquare(
                    isLight: isLight,
                    isSelected: isSelected,
                    isLegalTarget: isLegalTarget,
                    isLastMoveFrom: isLastMoveFrom,
                    isLastMoveTo: isLastMoveTo,
                    hasPiece: piece != null,
                    child: piece != null
                        ? _PieceWidget(
                            piece: piece,
                            isCapturable: isLegalTarget,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _onSquareTap(Position position, GameState gameState) {
    final piece = gameState.board.pieceAt(position);
    final myColor = ref.read(myColorProvider) ?? PlayerColor.white;
    final isOffline = ref.read(isOfflineGameProvider);

    // Determine who is allowed to move:
    // - Offline: anyone whose turn it is
    // - Online: only the player whose color matches myColor AND it's their turn
    final canMoveHere = isOffline
        ? piece != null && piece.color == gameState.board.turn
        : piece != null &&
            piece.color == myColor &&
            gameState.board.turn == myColor;

    // If we have a selected position and tap a legal target, make the move
    if (_selectedPosition != null && _legalMoves.contains(position)) {
      final move = Move(
        from: _selectedPosition!,
        to: position,
        piece: gameState.board.pieceAt(_selectedPosition!)!,
        capturedPiece: gameState.board.pieceAt(position),
      );
      ref.read(gameProvider.notifier).executeMove(move);
      setState(() {
        _selectedPosition = null;
        _legalMoves = [];
      });
      return;
    }

    // Deselect if tapping same square
    if (position == _selectedPosition) {
      setState(() {
        _selectedPosition = null;
        _legalMoves = [];
      });
      return;
    }

    // Select a piece if allowed
    if (canMoveHere) {
      setState(() {
        _selectedPosition = position;
        _legalMoves = gameState
            .getLegalMoves(position)
            .map((m) => m.to)
            .toList();
      });
    } else {
      setState(() {
        _selectedPosition = null;
        _legalMoves = [];
      });
    }
  }
}

/// Background gradient for the board.
class _BoardGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF0B0C10),
        const Color(0xFF1A0A2E).withValues(alpha: 0.3),
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader =
            gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A single square on the board.
class _BoardSquare extends StatelessWidget {
  final bool isLight;
  final bool isSelected;
  final bool isLegalTarget;
  final bool isLastMoveFrom;
  final bool isLastMoveTo;
  final bool hasPiece;
  final Widget? child;

  const _BoardSquare({
    required this.isLight,
    required this.isSelected,
    required this.isLegalTarget,
    required this.isLastMoveFrom,
    required this.isLastMoveTo,
    required this.hasPiece,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor =
        isLight ? const Color(0xFF2C3E50) : const Color(0xFF1A252F);

    Color squareColor = baseColor;

    if (isLastMoveFrom || isLastMoveTo) {
      squareColor = Color.alphaBlend(
        const Color(0x3066FCF1),
        baseColor,
      );
    }

    if (isSelected) {
      squareColor = Color.alphaBlend(
        const Color(0x4066FCF1),
        baseColor,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: squareColor,
        border: isSelected
            ? Border.all(color: const Color(0xFF66FCF1), width: 2)
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isLegalTarget && !hasPiece)
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF66FCF1).withValues(alpha: 0.4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF66FCF1).withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          if (isLegalTarget && hasPiece)
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                border: Border.all(
                  color: const Color(0xFFFF0055).withValues(alpha: 0.7),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF0055).withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

/// A chess piece with neon glow and selection state.
class _PieceWidget extends StatelessWidget {
  final Piece piece;
  final bool isCapturable;

  const _PieceWidget({
    required this.piece,
    this.isCapturable = false,
  });

  @override
  Widget build(BuildContext context) {
    final isWhite = piece.color == PlayerColor.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: isCapturable
            ? BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF0055).withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              )
            : null,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            piece.unicode,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.normal,
              fontFamily: 'Arial',
              color: isWhite ? const Color(0xFFF0F0F0) : const Color(0xFF404040),
              shadows: [
                Shadow(
                  color: isWhite
                      ? const Color(0xFF66FCF1).withValues(alpha: 0.4)
                      : const Color(0xFFFF0055).withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
