#include-once

; Phase 1-5 step indices (Overlook through remaining secondary professions)
Global Const $LEVELER_STEP_OVERLOOK = 0
Global Const $LEVELER_STEP_PARTY = 1
Global Const $LEVELER_STEP_SECONDARY = 2
Global Const $LEVELER_STEP_XUNLAI = 3
Global Const $LEVELER_STEP_WEAPON = 4
Global Const $LEVELER_STEP_ARMOR = 5
Global Const $LEVELER_STEP_DESTROY = 6
Global Const $LEVELER_STEP_BAGS = 7
Global Const $LEVELER_STEP_SKILLS = 8
Global Const $LEVELER_STEP_TO_CHO = 9
Global Const $LEVELER_STEP_CHO_MISSION = 10
Global Const $LEVELER_STEP_ATTR_1 = 11
Global Const $LEVELER_STEP_TENGU = 12
Global Const $LEVELER_STEP_THREAT = 13
Global Const $LEVELER_STEP_ROAD = 14
Global Const $LEVELER_STEP_SEITUNG = 15
Global Const $LEVELER_STEP_DESTROY_MON = 16
Global Const $LEVELER_STEP_TO_ZEN = 17
Global Const $LEVELER_STEP_ZEN_MISSION = 18
Global Const $LEVELER_STEP_TO_MARKET = 19
Global Const $LEVELER_STEP_TO_KC = 20
Global Const $LEVELER_STEP_SKILLS2 = 21
Global Const $LEVELER_STEP_MAX_ARMOR = 22
Global Const $LEVELER_STEP_DESTROY_SEITUNG = 23
Global Const $LEVELER_STEP_CURE = 24
Global Const $LEVELER_STEP_BURDEN = 25
Global Const $LEVELER_STEP_UNLOCK_MOX = 26
Global Const $LEVELER_STEP_TO_BOREAL = 27
Global Const $LEVELER_STEP_TO_EOTN = 28
Global Const $LEVELER_STEP_EOTN_POOL = 29
Global Const $LEVELER_STEP_ATTR_2 = 30
Global Const $LEVELER_STEP_TO_GUNNAR = 31
Global Const $LEVELER_STEP_KILROY = 32
Global Const $LEVELER_STEP_FARM_20 = 33
Global Const $LEVELER_STEP_TO_LA = 34
Global Const $LEVELER_STEP_TO_KAMADAN = 35
Global Const $LEVELER_STEP_TO_DOCKS = 36
Global Const $LEVELER_STEP_UNLOCK_OLIAS = 37
Global Const $LEVELER_STEP_UNLOCK_PROFS = 38
Global Const $LEVELER_STEP_DONE = 39
Global Const $LEVELER_STEP_COUNT = 40

Global $g_as_StepNames[$LEVELER_STEP_COUNT] = [ _
		"Exit Monastery Overlook", _
		"Quest: Forming A Party", _
		"Unlock Secondary Profession", _
		"Unlock Xunlai Storage", _
		"Craft Weapon", _
		"Craft Monastery Armor", _
		"Destroy Starter Armor", _
		"Extend Inventory", _
		"Unlock Skills Trainer", _
		"To Minister Cho's Estate", _
		"Minister Cho's Estate Mission", _
		"Quest: Lost Treasure", _
		"Quest: Warning the Tengu", _
		"Quest: The Threat Grows", _
		"Quest: The Road Less Traveled", _
		"Craft Seitung Armor", _
		"Destroy Monastery Armor", _
		"To Zen Daijun", _
		"Zen Daijun Mission", _
		"To Marketplace", _
		"To Kaineng Center", _
		"Complete Skills Training", _
		"Craft Max Armor", _
		"Destroy Seitung Armor", _
		"Quest: The Search For A Cure", _
		"Quest: A Master's Burden", _
		"Unlock Mox", _
		"To Boreal Station", _
		"To Eye of the North", _
		"Unlock Eye of the North Pool", _
		"Quest: An Unwelcome Guest", _
		"To Gunnar's Hold", _
		"Unlock Kilroy Stonekin", _
		"Farm Until Level 20", _
		"To Lion's Arch", _
		"To Kamadan", _
		"To Consulate Docks", _
		"Unlock Olias", _
		"Unlock Remaining Secondary Professions", _
		"Done" _
		]
