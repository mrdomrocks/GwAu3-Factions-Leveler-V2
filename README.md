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
- The first `Leveler_ExecuteStep` / `Map_Move` lazily runs `Wine_EnsureCommandQueue`: a read-only 4KB `.text` scan, then **one Engine JMP** and a small command page that includes `CommandEnterMission` / `CommandMove` / `CommandDialog` / `CommandPacketSend`. That call must leave `QueueBase` live so walking can enqueue. Start stays Running even if that install has not happened yet. Mid-mission Zen on Wine is **map/CurrentMapID 246** or Togo (lvl20 Rt) in the party — not stale `MissionObjectiveArraySize` on outpost 213.
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
5. At the Zen outpost (213) only: Wine hides the overlay and clicks the Enter Mission pill via PostMessage/ControlClick plus a **frame-mapped** MouseClick (outer “Guild Wars Reforged” rect, xdotool Y=59 — not the DX child’s Y≈30). Latch **only** when map/CurrentMapID is **246** for >1s. Do not latch on `{ENTER}` + Type/IsWaitingForMission flicker while still on 213.
6. Already-inside Zen on Wine is **map/CurrentMapID 246** or Togo (lvl20 Rt) in the party. Stale `MissionObjectiveArraySize` on outpost 213 must **not** skip Enter Mission or start Escort Togo. On 213 without Togo, do **not** Travel/resign 213→213 when InstanceInfo flickers explorable — go straight to Enter Mission.
7. The first step must log a live `QueueBase` (and `CommandMove`) after `Wine_EnsureCommandQueue`. `Map_Move` can then walk the mission path. Pathing/queue on Wine is validated live.
8. Zen combat stays on Togo (do not walk off him). A wipe / Togo death resigns **once**, sends Return-to-Outpost **once**, and waits. Do not re-send 0xA7 while the client shows Connecting — that hangs at 0%. Success is a clean Zen outpost (213), then re-enter.
9. After a held **246** (first live enter on wine-gw), wait for the world to settle before skill-bar writes, queue refresh, or the first Move. Do **not** re-inject Engine JMP if QueueBase is already live across the load. Do **not** keep PostMessage/MouseClick-ing once the load starts — that crashed Gw.
10. Mid-mission Start with Togo must log Escort and `Map_Move` without blocking the GUI. Skip `Cache_SkillBar` / Pathfinder / settle-wait on Wine when already in Zen. `Out()` also appends `Logs/leveler.log` next to the script. Togo is a **mission ally**, not a hench — detect him from agents (name/model/Rt). Do not resign while Togo or a clearly-alive player is present.
11. Wine arrival must not require Agent X,Y. Log `pos src=` each walk tick. If pos stays 0,0 after live QueueBase moves, count the waypoint arrived and resume the next one — do not restart escort at 15121.

## Scope

1. Shing Jea start: secondary, Xunlai, weapon, monastery armor, bags, skills.
2. Island story: Minister Cho, Lost Treasure, Tengu quests, Seitung armor, Zen Daijun.
3. Kaineng: Marketplace, max armor, Search for a Cure, Master's Burden, Mox.
4. Eye of the North unlock and Auspicious Beginnings farm to 20.
5. Post-20: An Unwelcome Guest, Gunnar's Hold, Punch the Clown, Lion's Arch, Kamadan, Consulate Docks, Olias, remaining secondaries, mercenary heroes, Longeye / Vaettir NPC (Assassin and Mesmer only).
