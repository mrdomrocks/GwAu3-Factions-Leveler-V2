#include-once

Func Leveler_ExecuteStep($a_i_Step)
	If $g_b_LevelerPaused Then Return False
	If Leveler_IsWiped() Then
		Out("[Step] Wipe detected before '" & $g_as_StepNames[$a_i_Step] & "'. Recovering.")
		Leveler_RecoverWipe()
		Return False
	EndIf

	Local $l_b_Ok = False
	Switch $a_i_Step
		Case $LEVELER_STEP_OVERLOOK
			$l_b_Ok = Leveler_Step_ExitOverlook()
		Case $LEVELER_STEP_PARTY
			$l_b_Ok = Leveler_Step_FormingAParty()
		Case $LEVELER_STEP_SECONDARY
			$l_b_Ok = Leveler_Step_UnlockSecondary()
		Case $LEVELER_STEP_XUNLAI
			$l_b_Ok = Leveler_Step_UnlockXunlai()
		Case $LEVELER_STEP_WEAPON
			$l_b_Ok = Leveler_Step_CraftWeapon()
		Case $LEVELER_STEP_ARMOR
			$l_b_Ok = Leveler_Step_CraftMonasteryArmor()
		Case $LEVELER_STEP_DESTROY
			$l_b_Ok = Leveler_Step_DestroyStarter()
		Case $LEVELER_STEP_BAGS
			$l_b_Ok = Leveler_Step_ExtendInventory()
		Case $LEVELER_STEP_SKILLS
			$l_b_Ok = Leveler_Step_UnlockSkills()
		Case $LEVELER_STEP_TO_CHO
			$l_b_Ok = Leveler_Step_ToChosEstate()
		Case $LEVELER_STEP_CHO_MISSION
			$l_b_Ok = Leveler_Step_ChosMission()
		Case $LEVELER_STEP_ATTR_1
			$l_b_Ok = Leveler_Step_LostTreasure()
		Case $LEVELER_STEP_TENGU
			$l_b_Ok = Leveler_Step_WarningTheTengu()
		Case $LEVELER_STEP_THREAT
			$l_b_Ok = Leveler_Step_TheThreatGrows()
		Case $LEVELER_STEP_ROAD
			$l_b_Ok = Leveler_Step_TheRoadLessTraveled()
		Case $LEVELER_STEP_SEITUNG
			$l_b_Ok = Leveler_Step_CraftSeitungArmor()
		Case $LEVELER_STEP_DESTROY_MON
			$l_b_Ok = Leveler_Step_DestroyMonastery()
		Case $LEVELER_STEP_TO_ZEN
			$l_b_Ok = Leveler_Step_ToZenDaijun()
		Case $LEVELER_STEP_SKILLS2
			$l_b_Ok = Leveler_Step_CompleteSkillsTraining()
		Case $LEVELER_STEP_ZEN_MISSION
			$l_b_Ok = Leveler_Step_ZenDaijunMission()
		Case $LEVELER_STEP_TO_MARKET
			$l_b_Ok = Leveler_Step_ToMarketplace()
		Case $LEVELER_STEP_TO_KC
			$l_b_Ok = Leveler_Step_ToKainengCenter()
		Case $LEVELER_STEP_MAX_ARMOR
			$l_b_Ok = Leveler_Step_CraftMaxArmor()
		Case $LEVELER_STEP_DESTROY_SEITUNG
			$l_b_Ok = Leveler_Step_DestroySeitung()
		Case $LEVELER_STEP_CURE
			$l_b_Ok = Leveler_Step_SearchForACure()
		Case $LEVELER_STEP_BURDEN
			$l_b_Ok = Leveler_Step_AMastersBurden()
		Case $LEVELER_STEP_UNLOCK_MOX
			$l_b_Ok = Leveler_Step_UnlockMox()
		Case $LEVELER_STEP_TO_BOREAL
			$l_b_Ok = Leveler_Step_ToBorealStation()
		Case $LEVELER_STEP_TO_EOTN
			$l_b_Ok = Leveler_Step_ToEyeOfTheNorth()
		Case $LEVELER_STEP_EOTN_POOL
			$l_b_Ok = Leveler_Step_UnlockEotnPool()
		Case $LEVELER_STEP_FARM_20
			$l_b_Ok = Leveler_Step_FarmUntil20()
		Case $LEVELER_STEP_ATTR_2
			$l_b_Ok = Leveler_Step_AnUnwelcomeGuest()
		Case $LEVELER_STEP_TO_GUNNAR
			$l_b_Ok = Leveler_Step_ToGunnarsHold()
		Case $LEVELER_STEP_KILROY
			$l_b_Ok = Leveler_Step_UnlockKilroy()
		Case $LEVELER_STEP_TO_LA
			$l_b_Ok = Leveler_Step_ToLionsArch()
		Case $LEVELER_STEP_TO_KAMADAN
			$l_b_Ok = Leveler_Step_ToKamadan()
		Case $LEVELER_STEP_TO_DOCKS
			$l_b_Ok = Leveler_Step_ToConsulateDocks()
		Case $LEVELER_STEP_UNLOCK_OLIAS
			$l_b_Ok = Leveler_Step_UnlockOlias()
		Case $LEVELER_STEP_UNLOCK_PROFS
			$l_b_Ok = Leveler_Step_UnlockSecondaryProfs()
		Case $LEVELER_STEP_UNLOCK_MERCS
			$l_b_Ok = Leveler_Step_UnlockMercenaries()
		Case $LEVELER_STEP_TO_LONGEYE
			$l_b_Ok = Leveler_Step_ToLongeyesLedge()
		Case $LEVELER_STEP_VAETTIR
			$l_b_Ok = Leveler_Step_UnlockVaettirNpc()
		Case Else
			Return True
	EndSwitch

	If Leveler_IsWiped() Then
		Leveler_RecoverWipe()
		Return False
	EndIf

	If $l_b_Ok Then
		If $a_i_Step = $LEVELER_STEP_SECONDARY And Not Leveler_SecondaryStepReadyToLeave() Then
			Leveler_LogQuestState($QUEST_SECONDARY, "Choose Secondary")
			Out("[Step] #317 reward or Formal Introduction still missing. Staying on '" & $g_as_StepNames[$a_i_Step] & "'.")
			Return False
		EndIf
		Local $l_i_QuestID = Leveler_StepQuestID($a_i_Step)
		If $l_i_QuestID <> 0 And Leveler_QuestLogActive($l_i_QuestID) Then
			Leveler_LogQuestState($l_i_QuestID, $g_as_StepNames[$a_i_Step])
			Out("[Step] Quest #" & $l_i_QuestID & " is still active. Staying on '" & $g_as_StepNames[$a_i_Step] & "'.")
			Return False
		EndIf
		$g_i_Step = $a_i_Step + 1
		Leveler_UpdateStepCombo()
		Return True
	EndIf
	Return False
EndFunc

Func Leveler_Step_ExitOverlook()
	$g_s_CurrentHeader = "Exit Monastery Overlook"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Map_GetMapID() = $MAP_SHING_JEA Then
		Out("[Step] Already in Shing Jea Monastery")
		Return True
	EndIf
	Leveler_SetPacifist()
	If Not Leveler_MoveAndDialog(-7048, 5817, $DIALOG_EXIT_OVERLOOK, False) Then
		If Map_GetMapID() <> $MAP_SHING_JEA Then Map_Move(-7048, 5817, 10)
	EndIf
	Return Map_WaitMapLoading($MAP_SHING_JEA)
EndFunc

Func Leveler_Step_FormingAParty()
	$g_s_CurrentHeader = "Quest: Forming A Party"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Leveler_SkipIfQuestDone($QUEST_FORMING_A_PARTY, "Forming A Party") Then Return True
	If Not Leveler_Travel($MAP_SHING_JEA) Then Return False
	Leveler_PrepareForBattle()
	If Not Leveler_HasQuest($QUEST_FORMING_A_PARTY) Then
		If Not Leveler_QuestLoop($QUEST_FORMING_A_PARTY, -14063.00, 10044.00, $DIALOG_FORMING_ACCEPT, "accept", Leveler_TogoModel()) Then Return False
	Else
		Out("[Step] Forming A Party already in the log")
	EndIf
	If Leveler_SkipIfQuestDone($QUEST_FORMING_A_PARTY, "Forming A Party") Then Return True
	If Not Leveler_MoveAndExit(-14961, 11453, $MAP_SUNQUA_VALE, True) Then Return False
	If Not Leveler_QuestLoop($QUEST_FORMING_A_PARTY, 19673.00, -6982.00, $DIALOG_FORMING_COMPLETE, "complete") Then Return False
	Return True
EndFunc

Func Leveler_Step_UnlockSecondary()
	$g_s_CurrentHeader = "Unlock Secondary Profession"
	Out("=== " & $g_s_CurrentHeader & " ===")
	Out("[Step] Profession " & Leveler_PrimaryProfession() & "/" & Leveler_SecondaryProfession() & "  Gold " & Leveler_CharacterGold())
	Leveler_LogQuestState($QUEST_SECONDARY, "Choose Secondary")
	Leveler_LogQuestState($QUEST_FORMAL_INTRO, "Formal Introduction")
	If Leveler_SecondaryStepReadyToLeave() Then
		Out("[Step] #317 turned in and Formal Introduction is ready")
		Return True
	EndIf
	Out("[Step] Talking to Togo in Linnok for #317 complete and #318 accept.")
	If Not Leveler_Travel($MAP_SHING_JEA) Then Return False
	Leveler_SetPacifist()
	If Map_GetMapID() <> $MAP_LINNOK Then
		If Not Leveler_MoveAndExit(-3480, 9460, $MAP_LINNOK, False) Then Return False
	EndIf
	Leveler_MoveTo(-159, 9174, False)

	Local $l_i_AcceptDialog = $DIALOG_SECONDARY_OTHER
	If Leveler_IsMesmer() Then $l_i_AcceptDialog = $DIALOG_SECONDARY_MESMER
	Local $l_i_Togo = Leveler_TogoModel()
	If Not Leveler_HasQuest($QUEST_SECONDARY) And Not Leveler_SecondaryRewardTaken() Then
		If Not Leveler_QuestLoop($QUEST_SECONDARY, -92, 9217, $l_i_AcceptDialog, "accept", $l_i_Togo) Then Return False
	EndIf
	If Leveler_QuestInLog($QUEST_SECONDARY) Or Not Leveler_SecondaryRewardTaken() Then
		Out("[Step] Sending Togo complete dialog 0x813D07 for the #317 gold reward.")
		If Not Leveler_QuestLoop($QUEST_SECONDARY, -92, 9217, $DIALOG_SECONDARY_COMPLETE, "complete", $l_i_Togo) Then Return False
	EndIf
	Sleep(1500)
	Leveler_LogQuestState($QUEST_SECONDARY, "Choose Secondary")
	If Leveler_QuestInLog($QUEST_SECONDARY) Then
		Out("[Step] Quest #317 is still in the log after Togo. Staying on this step.")
		Return False
	EndIf
	If Not Leveler_HasSecondaryProfession() Then
		Out("[Step] Togo dialog sent but secondary is still unset. Retrying.")
		Return False
	EndIf
	If Not Leveler_SecondaryRewardTaken() Then
		Out("[Step] #317 reward not taken yet (gold " & Leveler_CharacterGold() & "). Retrying Togo complete.")
		Return False
	EndIf
	Leveler_MarkQuestDone($QUEST_SECONDARY)
	Sleep(1500)
	If Not Leveler_HasQuest($QUEST_FORMAL_INTRO) And Not Leveler_QuestFinished($QUEST_FORMAL_INTRO) Then
		If Not Leveler_QuestLoop($QUEST_FORMAL_INTRO, -92, 9217, $DIALOG_FORMAL_ACCEPT, "accept", $l_i_Togo) Then Return False
	EndIf
	If Not Leveler_HasFormalOrLater() Then
		Out("[Step] Formal Introduction #318 is not in the log. Staying on this step.")
		Return False
	EndIf
	If Not Leveler_MoveAndExit(-3762, 9471, $MAP_SHING_JEA, False) Then Return False
	Return True
