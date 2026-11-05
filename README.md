# 40KBox

Warhammer 40K civilizations for WorldBox 0.51.2 (NeoModLoader 1.2). The
Imperium, Orks, Necrons and Chaos are real WorldBox civs: they found
kingdoms, build cities, grow, and go to war on their own. Spawn them from the
40KBox power tab.

## Layout

```text
src/FortyKBox/        the mod (net48): civ registration, power tab, locales
  GameResources/      generated sprites and icons (do not edit by hand)
art/sprites/*.json    unit sprite sources, one per civ; spec in art/SPRITE_SPEC.md
art/preview/          rendered previews of the sprites
godot/                build-time sprite pipeline (Godot 4.7, headless)
tools/                deploy, balance runs, window capture/click helpers, sprite extraction
```

Two research folders are local-only and not in the repository, because they
hold WorldBox's own code and art: `reference/decomp/` (decompile
`worldbox_Data/Managed/Assembly-CSharp.dll` with `ilspycmd -t <Type>`) and
`art/reference/vanilla/` (regenerate with `tools/extract_vanilla_sprites.py`).

## Build and deploy

Close WorldBox, then:

```bash
pwsh -NoProfile -File tools/deploy.ps1
```

This renders the sprites, builds the mod, moves the previous install to
`40KBox-backups`, and copies a clean package into `Mods/40KBox`. WorldBox
Experimental Mode must be on for NML to load mods.

## Live check and balance runs

Launch with `40KBOX_PROBE=1` in the environment. The probe closes the main
menu (the world is paused behind it), spawns eight units of every civ through
their god powers, sets the world to x10 and logs units, babies, kingdoms,
cities and buildings per civ every 30 seconds to
`%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\Player.log`.

For balance, run several unattended games with rotated start positions and
get a summary table:

```bash
python -I tools/balance_runs.py OUT_DIR --runs 4 --minutes 6
```

## How a civ is registered

Each civ clones a vanilla civ species (human, orc or dwarf), so it inherits a
working architecture, build order, boats, banner and name sets. Because NML
loads mods after the game's own setup passes, `CivRegistrar` repeats those
steps by hand: nomad and civ kingdom assets plus their wild kingdom objects,
the species' own texture sub-asset and shadow, and a re-link of the actor
library. Bodies use one `main` sheet per civ with the head drawn in.
