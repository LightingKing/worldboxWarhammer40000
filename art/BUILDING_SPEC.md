# 40KBox building sprite spec

City buildings for the four 40KBox civilizations. Each civ has its own
architecture; any building it has no art for falls back to the vanilla
sprite, so art can land a few buildings at a time.

## Source format

One JSON file per civ in `art/buildings/<civ_id>.json`. You draw only the
finished building (`main`); the Godot pipeline generates the ruin, the
construction scaffold and the tiny map icon from it.

```json
{
  "id": "w40k_imperium",
  "palette": {
    ".": "clear",
    "K": "K0", "k": "K2", "q": "K4",
    "L": "L",
    "s": "#8C8C8C"
  },
  "buildings": {
    "tent":    { "rows": ["... 8 rows of 8 ..."] },
    "house_0": { "rows": ["... 13 rows of 14 ..."] }
  }
}
```

- `rows` is top row first; every row has the same length. The canvas size is
  taken from the rows and must be within 2 px of the size in the table below
  (the building's footprint on the map is fixed).
- One palette for the whole file. Same palette rules as units
  (`art/SPRITE_SPEC.md`): one-character keys, `clear`, reserved keys, or
  `#RRGGBB` that is not a reserved colour.
- Stand the building on the bottom 1–2 rows (foundation / ground shadow),
  like vanilla; the game anchors the sprite 10 % above its bottom edge.
- Front view with a slight top-down tilt, like vanilla: roof on top, front
  wall with door and windows below. No black outline; use a darker shade of
  each material on edges.

## Colour keys

| Key | Hex | Use |
| --- | --- | --- |
| `K0`..`K4` | `#FF00FF #DE00DE #A700A7 #7F007F #580058` | Kingdom colour. Vanilla puts it on roofs; every building must show a clear block of it (roof, banners, cloth), roughly 20–35 % of the opaque pixels |
| `J0`..`J4` | `#00EFEF ..` `#007777` | Secondary kingdom colour, optional small trims |
| `L` | `#FFD800` | Light: lit windows, fires, glowing runes. They glow at night |

Skin keys (`S0`..`S3`) are not used on buildings.

## Buildings and sizes

Draw all thirteen. Size is width x height in pixels (vanilla human size).

| Key | Size | Notes |
| --- | --- | --- |
| `tent` | 8x8 | first shelter of a new village |
| `house_0` | 14x13 | smallest house |
| `house_1` | 15x16 | |
| `house_2` | 16x18 | |
| `house_3` | 18x18 | |
| `house_4` | 23x19 | wider, two parts |
| `house_5` | 24x24 | biggest house |
| `hall_0` | 29x24 | town hall, capital building |
| `hall_1` | 29x30 | |
| `hall_2` | 33x33 | the grandest building of the civ |
| `watch_tower` | 11x25 | tall and narrow, shoots at enemies |
| `barracks` | 28x29 | military |
| `temple` | 24x33 | religious |

Houses 0→5 and halls 0→2 are upgrade chains: each step should read as a
bigger, richer version of the previous one, in the same style.

## Faction styles

| Civ id | Materials | Signature details |
| --- | --- | --- |
| `w40k_imperium` | grey ferrocrete and stone, dark slate, brass | gothic arches and spires, kingdom-coloured roofs and banners, lit windows (`L`), a small skull or aquila on halls and the temple |
| `w40k_ork` | rusty corrugated scrap (rust, brown, dull grey), wood, rivets | crooked shacks, bolted plates, spikes, smoke stacks, crude kingdom-coloured glyph banners, fires (`L`) |
| `w40k_necron` | black/gunmetal stone, dull gold trim | pyramids, obelisks and monoliths, glowing green lines and eyes (`#3CFF6E`, never `L` for green), kingdom-coloured panels; tent = small obelisk, halls = step-pyramid tomb |
| `w40k_chaos` | dark stone, black iron, brass, dried-blood red | spikes and horns, eight-pointed star, kingdom-coloured banners and cloth, braziers (`L`) |

The four civs must be recognisable at a glance from each other and from
vanilla buildings.

## Checking your work

```bash
godot --headless --path godot --script res://build_sprites.gd
```

validates `art/buildings/*.json` along with the units, writes the game files
under `src/FortyKBox/GameResources/buildings/civ_main/<civ>/`, and renders
`art/preview/buildings_<civ>.png` (each building x4 in three kingdom
schemes, plus the generated ruin, construction and map icon).
