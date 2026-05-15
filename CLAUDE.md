# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow rules

- **Never offer to commit or push** unless the user explicitly asks (e.g. "commit", "push", "commit and push"). Do not suggest it at the end of a task.

## Project

Godot 4.6 prototype — top-down road-race game. Engine: mobile renderer, 1024×768 viewport, canvas_items stretch. No tests, no linter; iteration happens by running the game in the Godot editor.

## Running and building

**Run:** Open `project.godot` in Godot 4.6 and press F5, or use the editor's Play button.

**Export to Windows:** `Project → Export… → Windows Desktop → Export Project`. Output goes to `build/windows/RoadRace.exe`. The export preset is already configured in `export_presets.cfg`; you just need the Windows Desktop export template installed (`Editor → Manage Export Templates`).

There is no CLI build command — Godot exports are driven from the editor UI.

## Architecture

All game logic lives in `scripts/`, all assets in `assets/`, the single scene in `scenes/main.tscn`.

### Scene tree (`scenes/main.tscn`)
```
Main (Node2D)          ← main.gd: wires signals, updates HUD, handles restart
  Road (Node2D)        ← road.gd: draws everything via _draw()
  ObstacleManager      ← obstacle_manager.gd: spawns/moves/draws obstacles
  Car (Node2D)         ← car.gd: player input, speed, clamped lateral movement
    Sprite2D           ← car.png at scale 2× (84×128 px on screen)
  DayNight (CanvasLayer, layer=1)  ← day_night.gd: fullscreen color overlay
  HUD (CanvasLayer, layer=2)       ← SpeedLabel top-right
  GameOverlay (CanvasLayer, layer=3, hidden) ← shown on collision
```

### Rendering approach
The game uses **zero physics nodes** — everything is drawn with `Node2D._draw()` / `draw_rect` / `draw_texture` / `draw_set_transform`. `queue_redraw()` is called every `_process` frame.

- **Road** draws: grass fill → tiled asphalt (64×64 `asphalt.png`, random 0/90/180/270° rotations fixed per world-row) → grass overdraw to clip tile spillover → white shoulder lines → dashed yellow lane dividers.
- **ObstacleManager** draws: `HondaCivic.png` scaled 1.5× (96×96 px) centered on lane positions via `draw_set_transform`.

### Scrolling model
`Car.speed_kmh` (50–220) drives everything:
- Road scroll = `speed_kmh * KMH_TO_PXS` px/s (road moves down, car appears stationary).
- Obstacle scroll = `(speed_kmh − OBS_SPEED_KMH) * KMH_TO_PXS` px/s (relative speed; obstacles move slower, so they approach the player).

`KMH_TO_PXS = 5.0` is defined on `Car` and accessed by `Road` and `ObstacleManager` via `_car.KMH_TO_PXS` (Node2D reference, requires `var scroll: float = _car.speed_kmh * _car.KMH_TO_PXS` with explicit `: float` annotation to satisfy GDScript type inference).

### Collision
Pixel-perfect: alpha masks (`PackedByteArray`) are built at startup from the raw PNG files for both `HondaCivic.png` (obstacle) and `car.png` (player). Each frame, when bounding boxes overlap, `_pixel_collision()` walks the intersection region at 2-px steps checking both masks. Hit → `hit_detected` signal → `main.gd` freezes car and shows GameOverlay.

### Tile stability invariant
Asphalt tile rotation is a pure function of **world position**, not screen position:
```gdscript
var world_row := posmod(floori((ty - _world_scroll) / float(TILE_SIZE)), TILE_ROWS)
```
Never derive tile index from a per-frame screen counter — that causes tiles to "dance" (change rotation while on screen).

### Day-night cycle
`day_night.gd` runs a 60-second loop (20s day → 10s dusk → 20s night → 10s dawn) and lerps a fullscreen `ColorRect` overlay through transparent → warm orange → dark blue. The overlay sits at CanvasLayer layer=1; HUD is layer=2; GameOverlay is layer=3.

## GDScript gotchas in this codebase

- Accessing properties on a `Node2D`-typed variable loses type info — always annotate the result: `var x: float = _car.speed_kmh * _car.KMH_TO_PXS`.
- `i / 3.0` inside an untyped `for i in [1, 2]` loop also needs `var cx: float = ...`.
- Edit `.tscn` files carefully — Godot regenerates UIDs on open, but missing `unique_id` or malformed node entries will silently break the scene.