Global $g_ab_StepDone[$LEVELER_STEP_COUNT]

; Maps used in Phase 1-5
Global Const $MAP_MONASTERY_OVERLOOK = 212
Global Const $MAP_SHING_JEA = 242
Global Const $MAP_SUNQUA_VALE = 238
Global Const $MAP_LINNOK = 252
Global Const $MAP_CHO_OUTPOST = 214
Global Const $MAP_RAN_MUSU = 251
Global Const $MAP_CHO_EXPLORABLE = 245
Global Const $MAP_KINYA = 236
Global Const $MAP_TSUMEI = 249
Global Const $MAP_PANJIANG = 235
Global Const $MAP_SAOSHANG = 313
Global Const $MAP_SEITUNG = 250
Global Const $MAP_JAYA = 196
Global Const $MAP_HAIJU = 237
Global Const $MAP_ZEN_OP = 213
Global Const $MAP_ZEN_EXP = 246
Global Const $MAP_KAINENG_DOCKS = 302
Global Const $MAP_MARKETPLACE = 303
Global Const $MAP_BUKDEK = 240
Global Const $MAP_WAJJUN = 239
Global Const $MAP_KAINENG = 194
Global Const $MAP_TUNNELS = 692
Global Const $MAP_BOREAL = 675
Global Const $MAP_ICE_CLIFF = 499
Global Const $MAP_EOTN = 642
Global Const $MAP_HOM = 646
Global Const $MAP_AB = 849
Global Const $MAP_NORRHART = 548
Global Const $MAP_GUNNAR = 644
Global Const $MAP_KILROY = 703
Global Const $MAP_FRONIS = 704
Global Const $MAP_LIONS_ARCH = 55
Global Const $MAP_BEJUNKAN = 290
Global Const $MAP_LIONS_GATE = 415
Global Const $MAP_KC_SUNSPEARS = 400
Global Const $MAP_KAMADAN = 449
Global Const $MAP_SUN_DOCKS = 543
Global Const $MAP_CONSULATE = 429
Global Const $MAP_DOCKS = 493
Global Const $MAP_BLOODSTONE_FEN = 471
Global Const $MAP_GTOB = 248
Global Const $MAP_LONGEYE = 650
Global Const $MAP_BJORA = 482
Global Const $MAP_JAGA = 546

; Quests
Global Const $QUEST_FORMING_A_PARTY = 440
Global Const $QUEST_SECONDARY = 317
Global Const $QUEST_FORMAL_INTRO = 318
Global Const $QUEST_LOST_TREASURE = 346
Global Const $QUEST_WARNING_TENGU = 339
Global Const $QUEST_THREAT_GROWS = 340
Global Const $QUEST_JOURNEY_MASTER = 341
Global Const $QUEST_ROAD_LESS = 342
Global Const $QUEST_MASTERS_BURDEN = 349
Global Const $QUEST_SEARCH_CURE = 336
Global Const $QUEST_BROTHER_TOSAI = 337
Global Const $QUEST_EARTH_MOVE = 821
Global Const $QUEST_AGAINST_DESTROYERS = 913
Global Const $QUEST_MISSING_VANGUARD = 793
Global Const $QUEST_NORTHERN_ALLIES = 905
Global Const $QUEST_KNOWLEDGEABLE_ASURA = 915
Global Const $QUEST_UNWELCOME = 348
Global Const $QUEST_NORNBEAR = 808
Global Const $QUEST_PUNCH_CLOWN = 858
Global Const $QUEST_PUNCH_EXTRAVAGANZA = 856
Global Const $QUEST_CHAOS_KRYTA = 479
Global Const $QUEST_SUNSPEARS_CANTHA = 724
Global Const $QUEST_OLIAS = 782

