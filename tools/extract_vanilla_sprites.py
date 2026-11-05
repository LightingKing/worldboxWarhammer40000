"""Extract vanilla WorldBox sprite sheets for local reference (not committed).

Usage: python -I tools/extract_vanilla_sprites.py OUT_DIR RESOURCE_PATH [RESOURCE_PATH ...]
Example: python -I tools/extract_vanilla_sprites.py art/reference/vanilla actors/species/civs/human/male_1

Reads the installed game's resources with UnityPy and writes each sheet at
true size and x8, plus a text file listing every slice (name, rect, pivot),
which is how frame sizes and grip/head marker positions were measured.
"""
import os
import sys

import UnityPy

GAME_DATA = r"H:\SteamLibrary\steamapps\common\worldbox\worldbox_Data"


def main():
    out, paths = sys.argv[1], sys.argv[2:]
    env = UnityPy.load(GAME_DATA)
    container = [o for o in env.objects if o.type.name == "ResourceManager"][0].read_typetree()["m_Container"]
    by_id = {o.path_id: o for o in env.objects if o.type.name in ("Texture2D", "Sprite")}
    for path in paths:
        ids = [ptr["m_PathID"] for key, ptr in container if key == path]
        folder = os.path.join(out, *path.split("/")[-2:])
        os.makedirs(os.path.dirname(folder) or ".", exist_ok=True)
        slices = []
        for pid in ids:
            obj = by_id.get(pid)
            if obj is None:
                continue
            if obj.type.name == "Texture2D":
                image = obj.read().image
                image.save(folder + ".png")
                image.resize((image.width * 8, image.height * 8), 0).save(folder + "_x8.png")
            else:
                tree = obj.read_typetree()
                r, p = tree["m_Rect"], tree.get("m_Pivot", {})
                slices.append(f"{tree['m_Name']} rect=({r['x']:.0f},{r['y']:.0f},{r['width']:.0f},{r['height']:.0f}) "
                              f"pivot=({p.get('x', 0):.3f},{p.get('y', 0):.3f})")
        with open(folder + "_slices.txt", "w", encoding="utf-8") as handle:
            handle.write("\n".join(sorted(slices)) + "\n")
        print(path, len(slices), "slices")


if __name__ == "__main__":
    main()
