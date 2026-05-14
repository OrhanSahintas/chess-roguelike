import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/game_provider.dart';
import '../../services/supabase_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _uid = Uuid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B0C10),
              Color(0xFF1A0A2E),
              Color(0xFF0B0C10),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF66FCF1), Color(0xFFC77DFF)],
                  ).createShader(bounds),
                  child: const Text(
                    '♟ CHESS\nROGUELIKE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 8,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Draft. Adapt. Dominate.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[500],
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 64),

                // Play with Friend button
                _NeonButton(
                  text: '⚡ PLAY WITH FRIEND',
                  onTap: () => _createOnlineGame(context, ref),
                ),
                const SizedBox(height: 16),

                // Join by Code button
                _NeonButton(
                  text: '🔗 JOIN BY CODE',
                  onTap: () => _showJoinDialog(context, ref),
                  isSecondary: true,
                ),
                const SizedBox(height: 16),

                // Play Offline button
                _NeonButton(
                  text: '🖥 PLAY OFFLINE',
                  onTap: () => _createOfflineGame(context, ref),
                  isSecondary: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Create a multiplayer game in Supabase and navigate to it.
  Future<void> _createOnlineGame(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final playerId = _uid.v4();

    try {
      // Show loading
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final gameId = await SupabaseService.instance.createGame(
        whitePlayerId: playerId,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Dismiss loading

      // Initialize the game provider
      ref.read(gameProvider.notifier).newGame(
        gameId: gameId,
        whitePlayerId: playerId,
      );
      ref.read(myColorProvider.notifier).state = PlayerColor.white;

      if (!context.mounted) return;
      context.go('/game/$gameId');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create game: $e')),
      );
    }
  }

  /// Show dialog to enter a game ID and join.
  Future<void> _showJoinDialog(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final controller = TextEditingController();

    final gameId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2833),
        title: const Text('Join Game',
            style: TextStyle(color: Color(0xFF66FCF1))),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Paste game ID or code',
            hintStyle: TextStyle(color: Colors.grey),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF66FCF1)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Join',
                style: TextStyle(color: Color(0xFF66FCF1))),
          ),
        ],
      ),
    );

    if (gameId == null || gameId.isEmpty || !context.mounted) return;

    final playerId = _uid.v4();

    try {
      await SupabaseService.instance.joinGame(
        gameId: gameId,
        blackPlayerId: playerId,
      );

      ref.read(gameProvider.notifier).newGame(
        gameId: gameId,
        whitePlayerId: null, // Joined as black
      );
      ref.read(gameProvider.notifier).joinGame(playerId);
      ref.read(myColorProvider.notifier).state = PlayerColor.black;

      if (!context.mounted) return;
      context.go('/game/$gameId');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join: $e')),
      );
    }
  }

  /// Create a local-only game (no Supabase required).
  void _createOfflineGame(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    final gameId = _uid.v4();

    ref.read(gameProvider.notifier).newGame(gameId: gameId);
    ref.read(myColorProvider.notifier).state = PlayerColor.white;

    context.go('/game/$gameId?offline=true');
  }
}

class _NeonButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool isSecondary;

  const _NeonButton({
    required this.text,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  State<_NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<_NeonButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isSecondary
        ? const Color(0xFFC77DFF)
        : const Color(0xFF66FCF1);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 280,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
        decoration: BoxDecoration(
          color: _isHovered
              ? primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? primaryColor
                : primaryColor.withValues(alpha: 0.4),
            width: _isHovered ? 2 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Text(
          widget.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}
