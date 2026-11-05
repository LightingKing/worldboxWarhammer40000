using System;
using System.Collections.Generic;
using System.Reflection;

namespace FortyKBox;

/// <summary>
/// Registers each <see cref="CivDefinition"/> as a full WorldBox
/// civilization: a nomad and a civ kingdom asset, the species, and its spawn
/// power.
///
/// NML runs this after the game's asset libraries have finished their
/// post_init and linkAssets passes, so every per-asset setup step those
/// passes would have done for a vanilla civ is repeated here by hand.
/// </summary>
internal static class CivRegistrar
{
    private const BindingFlags Private = BindingFlags.Instance | BindingFlags.NonPublic;

    private static readonly MethodInfo LoadTexturesAndSprites =
        typeof(ActorAssetLibrary).GetMethod("loadTexturesAndSprites", Private);
    private static readonly MethodInfo LoadShadow =
        typeof(ActorTextureSubAsset).GetMethod("loadShadow", Private);
    private static readonly MethodInfo NewWildKingdom =
        typeof(WildKingdomsManager).GetMethod("newWildKingdom", Private);

    public static readonly List<CivDefinition> Registered = new List<CivDefinition>();

    public static int RegisterAll(Action<string> log)
    {
        if (LoadTexturesAndSprites == null || LoadShadow == null || NewWildKingdom == null)
            throw new MissingMethodException("A WorldBox setup method moved; this game version is not supported.");

        int count = 0;
        foreach (CivDefinition civ in Civs.All)
        {
            // A species without walk_0 crashes the renderer on first draw.
            if (!HasWalkFrames(civ.BodyPath))
            {
                log("Skipped " + civ.Id + ": no body sprites at " + civ.BodyPath + ".");
                continue;
            }

            bool hasChild = HasWalkFrames(civ.ChildPath);
            RegisterKingdoms(civ);
            RegisterSpecies(civ, hasChild, log);
            RegisterSpawnPower(civ);
            Registered.Add(civ);
            count++;
            log("Registered civilization " + civ.Id + " (cloned from " + civ.Template + (hasChild ? ", with children" : ", adults only") + ").");
        }

        // Cloning drops [NonSerialized] links (architecture_asset, spells,
        // color). The library's own link pass resolves them from the ids and
        // is safe to run again over the vanilla assets.
        AssetManager.actor_library.linkAssets();
        return count;
    }

    private static bool HasWalkFrames(string path)
    {
        foreach (UnityEngine.Sprite sprite in SpriteTextureLoader.getSpriteList(path, true) ?? new UnityEngine.Sprite[0])
        {
            if (sprite.name == "walk_0")
                return true;
        }
        return false;
    }

    private static void RegisterKingdoms(CivDefinition civ)
    {
        // Same shape as vanilla nomads_human -> human: the civ kingdom is a
        // clone of the nomad kingdom with civ switched on.
        KingdomAsset nomads = AssetManager.kingdoms.clone(civ.NomadKingdomId, "$TEMPLATE_NOMAD$");
        nomads.group_main = true;
        nomads.default_kingdom_color = ColorAsset.tryMakeNewColorAsset(civ.ColorHex);
        nomads.setIcon(civ.IconPath);
        nomads.addTag(civ.Id);
        if (civ.Organic)
            nomads.addTag("sliceable");
        nomads.addFriendlyTag(civ.Id);

        KingdomAsset kingdom = AssetManager.kingdoms.clone(civ.Id, civ.NomadKingdomId);
        kingdom.group_main = true;
        kingdom.setIcon(civ.IconPath);
        kingdom.civ = true;
        kingdom.mobs = false;
        // Vanilla civ kingdoms clear their colour and fall back to the shared
        // default; borrow it from the human kingdom that already has it.
        kingdom.default_kingdom_color = AssetManager.kingdoms.get("human").default_kingdom_color;

        foreach (KingdomAsset asset in new[] { nomads, kingdom })
        {
            // KingdomLibrary.post_init did this for every vanilla kingdom.
            asset.addTag("everyone");
            foreach (KingdomAsset other in AssetManager.kingdoms.list)
            {
                if (other.friendship_for_everyone && !other.brain)
                    asset.addFriendlyTag(other.id);
            }

            // Wild kingdom objects are only built once, in MapBox.Awake.
            NewWildKingdom.Invoke(World.world.kingdoms_wild, new object[] { asset });
        }
    }

