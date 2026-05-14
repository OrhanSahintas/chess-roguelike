import 'dart:math';
import 'ability.dart';
import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';

/// When any friendly piece dies, 50% chance it revives on a random free
/// square on your half of the board.
class SecondChance extends Ability {
  @override
  String get id => 'second_chance';

  @override
  String get name => 'Second Chance';

  @override
  String get description =>
      'When any friendly piece dies, there\'s a 50% chance it\'s revived '
      'on a random free square on your half of the board.';

  @override
  String get iconName => 'replay';

  final _random = Random();

  @override
  CaptureModification? onPieceCaptured(
    Board board,
    Piece captured,
    Piece capturer,
    Position capturePos,
  ) {
    if (captured.color != owner) return null;

    // 50% chance
    if (_random.nextDouble() > 0.5) return null;

    // Find a free square on owner's half
    final freeSquares = <Position>[];
    final (int minRow, int maxRow) = owner == PlayerColor.white
        ? (4, 7) // White's half (rows 4-7)
        : (0, 3); // Black's half (rows 0-3)

    for (int row = minRow; row <= maxRow; row++) {
      for (int col = 0; col < 8; col++) {
        if (board.grid[row][col] == null) {
          freeSquares.add(Position(row, col));
        }
      }
    }

    if (freeSquares.isEmpty) return null;

    final revivePos = freeSquares[_random.nextInt(freeSquares.length)];
    return CaptureModification(revive: true, revivePosition: revivePos);
  }
}
