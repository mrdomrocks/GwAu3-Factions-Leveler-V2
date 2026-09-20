# GwAu3 Factions Leveler V2

GwAu3 AutoIt3 Factions character leveler. Covers Shing Jea through the post-20 unlocks (Kilroy, Lion's Arch, Kamadan, Olias, GToB, and the Assassin/Mesmer Vaettir NPC).

## Layout

| File | Purpose |
| --- | --- |
| `Factions_Character_Leveler.au3` | GUI, bot loop, Start / Pause |
| `Leveler_Const.au3` | Step indices, maps, quests, dialogs, models, runtime state |
| `Leveler_Move.au3` | Pathfinder, travel, NPC talk, combat waits, punch-out, wipe recover |
| `Leveler_Quest.au3` | Quest accept / update / reward dialogs |
| `Leveler_Prof.au3` | Skill templates and trainer-bar load |
| `Leveler_Henchman.au3` | Hench invite lists and party prep |
| `Leveler_Party.au3` | Profession flags, heroes, UtilityAI cache |
| `Leveler_Mission.au3` | `Map_EnterChallenge` and post-mission outpost wait |
| `Leveler_Craft.au3` | Gold, Xunlai, weapons, armor, bags |
| `Leveler_Status.au3` | Progress flags and the GUI status check |
| `Leveler_Steps.au3` | Step dispatcher and campaign runners |

Lives in the GwAu3 checkout at `Scripts/GwAu3-Factions-Leveler-V2/`. The main script includes `../../API/_GwAu3.au3` and the Pathfinder plugin.

## Run

1. Launch Guild Wars and log the Factions character in.
2. Run `Factions_Character_Leveler.au3` with AutoIt3 x86 (admin).
3. Pick the character, click Start. Refresh re-detects the next incomplete step.

## Scope

1. Shing Jea start: secondary, Xunlai, weapon, monastery armor, bags, skills.
2. Island story: Minister Cho, Lost Treasure, Tengu quests, Seitung armor, Zen Daijun.
3. Kaineng: Marketplace, max armor, Search for a Cure, Master's Burden, Mox.
4. Eye of the North unlock and Auspicious Beginnings farm to 20.
5. Post-20: An Unwelcome Guest, Gunnar's Hold, Punch the Clown, Lion's Arch, Kamadan, Consulate Docks, Olias, remaining secondaries, mercenary heroes, Longeye / Vaettir NPC (Assassin and Mesmer only).
