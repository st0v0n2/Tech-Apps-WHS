# Fake Casino - Godot 4.6 Project

A bare-bones single-player casino game with provably fair mechanics.

## Games Included

1. **Mines**: 5x5 grid, avoid mines, cash out anytime
2. **Slide**: Set target multiplier, win if random result exceeds it

## Provably Fair System

Each round uses:
- Server Seed (random, hashed and shown before round)
- Client Seed (player-defined or random)
- Nonce (incrementing counter)
- HMAC-SHA256(server_seed, message) where message = "server_seed:client_seed:nonce"

## Controls

- Use mouse to interact with UI
- Set bet amounts, adjust game settings
- Click Play to start
- For Mines: click tiles to reveal, Cash Out to secure winnings
- For Slide: set target, click Play for instant result
- Use Fairness panels to verify outcomes

## Running

1. Open Godot 4.6
2. Import project.godot
3. Press F5 to run

## Architecture

- Autoloads: CurrencyManager, FairnessSystem, GameState
- Scenes: MainMenu, MinesGame, SlideGame
- Components: BetInput, FairnessPanel (reusable)
- No external dependencies

## Project Structure

```
fake_casino/
├── project.godot
├── README.md
├── assets/
├── autoload/
│   ├── game_state.gd
│   ├── fairness_system.gd
│   └── currency_manager.gd
├── scenes/
│   ├── main_menu/
│   │   ├── main_menu.tscn
│   │   └── main_menu.gd
│   ├── mines/
│   │   ├── mines_game.tscn
│   │   ├── mines_game.gd
│   │   └── mines_tile.tscn
│   ├── slide/
│   │   ├── slide_game.tscn
│   │   └── slide_game.gd
│   └── components/
│       ├── bet_input.tscn
│       ├── bet_input.gd
│       ├── fairness_panel.tscn
│       └── fairness_panel.gd
└── scripts/
    └── utils/
        └── math_helpers.gd
```

## Fairness Verification Flow

1. **Pre-round**: Server seed hash displayed (commitment)
2. **Round**: Client seed + nonce used in HMAC-SHA256
3. **Post-round**: Server seed revealed, verification panel allows recomputation
4. **Verification**: Player can independently verify that hash(server_seed) matches pre-round hash and that outcomes derive correctly from HMAC

## Security Considerations

- Server seed remains hidden during play (only hash shown)
- Client can change seed between rounds
- Nonce prevents replay attacks
- All randomness derived from cryptographic HMAC

## Extensibility

- Add more games by creating new scenes in `scenes/`
- Modify `fairness_system.gd` to support additional verification methods
- Extend `currency_manager.gd` for persistent storage (save files)