EndFunc

Func Leveler_Step_UnlockXunlai()
	$g_s_CurrentHeader = "Unlock Xunlai Storage"
	Out("=== " & $g_s_CurrentHeader & " ===")
	Local $l_i_Gold = Leveler_CharacterGold()
	If Not Leveler_SecondaryStepReadyToLeave() Or $l_i_Gold < $XUNLAI_GOLD_COST Then
		Leveler_LogQuestState($QUEST_SECONDARY, "Choose Secondary")
		Out("[Step] Need Togo's #317 reward before Xunlai (gold " & $l_i_Gold & "). Returning to Unlock Secondary.")
		$g_i_Step = $LEVELER_STEP_SECONDARY
		Return False
	EndIf
	If Map_GetMapID() <> $MAP_SHING_JEA Then
		If Not Leveler_Travel($MAP_SHING_JEA) Then Return False
	EndIf
	Leveler_SetPacifist()
	Out("[Step] Character gold: " & $l_i_Gold)
	If Not Leveler_MoveTo(-4958, 9472, False) Then Return False
	If Not Leveler_MoveTo(-5465, 9727, False) Then Return False
	If Not Leveler_MoveTo(-4791, 10140, False) Then Return False
	If Not Leveler_MoveTo(-3945, 10328, False) Then Return False
	If Not Leveler_MoveAndDialog(-3825.09, 10386.81, $DIALOG_GENERIC_TALK, False, $MODEL_XUNLAI) Then Return False
	Local $l_i_Xunlai = Leveler_GetAgentByModel($MODEL_XUNLAI)
	If $l_i_Xunlai <> 0 Then Agent_GoNPC($l_i_Xunlai)
	Sleep(600)
	Ui_Dialog($DIALOG_XUNLAI_1)
	Sleep(800)
	Ui_Dialog($DIALOG_XUNLAI_2)
	Sleep(800)
	Local $l_i_GoldAfter = Item_GetInventoryInfo("GoldCharacter")
	If $l_i_GoldAfter > $l_i_Gold - $XUNLAI_GOLD_COST + 5 Then
		Out("[Step] Xunlai unlock did not take " & $XUNLAI_GOLD_COST & " gold (now " & $l_i_GoldAfter & "). Not advancing.")
		Return False
	EndIf
	Out("[Step] Xunlai storage unlocked")
	Return True
EndFunc

Func Leveler_Step_CraftWeapon()
	$g_s_CurrentHeader = "Craft Weapon"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Not Leveler_Travel($MAP_SHING_JEA) Then Return False
	Leveler_SetPacifist()
	Item_WithdrawGold(5000)
	Sleep(400)
	If Not Leveler_MoveTo(-10896.94, 10807.54, False) Then Return False
	If Not Leveler_MoveTo(-10942.73, 10783.19, False) Then Return False
	If Not Leveler_InteractNpcAt(-10614.00, 10996.00, False) Then Return False
	If Not Leveler_BuyWeaponMaterials() Then Return False
	If Not Leveler_BuyEarlyArmorMaterials() Then Return False
	If Not Leveler_MoveTo(-10896.94, 10807.54, False) Then Return False
	If Not Leveler_InteractNpcAt(-6519.00, 12335.00, False) Then Return False
	Sleep(1000)
	If Not Leveler_CraftWeapon() Then Return False
	Return True
EndFunc

Func Leveler_Step_CraftMonasteryArmor()
	$g_s_CurrentHeader = "Craft Monastery Armor"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Not Leveler_Travel($MAP_SHING_JEA) Then Return False
	Leveler_SetPacifist()
	If Not Leveler_InteractNpcAt(-7115.00, 12636.00, False) Then Return False
	If Not Leveler_CraftMonasteryArmor() Then Return False
	Return True
EndFunc

Func Leveler_Step_DestroyStarter()
	$g_s_CurrentHeader = "Destroy Starter Armor"
	Out("=== " & $g_s_CurrentHeader & " ===")
	Return Leveler_DestroyStarterArmorAndJunk()
EndFunc

Func Leveler_Step_ExtendInventory()
	$g_s_CurrentHeader = "Extend Inventory"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Not Leveler_Travel($MAP_SHING_JEA) Then Return False
	Leveler_SetPacifist()
	Return Leveler_ExtendInventory()
EndFunc

Func Leveler_Step_UnlockSkills()
	$g_s_CurrentHeader = "Unlock Skills Trainer"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Not Leveler_Travel($MAP_SHING_JEA) Then Return False
	Leveler_SetPacifist()
	If Not Leveler_MoveAndDialog(-8790.00, 10366.00, $DIALOG_GENERIC_TALK, False) Then Return False
	Sleep(3000)
	Skill_BuySkillByID($SKILL_CRY_OF_PAIN)
	Sleep(250)
	Skill_BuySkillByID($SKILL_POWER_DRAIN)
	Sleep(250)
	Skill_BuySkillByID($SKILL_SIGNET_OF_DISRUPTION)
	Sleep(250)
	Out("[Step] Bought trainer skills 57 / 25 / 860")
	Return True
EndFunc

Func Leveler_Step_ToChosEstate()
	$g_s_CurrentHeader = "To Minister Cho's Estate"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Leveler_SkipIfQuestDone($QUEST_FORMAL_INTRO, "A Formal Introduction") Then Return True
	If Not Leveler_Travel($MAP_SHING_JEA) Then Return False
	If Not Leveler_MoveAndExit(-14961, 11453, $MAP_SUNQUA_VALE, False) Then Return False
	Leveler_SetPacifist()
	If Not Leveler_MoveTo(16182.62, -7841.86, False) Then Return False
	If Not Leveler_MoveTo(6611.58, 15847.51, False) Then Return False
	If Not Leveler_QuestLoop($QUEST_FORMAL_INTRO, 6637, 16147, $DIALOG_FORMAL_SKIP, "skip") Then
		If Map_GetMapID() <> $MAP_CHO_OUTPOST Then Map_WaitMapLoading($MAP_CHO_OUTPOST)
	EndIf
	If Map_GetMapID() <> $MAP_CHO_OUTPOST Then
		If Not Map_WaitMapLoading($MAP_CHO_OUTPOST) Then Return False
	EndIf
	If Not Leveler_QuestLoop($QUEST_FORMAL_INTRO, 7884, -10029, $DIALOG_FORMAL_COMPLETE, "complete") Then Return False
	Return True
EndFunc

Func Leveler_Step_ChosMission()
	$g_s_CurrentHeader = "Minister Cho's Estate Mission"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Map_GetMapID() <> $MAP_CHO_OUTPOST Or Not Map_GetInstanceInfo("IsOutpost") Then
		If Not Leveler_Travel($MAP_CHO_OUTPOST) Then Return False
	EndIf
	Leveler_PrepareForBattle()
	Map_EnterChallenge(True)
	Sleep(1500)
	Map_WaitMapLoading()
	If Leveler_IsWiped() Then Return False

	If Not Leveler_MoveTo(6220.76, -7360.73, True) Then Return False
	If Not Leveler_MoveTo(5523.95, -7746.41, True) Then Return False
	Sleep(15000)
	If Not Leveler_MoveTo(591.21, -9071.10, True) Then Return False
	Sleep(30000)
	If Not Leveler_MoveTo(4889, -5043, True) Then Return False
	If Not Leveler_MoveTo(4268.49, -3621.66, True) Then Return False
	Sleep(20000)
	If Not Leveler_MoveTo(6216, -1108, True) Then Return False
	If Not Leveler_MoveTo(2617, 642, True) Then Return False
	If Not Leveler_MoveTo(1706.90, 1711.44, True) Then Return False
	Sleep(30000)
	If Not Leveler_MoveTo(333.32, 1124.44, True) Then Return False
	If Not Leveler_MoveTo(-3337.14, -4741.27, True) Then Return False
	Sleep(35000)
	$g_b_CombatMode = True
	If Not Leveler_MoveTo(-4661.99, -6285.81, True) Then Return False
	If Not Leveler_MoveTo(-7454, -7384, True) Then Return False
	If Not Leveler_MoveTo(-9138, -4191, True) Then Return False
	If Not Leveler_MoveTo(-7109, -25, True) Then Return False
	If Not Leveler_MoveTo(-7443, 2243, True) Then Return False
	Sleep(5000)
	If Not Leveler_MoveTo(-16924, 2445, True) Then Return False
	If Not Leveler_InteractNpcAt(-17031, 2448, True) Then
		Local $l_i_Npc = Leveler_GetNearestNPC(400)
		If $l_i_Npc <> 0 Then Agent_GoNPC($l_i_Npc)
	EndIf
	If Not Map_WaitMapLoading($MAP_RAN_MUSU) Then Return False
	Out("[Step] Minister Cho's Estate complete. Arrived in Ran Musu Gardens.")
	Return True
EndFunc

Func Leveler_HandleBonusBow()
	; Phase 2 stub: bonus-item / custom bow spawn is out of scope.
	Return True
EndFunc

Func Leveler_Step_LostTreasure()
	$g_s_CurrentHeader = "Quest: Lost Treasure"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Leveler_SkipIfQuestDone($QUEST_LOST_TREASURE, "Lost Treasure") Then Return True

	If Map_GetMapID() <> $MAP_CHO_EXPLORABLE Then
		If Not Leveler_Travel($MAP_RAN_MUSU) Then Return False
		If Not Leveler_HasQuest($QUEST_LOST_TREASURE) Then
			Leveler_SetPacifist()
			Leveler_MoveTo(16184.75, 19001.78, False)
			If Not Leveler_QuestLoop($QUEST_LOST_TREASURE, 14363.00, 19499.00, $DIALOG_LOST_TREASURE_ACCEPT, "accept") Then Return False
		EndIf
		Leveler_PrepareForBattle()
		If Not Leveler_MoveTo(13713.27, 18504.61, True) Then Return False
		If Not Leveler_MoveTo(14576.15, 17817.62, True) Then Return False
		If Not Leveler_MoveTo(15824.60, 18817.90, True) Then Return False
		If Not Leveler_MoveAndExit(17005, 19787, $MAP_CHO_EXPLORABLE, True) Then Return False
	Else
		Leveler_PrepareForBattle()
	EndIf

	If Not Leveler_MoveTo(-17979.38, -493.08, True) Then Return False
	If Not Leveler_QuestLoop($QUEST_LOST_TREASURE, 0, 0, $DIALOG_LOST_TREASURE_STEP, "step", $MODEL_LOST_TREASURE_GUARD) Then Return False
	Sleep(5000)
	If Not Leveler_FollowModel($MODEL_LOST_TREASURE_GUARD) Then Return False
	If Not Leveler_QuestLoop($QUEST_LOST_TREASURE, 0, 0, $DIALOG_LOST_TREASURE_COMPLETE, "complete", $MODEL_LOST_TREASURE_GUARD) Then Return False
	If Not Leveler_Travel($MAP_RAN_MUSU) Then Return False
	Out("[Step] Lost Treasure complete")
	Return True
