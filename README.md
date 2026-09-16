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
- Queues Start onto the **main loop**. Attach is **read-only first**, then an **experimental single Engine JMP**:
  - 4KB PE header + **8-byte `.text` probe**. If `first8` is all zeros, **stop** (no further RPM).
  - Then a **4KB** `ReadProcessMemory` walk for five critical patterns (AgentBase, MyID, Engine, Move, BasePointer).
  - Pointers are **read** and logged. Gw.exe should still be alive here (cd758c0).
  - Then a second 4KB walk for PacketSend / PacketLocation / Dialog / Interact (and InstanceInfo/Region if present).
  - `VirtualAllocEx` **one** RWX allocation for the command queue + `CommandMove` / `CommandPacketSend` / `CommandDialog` / `CommandInteract` + RegularFlow `MainProc` only.
  - Exactly **one** 5-byte `E9` at Engine (`MainStart`) after the site 5 bytes are `8B EC D9 45 08` and `+0x22` still matches `568B3085F67478…`. Tries scan result, result-1, result+1.
  - **No** `Assembler_ModifyMemory`. **No** Render / LoadFinished / Trader / TradePartner JMPs. **No** five-JMP fallback if verify or alloc fails — abort with log lines, leave `g_p_QueueBase` at 0.
  - `Leveler_ExecuteStep` / the bot loop start only if `Wine_CommandsReady()` (live `g_p_QueueBase` after the JMP sticks).
- Attaches **by the window's PID first**, then `ProcessList("gw.exe")`.
- Does not rename the Guild Wars window, and does not use `Core_AutoStart`'s `Guild Wars - <char>` title check.

**This Wine inject is experimental and can still crash Gw.exe.** Native Windows still uses full `Core_Initialize`. Do not treat a green Start as a proven live bot run until wine-gw retests.

Optional `Config/leveler.ini` next to the script (defaults apply if the file is missing):

```
[Wine]
ForceWineCompat=0
SkipUpdater=1
ScannerTimeoutMs=15000
```

Native Windows is unchanged unless `ForceWineCompat=1`.

### Why this is not the a3ceeb0 five-JMP path

cd758c0 proved `ReadProcessMemory` of `.text` is safe (AgentBase live, Gw.exe stayed up). a3ceeb0 crashed after `Assembler_ModifyMemory` planted five `E9` JMPs (`MainStart`, `TraderStart`, `RenderingMod`, `LoadFinishedStart`, `TradePartnerStart`).

GwAu3 still has no read-only packet/UI path: `Map_Move`, `Ui_Dialog`, and `Core_SendPacket` all `Core_Enqueue` into `$g_p_QueueBase`, drained on the game thread by the Engine hook. This change plants **only that Engine JMP** after verifying site bytes. The other four detours are skipped. LoadFinished waits on Wine use `Leveler_WaitUntilMapReady` (instance/agent polling) instead of the `MapIsLoaded` flag.

If site bytes do not match or `VirtualAllocEx` fails, Start stays at read-only attach and the bot loop does **not** start. There is no fallback to planting all five JMPs.

Skills, trader, and other command stubs are **not** in this page. A step that needs them can enqueue a null command pointer — pause and report rather than expecting a full native run.

### Verify on wine-gw (retest; do not claim live success from this PR)

1. Character in-world under Wine. Refresh should list a `Gw.exe` PID (title may be `Guild Wars Reforged`) and must **not** print `0/78`.
2. Click Start. Log should say `Start queued`, then `Initializing and attaching to PID … (read-only 4KB first, then one Engine JMP)`.
3. **Read-only ok:** `Wine probe: … first8=` with **non-zero** code bytes, `Wine 4KB scan: found 5/5`, `Read-only attach ok`, AgentBase/BasePointer logged. **Gw.exe must still be running.**
4. **Single JMP:** `Wine Engine candidate … site5= … +22= …`, `Wine Engine site before JMP:`, `QueueBase=`, `Wine Engine site after JMP:` starting with `E9`, then **`Wine: single Engine JMP planted`**. The bot loop may start (`Wine command queue is live`). Confirm the log does **not** mention Trader/Render/LoadFinished/TradePartner detours being planted, and does **not** call `Assembler_ModifyMemory`.
5. **Abort path:** if site 5 bytes are not `8B EC D9 45 08`, pattern mismatch, or `VirtualAllocEx failed`, expect `Wine inject abort: …` / `single Engine JMP inject aborted` and `Bot loop not started`. Gw.exe should still be running. Do not retry with a five-JMP build.
6. If the JMP planted, the leveler may **attempt** a step (`Leveler_ExecuteStep`). That is not proof the bot completed a quest. Watch whether Gw.exe stays up. Pause immediately on a crash or odd client state.

## Scope

1. Shing Jea start: secondary, Xunlai, weapon, monastery armor, bags, skills.
2. Island story: Minister Cho, Lost Treasure, Tengu quests, Seitung armor, Zen Daijun.
3. Kaineng: Marketplace, max armor, Search for a Cure, Master's Burden, Mox.
4. Eye of the North unlock and Auspicious Beginnings farm to 20.
5. Post-20: An Unwelcome Guest, Gunnar's Hold, Punch the Clown, Lion's Arch, Kamadan, Consulate Docks, Olias, remaining secondaries, mercenary heroes, Longeye / Vaettir NPC (Assassin and Mesmer only).
