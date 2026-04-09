# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Godot 4.6 competitive blackjack game built for a game jam. Deployed to GitHub Pages. Play at: https://dustin-lucky.github.io/040726_team_1_jam/

**Status**: Early development — not all systems are in place yet.

### Game Design

Five players compete against the dealer and each other. Last player standing wins.

**Lives system**: Each player has 3 lives. Losing to the dealer or busting costs 1 life. A player eliminated at 0 lives is out.

**Round flow**:
1. Deal 2 cards to all players and dealer. Dealer's second card is face down.
2. Loop — each player takes one action per iteration — until all players have busted or are standing. (Unlike standard blackjack, players rotate one action at a time rather than each player completing their full turn before the next.)
3. Dealer flips their face-down card, then hits until score ≥ 17 (stands on 17+).
4. If dealer busts, all non-busted players are safe. Otherwise, players who scored lower than the dealer lose 1 life.
5. All cards move to the discard pile.

**Player actions**:
- *Hit* — draw a card
- *Stand* — lock in score; can no longer act, but also immune to other players' actions
- *Bust* — score > 21; lose 1 life, exit the round

**Competitive actions** (not yet implemented or designed): Players will be able to act against each other — examples include stealing a card, pushing a card into another player's hand, or modifying a score with a dice roll. Standing provides immunity from these.

**Excluded mechanics**: No splitting, no doubling down.

## Development

**Engine**: Godot 4.6 — no npm/Makefile. All build/run operations go through the Godot editor or CLI.

- **Run**: Open `project/project.godot` in Godot 4.6, press Play (F5)
- **Export Web**: Godot editor → Project → Export → "Web" preset → Export All
- **Export Windows**: Godot editor → Project → Export → "Windows Desktop" preset
- **Deploy**: Push to `docs/` on `main` branch; GitHub Pages serves from there

The `docs/vercel.json` sets required CORS headers (`Cross-Origin-Opener-Policy`, `Cross-Origin-Embedder-Policy`) for SharedArrayBuffer, which Godot web exports need.

## Architecture

**Language**: GDScript throughout. All scripts are in `project/Scripts/`.

### Core Game Loop

`GameStateManager` (game_manager.gd) drives the game loop using `await`:
1. Shuffle discard into shoe → deal initial cards → player action rounds → dealer plays → clean up → repeat

`GameAnimator` (game_animator.gd) handles all animated card movement (dealing, cleanup, shuffling). It wraps `CardMover` calls and updates game state (e.g. adding cards to hands, clearing hands) as cards arrive at their destinations.

### Action Selector System

Each `Player` node has an `ActionSelector` child that acts as its decision-making brain. The base class (`action_selector.gd`) is abstract — subclasses implement `_on_action_requested(player_states)`, populate the `action` property, and emit `action_ready`.

`GameStateManager` calls `request_make_action(player_states)` on each player's selector and awaits `action_ready` before proceeding.

**Existing selectors**:
- `ActionSelector_Dealer` — standard BJ dealer logic: stand at 17+, hit below 17.

**Planned selectors**:
- Human input selector (local player)
- Various AI strategy selectors
- Multiplayer/network input selector

The dealer is always `table.players[-1]` (last in the array). `my_player_index` is set on each selector by `Table._ready()` so selectors can look up their own player state from the passed array.

### Key Systems

| Script | Role |
|--------|------|
| `GameRules.gd` | Autoload — single source of truth for blackjack rules (`deck_count`, bust threshold, `is_busted()`, `is_blackjack()`) |
| `GlobalSignals.gd` (SignalBus) | Autoload — global event bus |
| `game_manager.gd` (`GameStateManager`) | Async game loop; coordinates action request/response cycle |
| `game_animator.gd` (`GameAnimator`) | Animated card dealing, cleanup, and shuffle; mutates game state on card arrival |
| `Table.gd` | Owns all game entities; initializes `my_player_index` on all action selectors |
| `card_mover.gd` | Tweened card movement animations with configurable timing |
| `hand.gd` | Score calculation (handles aces) and available actions (HIT/STAND/DOUBLE_DOWN/SPLIT) |
| `shoe.gd` | Shuffleable draw pile |
| `discard_pile.gd` | Discard/reshuffle management |
| `card.gd` | Individual card: flip animation, drag/click, rumble effect |
| `card_def.gd` | Card definition resource (suit, rank, sprite region) |
| `player.gd` | Player entity; tracks `last_action_taken`; `is_still_in_hand()` checks bust/blackjack/stand |
| `dealer.gd` | Extends `Player` (currently empty — behavior is in `ActionSelector_Dealer`) |
| `deck.gd` | Creates and holds a set of cards; supports debug layout |
| `action_selector.gd` | Abstract base for player decision-making; defines `ActionTypes`, `Action` class, `action_ready` signal |
| `action_selector_dealer.gd` | Dealer AI: stand ≥ 17, hit otherwise |

### Scene Hierarchy

```
GameScene (root)
├── GameStateManager
│   └── (exports: table, game_animator)
└── Table
    ├── Players[]
    │   └── (each has a Hand child and an ActionSelector child)
    ├── Dealer (last player, index -1)
    ├── Shoe
    ├── DiscardPile
    ├── CardMover
    └── GameAnimator
```

Scenes live in `project/Scenes/`; resources (card `.tres` files) in `project/Resources/`; sprites in `project/Graphics/`. Action Selector scripts live in `project/Scripts/Action Selector/`.