; Dialogs (GW Reforged values from the Python bot)
Global Const $DIALOG_EXIT_OVERLOOK = 0x85
Global Const $DIALOG_GENERIC_TALK = 0x84
Global Const $DIALOG_FORMING_ACCEPT = 0x81B801
Global Const $DIALOG_FORMING_COMPLETE = 0x81B807
Global Const $DIALOG_SECONDARY_MESMER = 0x813D08
Global Const $DIALOG_SECONDARY_OTHER = 0x813D0E
Global Const $DIALOG_SECONDARY_COMPLETE = 0x813D07
Global Const $DIALOG_FORMAL_ACCEPT = 0x813E01
Global Const $DIALOG_FORMAL_STEP = 0x813E04
Global Const $DIALOG_FORMAL_TOGO_TALK = 0x15
Global Const $DIALOG_FORMAL_TOGO_DONE = 0x18
Global Const $DIALOG_FORMAL_ZUI = 0x800008
Global Const $DIALOG_FORMAL_ZUI_2 = 0x800009
Global Const $DIALOG_FORMAL_ZUI_2_TALK = 0x19
Global Const $DIALOG_FORMAL_SKIP = 0x80000B
Global Const $DIALOG_FORMAL_COMPLETE = 0x813E07
Global Const $DIALOG_FORMAL_KAYAO_ACCEPT = 0x17
Global Const $TOGO_SUNQUA_X = 20007.00
Global Const $TOGO_SUNQUA_Y = -7747.00
Global Const $ZUI_SUNQUA_X = 6637.00
Global Const $ZUI_SUNQUA_Y = 16147.00
Global Const $KAYAO_CHO_X = 7884.00
Global Const $KAYAO_CHO_Y = -10029.00
Global Const $DIALOG_XUNLAI_1 = 0x800001
Global Const $DIALOG_XUNLAI_2 = 0x800002
Global Const $DIALOG_LOST_TREASURE_ACCEPT = 0x815A01
Global Const $DIALOG_LOST_TREASURE_STEP = 0x815A04
Global Const $DIALOG_LOST_TREASURE_COMPLETE = 0x17
Global Const $DIALOG_TENGU_ACCEPT = 0x815301
Global Const $DIALOG_TENGU_STEP = 0x815304
Global Const $DIALOG_TENGU_COMPLETE = 0x815307
; Python Attribute_Points_Quest_1 / Warning the Tengu waypoints
Global Const $LOST_TOWN_APPROACH_X = 16184.75
Global Const $LOST_TOWN_APPROACH_Y = 19001.78
Global Const $LOST_TOWN_PATH1_X = 13713.27
Global Const $LOST_TOWN_PATH1_Y = 18504.61
Global Const $LOST_TOWN_PATH2_X = 14576.15
Global Const $LOST_TOWN_PATH2_Y = 17817.62
Global Const $LOST_TOWN_PATH3_X = 15824.60
Global Const $LOST_TOWN_PATH3_Y = 18817.90
Global Const $LOST_TOWN_PORTAL_X = 17005
Global Const $LOST_TOWN_PORTAL_Y = 19787
Global Const $LOST_CHO_START_X = -17979.38
Global Const $LOST_CHO_START_Y = -493.08
Global Const $LOST_CHO_END_X = 20660.90
Global Const $LOST_CHO_END_Y = -9207.07
Global Const $LOST_CHO_END_RANGE = 2500
Global Const $TENGU_ANG_X = 15846
Global Const $TENGU_ANG_Y = 19013
Global Const $TENGU_PORTAL_X = 14730
Global Const $TENGU_PORTAL_Y = 15176
Global Const $TENGU_KINYA_START_X = 1429
Global Const $TENGU_KINYA_START_Y = 12768
Global Const $TENGU_SOAR_X = -1023
Global Const $TENGU_SOAR_Y = 4844
Global Const $TENGU_AFFLICTED_X = -5011
Global Const $TENGU_AFFLICTED_Y = 732
Global Const $DIALOG_THREAT_ACCEPT = 0x815401
Global Const $DIALOG_THREAT_COMPLETE = 0x815407
Global Const $DIALOG_JOURNEY_ACCEPT = 0x815501
Global Const $DIALOG_JOURNEY_COMPLETE = 0x815507
Global Const $DIALOG_ROAD_ACCEPT = 0x815601
Global Const $DIALOG_ROAD_STEP1 = 0x80000B
Global Const $DIALOG_ROAD_TSUKARO_TALK = 0x815604
Global Const $DIALOG_ROAD_TSUKARO_GO = 0x800008
Global Const $DIALOG_ROAD_TSUKARO_LETS_GO = 0x800009
Global Const $DIALOG_ROAD_TSUKARO_YES = 0x80000B
Global Const $DIALOG_ROAD_STEP2 = 0x815604
Global Const $DIALOG_ROAD_COMPLETE = 0x815607
Global Const $TSUKARO_LINNOK_X = 538.00
Global Const $TSUKARO_LINNOK_Y = 10125.00
Global Const $DIALOG_BURDEN_ACCEPT = 0x815D01
Global Const $DIALOG_BURDEN_STEP2 = 0x815D04
Global Const $DIALOG_BURDEN_COMPLETE = 0x815D07
Global Const $DIALOG_CURE_ACCEPT = 0x815001
Global Const $DIALOG_CURE_STEP = 0x815004
Global Const $DIALOG_CURE_COMPLETE = 0x815007
Global Const $DIALOG_TOSAI_ACCEPT = 0x815101
Global Const $DIALOG_UNLOCK_MOX = 0x85
Global Const $DIALOG_EARTH_ACCEPT = 0x833501
Global Const $DIALOG_DESTROYERS_STEP1 = 0x839104
Global Const $DIALOG_POOL_CINEMATIC = 0x800001
Global Const $DIALOG_POOL_STEP3 = 0x63C
; Look deep into the pool.
Global Const $DIALOG_POOL_LOOK_DEEP = 0x63D
; I'll keep my eyes open. I don't want to miss anything.
Global Const $DIALOG_POOL_EYES_OPEN = 0x63F
Global Const $DIALOG_POOL_SEND = 0xD
Global Const $DIALOG_GWEN_TAPESTRY = 0x89
Global Const $DIALOG_VANGUARD_STEP = 0x831904
Global Const $DIALOG_KEIRAN_BOW = 0x8A
Global Const $DIALOG_OGDEN_ALLIES = 0x838904
Global Const $DIALOG_VEKK_ASURA = 0x839304
Global Const $DIALOG_AB_OFFSET = 0xE
Global Const $DIALOG_UNWELCOME_ACCEPT = 0x815C01
Global Const $DIALOG_UNWELCOME_COMPLETE = 0x815C07
Global Const $DIALOG_ZEN_SKIP = 0x80000B
Global Const $DIALOG_NORNBEAR_ACCEPT = 0x832801
Global Const $DIALOG_PUNCH_ACCEPT = 0x835A01
Global Const $DIALOG_PUNCH_COMPLETE = 0x835A07
Global Const $DIALOG_FRONIS_INTRO = 0x835803
Global Const $DIALOG_FRONIS_ACCEPT = 0x835801
Global Const $DIALOG_FRONIS_ENTER = 0x85
Global Const $DIALOG_FRONIS_REWARD = 0x835807
Global Const $KILROY_NPC_X = 17341.00
Global Const $KILROY_NPC_Y = -4796.00
Global Const $FRONIS_START_X = -16919.56
Global Const $FRONIS_START_Y = -13485.12
Global Const $FRONIS_CHEST_X = 13275.00
Global Const $FRONIS_CHEST_Y = -16039.00
Global Const $DIALOG_CHAOS_ACCEPT = 0x81DF01
Global Const $DIALOG_CHAOS_STEP1 = 0x81DF04
Global Const $DIALOG_CHAOS_STEP3 = 0x85
Global Const $DIALOG_CHAOS_COMPLETE = 0x81DF07
Global Const $DIALOG_SUNSPEARS_ACCEPT = 0x82D401
Global Const $DIALOG_SUNSPEARS_STEP1 = 0x82D404
Global Const $DIALOG_SUNSPEARS_MULTI = 0x87
Global Const $DIALOG_SUNSPEARS_COMPLETE = 0x82D407
Global Const $DIALOG_UNLOCK_DOCKS = 0x85
Global Const $DIALOG_OLIAS_ACCEPT = 0x830E01
Global Const $DIALOG_OLIAS_STEP2 = 0x830E04
Global Const $DIALOG_OLIAS_COMPLETE = 0x830E07
Global Const $DIALOG_PROF_WARRIOR = 0x184
Global Const $DIALOG_PROF_RANGER = 0x284
Global Const $DIALOG_PROF_MONK = 0x384
Global Const $DIALOG_PROF_NECRO = 0x484
Global Const $DIALOG_PROF_MESMER = 0x584
Global Const $DIALOG_PROF_ELE = 0x684
Global Const $DIALOG_PROF_ASSASSIN = 0x784
Global Const $DIALOG_PROF_RIT = 0x884
Global Const $DIALOG_PROF_PARA = 0x984
Global Const $DIALOG_PROF_DERV = 0xA84