EndFunc

Func Leveler_Step_WarningTheTengu()
	$g_s_CurrentHeader = "Quest: Warning the Tengu"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Leveler_SkipIfQuestDone($QUEST_WARNING_TENGU, "Warning the Tengu") Then Return True
	Leveler_HandleBonusBow()

	If Map_GetMapID() <> $MAP_KINYA Then
		If Not Leveler_Travel($MAP_RAN_MUSU) Then Return False
		If Not Leveler_HasQuest($QUEST_WARNING_TENGU) Then
			If Not Leveler_QuestLoop($QUEST_WARNING_TENGU, 15846, 19013, $DIALOG_TENGU_ACCEPT, "accept") Then Return False
		EndIf
		Leveler_PrepareForBattle()
		If Not Leveler_MoveAndExit(14730, 15176, $MAP_KINYA, True) Then Return False
	Else
		Leveler_PrepareForBattle()
	EndIf

	If Not Leveler_MoveTo(1429, 12768, True) Then Return False
	If Not Leveler_QuestLoop($QUEST_WARNING_TENGU, -1023, 4844, $DIALOG_TENGU_STEP, "step") Then Return False
	If Not Leveler_MoveTo(-5011, 732, True) Then Return False
	If Not Leveler_WaitOutOfCombat() Then Return False
	If Not Leveler_QuestLoop($QUEST_WARNING_TENGU, -1023, 4844, $DIALOG_TENGU_COMPLETE, "complete") Then Return False
	Out("[Step] Warning the Tengu complete")
	Return True
EndFunc

Func Leveler_Step_TheThreatGrows()
	$g_s_CurrentHeader = "Quest: The Threat Grows"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Leveler_IsQuestDone($QUEST_THREAT_GROWS) And (Leveler_IsQuestDone($QUEST_JOURNEY_MASTER) Or Leveler_HasQuest($QUEST_JOURNEY_MASTER)) Then
		Out("[Step] The Threat Grows already completed")
		Return True
	EndIf

	If Not Leveler_HasQuest($QUEST_THREAT_GROWS) And Not Leveler_HasQuest($QUEST_JOURNEY_MASTER) Then
		If Map_GetMapID() <> $MAP_KINYA Then
			If Not Leveler_Travel($MAP_RAN_MUSU) Then Return False
			Leveler_PrepareForBattle()
			If Not Leveler_MoveAndExit(14730, 15176, $MAP_KINYA, True) Then Return False
		EndIf
		If Not Leveler_QuestLoop($QUEST_THREAT_GROWS, -1023, 4844, $DIALOG_THREAT_ACCEPT, "accept") Then Return False
	EndIf

	If Map_GetMapID() <> $MAP_TSUMEI And Map_GetMapID() <> $MAP_PANJIANG Then
		If Not Leveler_Travel($MAP_SHING_JEA) Then Return False
		Leveler_PrepareForBattle()
		If Not Leveler_MoveAndExit(-14961, 11453, $MAP_SUNQUA_VALE, True) Then Return False
		Leveler_SetPacifist()
		If Not Leveler_MoveTo(18245.78, -9448.29, False) Then Return False
		If Not Leveler_MoveAndExit(-4842, -13267, $MAP_TSUMEI, False) Then Return False
	EndIf

	If Map_GetMapID() = $MAP_TSUMEI Then
		Leveler_PrepareForBattle()
		If Not Leveler_MoveAndExit(-11600, -17400, $MAP_PANJIANG, True) Then Return False
	EndIf

	If Not Leveler_MoveTo(10077.84, 8047.69, True) Then Return False
	If Not Leveler_WaitUntilModelHasQuest($MODEL_SISTER_TAI) Then Return False
	Leveler_SetPacifist()
	If Not Leveler_QuestLoop($QUEST_THREAT_GROWS, 0, 0, $DIALOG_THREAT_COMPLETE, "complete", $MODEL_SISTER_TAI) Then Return False
	If Not Leveler_QuestLoop($QUEST_JOURNEY_MASTER, 0, 0, $DIALOG_JOURNEY_ACCEPT, "accept", $MODEL_SISTER_TAI) Then Return False
	Out("[Step] The Threat Grows complete. Accepted Journey of the Master.")
	Return True
EndFunc

Func Leveler_Step_TheRoadLessTraveled()
	$g_s_CurrentHeader = "Quest: The Road Less Traveled"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Leveler_SkipIfQuestDone($QUEST_ROAD_LESS, "The Road Less Traveled") Then Return True

	Local $l_i_Map = Map_GetMapID()
	If $l_i_Map <> $MAP_SAOSHANG And $l_i_Map <> $MAP_SEITUNG And $l_i_Map <> $MAP_LINNOK Then
		If Not Leveler_Travel($MAP_SHING_JEA) Then Return False
		Leveler_PrepareForBattle()
		If Not Leveler_MoveAndExit(-3480, 9460, $MAP_LINNOK, False) Then Return False
	EndIf

	If Map_GetMapID() = $MAP_LINNOK Or Map_GetMapID() = $MAP_SHING_JEA Then
		If Map_GetMapID() <> $MAP_LINNOK Then
			If Not Leveler_MoveAndExit(-3480, 9460, $MAP_LINNOK, False) Then Return False
		EndIf
		Local $l_i_Togo = Leveler_TogoModel()
		If Leveler_HasQuest($QUEST_JOURNEY_MASTER) Then
			If Not Leveler_QuestLoop($QUEST_JOURNEY_MASTER, -92, 9217, $DIALOG_JOURNEY_COMPLETE, "complete", $l_i_Togo) Then Return False
		EndIf
		If Not Leveler_HasQuest($QUEST_ROAD_LESS) Then
			If Not Leveler_QuestLoop($QUEST_ROAD_LESS, -92, 9217, $DIALOG_ROAD_ACCEPT, "accept", $l_i_Togo) Then Return False
		EndIf
		If Not Leveler_QuestLoop($QUEST_ROAD_LESS, 538, 10125, $DIALOG_ROAD_STEP1, "step") Then
			If Map_GetMapID() <> $MAP_SAOSHANG Then Map_WaitMapLoading($MAP_SAOSHANG)
		EndIf
		If Map_GetMapID() <> $MAP_SAOSHANG Then
			If Not Map_WaitMapLoading($MAP_SAOSHANG) Then Return False
		EndIf
	EndIf

	If Map_GetMapID() = $MAP_SAOSHANG Then
		If Not Leveler_QuestLoop($QUEST_ROAD_LESS, 1254, 10875, $DIALOG_ROAD_STEP2, "step") Then Return False
		If Not Leveler_MoveAndExit(16600, 13150, $MAP_SEITUNG, False) Then Return False
	EndIf

	If Map_GetMapID() <> $MAP_SEITUNG Then
		If Not Leveler_Travel($MAP_SEITUNG) Then Return False
	EndIf
	Leveler_MoveTo(16852, 12812, False)
	If Leveler_HasQuest($QUEST_ROAD_LESS) Then
		If Not Leveler_QuestLoop($QUEST_ROAD_LESS, 16435, 12047, $DIALOG_ROAD_COMPLETE, "complete") Then Return False
	EndIf
	Out("[Step] The Road Less Traveled complete. Arrived in Seitung Harbor.")
	Return True
EndFunc

Func Leveler_Step_CraftSeitungArmor()
	$g_s_CurrentHeader = "Craft Seitung Armor"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Leveler_HasSeitungArmor() Then
		Out("[Step] Seitung armor already crafted")
		Return True
	EndIf

	; Buy the larger Seitung material counts at the known Shing Jea merchant first.
	If Not Leveler_Travel($MAP_SHING_JEA) Then Return False
	Leveler_SetPacifist()
	Item_WithdrawGold(15000)
	Sleep(400)
	If Not Leveler_MoveTo(-10896.94, 10807.54, False) Then Return False
	If Not Leveler_InteractNpcAt(-10614.00, 10996.00, False) Then Return False
	If Not Leveler_BuySeitungMaterials() Then Return False

	If Not Leveler_Travel($MAP_SEITUNG) Then Return False
	Leveler_SetPacifist()
	If Not Leveler_MoveTo(19823.66, 9547.78, False) Then Return False
	If Not Leveler_InteractNpcAt(20508.00, 9497.00, False) Then Return False
	If Not Leveler_CraftSeitungArmor() Then Return False
	Return True
EndFunc

Func Leveler_Step_DestroyMonastery()
	$g_s_CurrentHeader = "Destroy Monastery Armor"
	Out("=== " & $g_s_CurrentHeader & " ===")
	Return Leveler_DestroyMonasteryArmor()
EndFunc

Func Leveler_Step_ToZenDaijun()
	$g_s_CurrentHeader = "To Zen Daijun"
	Out("=== " & $g_s_CurrentHeader & " ===")
	Local $l_i_Map = Map_GetMapID()
	If $l_i_Map = $MAP_ZEN_OP And Map_GetInstanceInfo("IsOutpost") Then
		Out("[Step] Already at Zen Daijun")
		Return True
	EndIf

	If $l_i_Map <> $MAP_JAYA And $l_i_Map <> $MAP_HAIJU Then
		If Not Leveler_Travel($MAP_SEITUNG) Then Return False
		Leveler_PrepareForBattle()
		If Not Leveler_MoveTo(18000, 11650, False) Then Return False
		If Not Leveler_MoveTo(19000, 13000, False) Then Return False
		If Not Leveler_MoveAndExit(16777, 17540, $MAP_JAYA, True) Then Return False
	EndIf

	If Map_GetMapID() = $MAP_JAYA Then
		If Not Leveler_MoveAndExit(23616, 1587, $MAP_HAIJU, True) Then Return False
	EndIf

	If Map_GetMapID() = $MAP_HAIJU Then
		If Not Leveler_MoveAndDialog(16489, -22213, $DIALOG_FORMAL_SKIP, True) Then Return False
		Sleep(7000)
		If Not Map_WaitMapLoading($MAP_ZEN_OP) Then Return False
	EndIf

	If Map_GetMapID() <> $MAP_ZEN_OP Then Return False
	Out("[Step] Arrived at Zen Daijun")
	Return True
EndFunc

Func Leveler_Step_CompleteSkillsTraining()
	$g_s_CurrentHeader = "Complete Skills Training"
	Out("=== " & $g_s_CurrentHeader & " ===")
	Party_LeaveGroup(True)
	Sleep(400)
	If Not Leveler_Travel($MAP_SHING_JEA) Then Return False
	Leveler_SetPacifist()
	If Not Leveler_MoveAndDialog(-8790.00, 10366.00, $DIALOG_GENERIC_TALK, False) Then Return False
	Sleep(3000)
	Skill_BuySkillByID($SKILL_POWER_SPIKE)
	Sleep(250)
	If Leveler_IsMesmer() Then
		Skill_BuySkillByID($SKILL_BACKFIRE)
		Sleep(250)
	EndIf
	If Leveler_IsMesmer() Then
		Out("[Step] Bought skills 61 and 54")
	Else
		Out("[Step] Bought skill 61")
	EndIf
	Return True
