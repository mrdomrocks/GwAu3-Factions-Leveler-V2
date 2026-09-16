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
- Sets `g_b_ScannerUseLocal` and skips the GitHub updater before any scan.
- Skips `Scanner_GetLoggedCharNames` on Wine. That call `Memory_Close()`s the process and can cache a **0/78** local pattern scan (`ScanAgentBasePtr`, `ScanMyIDPtr`, `ScanEngineHook`, `ScanMoveFunc`, `ScanBasePointerPtr`).
- Queues Start onto the **main loop**. The patched API local scanner is per-byte and hard-capped at **20s** (~0.5MB of a 5.4MB `.text`, 0 hits, then `Skipping critical rescan on Wine`). V2 **does not wait on that path**. It opens `Gw.exe` by PID, chunk-scans the full `.text` with `ReadProcessMemory`, and binds pointers via `Wine_FinishCoreInitialize`.
- Attaches **by the window's PID first**, then `ProcessList("gw.exe")`. Character name is still preferred when several clients are running and the memory charname matches.
- Clears the timed-scan miss cache (`g_b_SkipCriticalRescan` / recorded-sites flags) without closing the process if a Core_Initialize fallback is needed.
- Does not rename the Guild Wars window, and does not use `Core_AutoStart`'s `Guild Wars - <char>` title check.

Optional `Config/leveler.ini` next to the script (defaults apply if the file is missing):

```
[Wine]
ForceWineCompat=0
SkipUpdater=1
ScannerTimeoutMs=15000
```

`ScannerTimeoutMs` is kept for the API fallback only. The API local scan still prints `timed out after 20000 ms` if that path runs; the chunked salvage ignores it. Native Windows is unchanged unless `ForceWineCompat=1`.

### Verify attach

1. Character in-world under Wine. Refresh should list a `Gw.exe` PID (title may be `Guild Wars Reforged`) and must **not** print `0/78`.
2. Click Start. The log should say `Start queued` then `Initializing and attaching to PID … via chunked .text scan`. Expect `Wine chunked scan: .text 5473792 bytes` then `found N/78` (N large enough to include AgentBase/MyID/Engine/Move/BasePointer), then `Wine salvage: binding pointers`.
3. Success looks like `End of Initialization` then `Initialized for: <name>`.
4. A `Local pattern scan timed out after 20000 ms` line means the API fallback ran; the chunked salvage should still follow. If salvage prints `found 0/78`, copy the `Wine probe:` line (`handle=`, `text=`, `first8=`). `first8` all zeros means ReadProcessMemory is not seeing `.text`.
5. Restart AutoIt3 before retrying if a previous run already cached 0/78.

## Scope

1. Shing Jea start: secondary, Xunlai, weapon, monastery armor, bags, skills.
2. Island story: Minister Cho, Lost Treasure, Tengu quests, Seitung armor, Zen Daijun.
3. Kaineng: Marketplace, max armor, Search for a Cure, Master's Burden, Mox.
4. Eye of the North unlock and Auspicious Beginnings farm to 20.
5. Post-20: An Unwelcome Guest, Gunnar's Hold, Punch the Clown, Lion's Arch, Kamadan, Consulate Docks, Olias, remaining secondaries, mercenary heroes, Longeye / Vaettir NPC (Assassin and Mesmer only).
