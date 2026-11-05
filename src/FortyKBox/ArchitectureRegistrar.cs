using System;
using System.Collections.Generic;

namespace FortyKBox;

/// <summary>
/// Gives a civ its own architecture by cloning the template species'
/// architecture and every building it styles (tent, houses, halls, docks,
/// windmills, tower, temple...), renamed to the civ id with the upgrade
/// chains relinked. A building with its own art under
/// buildings/civ_main/&lt;civ&gt;/&lt;building&gt; uses it; any other keeps the
/// template's sprites, so art can be added a few buildings at a time.
///
/// Like the species, these clones are made after the game's own post_init
/// and link passes, so the per-building setup those passes do is repeated.
/// </summary>
internal static class ArchitectureRegistrar
{
    /// <summary>Registers the architecture; returns how many buildings use custom art.</summary>
    public static int Register(CivDefinition civ, string templateArchitecture, Action<string> log)
    {
        ArchitectureAsset template = AssetManager.architecture_library.get(templateArchitecture);
        ArchitectureAsset architecture = AssetManager.architecture_library.clone(civ.Id, templateArchitecture);

        // Order -> building map, e.g. order_house_2 -> house_<civ>_2. Shared
        // orders (bonfire, well, statue...) keep their common buildings.
        architecture.building_ids_for_construction = new Dictionary<string, string>();
        int custom = 0;
        HashSet<string> cloned = new HashSet<string>();
        foreach (KeyValuePair<string, string> order in template.building_ids_for_construction)
        {
            string styled = Restyle(order.Value, templateArchitecture, civ.Id);
            architecture.building_ids_for_construction[order.Key] = styled ?? order.Value;
            if (styled != null && cloned.Add(styled) && CloneBuilding(order.Value, styled, templateArchitecture, civ))
                custom++;
        }

        log("Architecture " + civ.Id + ": " + cloned.Count + " buildings cloned from " + templateArchitecture +
            ", " + custom + " with custom art.");
        return custom;
    }

    /// <summary>
    /// house_human_2 -> house_&lt;civ&gt;_2, docks_human -> docks_&lt;civ&gt;;
    /// null for ids that are not styled by the template architecture.
    /// </summary>
    private static string Restyle(string buildingId, string templateArchitecture, string civId)
    {
        if (string.IsNullOrEmpty(buildingId))
            return null;
        string suffix = "_" + templateArchitecture;
        if (buildingId.EndsWith(suffix, StringComparison.Ordinal))
            return buildingId.Substring(0, buildingId.Length - suffix.Length) + "_" + civId;
        string infix = suffix + "_";
        int at = buildingId.IndexOf(infix, StringComparison.Ordinal);
        if (at >= 0)
            return buildingId.Substring(0, at) + "_" + civId + "_" + buildingId.Substring(at + infix.Length);
        return null;
    }

    private static bool CloneBuilding(string sourceId, string id, string templateArchitecture, CivDefinition civ)
    {
        BuildingAsset source = AssetManager.buildings.get(sourceId);
        BuildingAsset building = AssetManager.buildings.clone(id, sourceId);
        building.main_path = "buildings/civ_main/" + civ.Id + "/";
        building.group = civ.Id;
        building.civ_kingdom = civ.Id;
        building.upgrade_to = Restyle(source.upgrade_to, templateArchitecture, civ.Id) ?? source.upgrade_to;
        building.upgraded_from = Restyle(source.upgraded_from, templateArchitecture, civ.Id) ?? source.upgraded_from;

        // [NonSerialized] state BuildingLibrary.linkAssets set on the source.
        building.atlas_asset = source.atlas_asset;
        building.has_step_action = source.has_step_action;
        building.has_get_map_icon_color = source.has_get_map_icon_color;
        building.has_biome_tags = source.has_biome_tags;
        building.has_biome_tags_spread = source.has_biome_tags_spread;

        // Sprites load lazily from sprite_path, or main_path + id when empty.
        building.sprites_are_initiated = false;
        building.building_sprites = null;
        bool hasArt = HasMainSprite(building.main_path + id);
        building.sprite_path = hasArt
            ? string.Empty
            : string.IsNullOrEmpty(source.sprite_path) ? source.main_path + source.id : source.sprite_path;
        return hasArt;
    }

    private static bool HasMainSprite(string path)
    {
        foreach (UnityEngine.Sprite sprite in SpriteTextureLoader.getSpriteList(path, true) ?? new UnityEngine.Sprite[0])
        {
            if (sprite.name == "main_0")
                return true;
        }
        return false;
    }
}
