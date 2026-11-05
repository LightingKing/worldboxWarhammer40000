using System.Collections.Generic;

namespace FortyKBox;

/// <summary>
/// One 40K faction as a WorldBox civilization. Each civ is a clone of a
/// vanilla civ species, so it inherits a complete, working city builder
/// (architecture, build order, boats, banner, name sets) and only overrides
/// identity, body sprites and flavour.
/// </summary>
internal sealed class CivDefinition
{
    public string Id;

    /// <summary>Vanilla species to clone: human, orc or dwarf.</summary>
    public string Template;

    /// <summary>Faction colour for the species UI and the nomad kingdom.</summary>
    public string ColorHex;

    /// <summary>Whether the body's skin keys take the template's skin tones.</summary>
    public bool UsePhenotypes = true;

    /// <summary>Organic species can be sliced by vanilla effects.</summary>
    public bool Organic = true;

    public string Genus;
    public string Species;

    public string[] CultureTraits = new string[0];
    public string[] SubspeciesTraits = new string[0];

    /// <summary>
    /// Multipliers on the template's genome (health, damage, speed, lifespan,
    /// offspring...). Civ stats come from genes generated from the genome,
    /// not from ActorAsset.base_stats, which has no such keys for civs.
    /// </summary>
    public Dictionary<string, float> GenomeMultipliers = new Dictionary<string, float>();

    public int? BaseCities;

    public string NomadKingdomId => "nomads_" + Id;
    public string IconPath => "ui/Icons/w40k/" + Id;
    public string BodyPath => "actors/species/civs/" + Id + "/main";
    public string ChildPath => "actors/species/civs/" + Id + "/child";
}

internal static class Civs
{
    // Orc and dwarf genomes start at 150 health with combat traits, humans at
    // 100. Balance runs showed growth is even for ~25 years and then wars
    // decide everything, so per-unit strength is pulled to roughly 125-140.
    public static readonly CivDefinition[] All =
    {
        new CivDefinition
        {
            Id = "w40k_imperium",
            Template = "human",
            ColorHex = "#C9A227",
            Genus = "imperialis",
            Species = "terrae",
            // Disciplined builders with sturdier troops. join_or_die put them
            // at war with everyone; they died out in every start position.
            CultureTraits = new[] { "xenophobic" },
            SubspeciesTraits = new[] { "fast_builders" },
            GenomeMultipliers = new Dictionary<string, float> { ["health"] = 1.4f, ["damage"] = 1.2f },
        },
        new CivDefinition
        {
            Id = "w40k_ork",
            Template = "orc",
            ColorHex = "#6E8B23",
            Genus = "orkoid",
            Species = "waaagh",
            CultureTraits = new[] { "happiness_from_war", "axe_lovers" },
            // Vanilla orcs already breed fast and fight hard; enhanced_strength
            // and high_fecundity on top made them win most balance games.
            SubspeciesTraits = new[] { "aggressive" },
            GenomeMultipliers = new Dictionary<string, float> { ["health"] = 0.9f },
        },
        new CivDefinition
        {
            Id = "w40k_necron",
            Template = "dwarf",
            ColorHex = "#2FBF71",
            UsePhenotypes = false,
            Organic = false,
            Genus = "necrontyr",
            Species = "aeterna",
            CultureTraits = new[] { "xenophobic", "elder_reverence" },
            // Armoured, slow and few. The dwarf template's 220-year lifespan
            // (plus extra lifespan, a stone diet and every biome) snowballed.
            SubspeciesTraits = new[] { "exoskeleton" },
            GenomeMultipliers = new Dictionary<string, float> { ["health"] = 0.9f, ["lifespan"] = 0.5f, ["speed"] = 0.85f },
        },
        new CivDefinition
        {
            Id = "w40k_chaos",
            Template = "human",
            ColorHex = "#8B1A1A",
            Genus = "corruptus",
            Species = "warpborn",
            // Hits hard, fights everyone. join_or_die left them at war with
            // the whole map.
            CultureTraits = new[] { "happiness_from_war" },
            SubspeciesTraits = new[] { "aggressive", "unstable_genome" },
            GenomeMultipliers = new Dictionary<string, float> { ["health"] = 1.25f, ["damage"] = 1.35f },
        },
    };
}
