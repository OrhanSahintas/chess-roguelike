import 'dart:math';
import '../abilities/abilities.dart';

/// The pool of all available abilities for drafting.
class AbilityPool {
  static final List<Ability Function()> _factory = [
    () => SecondChance(),
    () => CashGrab(),
    () => Charge(),
    () => Martyrdom(),
    () => TrojanHorse(),
    () => SnipersNest(),
  ];

  /// All ability instances (for display in lobby, etc.).
  static List<Ability> get all => _factory.map((f) => f()).toList();

  /// Get a random set of [count] abilities for drafting.
  /// Excludes abilities the player already owns.
  static List<Ability> draftChoices({
    required int count,
    required List<Ability> alreadyOwned,
  }) {
    final ownedIds = alreadyOwned.map((a) => a.id).toSet();
    final available = _factory
        .where((f) => !ownedIds.contains(f().id))
        .toList();

    final random = Random();
    available.shuffle(random);

    return available.take(count).map((f) {
      final ability = f();
      return ability;
    }).toList();
  }
}
