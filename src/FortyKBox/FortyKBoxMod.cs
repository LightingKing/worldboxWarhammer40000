using System;
using NeoModLoader.api;
using NeoModLoader.General;
using NeoModLoader.General.UI.Tab;
using UnityEngine;

namespace FortyKBox;

/// <summary>
/// NML entry point. Assets are registered in OnModLoad, which NML calls once
/// the game libraries are fully initialised; the power tab is built in Start,
/// after the toolbar UI exists.
/// </summary>
public sealed class FortyKBoxMod : BasicMod<FortyKBoxMod>
{
    private const string TabId = "40KBox";

    private bool _registered;

    protected override void OnModLoad()
    {
        try
        {
            int civs = CivRegistrar.RegisterAll(LogInfo);
            _registered = civs > 0;
            LogInfo("Registered " + civs + " civilizations.");
        }
        catch (Exception exception)
        {
            LogError("40KBox registration failed: " + exception);
        }
    }

    private void Start()
    {
        // NML can apply mod locales before the game has chosen its language;
        // re-applying here installs them for the language actually in use.
        LM.ApplyLocale();

        if (!_registered)
            return;

        try
        {
            PowersTab tab = TabManager.CreateTab(TabId, "tab_40kbox", "tab_40kbox_description",
                SpriteTextureLoader.getSprite("ui/Icons/w40k/tab"));
            foreach (CivDefinition civ in CivRegistrar.Registered)
            {
                PowerButton button = PowerButtonCreator.CreateGodPowerButton(civ.Id, SpriteTextureLoader.getSprite(civ.IconPath));
                PowerButtonCreator.AddButtonToTab(button, tab);
            }
            LogInfo("Added the 40KBox power tab with " + CivRegistrar.Registered.Count + " spawn buttons.");
        }
        catch (Exception exception)
        {
            LogError("40KBox power tab failed: " + exception);
        }

        if (DebugProbe.Enabled)
        {
            LogInfo("Probe enabled.");
            InvokeRepeating(nameof(ProbeTick), 5f, 5f);
        }
    }

    private void ProbeTick()
    {
        try { DebugProbe.Tick(LogInfo); }
        catch (Exception exception) { LogError("Probe failed: " + exception); }
    }
}
