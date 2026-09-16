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
- Sets `g_b_ScannerUseLocal` and skips the GitHub updater (so the API does not hang on update checks).
- Skips `Scanner_GetLoggedCharNames` on Wine (`Memory_Close()` / cached 0/78).
- Queues Start onto the **main loop**. Wine attach is **read-only**:
  - 4KB PE header + **8-byte `.text` probe**. If `first8` is all zeros, **stop** (no further RPM).
  - Then a **4KB** `ReadProcessMemory` walk for five critical patterns only (AgentBase, MyID, Engine, Move, BasePointer), yielding every 32KB.
  - **No** full-section RPM, **no** `VirtualAllocEx`, **no** `WriteProcessMemory`, **no** `Assembler_ModifyMemory`, **no** `Core_Initialize` fallback.
  - On success, pointers are **read** and logged. The bot loop does **not** start (hooks would write into Gw.exe and crashed the client on a3ceeb0).
- Attaches **by the window's PID first**, then `ProcessList("gw.exe")`.
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

1. Character in-world under Wine. Refresh should list a `Gw.exe` PID (title may be `Guild Wars Reforged`) and must **not** print `0/78`.
2. Click Start. The log should say `Start queued` then `Initializing and attaching to PID … (read-only 4KB scan)`. Expect `Wine probe: … first8=` with **non-zero** code bytes, then `Wine 4KB scan: found 5/5`, then `Read-only attach ok` and `Bot loop not started`.
3. **Gw.exe must still be running** after Start. If `first8` is all zeros, attach aborts before the scan.
4. Do not expect `End of Initialization` / a running leveler on Wine yet. Engine hooks are disabled until a safer inject path exists.

## Scope

1. Shing Jea start: secondary, Xunlai, weapon, monastery armor, bags, skills.
2. Island story: Minister Cho, Lost Treasure, Tengu quests, Seitung armor, Zen Daijun.
3. Kaineng: Marketplace, max armor, Search for a Cure, Master's Burden, Mox.
4. Eye of the North unlock and Auspicious Beginnings farm to 20.
5. Post-20: An Unwelcome Guest, Gunnar's Hold, Punch the Clown, Lion's Arch, Kamadan, Consulate Docks, Olias, remaining secondaries, mercenary heroes, Longeye / Vaettir NPC (Assassin and Mesmer only).