; NPC models
Global Const $MODEL_TOGO_1 = 3078
Global Const $MODEL_TOGO_2 = 3081
Global Const $MODEL_TOGO_3 = 3120
Global Const $MODEL_TOGO_4 = 3215
Global Const $MODEL_XUNLAI = 283
; Raitahn Nem. Same model in Ran Musu Gardens and Cho explorable.
Global Const $MODEL_LOST_TREASURE_GUARD = 3093
Global Const $MODEL_RAITAHN_NEM = 3093
Global Const $MODEL_SISTER_TAI = 3367
Global Const $MODEL_BROTHER_TOSAI = 3171
Global Const $MODEL_BURDEN_NPC = 3307
Global Const $MODEL_CURE_LOOT = 6496
Global Const $MODEL_DESTROYERS_NPC = 6034
Global Const $MODEL_JORA = 6034
Global Const $MODEL_JORA_ALT = 6374
Global Const $JORA_ICE_CLIFF_X = 2825.00
Global Const $JORA_ICE_CLIFF_Y = -481.00
Global Const $MODEL_GWEN = 6021
Global Const $MODEL_EOTN_POOL = 5959
Global Const $GWEN_HOM_X = -6583.00
Global Const $GWEN_HOM_Y = 6672.00
Global Const $EOTN_POOL_X = -6662.00
Global Const $EOTN_POOL_Y = 6234.60
Global Const $EOTN_POOL_TILE_X = -6662.00
Global Const $EOTN_POOL_TILE_Y = 6584.00
Global Const $OGDEN_HOM_X = -6133.41
Global Const $OGDEN_HOM_Y = 5717.30
Global Const $VEKK_HOM_X = -5626.80
Global Const $VEKK_HOM_Y = 6259.57
Global Const $MODEL_OGDEN = 5983
Global Const $MODEL_VEKK = 5964
Global Const $MODEL_KEIRAN_BOW = 35829
Global Const $MODEL_ZUNRAA = 4009
Global Const $MODEL_CHAOS_STEP1 = 3267
Global Const $MODEL_CHAOS_STEP2 = 2020
Global Const $MODEL_CHAOS_STEP3 = 2011
Global Const $MODEL_SUNSPEARS_NPC = 4914
Global Const $MODEL_SUNSPEARS_COMPLETE = 4829
Global Const $MODEL_GTOB_TRAINER = 201
Global Const $MODEL_BRASS_KNUCKLES = 24897
; Michiko [Skills] in Kaineng Center, north edge near the Bejunkan Pier exit.
Global Const $MODEL_MICHIKO = 3295
Global Const $MICHIKO_KAINENG_X = -1661.91
Global Const $MICHIKO_KAINENG_Y = -636.09

