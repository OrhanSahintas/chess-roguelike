import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    // TODO: Create game in Supabase, navigate to game
                  },
                ),
                const SizedBox(height: 16),

                // Join by Code button
                _NeonButton(
                  text: '🔗 JOIN BY CODE',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    // TODO: Show join dialog
                  },
                  isSecondary: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              ? primaryColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered ? primaryColor : primaryColor.withOpacity(0.4),
            width: _isHovered ? 2 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
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