EndFunc

Func Leveler_Step_ZenDaijunMission()
	$g_s_CurrentHeader = "Zen Daijun Mission"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Map_GetMapID() <> $MAP_ZEN_OP Or Not Map_GetInstanceInfo("IsOutpost") Then
		If Not Leveler_Travel($MAP_ZEN_OP) Then Return False
	EndIf
	Leveler_PrepareForBattle()
	Map_EnterChallenge(True)
	Sleep(1500)
	Map_WaitMapLoading()
	If Leveler_IsWiped() Then Return False

	$g_b_SpiritRiftWatch = True
	$g_h_RiftCooldown = TimerInit()
	$g_b_CombatMode = True

	If Not Leveler_MoveTo(15120.68, 10456.73, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	Sleep(15000)
	If Not Leveler_MoveTo(11990.38, 10782.05, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	Sleep(10000)
	If Not Leveler_MoveTo(10161.92, 9751.41, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(9723.10, 7968.76, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_WaitOutOfCombat() Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_InteractGadgetAt(9632.00, 8058.00, True) Then
		Out("[Step] Gadget interact failed; continuing the path")
	EndIf
	If Not Leveler_MoveTo(9412.15, 7257.83, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(9183.47, 6653.42, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(8966.42, 6203.29, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(3510.94, 2724.63, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(2120.18, 1690.91, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(928.27, 2782.67, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(744.67, 4187.17, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(242.27, 6558.48, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(-4565.76, 8326.51, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(-5374.88, 8626.30, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(-10291.65, 8519.68, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(-11009.76, 6292.73, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(-12762.20, 6112.31, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(-14029.90, 3699.97, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(-13243.47, 1253.06, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(-11907.05, 28.87, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(-11306.09, 802.47, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	Sleep(5000)
	If Not Leveler_MoveTo(-10255.23, 178.48, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	If Not Leveler_MoveTo(-9068.41, -553.94, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	Sleep(5000)
	If Not Leveler_MoveTo(-7949.79, -1376.02, True) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	Leveler_MoveTo(-7688.63, -1538.34, True)
	If Not Map_WaitMapLoading($MAP_SEITUNG) Then
		$g_b_SpiritRiftWatch = False
		Return False
	EndIf
	$g_b_SpiritRiftWatch = False
	Out("[Step] Zen Daijun complete. Arrived in Seitung Harbor.")
	Return True
EndFunc

Func Leveler_Step_ToMarketplace()
	$g_s_CurrentHeader = "To Marketplace"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Map_GetMapID() = $MAP_MARKETPLACE And Map_GetInstanceInfo("IsOutpost") Then
		Out("[Step] Already at The Marketplace")
		Return True
	EndIf

	If Map_GetMapID() <> $MAP_KAINENG_DOCKS Then
		If Not Leveler_Travel($MAP_SEITUNG) Then Return False
		If Not Leveler_HasQuest($QUEST_MASTERS_BURDEN) Then
			If Not Leveler_QuestLoop($QUEST_MASTERS_BURDEN, 16927, 9004, $DIALOG_BURDEN_ACCEPT, "accept") Then Return False
		EndIf
		If Not Leveler_QuestLoop($QUEST_MASTERS_BURDEN, 16927, 9004, $DIALOG_GENERIC_TALK, "step") Then
			If Map_GetMapID() <> $MAP_KAINENG_DOCKS Then Map_WaitMapLoading($MAP_KAINENG_DOCKS)
		EndIf
		If Map_GetMapID() <> $MAP_KAINENG_DOCKS Then
			If Not Map_WaitMapLoading($MAP_KAINENG_DOCKS) Then Return False
		EndIf
	EndIf

	If Not Leveler_QuestLoop($QUEST_MASTERS_BURDEN, 9955, 20033, $DIALOG_BURDEN_STEP2, "step") Then Return False
	If Not Leveler_MoveAndExit(12003, 18529, $MAP_MARKETPLACE, False) Then Return False
	Out("[Step] Arrived at The Marketplace")
	Return True
EndFunc

Func Leveler_Step_ToKainengCenter()
	$g_s_CurrentHeader = "To Kaineng Center"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Map_GetMapID() = $MAP_KAINENG And Map_GetInstanceInfo("IsOutpost") Then
		Out("[Step] Already in Kaineng Center")
		Return True
	EndIf

	If Map_GetMapID() <> $MAP_BUKDEK Then
		If Not Leveler_Travel($MAP_MARKETPLACE) Then Return False
		Leveler_PrepareForBattle()
		If Not Leveler_MoveAndExit(16640, 19882, $MAP_BUKDEK, True) Then Return False
	Else
		Leveler_PrepareForBattle()
	EndIf

	If Not Leveler_MoveTo(-10254.0, -1759.0, True) Then Return False
	If Not Leveler_MoveTo(-10332.0, 1442.0, True) Then Return False
	If Not Leveler_MoveTo(-10965.0, 9309.0, True) Then Return False
	If Not Leveler_MoveTo(-9467.0, 14207.0, True) Then Return False
	If Not Leveler_MoveTo(-8601.28, 17419.64, True) Then Return False
	If Not Leveler_MoveTo(-6857.17, 19098.28, True) Then Return False
	If Not Leveler_MoveAndExit(-6706, 20388, $MAP_KAINENG, True) Then Return False
	Out("[Step] Arrived in Kaineng Center")
	Return True
EndFunc

Func Leveler_Step_CraftMaxArmor()
	$g_s_CurrentHeader = "Craft Max Armor"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Leveler_HasMaxArmor() Then
		Out("[Step] Max armor already crafted")
		Return True
	EndIf

	If Not Leveler_Travel($MAP_KAINENG) Then Return False
	Leveler_SetPacifist()
	If Not Leveler_MoveTo(1592.00, -796.00, False) Then Return False
	Item_WithdrawGold(20000)
	Sleep(400)
	If Not Leveler_InteractNpcAt(1592.00, -796.00, False) Then Return False
	If Not Leveler_BuyMaxArmorMaterials(True) Then Return False
	Sleep(1500)

	Local $l_ai_RareM, $l_ai_RareC
	Leveler_GetMaxArmorMatNeeds(False, $l_ai_RareM, $l_ai_RareC)
	If UBound($l_ai_RareM) > 0 Then
		If Not Leveler_InteractNpcAt(1495.00, -1315.00, False) Then Return False
		If Not Leveler_BuyMaxArmorMaterials(False) Then Return False
		Sleep(2000)
	EndIf

	Local $l_f_X, $l_f_Y
	Leveler_GetMaxArmorCrafter($l_f_X, $l_f_Y)
	If Not Leveler_MoveTo($l_f_X, $l_f_Y, False) Then Return False
	If Not Leveler_InteractNpcAt($l_f_X, $l_f_Y, False) Then Return False
	Sleep(1000)
	If Not Leveler_CraftMaxArmor() Then Return False
	Return True
EndFunc

Func Leveler_Step_DestroySeitung()
	$g_s_CurrentHeader = "Destroy Seitung Armor"
	Out("=== " & $g_s_CurrentHeader & " ===")
	Return Leveler_DestroySeitungArmor()
EndFunc

Func Leveler_Step_SearchForACure()
	$g_s_CurrentHeader = "Quest: The Search For A Cure"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Leveler_SkipIfQuestDone($QUEST_SEARCH_CURE, "The Search For A Cure") Then Return True

	If Not Leveler_HasQuest($QUEST_SEARCH_CURE) Then
		If Not Leveler_Travel($MAP_KAINENG) Then Return False
		If Not Leveler_QuestLoop($QUEST_SEARCH_CURE, 3772.00, -961.00, $DIALOG_CURE_ACCEPT, "accept") Then Return False
	EndIf
	If Map_GetMapID() = $MAP_KAINENG Then
		If Not Leveler_QuestLoop($QUEST_SEARCH_CURE, 1784.00, 991.00, $DIALOG_CURE_STEP, "step") Then Return False
	EndIf

	If Map_GetMapID() <> $MAP_WAJJUN Then
		If Not Leveler_Travel($MAP_MARKETPLACE) Then Return False
		Leveler_PrepareForBattle()
		If Not Leveler_MoveAndExit(11430.00, 15200.00, $MAP_WAJJUN, True) Then Return False
	EndIf

	If Not Leveler_MoveTo(10350.00, 14100.00, True) Then Return False
	If Not Leveler_MoveTo(8300.00, 14100.00, True) Then Return False
	Leveler_LootNearby($MODEL_CURE_LOOT, 2000, 8000)
	Sleep(5000)

	If Not Leveler_Travel($MAP_KAINENG) Then Return False
	If Not Leveler_QuestLoop($QUEST_SEARCH_CURE, 1784.00, 991.00, $DIALOG_CURE_COMPLETE, "complete") Then Return False
	Out("[Step] The Search For A Cure complete")
	Return True
EndFunc

Func Leveler_Step_AMastersBurden()
	$g_s_CurrentHeader = "Quest: A Master's Burden"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Leveler_SkipIfQuestDone($QUEST_MASTERS_BURDEN, "A Master's Burden") Then Return True

	If Not Leveler_Travel($MAP_KAINENG) Then Return False
	If Not Leveler_HasQuest($QUEST_BROTHER_TOSAI) Then
		Leveler_MoveAndDialog(1784.00, 991.00, $DIALOG_TOSAI_ACCEPT, False)
	EndIf
	If Leveler_HasQuest($QUEST_MASTERS_BURDEN) Then Ui_ActiveQuest($QUEST_MASTERS_BURDEN)
	Sleep(300)

	If Map_GetMapID() <> $MAP_KAINENG_DOCKS Then
		If Not Leveler_Travel($MAP_MARKETPLACE) Then Return False
		Leveler_PrepareForBattle()
		If Not Leveler_MoveAndExit(11430.00, 15200.00, $MAP_WAJJUN, True) Then Return False
		If Not Leveler_MoveTo(10033.88, 13838.59, True) Then Return False
		If Not Leveler_MoveTo(11637.23, 11837.92, True) Then Return False
		If Not Leveler_MoveTo(10007.72, 10951.80, True) Then Return False
		If Not Leveler_MoveTo(8200.78, 12134.04, True) Then Return False
		If Not Leveler_MoveTo(8133.31, 7629.99, True) Then Return False
		If Not Leveler_MoveTo(5329.09, 7626.73, True) Then Return False
		If Not Leveler_MoveTo(4145.20, 6584.09, True) Then Return False
		If Not Leveler_MoveTo(-1663.82, 7113.72, True) Then Return False
		If Not Leveler_QuestLoop($QUEST_MASTERS_BURDEN, -1893.00, 6922.00, $DIALOG_BURDEN_STEP2, "step", $MODEL_BROTHER_TOSAI) Then Return False
		If Not Leveler_MoveTo(4207.15, 6226.59, True) Then Return False
		If Not Leveler_MoveTo(4944.20, 3398.03, True) Then Return False
		If Not Leveler_MoveTo(4401.08, 618.24, True) Then Return False
		If Not Leveler_MoveTo(5802.95, -2295.56, True) Then Return False
		If Not Leveler_MoveTo(4671.93, -5007.46, True) Then Return False
		If Not Leveler_QuestLoop($QUEST_MASTERS_BURDEN, 10774.00, -6636.00, $DIALOG_BURDEN_STEP2, "step", $MODEL_BURDEN_NPC) Then Return False
	EndIf

	If Map_GetMapID() <> $MAP_KAINENG_DOCKS Then
		If Not Leveler_Travel($MAP_MARKETPLACE) Then Return False
		If Not Leveler_MoveTo(12250, 18236, False) Then Return False
		If Not Leveler_MoveTo(10343, 20329, False) Then Return False
		If Not Map_WaitMapLoading($MAP_KAINENG_DOCKS) Then Return False
	EndIf
	If Not Leveler_QuestLoop($QUEST_MASTERS_BURDEN, 9950.00, 20033.00, $DIALOG_BURDEN_COMPLETE, "complete") Then Return False
	If Leveler_HasQuest($QUEST_BROTHER_TOSAI) Then
		Ui_ActiveQuest($QUEST_BROTHER_TOSAI)
		Sleep(200)
		Quest_AbandonQuest($QUEST_BROTHER_TOSAI)
		Sleep(300)
	EndIf
	Out("[Step] A Master's Burden complete")
	Return True
EndFunc

Func Leveler_Step_UnlockMox()
	$g_s_CurrentHeader = "Unlock Mox"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Not Leveler_Travel($MAP_KAINENG) Then Return False
	Leveler_PrepareForBattle()
	If Not Leveler_MoveAndExit(3243, -4911, $MAP_BUKDEK, True) Then Return False
	If Not Leveler_MoveAndDialog(-5803.48, 18951.70, $DIALOG_UNLOCK_MOX, True) Then Return False
	Sleep(1000)
	If Not Leveler_Travel($MAP_KAINENG) Then Return False
	Out("[Step] Mox unlock dialog sent. Back in Kaineng Center.")
	Return True
EndFunc

Func Leveler_Step_ToBorealStation()
	$g_s_CurrentHeader = "To Boreal Station"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Map_GetMapID() = $MAP_BOREAL And Map_GetInstanceInfo("IsOutpost") Then
		Out("[Step] Already at Boreal Station")
		Return True
	EndIf

	If Map_GetMapID() <> $MAP_TUNNELS Then
		If Not Leveler_Travel($MAP_KAINENG) Then Return False
		Leveler_MoveTo(3444.90, -1728.31, False)
		If Not Leveler_HasQuest($QUEST_EARTH_MOVE) Then
			If Not Leveler_QuestLoop($QUEST_EARTH_MOVE, 3747.00, -2174.00, $DIALOG_EARTH_ACCEPT, "accept") Then Return False
		EndIf
		Leveler_MoveTo(3444.90, -1728.31, False)
		Leveler_PrepareForBattle()
		If Not Leveler_MoveAndExit(3243, -4911, $MAP_BUKDEK, True) Then Return False
		If Not Leveler_QuestLoop($QUEST_EARTH_MOVE, -10103.00, 16493.00, $DIALOG_GENERIC_TALK, "step") Then
			If Map_GetMapID() <> $MAP_TUNNELS Then Map_WaitMapLoading($MAP_TUNNELS, -1, 45000)
		EndIf
		If Map_GetMapID() <> $MAP_TUNNELS Then
			If Not Map_WaitMapLoading($MAP_TUNNELS, -1, 45000) Then Return False
		EndIf
	EndIf

	If Not Leveler_MoveTo(16738.77, 3046.05, True) Then Return False
	If Not Leveler_MoveTo(13028.36, 6146.36, True) Then Return False
	If Not Leveler_MoveTo(10968.19, 9623.72, True) Then Return False
	If Not Leveler_MoveTo(3918.55, 10383.79, True) Then Return False
	If Not Leveler_MoveTo(8435, 14378, True) Then Return False
	If Not Leveler_MoveTo(10134, 16742, True) Then Return False
	Sleep(3000)
	Leveler_SetPacifist()
	If Not Leveler_MoveTo(4523.25, 15448.03, False) Then Return False
	If Not Leveler_MoveTo(-43.80, 18365.45, False) Then Return False
	If Not Leveler_MoveTo(-10234.92, 16691.96, False) Then Return False
	If Not Leveler_MoveTo(-17917.68, 18480.57, False) Then Return False
	If Not Leveler_MoveAndExit(-18775, 19097, $MAP_BOREAL, False) Then
		Sleep(8000)
		If Not Map_WaitMapLoading($MAP_BOREAL, -1, 20000) Then Return False
	EndIf
	Out("[Step] Arrived at Boreal Station")
	Return True
EndFunc

Func Leveler_Step_ToEyeOfTheNorth()
	$g_s_CurrentHeader = "To Eye of the North"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Map_GetMapID() = $MAP_EOTN And Map_GetInstanceInfo("IsOutpost") Then
		Out("[Step] Already at Eye of the North")
		Return True
	EndIf

	If Map_GetMapID() <> $MAP_ICE_CLIFF Then
		If Not Leveler_Travel($MAP_BOREAL) Then Return False
		Leveler_PrepareForBattle()
		If Not Leveler_MoveAndExit(4684, -27869, $MAP_ICE_CLIFF, True) Then Return False
	Else
		Leveler_PrepareForBattle()
	EndIf

	If Not Leveler_MoveTo(3579.07, -22007.27, True) Then Return False
	Sleep(15000)
	If Not Leveler_TalkModel($MODEL_DESTROYERS_NPC, $DIALOG_DESTROYERS_STEP1) Then
		Out("[Step] Against the Destroyers NPC dialog failed; continuing the path")
	EndIf
	If Not Leveler_MoveTo(3743.31, -15862.36, True) Then Return False
	If Not Leveler_MoveTo(3607.21, -6937.32, True) Then Return False
	If Not Leveler_MoveTo(2557.23, -275.97, True) Then Return False
	If Not Leveler_MoveAndExit(-641.25, 2069.27, $MAP_EOTN, True) Then Return False
	Out("[Step] Arrived at Eye of the North")
	Return True
EndFunc

Func Leveler_Step_UnlockEotnPool()
	$g_s_CurrentHeader = "Unlock Eye of the North Pool"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Map_GetMapID() <> $MAP_HOM Then
		If Not Leveler_Travel($MAP_EOTN) Then Return False
		Leveler_SetPacifist()
		If Not Leveler_MoveTo(-4416.39, 4932.36, False) Then Return False
		If Not Leveler_MoveAndExit(-5198.00, 5595.00, $MAP_HOM, False) Then Return False
	EndIf

	Leveler_SetPacifist()
	If Not Leveler_MoveTo(-6572.70, 6588.83, False) Then Return False
	Leveler_TalkModel($MODEL_GWEN, $DIALOG_POOL_CINEMATIC)
	Sleep(1000)
	Leveler_WaitCinematic()
	Leveler_TalkModel($MODEL_EOTN_POOL, $DIALOG_POOL_STEP3)
	Sleep(1000)
	Leveler_WaitCinematic()
	If Map_GetMapID() <> $MAP_HOM Then Map_WaitMapLoading($MAP_HOM, -1, 30000)
	Sleep(500)

	Leveler_TalkModel($MODEL_GWEN, $DIALOG_GWEN_TAPESTRY)
	Sleep(1000)
	Leveler_TalkModel($MODEL_GWEN, $DIALOG_VANGUARD_STEP)
	Ui_Dialog($DIALOG_KEIRAN_BOW)
	Sleep(600)
	Leveler_TalkModel($MODEL_OGDEN, $DIALOG_OGDEN_ALLIES)
	Leveler_TalkModel($MODEL_VEKK, $DIALOG_VEKK_ASURA)

	Local $l_i_Bow = Item_FindItemByModelID($MODEL_KEIRAN_BOW)
	If $l_i_Bow <> 0 Then Item_EquipItem($l_i_Bow)
	If Not Leveler_Travel($MAP_EOTN) Then Return False
	Out("[Step] Eye of the North pool unlocked")
	Return True
EndFunc

Func Leveler_Step_FarmUntil20()
	$g_s_CurrentHeader = "Farm Until Level 20"
	Local $l_i_Level = Leveler_PlayerLevel()
	If $l_i_Level >= 20 Then
		$g_b_FarmMode = False
		Out("[Farm] Already level " & $l_i_Level)
		Return True
	EndIf

	$g_b_FarmMode = True
	Out("=== " & $g_s_CurrentHeader & " (level " & $l_i_Level & ") ===")

	If Map_GetMapID() = $MAP_AB Then
		If Not Leveler_RunAbPath() Then Return False
	Else
		Party_LeaveGroup(True)
		Sleep(400)
		If Map_GetMapID() <> $MAP_HOM Then
			If Not Leveler_Travel($MAP_EOTN) Then Return False
			Party_LeaveGroup(True)
			Sleep(300)
			If Not Leveler_MoveAndExit(-4873.00, 5284.00, $MAP_HOM, False) Then Return False
		EndIf
		If Not Leveler_EquipKeiranBow() Then Return False
		If Not Leveler_EnterAbQuest() Then Return False
		If Not Leveler_RunAbPath() Then Return False
	EndIf

	$l_i_Level = Leveler_PlayerLevel()
	Out("[Farm] End-of-run level: " & $l_i_Level)
	If $l_i_Level >= 20 Then
		$g_b_FarmMode = False
		Out("[Farm] Reached level 20")
		Return True
	EndIf
	; Stay on this step and start another AB run.
	Return False
EndFunc

Func Leveler_RunAbPath()
	If Map_GetMapID() <> $MAP_AB Then Return False
	$g_b_CombatMode = True
	If Not Leveler_MoveTo(11714, -4590, True) Then Return False
	Leveler_WaitUntilInCombat(20000)
	If Not Leveler_MoveTo(9973, -6394, True) Then Return False
	If Not Leveler_MoveTo(8448, -8676, True) Then Return False
	If Not Leveler_MoveTo(4284, -7384, True) Then Return False
	If Not Leveler_MoveTo(2442, -9532, True) Then Return False
	If Not Leveler_MoveTo(948, -11427, True) Then Return False
	If Not Leveler_MoveTo(-1605, -11181, True) Then Return False
	If Not Leveler_MoveTo(-2279, -9099, True) Then Return False
	If Not Leveler_MoveTo(-5688, -10252, True) Then Return False
	If Not Leveler_MoveTo(-9311, -8500, True) Then Return False
	If Not Leveler_MoveTo(-12904, -7805, True) Then Return False
	If Not Leveler_MoveTo(-15338, -8893, True) Then Return False
	Sleep(10000)
	If Not Leveler_MoveTo(-17952, -8940, True) Then Return False
	If Not Map_WaitMapLoading($MAP_HOM, -1, 45000) Then Return False
	Leveler_SetPacifist()
	Return True
EndFunc

Func Leveler_SeitungZunraaPath()
	Local $l_af_Path[5][2] = [ _
			[16602.23, 11612.10], _
			[16886.80, 9577.24], _
			[16940.28, 9860.90], _
			[19243.22, 9093.26], _
			[19840.55, 7956.64] _
			]
	If Not Leveler_FollowCoords($l_af_Path, False) Then Return False
	If Not Leveler_InteractGadgetAt(19642.00, 7386.00, False) Then Return False
	Return Leveler_WaitMs(5000)
EndFunc

Func Leveler_Step_AnUnwelcomeGuest()
	$g_s_CurrentHeader = "Attribute points quest n. 2"
	Out("=== " & $g_s_CurrentHeader & " ===")
	$g_b_FarmMode = False
	$g_b_KilroyMode = False

	If Leveler_SkipIfQuestDone($QUEST_UNWELCOME, "An Unwelcome Guest") Then Return True

	If Map_GetMapID() <> $MAP_ZEN_EXP Then
		If Not Leveler_Travel($MAP_SEITUNG) Then Return False
		Party_LeaveGroup(True)
		Sleep(400)
		If Not Leveler_SeitungZunraaPath() Then Return False
		If Not Leveler_HasQuest($QUEST_UNWELCOME) Then
			If Not Leveler_QuestLoop($QUEST_UNWELCOME, 0, 0, $DIALOG_UNWELCOME_ACCEPT, "accept", $MODEL_ZUNRAA) Then Return False
		EndIf
		Party_LeaveGroup(True)
		Sleep(300)
		Local $l_ai_Hench[1] = [5]
		Leveler_PrepareHeroTeam($l_ai_Hench)
		If Not Leveler_MoveAndDialog(20350.00, 9087.00, $DIALOG_ZEN_SKIP, False) Then Return False
		If Not Leveler_WaitForMap($MAP_ZEN_EXP, 30000) Then Return False
	EndIf

	Leveler_EquipSkillBar()
	$g_b_CombatMode = True
	Local $l_af_Out[11][2] = [ _
			[-13959.50, 6375.26], _
			[-14567.47, 1775.31], _
			[-12310.05, 2417.60], _
			[-12071.83, 294.29], _
			[-9972.85, 4141.29], _
			[-9331.86, 7932.66], _
			[-6353.09, 9385.63], _
			[247.80, 12070.21], _
			[-8180.59, 12189.97], _
			[-9540.45, 7760.86], _
			[-5038.08, 2977.42] _
			]
	If Not Leveler_FollowCoords($l_af_Out, True) Then Return False
	If Not Leveler_InteractGadgetAt(-4862.00, 3005.00, True) Then Return False
	If Not Leveler_MoveTo(-9643.93, 7759.69, True) Then Return False
	If Not Leveler_WaitMs(5000) Then Return False

	$g_b_CombatMode = False
	If Not Leveler_MoveTo(-8294.21, 10061.62, False) Then Return False
	If Not Leveler_CombatBurst(5000) Then Return False
	If Not Leveler_MoveTo(-6473.26, 8771.21, False) Then Return False
	If Not Leveler_CombatBurst(5000) Then Return False
	If Not Leveler_MoveTo(-6365.32, 10234.20, False) Then Return False
	If Not Leveler_CombatBurst(5000) Then Return False
	$g_b_CombatMode = True
	If Not Leveler_MoveTo(-8655.04, -769.98, True) Then Return False
	If Not Leveler_WaitMs(5000) Then Return False

	$g_b_CombatMode = False
	If Not Leveler_MoveTo(-6744.75, -1842.97, False) Then Return False
	If Not Leveler_CombatBurst(10000) Then Return False
	If Not Leveler_MoveTo(-7720.80, -905.19, False) Then Return False
	If Not Leveler_CombatBurst(5000) Then Return False
	$g_b_CombatMode = True

	Local $l_af_Return[13][2] = [ _
			[-5016.76, -8800.93], _
			[3268.68, -6118.96], _
			[3808.16, -830.31], _
			[536.95, 2452.17], _
			[599.18, 12088.79], _
			[3605.82, 2336.79], _
			[5509.49, 1978.54], _
			[11313.49, 3755.03], _
			[12442.71, 8301.94], _
			[8133.23, 7540.54], _
			[15029.96, 10187.60], _
			[14062.33, 13088.72], _
			[11775.22, 11310.60] _
			]
	If Not Leveler_FollowCoords($l_af_Return, True) Then Return False
	If Not Leveler_InteractGadgetAt(11665, 11386, True) Then Return False

	$g_b_CombatMode = False
	If Not Leveler_MoveTo(12954.96, 9288.47, False) Then Return False
	If Not Leveler_CombatBurst(5000) Then Return False
	If Not Leveler_MoveTo(12507.05, 11450.91, False) Then Return False
	If Not Leveler_CombatBurst(5000) Then Return False
	$g_b_CombatMode = True
	If Not Leveler_MoveTo(7709.06, 4550.47, True) Then Return False
	If Not Leveler_WaitMs(5000) Then Return False

	$g_b_CombatMode = False
	If Not Leveler_MoveTo(9334.25, 5746.98, False) Then Return False
	If Not Leveler_CombatBurst(5000) Then Return False
	If Not Leveler_MoveTo(7554.94, 6159.84, False) Then Return False
	If Not Leveler_CombatBurst(5000) Then Return False
	If Not Leveler_MoveTo(9242.30, 6127.45, False) Then Return False
	If Not Leveler_CombatBurst(5000) Then Return False
	$g_b_CombatMode = True
	If Not Leveler_MoveTo(4855.66, 1521.21, True) Then Return False
	If Not Leveler_InteractGadgetAt(4754, 1451, True) Then Return False
	If Not Leveler_MoveTo(2958.13, 6410.57, True) Then Return False

	$g_b_CombatMode = False
	If Not Leveler_MoveTo(2683.69, 8036.28, False) Then Return False
	If Not Leveler_CombatBurst(8000) Then Return False
	If Not Leveler_MoveTo(3366.55, -5996.11, False) Then Return False
	If Not Leveler_CombatBurst(10000) Then Return False
	If Not Leveler_MoveTo(1866.87, -5454.60, False) Then Return False
	If Not Leveler_CombatBurst(5000) Then Return False
	If Not Leveler_MoveTo(3322.93, -5703.29, False) Then Return False
	If Not Leveler_CombatBurst(5000) Then Return False
	If Not Leveler_MoveTo(1855.78, -5376.80, False) Then Return False
	If Not Leveler_CombatBurst(5000) Then Return False
	$g_b_CombatMode = True
	If Not Leveler_MoveTo(-8655.04, -769.98, True) Then Return False
	If Not Leveler_MoveTo(-7453.22, -1483.71, True) Then Return False
	If Not Leveler_WaitOutOfCombat(120000) Then Return False

	If Not Leveler_Travel($MAP_SEITUNG) Then Return False
	Leveler_SetPacifist()
	If Not Leveler_SeitungZunraaPath() Then Return False
	Leveler_TalkModel($MODEL_ZUNRAA, $DIALOG_UNWELCOME_COMPLETE)
	If Not Leveler_QuestLoop($QUEST_UNWELCOME, 0, 0, $DIALOG_UNWELCOME_ACCEPT, "complete", $MODEL_ZUNRAA) Then Return False
	Out("[Step] An Unwelcome Guest complete")
	Return True
EndFunc

Func Leveler_Step_ToGunnarsHold()
	$g_s_CurrentHeader = "To Gunnar's Hold"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Map_GetMapID() = $MAP_GUNNAR And Map_GetInstanceInfo("IsOutpost") Then
		Out("[Step] Already at Gunnar's Hold")
		Return True
	EndIf

	If Map_GetMapID() <> $MAP_ICE_CLIFF And Map_GetMapID() <> $MAP_NORRHART Then
		If Not Leveler_Travel($MAP_EOTN) Then Return False
		Local $l_ai_Hench[3] = [4, 5, 6]
		Leveler_PrepareHeroTeam($l_ai_Hench)
		Local $l_af_Exit[5][2] = [ _
				[-1814.0, 2917.0], _
				[-964.0, 2270.0], _
				[-115.0, 1677.0], _
				[718.0, 1060.0], _
				[1522.0, 464.0] _
				]
		Leveler_FollowCoords($l_af_Exit, False)
		If Not Leveler_WaitForMap($MAP_ICE_CLIFF, 30000) Then Return False
	EndIf

	If Map_GetMapID() = $MAP_ICE_CLIFF Then
		$g_b_CombatMode = True
		If Leveler_GetAgentByModel($MODEL_DESTROYERS_NPC) <> 0 And Not Leveler_HasQuest($QUEST_NORNBEAR) Then
			Leveler_MoveAndDialog(2825, -481, $DIALOG_NORNBEAR_ACCEPT, True, $MODEL_DESTROYERS_NPC)
		EndIf
		Local $l_af_Ice[4][2] = [ _
				[2548.84, 7266.08], _
				[1233.76, 13803.42], _
				[978.88, 21837.26], _
				[-4031.0, 27872.0] _
				]
		Leveler_FollowCoords($l_af_Ice, True)
		If Not Leveler_WaitForMap($MAP_NORRHART, 45000) Then Return False
	EndIf

	$g_b_CombatMode = True
	If Not Leveler_MoveTo(14546.0, -6043.0, True) Then Return False
	If Not Leveler_MoveAndExit(15578, -6548, $MAP_GUNNAR, True) Then Return False
	Out("[Step] Arrived at Gunnar's Hold")
	Return True
EndFunc

Func Leveler_Step_UnlockKilroy()
	$g_s_CurrentHeader = "Unlock Kilroy Stonekin"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Leveler_SkipIfQuestDone($QUEST_PUNCH_CLOWN, "Punch the Clown") Then Return True

	If Not Leveler_Travel($MAP_GUNNAR) Then Return False
	$g_b_KilroyMode = True
	If Not Leveler_HasQuest($QUEST_PUNCH_CLOWN) Then
		If Not Leveler_QuestLoop($QUEST_PUNCH_CLOWN, 17341.00, -4796.00, $DIALOG_PUNCH_ACCEPT, "accept") Then
			$g_b_KilroyMode = False
			Return False
		EndIf
	EndIf
	If Map_GetMapID() <> $MAP_KILROY Then
		If Not Leveler_QuestLoop($QUEST_PUNCH_CLOWN, 17341.00, -4796.00, $DIALOG_GENERIC_TALK, "step") Then
			If Map_GetMapID() <> $MAP_KILROY Then
				$g_b_KilroyMode = False
				Return False
			EndIf
		EndIf
		If Not Leveler_WaitForMap($MAP_KILROY, 20000) And Map_GetMapID() <> $MAP_KILROY Then
			$g_b_KilroyMode = False
			Return False
		EndIf
	EndIf

	Leveler_EquipItemByModel($MODEL_BRASS_KNUCKLES)
	If Not Leveler_WaitMs(3000) Then
		$g_b_KilroyMode = False
		Return False
	EndIf
	Leveler_MoveTo(19290.50, -11552.23, True)
	If Not Leveler_WaitUntilOutpost(180000) Then
		$g_b_KilroyMode = False
		Return False
	EndIf

	If Map_GetMapID() <> $MAP_GUNNAR Then
		If Not Leveler_Travel($MAP_GUNNAR) Then
			$g_b_KilroyMode = False
			Return False
		EndIf
	EndIf
	If Not Leveler_QuestLoop($QUEST_PUNCH_CLOWN, 17341.00, -4796.00, $DIALOG_PUNCH_COMPLETE, "complete") Then
		$g_b_KilroyMode = False
		Return False
	EndIf
	$g_b_KilroyMode = False
	Leveler_EquipItemByModel($MODEL_KEIRAN_BOW)
	Out("[Step] Kilroy Stonekin unlocked")
	Return True
EndFunc

Func Leveler_Step_ToLionsArch()
	$g_s_CurrentHeader = "To Lion's Arch"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Map_GetMapID() = $MAP_LIONS_ARCH And Map_GetInstanceInfo("IsOutpost") And Leveler_IsQuestDone($QUEST_CHAOS_KRYTA) Then
		Out("[Step] Already in Lion's Arch")
		Return True
	EndIf

	If Map_GetMapID() <> $MAP_BEJUNKAN And Map_GetMapID() <> $MAP_LIONS_GATE And Map_GetMapID() <> $MAP_LIONS_ARCH Then
		If Not Leveler_Travel($MAP_KAINENG) Then Return False
		Leveler_SetPacifist()
		Local $l_af_Kc[4][2] = [ _
				[3049.35, -2020.75], _
				[2739.30, -3710.67], _
				[-648.30, -3493.72], _
				[-1661.91, -636.09] _
				]
		If Not Leveler_FollowCoords($l_af_Kc, False) Then Return False
		If Not Leveler_HasQuest($QUEST_CHAOS_KRYTA) Then
			If Not Leveler_QuestLoop($QUEST_CHAOS_KRYTA, -1006.97, -817.63, $DIALOG_CHAOS_ACCEPT, "accept") Then Return False
		EndIf
		If Not Leveler_MoveAndExit(-2439, 1732, $MAP_BEJUNKAN, False) Then Return False
	EndIf

	If Map_GetMapID() = $MAP_BEJUNKAN Then
		Local $l_af_Pier[5][2] = [ _
				[-2995.68, 2077.20], _
				[-6938.10, 4286.61], _
				[-6064.40, 5300.26], _
				[-2396.20, 5260.67], _
				[-5031.77, 6001.52] _
				]
		If Not Leveler_FollowCoords($l_af_Pier, False) Then Return False
		If Not Leveler_MoveTo(-5626.17, 7017.33, False) Then Return False
		If Not Leveler_QuestLoop($QUEST_CHAOS_KRYTA, 0, 0, $DIALOG_CHAOS_STEP1, "step", $MODEL_CHAOS_STEP1) Then
			If Map_GetMapID() = $MAP_BEJUNKAN Then Return False
		EndIf
		If Map_GetMapID() = $MAP_BEJUNKAN Then
			If Not Leveler_MoveTo(-4661.13, 7479.86, False) Then Return False
			If Not Leveler_QuestLoop($QUEST_CHAOS_KRYTA, 0, 0, $DIALOG_GENERIC_TALK, "step", $MODEL_CHAOS_STEP2) Then
				If Map_GetMapID() = $MAP_BEJUNKAN Then Return False
			EndIf
		EndIf
		If Not Leveler_WaitForMap($MAP_LIONS_GATE, 45000) And Map_GetMapID() <> $MAP_LIONS_ARCH Then Return False
	EndIf

	If Map_GetMapID() = $MAP_LIONS_GATE Then
		If Not Leveler_MoveTo(-1181, 1038, False) Then Return False
		If Not Leveler_QuestLoop($QUEST_CHAOS_KRYTA, 0, 0, $DIALOG_CHAOS_STEP3, "step", $MODEL_CHAOS_STEP3) Then
			If Map_GetMapID() = $MAP_LIONS_GATE Then Return False
		EndIf
	EndIf

	If Not Leveler_Travel($MAP_LIONS_ARCH) Then Return False
	If Leveler_HasQuest($QUEST_CHAOS_KRYTA) Then
		If Not Leveler_QuestLoop($QUEST_CHAOS_KRYTA, 328.00, 9594.00, $DIALOG_CHAOS_COMPLETE, "complete") Then Return False
	EndIf
	Out("[Step] Arrived at Lion's Arch")
	Return True
EndFunc

Func Leveler_Step_ToKamadan()
	$g_s_CurrentHeader = "To Kamadan"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If (Map_GetMapID() = $MAP_KAMADAN Or Map_GetMapID() = $MAP_SUN_DOCKS) And Leveler_IsQuestDone($QUEST_SUNSPEARS_CANTHA) Then
		Out("[Step] Sunspears in Cantha already complete")
		Return True
	EndIf

	If Map_GetMapID() <> $MAP_BEJUNKAN And Map_GetMapID() <> $MAP_KC_SUNSPEARS And Map_GetMapID() <> $MAP_SUN_DOCKS Then
		If Not Leveler_Travel($MAP_KAINENG) Then Return False
		Local $l_ai_Hench[3] = [2, 12, 9]
		Leveler_PrepareHeroTeam($l_ai_Hench)
		Local $l_af_Kc[4][2] = [ _
				[3049.35, -2020.75], _
				[2739.30, -3710.67], _
				[-648.30, -3493.72], _
				[-1661.91, -636.09] _
				]
		If Not Leveler_FollowCoords($l_af_Kc, False) Then Return False
		If Not Leveler_HasQuest($QUEST_SUNSPEARS_CANTHA) Then
			If Not Leveler_QuestLoop($QUEST_SUNSPEARS_CANTHA, -1131.99, 818.35, $DIALOG_SUNSPEARS_ACCEPT, "accept") Then Return False
		EndIf
		If Not Leveler_MoveAndExit(-2439, 1732, $MAP_BEJUNKAN, False) Then Return False
	EndIf

	If Map_GetMapID() = $MAP_BEJUNKAN Then
		Local $l_af_Pier[5][2] = [ _
				[-2995.68, 2077.20], _
				[-6938.10, 4286.61], _
				[-6064.40, 5300.26], _
				[-2396.20, 5260.67], _
				[-5031.77, 6001.52] _
				]
		If Not Leveler_FollowCoords($l_af_Pier, False) Then Return False
		If Not Leveler_MoveTo(-5899.57, 7240.19, False) Then Return False
		If Not Leveler_QuestLoop($QUEST_SUNSPEARS_CANTHA, 0, 0, $DIALOG_SUNSPEARS_STEP1, "step", $MODEL_SUNSPEARS_NPC, $DIALOG_SUNSPEARS_MULTI) Then
			If Map_GetMapID() = $MAP_BEJUNKAN Then Return False
		EndIf
		If Not Leveler_WaitForMap($MAP_KC_SUNSPEARS, 45000) And Map_GetMapID() <> $MAP_KC_SUNSPEARS Then Return False
	EndIf

	If Map_GetMapID() = $MAP_KC_SUNSPEARS Then
		$g_b_CombatMode = True
		Local $l_af_A[3][2] = [[-1712.16, -700.23], [-907.97, -2862.29], [742.42, -4167.73]]
		If Not Leveler_FollowCoords($l_af_A, True) Then Return False
		If Not Leveler_WaitMs(10000) Then Return False
		Local $l_af_B[3][2] = [[1352.94, -3694.75], [2547.49, -3667.82], [2541.67, -2582.88]]
		If Not Leveler_FollowCoords($l_af_B, True) Then Return False
		If Not Leveler_WaitMs(10000) Then Return False
		If Not Leveler_MoveTo(1990.27, -1636.21, True) Then Return False
		If Not Leveler_WaitMs(15000) Then Return False
		Local $l_af_C[2][2] = [[2651.48, -3750.63], [3355.63, -2151.82]]
		If Not Leveler_FollowCoords($l_af_C, True) Then Return False
		If Not Leveler_WaitMs(10000) Then Return False
		If Not Leveler_MoveTo(4565.37, -1630.73, True) Then Return False
		If Not Leveler_WaitMs(15000) Then Return False
		Local $l_af_D[3][2] = [[2951.07, -723.50], [2875.84, 488.42], [1354.73, 583.06]]
		If Not Leveler_FollowCoords($l_af_D, True) Then Return False
		If Not Leveler_WaitForMap($MAP_BEJUNKAN, 45000) Then Return False
	EndIf

	If Map_GetMapID() = $MAP_BEJUNKAN Then
		If Not Leveler_WaitMs(2000) Then Return False
		If Not Leveler_QuestLoop($QUEST_SUNSPEARS_CANTHA, 0, 0, $DIALOG_GENERIC_TALK, "step", $MODEL_SUNSPEARS_NPC) Then
			If Map_GetMapID() = $MAP_BEJUNKAN Then Return False
		EndIf
		If Not Leveler_WaitForMap($MAP_SUN_DOCKS, 45000) Then Return False
	EndIf

	If Map_GetMapID() = $MAP_SUN_DOCKS Then
		If Not Leveler_WaitMs(2000) Then Return False
		If Not Leveler_QuestLoop($QUEST_SUNSPEARS_CANTHA, 0, 0, $DIALOG_SUNSPEARS_COMPLETE, "complete", $MODEL_SUNSPEARS_COMPLETE) Then Return False
	EndIf
	Out("[Step] Arrived toward Kamadan")
	Return True
EndFunc

Func Leveler_Step_ToConsulateDocks()
	$g_s_CurrentHeader = "To Consulate Docks"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Map_GetMapID() = $MAP_DOCKS And Map_GetInstanceInfo("IsOutpost") Then
		Out("[Step] Already at Consulate Docks")
		Return True
	EndIf

	If Map_GetMapID() <> $MAP_CONSULATE Then
		If Not Leveler_Travel($MAP_KAINENG) Then Return False
		Party_LeaveGroup(True)
		Sleep(300)
		If Not Leveler_Travel($MAP_KAMADAN) Then Return False
		If Not Leveler_MoveTo(-8075.89, 14592.47, False) Then Return False
		If Not Leveler_MoveTo(-6743.29, 16663.21, False) Then Return False
		If Not Leveler_MoveAndExit(-5271.00, 16740.00, $MAP_CONSULATE, False) Then Return False
	EndIf

	If Not Leveler_MoveAndDialog(-4631.86, 16711.79, $DIALOG_UNLOCK_DOCKS, False) Then Return False
	If Not Leveler_WaitForMap($MAP_DOCKS, 30000) Then Return False
	Out("[Step] Arrived at Consulate Docks")
	Return True
EndFunc

Func Leveler_Step_UnlockOlias()
	$g_s_CurrentHeader = "Unlock Olias"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Leveler_SkipIfQuestDone($QUEST_OLIAS, "All for One and One for Justice") Then Return True

	If Map_GetMapID() <> $MAP_BLOODSTONE_FEN And Map_GetMapID() <> $MAP_LIONS_ARCH And Map_GetMapID() <> $MAP_KAMADAN Then
		If Not Leveler_Travel($MAP_DOCKS) Then Return False
		If Not Leveler_HasQuest($QUEST_OLIAS) Then
			If Not Leveler_QuestLoop($QUEST_OLIAS, -2367.00, 16796.00, $DIALOG_OLIAS_ACCEPT, "accept") Then Return False
		EndIf
		Party_LeaveGroup(True)
		Sleep(300)
		If Not Leveler_Travel($MAP_LIONS_ARCH) Then Return False
	EndIf

	If Map_GetMapID() = $MAP_LIONS_ARCH Then
		Party_LeaveGroup(True)
		Sleep(300)
		Local $l_ai_Hench[1] = [1]
		Leveler_PrepareHeroTeam($l_ai_Hench)
		If Not Leveler_MoveTo(1413.11, 9255.51, False) Then Return False
		If Not Leveler_MoveTo(242.96, 6130.82, False) Then Return False
		If Not Leveler_QuestLoop($QUEST_OLIAS, -1137.00, 2501.00, $DIALOG_GENERIC_TALK, "step") Then
			If Map_GetMapID() = $MAP_LIONS_ARCH Then Return False
		EndIf
		If Not Leveler_WaitForMap($MAP_BLOODSTONE_FEN, 45000) And Map_GetMapID() <> $MAP_BLOODSTONE_FEN Then Return False
	EndIf

	If Map_GetMapID() = $MAP_BLOODSTONE_FEN Then
		If Not Leveler_WaitMs(3000) Then Return False
		If Not Leveler_QuestLoop($QUEST_OLIAS, 5117.00, 10515.00, $DIALOG_OLIAS_STEP2, "step") Then
			Out("[Step] Olias step 2 dialog failed; continuing the path")
		EndIf
		$g_b_CombatMode = True
		If Not Leveler_MoveTo(8518.10, 9309.66, True) Then Return False
		If Not Leveler_MoveTo(8067.40, 5703.23, True) Then Return False
		If Not Leveler_MoveTo(5657.20, 4485.55, True) Then Return False
		If Not Leveler_MoveTo(4461.65, -710.88, True) Then Return False
		If Not Leveler_MoveTo(10750, 2100, True) Then Return False
		If Not Leveler_WaitMs(20000) Then Return False
		If Not Leveler_WaitForMap($MAP_LIONS_ARCH, 45000) Then Return False
	EndIf

	Party_LeaveGroup(True)
	If Not Leveler_Travel($MAP_KAMADAN) Then Return False
	If Not Leveler_MoveTo(-8149.02, 14900.65, False) Then Return False
	If Not Leveler_QuestLoop($QUEST_OLIAS, -6480.00, 16331.00, $DIALOG_OLIAS_COMPLETE, "complete") Then Return False
	Out("[Step] Olias unlocked")
	Return True
EndFunc

Func Leveler_UnlockTrainerDialogs()
	Local $l_i_Prof = Leveler_PrimaryProfession()
	Local $l_ai_All[10] = [ _
			$DIALOG_PROF_WARRIOR, _
			$DIALOG_PROF_RANGER, _
			$DIALOG_PROF_MONK, _
			$DIALOG_PROF_NECRO, _
			$DIALOG_PROF_MESMER, _
			$DIALOG_PROF_ELE, _
			$DIALOG_PROF_ASSASSIN, _
			$DIALOG_PROF_RIT, _
			$DIALOG_PROF_PARA, _
			$DIALOG_PROF_DERV _
			]
	Local $l_ai_Skip[10] = [ _
			$GC_I_PROFESSION_WARRIOR, _
			$GC_I_PROFESSION_RANGER, _
			$GC_I_PROFESSION_MONK, _
			$GC_I_PROFESSION_NECROMANCER, _
			$GC_I_PROFESSION_MESMER, _
			$GC_I_PROFESSION_ELEMENTALIST, _
			$GC_I_PROFESSION_ASSASSIN, _
			$GC_I_PROFESSION_RITUALIST, _
			$GC_I_PROFESSION_PARAGON, _
			$GC_I_PROFESSION_DERVISH _
			]
	Local $i
	For $i = 0 To 9
		If $l_ai_Skip[$i] = $l_i_Prof Then ContinueLoop
		Leveler_TalkModel($MODEL_GTOB_TRAINER, $l_ai_All[$i])
		Sleep(400)
	Next
	Return True
EndFunc

Func Leveler_Step_UnlockSecondaryProfs()
	$g_s_CurrentHeader = "Unlock remaining secondary professions"
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Not Leveler_Travel($MAP_GTOB) Then Return False
	Item_WithdrawGold(5000)
	Sleep(400)
	If Not Leveler_MoveTo(-5540.40, -5733.11, False) Then Return False
	If Not Leveler_MoveTo(-3151.22, -7255.13, False) Then Return False
	Leveler_UnlockTrainerDialogs()
	Out("[Step] Secondary profession trainers talked")
	Return True
EndFunc

Func Leveler_Step_UnlockMercenaries()
	$g_s_CurrentHeader = "Unlock Mercenary Heroes"
	Out("=== " & $g_s_CurrentHeader & " ===")
	Party_LeaveGroup(True)
	Sleep(300)
	If Not Leveler_Travel($MAP_GTOB) Then Return False
	If Not Leveler_MoveTo(-4231.87, -8965.95, False) Then Return False
	Leveler_TalkModel($MODEL_MERC_NPC, $DIALOG_MERC_HEROES)
	Out("[Step] Mercenary hero dialog sent")
	Return True
EndFunc

Func Leveler_Step_ToLongeyesLedge()
	$g_s_CurrentHeader = "To Longeye's Ledge"
	If Not Leveler_NeedsVaettirPath() Then
		Out("[Step] Skipping Longeye's Ledge (not Assassin/Mesmer)")
		Return True
	EndIf
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Map_GetMapID() = $MAP_LONGEYE And Map_GetInstanceInfo("IsOutpost") Then
		Out("[Step] Already at Longeye's Ledge")
		Return True
	EndIf

	If Map_GetMapID() <> $MAP_NORRHART And Map_GetMapID() <> $MAP_BJORA Then
		If Not Leveler_Travel($MAP_GUNNAR) Then Return False
		Local $l_ai_Hench[3] = [4, 5, 6]
		Leveler_PrepareHeroTeam($l_ai_Hench)
		If Not Leveler_MoveTo(15886.20, -6687.82, False) Then Return False
		If Not Leveler_MoveAndExit(15183.20, -6381.96, $MAP_NORRHART, False) Then Return False
	EndIf

	If Map_GetMapID() = $MAP_NORRHART Then
		$g_b_CombatMode = True
		Local $l_af_Norr[9][2] = [ _
				[14233.82, -3638.70], _
				[14944.69, 1197.74], _
				[14855.55, 4450.14], _
				[17964.74, 6782.41], _
				[19127.48, 9809.46], _
				[21742.71, 14057.23], _
				[19933.87, 15609.06], _
				[16294.68, 16369.74], _
				[16392.48, 16768.86] _
				]
		Leveler_FollowCoords($l_af_Norr, True)
		If Not Leveler_WaitForMap($MAP_BJORA, 45000) Then Return False
	EndIf

	If Map_GetMapID() = $MAP_BJORA Then
		$g_b_CombatMode = True
		Local $l_af_Bjora[13][2] = [ _
				[-11232.55, -16722.86], _
				[-7655.78, -13250.32], _
				[-6672.13, -13080.85], _
				[-5497.73, -11904.58], _
				[-3598.34, -11162.59], _
				[-3013.93, -9264.66], _
				[-1002.17, -8064.57], _
				[3533.10, -9982.70], _
				[7472.13, -10943.37], _
				[12984.51, -15341.86], _
				[17305.52, -17686.40], _
				[19048.21, -18813.70], _
				[19634.17, -19118.78] _
				]
		Leveler_FollowCoords($l_af_Bjora, True)
		If Not Leveler_MoveAndExit(19634.17, -19118.78, $MAP_LONGEYE, True) Then Return False
	EndIf
	Out("[Step] Arrived at Longeye's Ledge")
	Return True
EndFunc

Func Leveler_Step_UnlockVaettirNpc()
	$g_s_CurrentHeader = "Unlock NPC for vaettir farm"
	If Not Leveler_NeedsVaettirPath() Then
		Out("[Step] Skipping Vaettir NPC (not Assassin/Mesmer)")
		Return True
	EndIf
	Out("=== " & $g_s_CurrentHeader & " ===")
	If Map_GetMapID() = $MAP_JAGA Then
		If Not Leveler_MoveTo(13372.44, -20758.50, False) Then Return False
		Leveler_MoveAndDialog(13367, -20771, $DIALOG_GENERIC_TALK, True)
		Leveler_WaitOutOfCombat(60000)
		Leveler_MoveAndDialog(13367, -20771, $DIALOG_GENERIC_TALK, False)
		Out("[Step] Vaettir NPC unlocked")
		Return True
	EndIf

	If Map_GetMapID() <> $MAP_BJORA Then
		If Not Leveler_Travel($MAP_LONGEYE) Then Return False
		Local $l_ai_Hench[3] = [4, 5, 6]
		Leveler_PrepareHeroTeam($l_ai_Hench)
		If Not Leveler_MoveAndExit(-26375, 16180, $MAP_BJORA, False) Then Return False
	EndIf

	$g_b_CombatMode = True
	Local $l_af_Bjora[80][2] = [ _
			[17810, -17649], [17516, -17270], [17166, -16813], [16862, -16324], [16472, -15934], _
			[15929, -15731], [15387, -15521], [14849, -15312], [14311, -15101], [13776, -14882], _
			[13249, -14642], [12729, -14386], [12235, -14086], [11748, -13776], [11274, -13450], _
			[10839, -13065], [10572, -12590], [10412, -12036], [10238, -11485], [10125, -10918], _
			[10029, -10348], [9909, -9778], [9599, -9327], [9121, -9009], [8674, -8645], _
			[8215, -8289], [7755, -7945], [7339, -7542], [6962, -7103], [6587, -6666], _
			[6210, -6226], [5834, -5788], [5457, -5349], [5081, -4911], [4703, -4470], _
			[4379, -3990], [4063, -3507], [3773, -3031], [3452, -2540], [3117, -2070], _
			[2678, -1703], [2115, -1593], [1541, -1614], [960, -1563], [388, -1491], _
			[-187, -1419], [-770, -1426], [-1343, -1440], [-1922, -1455], [-2496, -1472], _
			[-3073, -1535], [-3650, -1607], [-4214, -1712], [-4784, -1759], [-5278, -1492], _
			[-5754, -1164], [-6200, -796], [-6632, -419], [-7192, -300], [-7770, -306], _
			[-8352, -286], [-8932, -258], [-9504, -226], [-10086, -201], [-10665, -215], _
			[-11247, -242], [-11826, -262], [-12400, -247], [-12979, -216], [-13529, -53], _
			[-13944, 341], [-14358, 743], [-14727, 1181], [-15109, 1620], [-15539, 2010], _
			[-15963, 2380], [-18048, 4223], [-19196, 4986], [-20000, 5595], [-20300, 5600] _
			]
	Leveler_FollowCoords($l_af_Bjora, True)
	If Map_GetMapID() = $MAP_BJORA Then
		If Not Leveler_MoveAndExit(-20300, 5600, $MAP_JAGA, True) Then Return False
	EndIf
	If Not Leveler_MoveTo(13372.44, -20758.50, False) Then Return False
	Leveler_MoveAndDialog(13367, -20771, $DIALOG_GENERIC_TALK, True)
	Leveler_WaitOutOfCombat(60000)
	Leveler_MoveAndDialog(13367, -20771, $DIALOG_GENERIC_TALK, False)
	Out("[Step] Vaettir NPC unlocked")
	Return True
EndFunc
