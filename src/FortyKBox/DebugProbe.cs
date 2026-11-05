using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace FortyKBox;

/// <summary>
/// Opt-in live check, enabled by the environment variable 40KBOX_PROBE=1.
/// Closes the startup menu (the world is paused behind it), spawns a group of
/// every registered civ through its real god power, speeds the world up, and
/// logs population, kingdoms, cities and buildings per civ, so a balance run
/// can be judged from Player.log alone.
///
/// 40KBOX_PROBE_ROTATE=k shifts which band of the map each civ starts in, so
/// several runs give every civ every start. 40KBOX_PROBE_SPEED picks a world
/// speed id (default x10).
/// </summary>
internal static class DebugProbe
{
    private const int UnitsPerCiv = 8;
    private const float ReportInterval = 30f;

    private static bool _started;
    private static float _nextReport;
    private static int _startYear;

    public static bool Enabled => Env("40KBOX_PROBE") == "1";

    private static string Env(string name) => Environment.GetEnvironmentVariable(name);

    /// <summary>Called every few seconds; does nothing until the map is ready.</summary>
    public static void Tick(Action<string> log)
    {
        if (!_started)
        {
            if (ScrollWindow.isWindowActive())
            {
                ScrollWindow.hideAllEvent(false);
                return;
            }
            if (!SpawnGroups(log))
                return;
            _started = true;
            _startYear = Date.getCurrentYear();
            Config.setWorldSpeed(Env("40KBOX_PROBE_SPEED") ?? "x10");
            _nextReport = UnityEngine.Time.realtimeSinceStartup + ReportInterval;
            log("Probe: started in year " + _startYear + " at speed " + Config.time_scale_asset?.id + ".");
            return;
        }

        if (UnityEngine.Time.realtimeSinceStartup >= _nextReport)
        {
            _nextReport += ReportInterval;
            Report(log);
        }
    }

    private static bool SpawnGroups(Action<string> log)
    {
        FieldInfo tilesField = typeof(MapBox).GetField("tiles_list", BindingFlags.Instance | BindingFlags.NonPublic);
        WorldTile[] tiles = tilesField?.GetValue(World.world) as WorldTile[];
        if (tiles == null || tiles.Length == 0)
            return false;

        // Plain walkable land, sorted west to east, so each civ starts in its
        // own band of the map instead of on top of the others.
        List<WorldTile> land = tiles
            .Where(t => t.Type.ground && !t.Type.liquid && !t.Type.block && !t.Type.mountains && !t.Type.lava)
            .OrderBy(t => t.x)
            .ToList();
        if (land.Count == 0)
            return false;

        int.TryParse(Env("40KBOX_PROBE_ROTATE"), out int rotate);
        List<CivDefinition> civs = CivRegistrar.Registered;
        for (int i = 0; i < civs.Count; i++)
        {
            CivDefinition civ = civs[i];
            int band = (i + rotate) % civs.Count;
            WorldTile tile = land[(int)((band + 0.5f) / civs.Count * (land.Count - 1))];
            GodPower power = AssetManager.powers.get(civ.Id);
            int spawned = 0;
            for (int n = 0; n < UnitsPerCiv; n++)
            {
                if (power.click_action(tile, civ.Id))
                    spawned++;
            }
            log("Probe: spawned " + spawned + "/" + UnitsPerCiv + " " + civ.Id + " in band " + band + " at " + tile.x + "," + tile.y + ".");
        }
        return true;
    }

    private static void Report(Action<string> log)
    {
        int years = Date.getCurrentYear() - _startYear;
        foreach (CivDefinition civ in CivRegistrar.Registered)
        {
            List<Actor> units = World.world.units.Where(a => a.asset != null && a.asset.id == civ.Id).ToList();
            int babies = units.Count(a => a.isBaby());
            int kingdoms = World.world.kingdoms.Count(k => k.asset != null && k.asset.id == civ.Id);
            List<City> cities = World.world.cities.Where(c => c.getActorAsset()?.id == civ.Id).ToList();
            int buildings = cities.Sum(c => c.countBuildings());
            log("Probe: year+" + years + " " + civ.Id + " units=" + units.Count + " babies=" + babies +
                " kingdoms=" + kingdoms + " cities=" + cities.Count + " buildings=" + buildings + ".");
        }
    }
}