; Merchant bags
Global Const $MODEL_BAG = 16
Global Const $MODEL_BELT_POUCH = 34

; Zhao Di (Shing Jea Monastery) Mesmer skills. Cry of Frustration is NOT here.
Global Const $SKILL_ENERGY_BURN = 42
Global Const $SKILL_LEECH_SIGNET = 61
Global Const $SKILL_SIGNET_OF_DISRUPTION = 860
; Michiko in Kaineng: Cry of Frustration and Power Drain.
Global Const $SKILL_CRY_OF_FRUSTRATION = 57
Global Const $SKILL_POWER_DRAIN = 25
Global Const $SKILL_BACKFIRE = 54
Global Const $SKILL_SPIRIT_RIFT = 910

; Weapon / armor gold
Global Const $MODEL_CLAIRVOYANT_STAFF = 11647
; Paid from the Choose Your Secondary Profession (#317) complete reward, not storage.
Global Const $XUNLAI_GOLD_COST = 50
Global Const $WEAPON_GOLD_COST = 100
Global Const $MONASTERY_ARMOR_GOLD = 20
Global Const $SEITUNG_ARMOR_GOLD = 200
Global Const $MAX_ARMOR_GOLD = 1000

; Movement
Global Const $LEVELER_ARRIVE_RANGE = 200
Global Const $LEVELER_NPC_RANGE = 250
Global Const $LEVELER_AGGRO = 1320
Global Const $LEVELER_FIGHT_RANGE_OUT = 3500
Global Const $LEVELER_AREA_RANGE = 322
Global Const $LEVELER_SPIRIT_RANGE = 2500

; Quest completion flag indices. Sticky during a run; rebuilt on Refresh.
Global Enum $LEVELER_Q_FORMING, $LEVELER_Q_SECONDARY, $LEVELER_Q_FORMAL, $LEVELER_Q_LOST, _
		$LEVELER_Q_TENGU, $LEVELER_Q_THREAT, $LEVELER_Q_JOURNEY, $LEVELER_Q_ROAD, _
		$LEVELER_Q_CURE, $LEVELER_Q_TOSAI, $LEVELER_Q_BURDEN, $LEVELER_Q_EARTH, _
		$LEVELER_Q_DESTROYERS, $LEVELER_Q_VANGUARD, $LEVELER_Q_ALLIES, $LEVELER_Q_ASURA, _
		$LEVELER_Q_UNWELCOME, $LEVELER_Q_NORNBEAR, $LEVELER_Q_PUNCH, $LEVELER_Q_CHAOS, _
		$LEVELER_Q_SUNSPEARS, $LEVELER_Q_OLIAS, $LEVELER_Q_COUNT
Global $g_ab_QuestDone[$LEVELER_Q_COUNT]

; Shared runtime state
Global $g_i_Step = $LEVELER_STEP_OVERLOOK
Global $g_b_NeedStatusCheck = False
Global $g_b_LevelerPaused = False
Global $g_b_LevelerFailed = False
Global $g_b_CombatMode = False
Global $g_b_SpiritRiftWatch = False
Global $g_b_FarmMode = False
Global $g_b_KilroyMode = False
Global $g_h_RiftCooldown = 0
Global $g_s_CurrentHeader = ""
Global $g_b_UAIReady = False
Global $g_i_LastUAIMap = 0
Global $g_b_ConnectionLost = False
; One-time recovery after a completed Lost Treasure restart: path Cho -> Ran Musu -> Tengu.
Global $g_b_LostTreasureToTenguOnce = False
; Set on Start only. Stay in an explorable after a client/script restart; do not block the next quest.
Global $g_b_ExplorableResume = False
; Sticky after this character has entered Gunnar's Hold.
Global $g_b_ReachedGunnar = False
; Sticky after Bloodstone Fen for All for One and One for Justice.
Global $g_b_OliasFenDone = False
; Sticky after Olias is in the party or can be added.
Global $g_b_OliasUnlocked = False
; Sticky after the Bukdek dialog actually puts Mox on the hero list.
Global $g_b_MoxUnlocked = False
; Sticky after GToB trainer dialogs.
Global $g_b_SecondaryProfsTalked = False
; Sticky after OwVAIcdP8BogGwBFhAA is applied. Do not SKILLBAR_LOAD again next to Enter.
Global $g_b_ZenTemplateApplied = False
; Py4GW UIMessage.kSendEnterMission. wparam = uint32 arena_id.
Global Const $LEVELER_UIMSG_SEND_ENTER_MISSION = 0x30000002
; Persistent CommandUIMsg struct. A Local DllStruct is freed before the queue drains.
Global $g_d_LevelerUIEnter = 0
Global $g_p_LevelerUIEnter = 0