    private static void RegisterSpecies(CivDefinition civ, bool hasChild, Action<string> log)
    {
        ActorAsset asset = AssetManager.actor_library.clone(civ.Id, civ.Template);
        asset.name_locale = civ.Id;
        asset.power_id = civ.Id;
        asset.icon = "w40k/" + civ.Id;
        asset.color_hex = civ.ColorHex;
        asset.kingdom_id_civilization = civ.Id;
        asset.kingdom_id_wild = civ.NomadKingdomId;
        asset.name_taxonomic_genus = civ.Genus;
        asset.name_taxonomic_species = civ.Species;
        if (civ.BaseCities.HasValue)
            asset.civ_base_cities = civ.BaseCities.Value;

        // The zombie_<id> species is generated only at game start, so a mod
        // species would turn into an asset that does not exist.
        asset.can_turn_into_zombie = false;

        ApplyBody(civ, asset, hasChild);

        foreach (string trait in civ.CultureTraits)
            asset.addCultureTrait(trait);
        foreach (string trait in civ.SubspeciesTraits)
            asset.addSubspeciesTrait(trait);
        ScaleGenome(civ, asset, log);
    }

    /// <summary>
    /// Scales genome parts on the clone. The set is copied first so the
    /// template species keeps its own values.
    /// </summary>
    private static void ScaleGenome(CivDefinition civ, ActorAsset asset, Action<string> log)
    {
        if (civ.GenomeMultipliers.Count == 0)
            return;
        asset.genome_parts = new HashSet<GenomePart>(asset.genome_parts);
        List<string> changes = new List<string>();
        foreach (KeyValuePair<string, float> scale in civ.GenomeMultipliers)
        {
            if (!asset.genome_parts.TryGetValue(new GenomePart(scale.Key, 0f), out GenomePart part))
            {
                log("Genome of " + civ.Template + " has no '" + scale.Key + "'; " + civ.Id + " keeps it unchanged.");
                continue;
            }
            asset.genome_parts.Remove(part);
            asset.genome_parts.Add(new GenomePart(scale.Key, part.value * scale.Value));
            changes.Add(scale.Key + " " + part.value + "->" + part.value * scale.Value);
        }
        log("Genome of " + civ.Id + ": " + string.Join(", ", changes) + ".");
    }

    /// <summary>
    /// Points the species at its own single-sheet body: one "main" folder of
    /// walk/swim frames with the head drawn in, under
    /// actors/species/civs/&lt;id&gt;/main. Without advanced textures every
    /// adult role (citizen, warrior, king) uses that sheet; babies use the
    /// sibling "child" sheet when the civ has one.
    /// </summary>
    private static void ApplyBody(CivDefinition civ, ActorAsset asset, bool hasChild)
    {
        asset.texture_id = civ.Id;
        asset.has_advanced_textures = false;
        // Without a child sheet babies would have no body, so such a civ is
        // born adult. Child heads are drawn in, never composited.
        asset.has_baby_form = hasChild;
        asset.render_heads_for_babies = false;
        asset.use_phenotypes = civ.UsePhenotypes;
        // UI previews read the first entry of these; all must name the sheet.
        asset.skin_citizen_male = new[] { "main" };
        asset.skin_citizen_female = new[] { "main" };
        asset.skin_warrior = new[] { "main" };
        asset.animation_walk = ActorAnimationSequences.walk_0_3;
        asset.animation_idle = ActorAnimationSequences.walk_0;
        asset.animation_swim = ActorAnimationSequences.swim_0_3;

        // The clone still carries the template's texture sub-asset. Clear it
        // and let the library build ours exactly as it does at startup.
        asset.texture_asset = null;
        LoadTexturesAndSprites.Invoke(AssetManager.actor_library, new object[] { asset });
        LoadShadow.Invoke(asset.texture_asset, null);
    }

    private static void RegisterSpawnPower(CivDefinition civ)
    {
        // spawnUnit looks the power up by the button id, so the power id,
        // the button name and the species id are all the same string.
        GodPower power = AssetManager.powers.clone(civ.Id, "$template_spawn_actor$");
        power.name = civ.Id;
        power.actor_asset_id = civ.Id;
        power.path_icon = civ.IconPath;
        power.requires_premium = false;
    }
}
