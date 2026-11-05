# 40KBox unit sprite spec

In-world unit bodies for the four 40KBox civilizations. These are the tiny
people walking around the WorldBox map, not icons. They must read like
vanilla WorldBox units at vanilla scale.

## Source format

One JSON file per civ in `art/sprites/<civ_id>.json`. The Godot pipeline
(`godot/`) turns it into game files; never hand-edit the generated PNGs.

```json
{
  "id": "w40k_imperium",
  "size": [10, 10],
  "palette": {
    ".": "clear",
    "K": "K0", "k": "K2", "q": "K4",
    "s": "S0", "z": "S2",
    "h": "#5A5F3C"
  },
  "frames": {
    "walk_0": { "item": [1, 4], "rows": ["..........", "... 10 rows, top row first ..."] },
    "walk_1": { "item": [1, 7], "rows": [] },
    "walk_2": { "item": [1, 6], "rows": [] },
    "walk_3": { "item": [1, 4], "rows": [] }
  }
}
```

- `rows` is top row first. Every row is exactly `size[0]` characters and
  every frame has exactly `size[1]` rows.
- Every character used in a row must be defined in `palette`.
- `item` is where the unit's held weapon is drawn: `[x, y]` with x counted
  from the LEFT edge and y counted from the BOTTOM row (bottom row is y = 0).
  It is the lowest pixel of a 1x3 grip column, normally the front hand.
- Swim frames are generated from the walk frames. Do not draw them.

## Child body

Every civ also has a child body, drawn in an optional `child` object in the
same file. It shares the palette with the adult and has its own canvas:

```json
"child": {
  "size": [8, 8],
  "frames": {
    "walk_0": { "rows": ["... 8 rows of 8 ..."] },
    "walk_1": { "rows": [] },
    "walk_2": { "rows": [] },
    "walk_3": { "rows": [] }
  }
}
```

- Canvas 8x8, figure 5–6 px tall, feet on the bottom row, facing left.
- Same 4-frame walk with a smaller bob (frame 1 up 1 px, frames 0/2/3 on
  the ground is fine).
- `item` is optional for children; leave it out (children carry nothing).
- Must still show a visible kingdom-colour block and read as the same
  faction as the adult.

| Civ id | Child look |
| --- | --- |
| `w40k_imperium` | Scholam child: bare head with dark hair, skin face, small kingdom-coloured tunic |
| `w40k_ork` | Gretchin (grot): scrawny, big pointed ears, long nose, green hide (`S`), kingdom-coloured rag |
| `w40k_necron` | Canoptek scarab: low metal beetle, 4–5 px wide, 3–4 px tall, green glow pixel, kingdom-coloured shell plate, no `S` |
| `w40k_chaos` | Small hooded acolyte in a kingdom-coloured robe, 1 px of skin |

## Canvas and pose

- Canvas 10x10 (Orks may use 11x11). Vanilla humans are 10x10.
- The unit faces LEFT. Front hand and weapon on the left side.
- Feet stand on the bottom row (y = 0), horizontally centred around x = 4..5.
- Figure height 8 px including the head (Orks 9, Necrons 8–9).
- Four walk frames, `walk_0`..`walk_3`, a 4-step cycle like vanilla:
  frame 0 = contact, frame 1 = body raised 2 px (legs together / passing),
  frame 2 = raised 1 px, frame 3 = contact with the other leg forward.
  Vanilla grip heights per frame are y = 4, 7, 6, 4; follow the body's bob.
- The head is drawn into the body. There are no separate head sprites.
- No black outline. Vanilla units are flat colour blobs with 1 px detail.
  Silhouette first; at this size a helmet, a shoulder pad or a glowing eye is
  one or two pixels.

## Reserved colour keys

The game recolours these exact RGB values at runtime. Use them through the
palette keys, never as hex. Custom `#RRGGBB` colours must not equal any of
these (the pipeline rejects that).

| Key | Hex | Replaced by |
| --- | --- | --- |
| `K0`..`K4` | `#FF00FF #DE00DE #A700A7 #7F007F #580058` | Kingdom colour, light to dark |
| `J0`..`J4` | `#00EFEF #00DBDB #00BCBC #009E9E #007777` | Secondary kingdom colour |
| `S0`..`S3` | `#B8FF96 #00FF00 #00AF00 #4A831F` | Skin tone, light to dark |
| `L` | `#FFD800` | Light-emitting pixel |
| (none) | `#D1E3EB` | Water line, pipeline only |

- Kingdom colour is how the player tells kingdoms apart. Every civ must show
  a clear block of `K` colour (uniform, armour plates, cloak, banner cloth),
  roughly 25–40 % of the figure.
- Skin keys only where there is skin. Imperium and Chaos use `S` for faces.
  Orks use `S` for their green hide (the game tints it with orc skin tones).
  Necrons have no skin: never use `S` keys on Necrons.

## Faction briefs

| Civ id | Look | Kingdom colour on | Notes |
| --- | --- | --- | --- |
| `w40k_imperium` | Imperial Guardsman: rounded helmet, flak vest, greatcoat, lasgun | coat / vest | Helmet olive or grey, face skin `S`. |
| `w40k_ork` | Ork Boy: hunched, big jaw and tusks, small head low between shoulders, choppa | rags, shoulder plate | Hide uses `S` keys, 11x11 allowed, broader than humans. |
| `w40k_necron` | Necron Warrior: skeletal metal, thin limbs, skull head, green glowing eyes | chest plate / shoulder | Metal greys and bronze, eye pixel bright green `#3CFF6E`, no `S`. |
| `w40k_chaos` | Chaos Cultist: hooded robe, spiked shoulder, autogun | robe | Face mostly hidden by hood, 1–2 px skin `S`, red/brass accents. |

Concept paintings in `art/concept/unit_*.png` show the intended mood; they
are far too detailed to downscale, so redraw from scratch at 10x10.
Vanilla reference sheets (true size and x8) are in `art/reference/vanilla/`.

## Checking your work

```bash
godot --headless --path godot --script res://build_sprites.gd
```

This validates every `art/sprites/*.json`, writes the game files into
`src/FortyKBox/GameResources/actors/species/civs/<id>/main/`, and renders
`art/preview/<id>.png`: all frames at x8 in three different kingdom colour
schemes, plus a row at true size. Look at the preview before calling a
sprite done.
