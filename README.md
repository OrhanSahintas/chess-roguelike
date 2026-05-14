# ♟ Chess Roguelike

**Real-time multiplayer PvP chess with Roguelike Draft abilities.**

Every 3 turns, draft a game-warping perk. Adapt your strategy on the fly. Available for iOS, Android, and Web.

> Built with Flutter 3.x, Riverpod, and Supabase Realtime.

---

## 🎮 Gameplay

Standard chess rules apply — with one twist. After every 3 full turns (both players move once), a **Draft Phase** interrupts the game. Both players are shown 3 randomized ability cards and must pick one.

### 🃏 Abilities (Perks)

| Ability | Effect |
|---------|--------|
| **Second Chance** | 50% chance to revive a captured piece on your half of the board |
| **Cash Grab** | ANY piece reaching the enemy backline can promote (Queen/Rook/Bishop/Knight) |
| **CHARGE** | On draft: all your pieces immediately advance 1 square toward the enemy (one-time) |
| **Martyrdom** | When your piece is captured, the capturer is FROZEN for its next turn |
| **Trojan Horse** | Once per game: swap the positions of any friendly Knight and Pawn |
| **Sniper's Nest** | Rooks can capture in their line of sight without moving (4-turn cooldown) |

---

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK** (3.27+): [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Supabase account**: [supabase.com](https://supabase.com) (free tier works)

### 1. Clone & Install

```bash
git clone https://github.com/OrhanSahintas/chess-roguelike.git
cd chess-roguelike
flutter pub get
```

### 2. Set Up Supabase

Create a new Supabase project and run this SQL in the SQL Editor:

```sql
CREATE TABLE games (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  white_player_id TEXT,
  black_player_id TEXT,
  board_state JSONB NOT NULL,
  turn TEXT DEFAULT 'white',
  status TEXT DEFAULT 'waiting',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE games;

-- Enable RLS
ALTER TABLE games ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read/update games (for now)
CREATE POLICY "Enable all for games" ON games
  FOR ALL USING (true);
```

Copy your Supabase URL and anon key from the project settings.

### 3. Configure & Run

Edit `lib/main.dart` and replace the Supabase credentials:

```dart
await SupabaseService.instance.initialize(
  url: 'https://sdiqylrnphkqciukdfno.supabase.co',
  anonKey: 'YOUR_ANON_KEY',
);
```

Then run:

```bash
# Web
flutter run -d chrome

# iOS Simulator
flutter run -d ios

# Android Emulator
flutter run -d android
```

### 4. Play with a Friend

1. Tap **PLAY WITH FRIEND** → a deep link is generated
2. Send the link to your friend
3. They open it on their phone → the app launches and joins the game
4. Chess with abilities begins!

---

## 🏗 Architecture

```
lib/
├── models/           # Core engine (no external chess packages)
│   ├── position.dart   # Immutable 8x8 coordinates
│   ├── piece.dart      # Piece with freeze/replay state
│   ├── move.dart       # Move with castling/en passant
│   ├── board.dart      # Custom 500+ line chess engine
│   └── game_state.dart # Full match orchestrator
├── abilities/        # Roguelike perks (easily extensible)
│   ├── ability.dart    # Base class with 7 hook methods
│   ├── second_chance.dart
│   ├── cash_grab.dart
│   ├── charge.dart
│   ├── martyrdom.dart
│   ├── trojan_horse.dart
│   └── snipers_nest.dart
├── providers/        # Riverpod state management
├── services/         # Supabase realtime + deep links
├── routing/          # go_router with /join/:gameId deep links
└── ui/
    ├── theme/        # OLED black + neon cyan/crimson
    ├── screens/      # Home, Game, Draft (3D card flip)
    └── widgets/      # Frosted glass chess board
```

### Key Design Decisions

- **Custom chess engine** (not `chess` package): abilities modify movement rules — no off-the-shelf engine supports `Sniper's Nest` (capture without moving) or `CHARGE` (mass forced advance)
- **Hook-based ability system**: 7 hooks (`onTurnStart`, `onBeforeMove`, `onPieceCaptured`, etc.). Add a new perk in ~30 lines
- **Immutable state**: every move returns a new `BoardResult`. Safe for Riverpod + Supabase sync
- **Realtime multiplayer**: Supabase Postgres Changes → instant board updates between players

---

## 🎨 Theme

- **Background**: OLED black `#0B0C10` with deep navy gradients
- **Accents**: Neon Cyan `#66FCF1` (selections) + Crimson `#FF0055` (captures)
- **Board**: Frosted glass tiles with soft neon glow on active squares
- **Animations**: 3D card flips for draft, smooth piece glide, `BoxShadow` glows

---

## 📋 Roadmap

- [ ] Movement animations (piece glide transitions)
- [ ] Promotion picker modal
- [ ] Trojan Horse piece selector UI
- [ ] Match history & ELO
- [ ] More abilities (Phase Shift, Mirror Match, Time Warp)
- [ ] Single-player vs AI

---

## 📄 License

MIT — build cool things.
