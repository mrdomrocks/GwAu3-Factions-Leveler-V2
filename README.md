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
- Sets `g_b_ScannerUseLocal`, floors the local-scanner timeout to 60s on Wine (15s recorded 0 sites then skipped the critical rescan), and skips the GitHub updater before any scan.
- Skips `Scanner_GetLoggedCharNames` on Wine. That call `Memory_Close()`s the process and can cache a **0/78** local pattern scan (`ScanAgentBasePtr`, `ScanMyIDPtr`, `ScanEngineHook`, `ScanMoveFunc`, `ScanBasePointerPtr`).
- Queues Start onto the **main loop** instead of calling `Core_Initialize` from the button OnEvent. The old leveler attached from its runner loop; scanning from an AutoIt GUI event is where wine-gw was returning 0/78 on a real `Gw.exe` (PID 32 owned `Guild Wars Reforged`).
- Attaches **by the window's PID first**, then `ProcessList("gw.exe")`. Character name is still preferred when several clients are running and the memory charname matches.
- Calls `Core_Initialize(pid)` once from the main loop (same as Fedora/desktop). A 4/78 local scan can still print `End of Initialization` / `Initialized for: <name>` with **AgentBase=0** and **QueueBase=0**. That is not a live attach.
- If those criticals are dead, salvages with a read-only 4KB `.text` scan of AgentBase/MyID/Engine/Move/BasePointer, then plants **one** Engine JMP for the Map_Move queue drain. Never `Assembler_ModifyMemory` / five detours.
- Start enables the bot loop only when AgentBase, MyID, Engine (site `E9`), Move, BasePointer, and QueueBase are live user pointers. Otherwise the log says **ATTACH FAILED** and the GUI stays on Start.
- Does not rename the Guild Wars window, and does not use `Core_AutoStart`'s `Guild Wars - <char>` title check.

Optional `Config/leveler.ini` next to the script (defaults apply if the file is missing):

```
[Wine]
ForceWineCompat=0
SkipUpdater=1
ScannerTimeoutMs=60000
```

On Wine, timeouts below 60000 are raised to 60000. Native Windows is unchanged unless `ForceWineCompat=1`.

### Verify attach

1. Character in-world under Wine. Refresh should list a `Gw.exe` PID (title may be `Guild Wars Reforged`).
2. Click Start. The log should say `Start queued` then `Initializing and attaching to PID … via Core_Initialize`. The GUI may freeze during the local scan.
3. `End of Initialization` / `Initialized for: <name>` is **not** enough. The log must then show `Wine pointers (after Core_Initialize):` with non-zero AgentBase/MyID/Engine/Move/BasePointer/QueueBase, **or** a salvage pass (`Wine 4KB scan: found 5/5`, `Wine: single Engine JMP planted`, site after JMP starting with `E9`).
4. Bot loop starts only after `Wine: Core_Initialize bound live …` or `Wine: salvage bound live …`. The Start button becoming **Running** with AgentBase=0 / QueueBase=0 is a bug — that path must print **ATTACH FAILED** instead.
5. On failure, copy `Wine pointers` / `Wine criticals missing:` / `Wine probe:` (`handle=`, `text=`, `first8=`). `first8` all zeros means ReadProcessMemory is not seeing `.text`.
6. Do not claim a live Wine leveling run from this PR until wine-gw shows those six pointers live and Map_Move actually moves the character.

## Scope

1. Shing Jea start: secondary, Xunlai, weapon, monastery armor, bags, skills.
2. Island story: Minister Cho, Lost Treasure, Tengu quests, Seitung armor, Zen Daijun.
3. Kaineng: Marketplace, max armor, Search for a Cure, Master's Burden, Mox.
4. Eye of the North unlock and Auspicious Beginnings farm to 20.
5. Post-20: An Unwelcome Guest, Gunnar's Hold, Punch the Clown, Lion's Arch, Kamadan, Consulate Docks, Olias, remaining secondaries, mercenary heroes, Longeye / Vaettir NPC (Assassin and Mesmer only).
