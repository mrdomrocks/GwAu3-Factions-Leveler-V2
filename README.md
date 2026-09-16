# Gwau3 Factions Leveler V2

Port of the Py4GW Factions Character Leveler into GwAu3 AutoIt3. Covers Shing Jea through the post-20 unlocks (Kilroy, Lion's Arch, Kamadan, Olias, GToB, and the Assassin/Mesmer Vaettir NPC).

## Install

Copy these files into a GwAu3 checkout at:

`Scripts/FactionsLeveler/`

The main script includes `../../API/_GwAu3.au3` and uses the vendored Pathfinder plugin (`API/Plugins/Pathfinder/GWPathfinder.dll`).

Wine/Linux attach needs the GwAu3 API Wine-compat patches in `API/Core/GwAu3_Core_Scanner.au3` and `API/Core/GwAu3_Core.au3` (local scanner, `g_b_ScannerUseLocal`, skip GitHub updater). This script sets those flags; it does not replace the API patches.

## Run

1. Launch Guild Wars and log the Factions character in.
2. Run `Factions_Character_Leveler.au3` with AutoIt3 x86 (admin).
3. Pick the character, click Start. Refresh re-detects the next incomplete step.

## Wine / Linux (wine-gw)

Run AutoIt3 x86 **inside the same Wine prefix** as `Gw.exe` (both PE32). Example:

```
WINEPREFIX=~/.wine-gw wine /path/to/AutoIt3.exe Factions_Character_Leveler.au3
```

Under Wine the client window title is often `Guild Wars Reforged`, not `Guild Wars - <character>`. V2 therefore:

- Detects Wine (`ntdll.wine_get_version`, `HKCU\Software\Wine`, `WINEPREFIX`) or honors `ForceWineCompat=1`.
- Sets `g_b_ScannerUseLocal`, scanner timeout, and skips the GitHub updater before any scan.
- Skips `Scanner_GetLoggedCharNames` on Wine. That call `Memory_Close()`s the process and can cache a **0/78** local pattern scan (`ScanAgentBasePtr`, `ScanMyIDPtr`, `ScanEngineHook`, `ScanMoveFunc`, `ScanBasePointerPtr`), after which the patched scanner skips the critical rescan.
- **Start calls `Core_Initialize` immediately** from the button (same as stock V2 / other GwAu3 bots). No delayed main-loop queue, no Start-time salvage, no five-JMP `Assembler_ModifyMemory`.
- The first leveling step lazily runs `Wine_EnsureCommandQueue`: a read-only 4KB `.text` scan, then **one Engine JMP** and a small command page that includes `CommandEnterMission` / `CommandMove` / `CommandDialog` / `CommandPacketSend`. Start stays Running even if that install has not happened yet.
- Attaches **by Gw.exe PID** when the title is `Guild Wars Reforged` (window PID first, then `ProcessList`). Character name is still preferred when several clients are running and the memory charname matches.
- Does not rename the Guild Wars window, and does not use `Core_AutoStart`'s `Guild Wars - <char>` title check.

Optional `Config/leveler.ini` next to the script (defaults apply if the file is missing):

```
[Wine]
ForceWineCompat=0
SkipUpdater=1
ScannerTimeoutMs=15000
```

Native Windows is unchanged unless `ForceWineCompat=1`.

### Verify attach

1. Character in-world under Wine. Refresh should list a `Gw.exe` PID (title may be `Guild Wars Reforged`).
2. Click Start. The log should say `Initializing and attaching to PID …` then stock `End of Initialization` / `Initialized for: <name>`.
3. If attach reports 0/78, the API Wine patches are missing or a previous 0/78 result was cached — restart AutoIt3.
4. Status check uses the current map and later quests as a floor. At Zen Daijun (213) with Enter Mission, next step must be **Zen Daijun Mission**, not Forming A Party, even when AgentBase is 0.
5. At 213, Wine clicks the visible **Enter Mission** button (and `{ENTER}`). It does **not** enqueue `Ui_EnterChallenge` or `PARTY_ENTER_CHALLENGE 0xA5` — both of those started a load then dumped this wine-gw client to character select. Skill/hench packets are skipped before that click (same DC risk). Success is explorable type 1 on **246** (or 213 if Zen keeps the outpost id). The command queue is only armed later, when Map_Move needs it. Do not claim a full Wine leveling-loop success until that enter is confirmed live.

## Scope

1. Shing Jea start: secondary, Xunlai, weapon, monastery armor, bags, skills.
2. Island story: Minister Cho, Lost Treasure, Tengu quests, Seitung armor, Zen Daijun.
3. Kaineng: Marketplace, max armor, Search for a Cure, Master's Burden, Mox.
4. Eye of the North unlock and Auspicious Beginnings farm to 20.
5. Post-20: An Unwelcome Guest, Gunnar's Hold, Punch the Clown, Lion's Arch, Kamadan, Consulate Docks, Olias, remaining secondaries, mercenary heroes, Longeye / Vaettir NPC (Assassin and Mesmer only).
