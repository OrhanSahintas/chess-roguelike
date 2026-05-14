import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../../abilities/abilities.dart';
import '../../models/models.dart';
import '../../models/ability_pool.dart';

/// The ability draft modal — 3 cards flip over, player picks one.
class DraftScreen extends StatefulWidget {
  final PlayerColor draftingFor;
  final void Function(Ability ability) onAbilitySelected;

  const DraftScreen({
    super.key,
    required this.draftingFor,
    required this.onAbilitySelected,
  });

  @override
  State<DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends State<DraftScreen>
    with SingleTickerProviderStateMixin {
  late List<Ability> _choices;
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  final _flippedCards = <int, bool>{};

  @override
  void initState() {
    super.initState();
    _choices = AbilityPool.all..shuffle(Random());
    _choices = _choices.take(3).toList();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _flippedCards[index] = true;
    });
  }

  void _selectAbility(Ability ability) {
    HapticFeedback.heavyImpact();
    widget.onAbilitySelected(ability);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title with color indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.draftingFor == PlayerColor.white
                          ? const Color(0xFF66FCF1)
                          : const Color(0xFFFF0055),
                      boxShadow: [
                        BoxShadow(
                          color: widget.draftingFor == PlayerColor.white
                              ? const Color(0xFF66FCF1).withValues(alpha: 0.5)
                              : const Color(0xFFFF0055).withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: widget.draftingFor == PlayerColor.white
                          ? [const Color(0xFF66FCF1), const Color(0xFFC77DFF)]
                          : [const Color(0xFFFF0055), const Color(0xFFC77DFF)],
                    ).createShader(bounds),
                    child: Text(
                      widget.draftingFor == PlayerColor.white
                          ? 'WHITE DRAFT'
                          : 'BLACK DRAFT',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Choose one ability to add to your arsenal',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 40),

              // 3 Ability cards
              SizedBox(
                height: 320,
                child: ListView.separated(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _choices.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    return _DraftCard(
                      ability: _choices[index],
                      isFlipped: _flippedCards[index] ?? false,
                      onFlip: () => _flipCard(index),
                      onSelect: () => _selectAbility(_choices[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftCard extends StatefulWidget {
  final Ability ability;
  final bool isFlipped;
  final VoidCallback onFlip;
  final VoidCallback onSelect;

  const _DraftCard({
    required this.ability,
    required this.isFlipped,
    required this.onFlip,
    required this.onSelect,
  });

  @override
  State<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<_DraftCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_DraftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped && !oldWidget.isFlipped) {
      _flipController.forward();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!widget.isFlipped) {
          widget.onFlip();
        } else {
          widget.onSelect();
        }
      },
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_flipAnimation.value * 3.14159),
            child: _flipAnimation.value < 0.5
                ? _buildCardBack()
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.14159),
                    child: _buildCardFront(),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: 200,
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2833),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC77DFF).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC77DFF).withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, color: Color(0xFFC77DFF), size: 48),
            SizedBox(height: 12),
            Text(
              'TAP TO REVEAL',
              style: TextStyle(
                color: Color(0xFFC77DFF),
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFront() {
    final ability = widget.ability;
    final accentColors = _accentForAbility(ability.id);

    return Container(
      width: 200,
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F2833),
            accentColors.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColors.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColors.withOpacity(0.2),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Icon(_iconForAbility(ability.id), color: accentColors, size: 40),
            const SizedBox(height: 12),
            // Name
            Text(
              ability.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accentColors,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            // Description
            Expanded(
              child: Text(
                ability.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Select hint
            Text(
              'TAP TO SELECT',
              style: TextStyle(
                color: accentColors.withOpacity(0.7),
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _accentForAbility(String id) {
    return switch (id) {
      'second_chance' => const Color(0xFF66FCF1), // Cyan
      'cash_grab' => const Color(0xFFFFD700), // Gold
      'charge' => const Color(0xFFFF0055), // Crimson
      'martyrdom' => const Color(0xFF00BFFF), // Ice blue
      'trojan_horse' => const Color(0xFFC77DFF), // Purple
      'snipers_nest' => const Color(0xFF00FF7F), // Green
      _ => const Color(0xFF66FCF1),
    };
  }

  IconData _iconForAbility(String id) {
    return switch (id) {
      'second_chance' => Icons.replay,
      'cash_grab' => Icons.monetization_on,
      'charge' => Icons.flash_on,
      'martyrdom' => Icons.ac_unit,
      'trojan_horse' => Icons.swap_horiz,
      'snipers_nest' => Icons.gps_fixed,
      _ => Icons.auto_awesome,
    };
  }
}
