#include-once

Func Leveler_CharacterGold()
	Return Item_GetInventoryInfo("GoldCharacter")
EndFunc

; Lost Treasure or later means this character already passed the monastery tutorial.
Func Leveler_HasPostXunlaiProgress()
	If Leveler_QuestProgress($QUEST_LOST_TREASURE) Then Return True
	If Leveler_HasLaterQuest() Then Return True
	Return False
EndFunc

Func Leveler_HasFormalOrLater()
	If Leveler_HasQuest($QUEST_FORMAL_INTRO) Then Return True
	If Leveler_QuestFinished($QUEST_FORMAL_INTRO) Then Return True
	If Leveler_HasPostXunlaiProgress() Then Return True
	; Skills / Cho happen after #318 is accepted. Do not send them back to Togo.
	If Leveler_HasSecondaryProfession() And Not Leveler_QuestInLog($QUEST_SECONDARY) And Leveler_ZhaoDiSkillsUnlocked() Then Return True
	Return False
EndFunc

; #317 gold is granted on Togo's complete dialog, not when the secondary is assigned.
; Once #317 has left the log the gold may already be spent on Xunlai / crafts.
Func Leveler_SecondaryRewardTaken()
	If Leveler_QuestInLog($QUEST_SECONDARY) Then Return False
	If Not Leveler_HasSecondaryProfession() Then Return False
	Return True
EndFunc

; Leave Unlock Secondary only after #317 is turned in and #318 is accepted or later.
Func Leveler_SecondaryStepReadyToLeave()
	If Not Leveler_HasSecondaryProfession() Then Return False
	If Leveler_QuestInLog($QUEST_SECONDARY) Then Return False
	If Not Leveler_HasFormalOrLater() Then Return False
	Return True
EndFunc

; Formal Introduction is finished only after Kayao's Accept removes it from the log.
Func Leveler_FormalIntroductionTurnedIn()
	If Leveler_QuestInLog($QUEST_FORMAL_INTRO) Then Return False
	If Leveler_HasPostXunlaiProgress() Then Return True
	If Quest_GetQuestInfo($QUEST_FORMAL_INTRO, "IsCompleted") Then Return True
	Local $l_i_Map = Map_GetMapID()
	If Leveler_HasSecondaryProfession() And ($l_i_Map = $MAP_CHO_OUTPOST Or $l_i_Map = $MAP_RAN_MUSU Or $l_i_Map = $MAP_CHO_EXPLORABLE) Then Return True
	Return False
EndFunc

Func Leveler_QuestFinished($a_i_QuestID)
	If $a_i_QuestID = $QUEST_SECONDARY Then Return Leveler_SecondaryRewardTaken()
	If $a_i_QuestID = $QUEST_FORMAL_INTRO Then Return Leveler_FormalIntroductionTurnedIn()
	If $a_i_QuestID = $QUEST_ROAD_LESS Then Return Leveler_RoadLessTraveledDone()
	If Leveler_QuestNeedsHandIn($a_i_QuestID) Then Return False
	If Quest_GetQuestInfo($a_i_QuestID, "IsCompleted") Then Return True
	If Leveler_IsQuestDone($a_i_QuestID) Then Return True
	Return False
EndFunc

Func Leveler_QuestFlagIndex($a_i_QuestID)
	Switch $a_i_QuestID
		Case $QUEST_FORMING_A_PARTY
			Return $LEVELER_Q_FORMING
		Case $QUEST_SECONDARY
			Return $LEVELER_Q_SECONDARY
		Case $QUEST_FORMAL_INTRO
			Return $LEVELER_Q_FORMAL
		Case $QUEST_LOST_TREASURE
			Return $LEVELER_Q_LOST
		Case $QUEST_WARNING_TENGU
			Return $LEVELER_Q_TENGU
		Case $QUEST_THREAT_GROWS
			Return $LEVELER_Q_THREAT
		Case $QUEST_JOURNEY_MASTER
			Return $LEVELER_Q_JOURNEY
		Case $QUEST_ROAD_LESS
			Return $LEVELER_Q_ROAD
		Case $QUEST_SEARCH_CURE
			Return $LEVELER_Q_CURE
		Case $QUEST_BROTHER_TOSAI
			Return $LEVELER_Q_TOSAI
		Case $QUEST_MASTERS_BURDEN
			Return $LEVELER_Q_BURDEN
		Case $QUEST_EARTH_MOVE
			Return $LEVELER_Q_EARTH
		Case $QUEST_AGAINST_DESTROYERS
			Return $LEVELER_Q_DESTROYERS
		Case $QUEST_MISSING_VANGUARD
			Return $LEVELER_Q_VANGUARD
		Case $QUEST_NORTHERN_ALLIES
			Return $LEVELER_Q_ALLIES
		Case $QUEST_KNOWLEDGEABLE_ASURA
			Return $LEVELER_Q_ASURA
		Case $QUEST_UNWELCOME
			Return $LEVELER_Q_UNWELCOME
		Case $QUEST_NORNBEAR
			Return $LEVELER_Q_NORNBEAR
		Case $QUEST_PUNCH_CLOWN
			Return $LEVELER_Q_PUNCH
		Case $QUEST_CHAOS_KRYTA
			Return $LEVELER_Q_CHAOS
		Case $QUEST_SUNSPEARS_CANTHA
			Return $LEVELER_Q_SUNSPEARS
		Case $QUEST_OLIAS
			Return $LEVELER_Q_OLIAS
	EndSwitch
	Return -1
EndFunc

Func Leveler_QuestIDFromFlag($a_i_Flag)
	Switch $a_i_Flag
		Case $LEVELER_Q_FORMING
			Return $QUEST_FORMING_A_PARTY
		Case $LEVELER_Q_SECONDARY
			Return $QUEST_SECONDARY
		Case $LEVELER_Q_FORMAL
			Return $QUEST_FORMAL_INTRO
		Case $LEVELER_Q_LOST
			Return $QUEST_LOST_TREASURE
		Case $LEVELER_Q_TENGU
			Return $QUEST_WARNING_TENGU
		Case $LEVELER_Q_THREAT
			Return $QUEST_THREAT_GROWS
		Case $LEVELER_Q_JOURNEY
			Return $QUEST_JOURNEY_MASTER
		Case $LEVELER_Q_ROAD
			Return $QUEST_ROAD_LESS
		Case $LEVELER_Q_CURE
			Return $QUEST_SEARCH_CURE
		Case $LEVELER_Q_TOSAI
			Return $QUEST_BROTHER_TOSAI
		Case $LEVELER_Q_BURDEN
			Return $QUEST_MASTERS_BURDEN
		Case $LEVELER_Q_EARTH
			Return $QUEST_EARTH_MOVE
		Case $LEVELER_Q_DESTROYERS
			Return $QUEST_AGAINST_DESTROYERS
		Case $LEVELER_Q_VANGUARD
			Return $QUEST_MISSING_VANGUARD
		Case $LEVELER_Q_ALLIES
			Return $QUEST_NORTHERN_ALLIES
		Case $LEVELER_Q_ASURA
			Return $QUEST_KNOWLEDGEABLE_ASURA
		Case $LEVELER_Q_UNWELCOME
			Return $QUEST_UNWELCOME
		Case $LEVELER_Q_NORNBEAR
			Return $QUEST_NORNBEAR
		Case $LEVELER_Q_PUNCH
			Return $QUEST_PUNCH_CLOWN
		Case $LEVELER_Q_CHAOS
			Return $QUEST_CHAOS_KRYTA
		Case $LEVELER_Q_SUNSPEARS
			Return $QUEST_SUNSPEARS_CANTHA
		Case $LEVELER_Q_OLIAS
			Return $QUEST_OLIAS
	EndSwitch
	Return 0
EndFunc

Func Leveler_IsQuestDone($a_i_QuestID)
	Local $l_i_Flag = Leveler_QuestFlagIndex($a_i_QuestID)
	If $l_i_Flag < 0 Then Return Leveler_QuestFinished($a_i_QuestID)
	Return $g_ab_QuestDone[$l_i_Flag] = True
EndFunc

Func Leveler_MarkQuestDone($a_i_QuestID)
	If Leveler_HasIncompleteQuest($a_i_QuestID) Then Return
	Local $l_i_Flag = Leveler_QuestFlagIndex($a_i_QuestID)
	If $l_i_Flag < 0 Then Return
	$g_ab_QuestDone[$l_i_Flag] = True
EndFunc

; Active or turned-in on THIS character. Do not use bare HasQuest leftovers.
Func Leveler_QuestProgress($a_i_QuestID)
	If Leveler_HasIncompleteQuest($a_i_QuestID) Then Return True
	If Leveler_QuestFinished($a_i_QuestID) Then Return True
	Return False
EndFunc

; Rebuild completion flags from the quest log. Only infer earlier quests from
; later quests that are still in progress or actually finished.
Func Leveler_RefreshQuestFlags($a_b_Reset = False)
	Local $i
	If $a_b_Reset Then
		For $i = 0 To $LEVELER_Q_COUNT - 1
			$g_ab_QuestDone[$i] = False
		Next
	EndIf

	For $i = 0 To $LEVELER_Q_COUNT - 1
		Local $l_i_QuestID = Leveler_QuestIDFromFlag($i)
		If $l_i_QuestID = 0 Then ContinueLoop
		If Leveler_HasIncompleteQuest($l_i_QuestID) Then
			$g_ab_QuestDone[$i] = False
		ElseIf Leveler_QuestFinished($l_i_QuestID) Then
			$g_ab_QuestDone[$i] = True
		EndIf
	Next

	If Leveler_SecondaryRewardTaken() Then
		Leveler_MarkQuestDone($QUEST_SECONDARY)
		Leveler_MarkQuestDone($QUEST_FORMING_A_PARTY)
	EndIf
	If Leveler_QuestProgress($QUEST_SECONDARY) Or Leveler_QuestProgress($QUEST_FORMAL_INTRO) Then
		Leveler_MarkQuestDone($QUEST_FORMING_A_PARTY)
	EndIf
	If Leveler_QuestProgress($QUEST_LOST_TREASURE) Or Leveler_HasLaterQuest() Then
		Leveler_MarkQuestDone($QUEST_FORMAL_INTRO)
		Leveler_MarkQuestDone($QUEST_SECONDARY)
		Leveler_MarkQuestDone($QUEST_FORMING_A_PARTY)
	EndIf
	If Not Leveler_QuestNeedsHandIn($QUEST_LOST_TREASURE) Then
		If Leveler_QuestProgress($QUEST_WARNING_TENGU) Or Leveler_QuestFinished($QUEST_WARNING_TENGU) Or Leveler_QuestProgress($QUEST_THREAT_GROWS) Or Leveler_QuestProgress($QUEST_JOURNEY_MASTER) Or Leveler_QuestProgress($QUEST_ROAD_LESS) Then
			Leveler_MarkQuestDone($QUEST_LOST_TREASURE)
		EndIf
	EndIf
	If Not Leveler_QuestNeedsHandIn($QUEST_WARNING_TENGU) Then
		If Leveler_QuestFinished($QUEST_WARNING_TENGU) Or Leveler_QuestProgress($QUEST_THREAT_GROWS) Or Leveler_QuestProgress($QUEST_JOURNEY_MASTER) Or Leveler_QuestProgress($QUEST_ROAD_LESS) Then
			Leveler_MarkQuestDone($QUEST_WARNING_TENGU)
		EndIf
	EndIf
	If Leveler_QuestProgress($QUEST_JOURNEY_MASTER) Or Leveler_QuestProgress($QUEST_ROAD_LESS) Then
		Leveler_MarkQuestDone($QUEST_THREAT_GROWS)
	EndIf
	If Leveler_QuestProgress($QUEST_ROAD_LESS) Then
		Leveler_MarkQuestDone($QUEST_JOURNEY_MASTER)
	EndIf
	If Leveler_QuestProgress($QUEST_BROTHER_TOSAI) Or Leveler_QuestFinished($QUEST_MASTERS_BURDEN) Then
		Leveler_MarkQuestDone($QUEST_SEARCH_CURE)
	EndIf
	If Leveler_QuestFinished($QUEST_MASTERS_BURDEN) Then
		Leveler_MarkQuestDone($QUEST_ROAD_LESS)
	EndIf
	If Leveler_QuestFinished($QUEST_AGAINST_DESTROYERS) Then
		Leveler_MarkQuestDone($QUEST_EARTH_MOVE)
	EndIf
	If Leveler_QuestProgress($QUEST_NORTHERN_ALLIES) Or Leveler_QuestProgress($QUEST_KNOWLEDGEABLE_ASURA) Then
		Leveler_MarkQuestDone($QUEST_MISSING_VANGUARD)
	EndIf
	If Leveler_QuestProgress($QUEST_KNOWLEDGEABLE_ASURA) Then
		Leveler_MarkQuestDone($QUEST_NORTHERN_ALLIES)
	EndIf
EndFunc

Func Leveler_SkipIfQuestDone($a_i_QuestID, $a_s_Name)
	If Leveler_HasIncompleteQuest($a_i_QuestID) Then Return False
	If Not Leveler_IsQuestDone($a_i_QuestID) And Not Leveler_QuestFinished($a_i_QuestID) Then Return False
	Leveler_MarkQuestDone($a_i_QuestID)
	Out("[Step] " & $a_s_Name & " already completed")
	Return True
EndFunc

Func Leveler_OnOverlook($a_i_Map = -1)
	If $a_i_Map < 0 Then $a_i_Map = Map_GetMapID()
	Return $a_i_Map = 212 Or $a_i_Map = 285 Or $a_i_Map = 416
EndFunc

; Map_GetMapID() is 0 while Connecting (CurrentMapID often 897). Use the live
; story map when it is a real outpost/explorable so Zen 213 is not Overlook.
Func Leveler_StatusMapID()
	Local $l_i_Map = Number(Map_GetMapID())
	If $l_i_Map > 0 And $l_i_Map <> 897 Then Return $l_i_Map
	Local $l_i_Live = Leveler_LiveMapID()
	If $l_i_Live > 0 And $l_i_Live <> 897 Then Return $l_i_Live
	Return $l_i_Map
EndFunc

; Do not lock step 0 while map=0/connecting/AgentBase=0. 213/246 are ready.
Func Leveler_StatusMapReady()
	Local $l_i_Map = Number(Map_GetMapID())
	Local $l_i_Live = Leveler_LiveMapID()
	If $l_i_Map = 897 Then Return False
	If $l_i_Map > 0 And Not Leveler_MapLooksConnecting() Then Return True
	If $l_i_Map > 0 And Leveler_StoryFloorFromMap($l_i_Map) >= 0 Then Return True
	If $l_i_Live > 0 And $l_i_Live <> 897 And Leveler_StoryFloorFromMap($l_i_Live) >= 0 Then Return True
	Return False
EndFunc

Func Leveler_WaitStatusMap($a_i_Timeout = 90000)
	Local $l_h_Timer = TimerInit()
	Local $l_i_LastLog = -8000
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Leveler_StatusMapReady() Then Return True
		If TimerDiff($l_h_Timer) - $l_i_LastLog >= 8000 Then
			Out("[Status] Waiting for a live story map before picking a step (map " & Map_GetMapID() & _
					" current " & Leveler_LiveMapID() & " connecting=" & Number(Leveler_MapLooksConnecting()) & ")")
			$l_i_LastLog = TimerDiff($l_h_Timer)
		EndIf
		Sleep(500)
	WEnd
	Return Leveler_StatusMapReady()
EndFunc

Func Leveler_HasStorageAccess()
	If Item_GetBagPtr($GC_I_INVENTORY_STORAGE1) <> 0 Then Return True
	If Item_GetInventoryInfo("Storage1Ptr") <> 0 Then Return True
	Return False
EndFunc

; Chest already opened, or this character already used storage for later monastery crafts.
Func Leveler_XunlaiUnlocked()
	If Leveler_HasStorageAccess() Then Return True
	If Leveler_HasCraftedWeapon() Then Return True
	If Leveler_HasMonasteryArmor() Then Return True
	If Leveler_HasSeitungArmor() Then Return True
	If Leveler_HasPostXunlaiProgress() Then Return True
	Return False
EndFunc

; Zhao Di in Shing Jea. Energy Burn is optional if a skill point was already spent.
Func Leveler_ZhaoDiSkillsUnlocked()
	If Not World_IsSkillLearnt($SKILL_SIGNET_OF_DISRUPTION) Then Return False
	If Not World_IsSkillLearnt($SKILL_LEECH_SIGNET) Then Return False
	Return True
EndFunc

; Cry of Frustration + Power Drain are sold at Xu Fengxia / Michiko, not Zhao Di.
Func Leveler_InterruptSkillsUnlocked()
	If Not World_IsSkillLearnt($SKILL_CRY_OF_FRUSTRATION) Then Return False
	If Not World_IsSkillLearnt($SKILL_POWER_DRAIN) Then Return False
	If Not World_IsSkillLearnt($SKILL_SIGNET_OF_DISRUPTION) Then Return False
	Return True
EndFunc

Func Leveler_Skills2Unlocked()
	If Not Leveler_InterruptSkillsUnlocked() Then Return False
	If Leveler_HasMesmer() And Not World_IsSkillLearnt($SKILL_BACKFIRE) Then Return False
	Return True
EndFunc

Func Leveler_HasLaterQuest()
	If Leveler_HasQuest($QUEST_WARNING_TENGU) Or Leveler_HasIncompleteQuest($QUEST_WARNING_TENGU) Then Return True
	If Leveler_HasQuest($QUEST_THREAT_GROWS) Or Leveler_HasIncompleteQuest($QUEST_THREAT_GROWS) Then Return True
	If Leveler_HasQuest($QUEST_JOURNEY_MASTER) Or Leveler_HasIncompleteQuest($QUEST_JOURNEY_MASTER) Then Return True
	If Leveler_HasQuest($QUEST_ROAD_LESS) Or Leveler_HasIncompleteQuest($QUEST_ROAD_LESS) Then Return True
	Return False
EndFunc

; This character already left the Shing Jea armor crafter. Do not rerun monastery crafts.
Func Leveler_PastMonasteryArmor()
	If Leveler_HasMonasteryArmor() Then Return True
	If Leveler_HasSeitungArmor() Then Return True
	If Leveler_QuestProgress($QUEST_LOST_TREASURE) Then Return True
	If Leveler_HasLaterQuest() Then Return True
	If Leveler_IsQuestDone($QUEST_ROAD_LESS) Then Return True
	Local $l_i_Map = Map_GetMapID()
	If $l_i_Map = $MAP_SEITUNG Or $l_i_Map = $MAP_SAOSHANG Or $l_i_Map = $MAP_JAYA Or $l_i_Map = $MAP_HAIJU Or $l_i_Map = $MAP_ZEN_OP Then Return True
	Return False
EndFunc

; The Road Less Traveled is done only after the Seitung Harbor hand-in. Journey still in the log is not enough.
Func Leveler_RoadLessTraveledDone()
	If Leveler_QuestNeedsHandIn($QUEST_ROAD_LESS) Then Return False
	If Leveler_HasQuest($QUEST_JOURNEY_MASTER) Then Return False
	If Leveler_QuestNeedsHandIn($QUEST_JOURNEY_MASTER) Then Return False
	If Map_GetMapID() = $MAP_PANJIANG Or Map_GetMapID() = $MAP_TSUMEI Or Map_GetMapID() = $MAP_SUNQUA_VALE Or Map_GetMapID() = $MAP_KINYA Then Return False
	If Map_IsMapUnlocked($MAP_SEITUNG) Then Return True
	If Map_GetMapID() = $MAP_SEITUNG And Map_GetInstanceInfo("IsOutpost") Then Return True
	Return False
EndFunc

Func Leveler_LostTreasureAlreadyDone()
	If Leveler_QuestNeedsHandIn($QUEST_LOST_TREASURE) Then Return False
	If Quest_GetQuestInfo($QUEST_LOST_TREASURE, "IsCompleted") Then Return True
	If Leveler_IsQuestDone($QUEST_LOST_TREASURE) Then Return True
	If Leveler_QuestFinished($QUEST_THREAT_GROWS) Or Leveler_HasQuest($QUEST_THREAT_GROWS) Then Return True
	If Leveler_HasQuest($QUEST_JOURNEY_MASTER) Or Leveler_HasQuest($QUEST_ROAD_LESS) Then Return True
	Return False
EndFunc

; AgentBase/MyID are required for profession, position, and many quest predicates.
Func Leveler_AgentMemoryLive()
	If IsDeclared("g_p_AgentBase") And Number($g_p_AgentBase) <> 0 Then Return True
	If Agent_GetAgentInfo(-2, "X") <> 0 Or Agent_GetAgentInfo(-2, "Y") <> 0 Then Return True
	If Leveler_PrimaryProfession() >= 1 Then Return True
	Return False
EndFunc

Func Leveler_MaxStep($a_i_A, $a_i_B)
	If $a_i_A > $a_i_B Then Return $a_i_A
	Return $a_i_B
EndFunc

; Last completed story step implied by the character's current map. Uses Map_GetMapID
; only (not account Map_IsMapUnlocked) so a fresh courtyard character is not skipped.
Func Leveler_StoryFloorFromMap($a_i_Map)
	Switch $a_i_Map
		Case $MAP_JAGA
			Return $LEVELER_STEP_VAETTIR
		Case $MAP_LONGEYE, $MAP_BJORA
			Return $LEVELER_STEP_TO_LONGEYE
		Case $MAP_DOCKS, $MAP_CONSULATE, $MAP_SUN_DOCKS, $MAP_GTOB
			Return $LEVELER_STEP_TO_DOCKS
		Case $MAP_KAMADAN
			Return $LEVELER_STEP_TO_KAMADAN
		Case $MAP_LIONS_ARCH, $MAP_LIONS_GATE, $MAP_BEJUNKAN
			Return $LEVELER_STEP_TO_LA
		Case $MAP_GUNNAR, $MAP_KILROY
			Return $LEVELER_STEP_TO_GUNNAR
		Case $MAP_NORRHART
			Return $LEVELER_STEP_ATTR_2
		Case $MAP_HOM, $MAP_AB
			Return $LEVELER_STEP_EOTN_POOL
		Case $MAP_EOTN
			Return $LEVELER_STEP_TO_EOTN
		Case $MAP_BOREAL, $MAP_ICE_CLIFF
			Return $LEVELER_STEP_TO_BOREAL
		Case $MAP_TUNNELS
			Return $LEVELER_STEP_UNLOCK_MOX
		Case $MAP_KAINENG
			Return $LEVELER_STEP_TO_KC
		Case $MAP_MARKETPLACE, $MAP_BUKDEK, $MAP_WAJJUN
			Return $LEVELER_STEP_TO_MARKET
		Case $MAP_KAINENG_DOCKS
			Return $LEVELER_STEP_ZEN_MISSION
		Case $MAP_ZEN_EXP
			Return $LEVELER_STEP_TO_ZEN
		Case $MAP_ZEN_OP
			Return $LEVELER_STEP_TO_ZEN
		Case $MAP_JAYA, $MAP_HAIJU
			Return $LEVELER_STEP_DESTROY_MON
		Case $MAP_SEITUNG, $MAP_SAOSHANG
			Return $LEVELER_STEP_ROAD
		Case $MAP_TSUMEI, $MAP_PANJIANG
			Return $LEVELER_STEP_CHO_MISSION
		Case $MAP_RAN_MUSU, $MAP_CHO_EXPLORABLE, $MAP_KINYA
			Return $LEVELER_STEP_CHO_MISSION
		Case $MAP_CHO_OUTPOST
			Return $LEVELER_STEP_TO_CHO
		Case $MAP_SHING_JEA, $MAP_SUNQUA_VALE, $MAP_LINNOK
			Return $LEVELER_STEP_OVERLOOK
	EndSwitch
	Return -1
EndFunc

; Raise the floor from later story steps that are already proven done on this
; character. Skip account-wide skill / storage / bag flags.
Func Leveler_StoryFloorFromDoneFlags()
	Local $l_i_Floor = -1
	Local $l_ai_Story[22] = [ _
			$LEVELER_STEP_PARTY, $LEVELER_STEP_SECONDARY, $LEVELER_STEP_TO_CHO, $LEVELER_STEP_CHO_MISSION, _
			$LEVELER_STEP_ATTR_1, $LEVELER_STEP_TENGU, $LEVELER_STEP_THREAT, $LEVELER_STEP_ROAD, _
			$LEVELER_STEP_SEITUNG, $LEVELER_STEP_DESTROY_MON, $LEVELER_STEP_TO_ZEN, $LEVELER_STEP_ZEN_MISSION, _
			$LEVELER_STEP_TO_MARKET, $LEVELER_STEP_TO_KC, $LEVELER_STEP_CURE, $LEVELER_STEP_BURDEN, _
			$LEVELER_STEP_TO_BOREAL, $LEVELER_STEP_TO_EOTN, $LEVELER_STEP_ATTR_2, $LEVELER_STEP_TO_GUNNAR, _
			$LEVELER_STEP_TO_LA, $LEVELER_STEP_TO_KAMADAN]
	Local $i = 0
	For $i = 0 To UBound($l_ai_Story) - 1
		If $g_ab_StepDone[$l_ai_Story[$i]] Then $l_i_Floor = Leveler_MaxStep($l_i_Floor, $l_ai_Story[$i])
	Next
	If Leveler_IsQuestDone($QUEST_FORMING_A_PARTY) Then $l_i_Floor = Leveler_MaxStep($l_i_Floor, $LEVELER_STEP_PARTY)
	If Leveler_LostTreasureAlreadyDone() Then $l_i_Floor = Leveler_MaxStep($l_i_Floor, $LEVELER_STEP_ATTR_1)
	If Leveler_HasLaterQuest() Then $l_i_Floor = Leveler_MaxStep($l_i_Floor, $LEVELER_STEP_ATTR_1)
	Return $l_i_Floor
EndFunc

; If a later story beat is clearly done (standing at Zen Daijun, Road handed in,
; Lost Treasure done), mark every earlier step done so FirstIncompleteStep
; cannot jump back to Forming A Party.
Func Leveler_ApplyStoryMonotonicity($a_i_Map)
	Local $l_i_Floor = Leveler_MaxStep(Leveler_StoryFloorFromMap($a_i_Map), Leveler_StoryFloorFromDoneFlags())
	If $l_i_Floor < 0 Then Return -1
	Local $i = 0
	Local $l_i_Filled = 0
	For $i = 0 To $l_i_Floor
		If Not $g_ab_StepDone[$i] Then $l_i_Filled += 1
		$g_ab_StepDone[$i] = True
	Next
	If $l_i_Filled > 0 Then
		Out("[Status] Story floor " & $l_i_Floor & " — " & $g_as_StepNames[$l_i_Floor] & _
				" (map " & $a_i_Map & "). Marked " & $l_i_Filled & " earlier step(s) done.")
	EndIf
	Return $l_i_Floor
EndFunc

; Brief inventory / quest / map check. Greys finished steps and returns the first incomplete one.
Func Leveler_StatusCheck()
	Out("[Status] Checking character progress...")
	Local $l_i_Raw = Number(Map_GetMapID())
	Local $l_i_Live = Leveler_LiveMapID()
	Local $l_i_Map = Leveler_StatusMapID()
	If $l_i_Map <> $l_i_Raw Then
		Out("[Status] Map_GetMapID=" & $l_i_Raw & " current " & $l_i_Live & " — using story map " & $l_i_Map)
	EndIf
	If Not Leveler_AgentMemoryLive() Then
		Local $sQ = "0"
		If IsDeclared("g_p_QueueBase") Then $sQ = Hex(Number($g_p_QueueBase), 8)
		Local $sA = "0"
		If IsDeclared("g_p_AgentBase") Then $sA = Hex(Number($g_p_AgentBase), 8)
		Out("[Status] AgentBase=" & $sA & " QueueBase=" & $sQ & _
				" — profession/position reads are dead. Using map " & $l_i_Map & _
				" (raw " & $l_i_Raw & " current " & $l_i_Live & ")" & _
				" objectives " & Number(World_GetWorldInfo("MissionObjectiveArraySize")) & _
				" and quest flags.")
	EndIf
	Local $l_b_Cho = Map_IsMapUnlocked($MAP_CHO_OUTPOST) Or $l_i_Map = $MAP_CHO_OUTPOST Or $l_i_Map = 257
	Local $l_b_RanMusu = Map_IsMapUnlocked($MAP_RAN_MUSU) Or $l_i_Map = $MAP_RAN_MUSU Or $l_i_Map = $MAP_CHO_EXPLORABLE Or $l_i_Map = $MAP_KINYA
	Local $l_b_Seitung = Map_IsMapUnlocked($MAP_SEITUNG) Or $l_i_Map = $MAP_SEITUNG Or $l_i_Map = $MAP_SAOSHANG Or $l_i_Map = $MAP_JAYA Or $l_i_Map = $MAP_HAIJU Or $l_i_Map = $MAP_ZEN_OP
	Local $l_b_TsumeiPath = $l_i_Map = $MAP_TSUMEI Or $l_i_Map = $MAP_PANJIANG
	Local $l_b_ZenOp = Map_IsMapUnlocked($MAP_ZEN_OP) Or $l_i_Map = $MAP_ZEN_OP
	Local $l_b_ToZenPath = $l_i_Map = $MAP_JAYA Or $l_i_Map = $MAP_HAIJU
	Local $l_b_ShingJea = Map_IsMapUnlocked($MAP_SHING_JEA) Or $l_i_Map = $MAP_SHING_JEA Or $l_b_Cho Or $l_b_RanMusu Or $l_b_Seitung
	Local $l_b_SeitungArmor = Leveler_HasSeitungArmor()
	Local $l_b_Marketplace = Map_IsMapUnlocked($MAP_MARKETPLACE) Or $l_i_Map = $MAP_MARKETPLACE Or $l_i_Map = $MAP_KAINENG_DOCKS Or $l_i_Map = $MAP_BUKDEK Or $l_i_Map = $MAP_WAJJUN Or $l_i_Map = $MAP_KAINENG
	Local $l_b_Kaineng = Map_IsMapUnlocked($MAP_KAINENG) Or $l_i_Map = $MAP_KAINENG
	Local $l_b_MaxArmor = Leveler_HasMaxArmor()
	Local $l_b_Boreal = Map_IsMapUnlocked($MAP_BOREAL) Or $l_i_Map = $MAP_BOREAL Or $l_i_Map = $MAP_TUNNELS Or $l_i_Map = $MAP_ICE_CLIFF Or $l_i_Map = $MAP_EOTN Or $l_i_Map = $MAP_HOM Or $l_i_Map = $MAP_AB
	Local $l_b_Eotn = Map_IsMapUnlocked($MAP_EOTN) Or $l_i_Map = $MAP_EOTN Or $l_i_Map = $MAP_HOM Or $l_i_Map = $MAP_AB
	Local $l_b_Hom = Map_IsMapUnlocked($MAP_HOM) Or $l_i_Map = $MAP_HOM Or $l_i_Map = $MAP_AB
	Local $l_i_Level = Leveler_PlayerLevel()
	Local $l_b_Gunnar = Map_IsMapUnlocked($MAP_GUNNAR) Or $l_i_Map = $MAP_GUNNAR Or $l_i_Map = $MAP_NORRHART
	Local $l_b_Lions = Map_IsMapUnlocked($MAP_LIONS_ARCH) Or $l_i_Map = $MAP_LIONS_ARCH Or $l_i_Map = $MAP_LIONS_GATE
	Local $l_b_Kamadan = Map_IsMapUnlocked($MAP_KAMADAN) Or $l_i_Map = $MAP_KAMADAN Or $l_i_Map = $MAP_SUN_DOCKS Or $l_i_Map = $MAP_CONSULATE Or $l_i_Map = $MAP_DOCKS
	Local $l_b_Docks = Map_IsMapUnlocked($MAP_DOCKS) Or $l_i_Map = $MAP_DOCKS
	Local $l_b_Longeye = Map_IsMapUnlocked($MAP_LONGEYE) Or $l_i_Map = $MAP_LONGEYE Or $l_i_Map = $MAP_BJORA Or $l_i_Map = $MAP_JAGA
	Local $l_b_Jaga = Map_IsMapUnlocked($MAP_JAGA) Or $l_i_Map = $MAP_JAGA

	For $i = 0 To $LEVELER_STEP_COUNT - 1
		$g_ab_StepDone[$i] = False
	Next

	Leveler_RefreshQuestFlags(False)
	Local $l_i_QDone = 0
	For $i = 0 To $LEVELER_Q_COUNT - 1
		If $g_ab_QuestDone[$i] Then $l_i_QDone += 1
	Next
	Out("[Status] Quest flags: " & $l_i_QDone & "/" & $LEVELER_Q_COUNT & " complete")

	; Monastery tutorial is character-specific. Account map unlocks, storage
	; pointers, and account skill unlocks must not skip Secondary / Xunlai / craft.
	$g_ab_StepDone[$LEVELER_STEP_OVERLOOK] = $l_b_ShingJea And Not Leveler_OnOverlook($l_i_Map)
	; AgentBase=0 makes HasSecondaryProfession false even when A/Me9 is in-world.
	; Later quests / current map must still count Forming A Party as done.
	Local $l_b_PastParty = Leveler_IsQuestDone($QUEST_FORMING_A_PARTY) Or Leveler_LostTreasureAlreadyDone() Or _
			Leveler_HasLaterQuest() Or $l_b_TsumeiPath Or _
			$l_i_Map = $MAP_SEITUNG Or $l_i_Map = $MAP_SAOSHANG Or $l_i_Map = $MAP_JAYA Or $l_i_Map = $MAP_HAIJU Or _
			$l_i_Map = $MAP_ZEN_OP Or $l_i_Map = $MAP_ZEN_EXP Or $l_i_Map = $MAP_RAN_MUSU Or _
			$l_i_Map = $MAP_CHO_OUTPOST Or $l_i_Map = $MAP_CHO_EXPLORABLE Or $l_i_Map = $MAP_MARKETPLACE
	$g_ab_StepDone[$LEVELER_STEP_PARTY] = $l_b_PastParty Or ((Not Leveler_QuestLogActive($QUEST_FORMING_A_PARTY)) And _
			(Leveler_QuestLogCompleted($QUEST_FORMING_A_PARTY) Or Leveler_HasSecondaryProfession() Or _
			Leveler_HasQuest($QUEST_SECONDARY) Or Leveler_HasQuest($QUEST_FORMAL_INTRO)))
	$g_ab_StepDone[$LEVELER_STEP_SECONDARY] = Leveler_SecondaryStepReadyToLeave() Or $l_b_PastParty
	Out("[Status] Profession " & Leveler_PrimaryProfession() & "/" & Leveler_SecondaryProfession() & "  Gold " & Leveler_CharacterGold() & "  Secondary step done=" & $g_ab_StepDone[$LEVELER_STEP_SECONDARY])
	$g_ab_StepDone[$LEVELER_STEP_XUNLAI] = Leveler_XunlaiUnlocked()
	; After Road / Seitung, do not send this character back to the monastery weapon/armor crafts.
	Local $l_b_PastMonArmor = Leveler_PastMonasteryArmor()
	$g_ab_StepDone[$LEVELER_STEP_WEAPON] = (Leveler_HasCraftedWeapon() And Leveler_IsModelEquipped($MODEL_CLAIRVOYANT_STAFF)) Or $l_b_PastMonArmor
	$g_ab_StepDone[$LEVELER_STEP_ARMOR] = Leveler_ArmorSetEquipped(Leveler_GetMonasteryPieces()) Or $l_b_PastMonArmor
	$g_ab_StepDone[$LEVELER_STEP_DESTROY] = (Not Leveler_HasStarterArmor() And (Leveler_HasMonasteryArmor() Or $l_b_SeitungArmor)) Or $l_b_PastMonArmor
	$g_ab_StepDone[$LEVELER_STEP_BAGS] = Leveler_HasExtendedBags()
	$g_ab_StepDone[$LEVELER_STEP_SKILLS] = Leveler_ZhaoDiSkillsUnlocked() Or Leveler_QuestProgress($QUEST_LOST_TREASURE) Or Leveler_HasLaterQuest()
	$g_ab_StepDone[$LEVELER_STEP_TO_CHO] = $l_b_RanMusu Or $l_b_Seitung Or ($l_b_Cho And Not Leveler_HasIncompleteQuest($QUEST_FORMAL_INTRO) And Leveler_FormalIntroductionTurnedIn())
	$g_ab_StepDone[$LEVELER_STEP_CHO_MISSION] = $l_b_RanMusu Or $l_b_Seitung Or $l_b_TsumeiPath

	$g_ab_StepDone[$LEVELER_STEP_ATTR_1] = Leveler_LostTreasureAlreadyDone()
	If Leveler_QuestNeedsHandIn($QUEST_WARNING_TENGU) Then
		$g_ab_StepDone[$LEVELER_STEP_TENGU] = False
	ElseIf Leveler_QuestFinished($QUEST_WARNING_TENGU) Or Quest_GetQuestInfo($QUEST_WARNING_TENGU, "IsCompleted") Then
		$g_ab_StepDone[$LEVELER_STEP_TENGU] = True
		Leveler_MarkQuestDone($QUEST_WARNING_TENGU)
	ElseIf Leveler_QuestNeedsHandIn($QUEST_LOST_TREASURE) Then
		$g_ab_StepDone[$LEVELER_STEP_TENGU] = True
		Leveler_MarkQuestDone($QUEST_WARNING_TENGU)
		Out("[Status] Warning the Tengu is already out of the log. Logging it completed and staying on Lost Treasure.")
	Else
		$g_ab_StepDone[$LEVELER_STEP_TENGU] = Leveler_IsQuestDone($QUEST_WARNING_TENGU) Or Leveler_HasIncompleteQuest($QUEST_THREAT_GROWS) Or Leveler_HasIncompleteQuest($QUEST_JOURNEY_MASTER) Or Leveler_HasIncompleteQuest($QUEST_ROAD_LESS) Or $l_b_Seitung Or $l_b_TsumeiPath
		If $g_ab_StepDone[$LEVELER_STEP_TENGU] Then Leveler_MarkQuestDone($QUEST_WARNING_TENGU)
	EndIf
	If Leveler_QuestNeedsHandIn($QUEST_LOST_TREASURE) And Leveler_NearLostTreasureHandIn() Then
		Out("[Status] Already at Raitahn Nem hand-in " & Round($LOST_CHO_END_X) & ", " & Round($LOST_CHO_END_Y) & ". Will send dialog 0x17 without replaying the escort.")
	EndIf
	Leveler_LogActiveQuests()
	If $g_b_ExplorableResume And Not Leveler_IsOutpost() And Map_GetInstanceInfo("IsExplorable") Then
		Out("[Status] Restart recovery: not in an outpost (map " & $l_i_Map & "). Will resume only if this map belongs to the current quest.")
	EndIf
	Out("[Status] Lost Treasure step done=" & $g_ab_StepDone[$LEVELER_STEP_ATTR_1] & "  Tengu step done=" & $g_ab_StepDone[$LEVELER_STEP_TENGU])
	If Leveler_QuestNeedsHandIn($QUEST_THREAT_GROWS) Then
		$g_ab_StepDone[$LEVELER_STEP_THREAT] = False
	ElseIf Leveler_HasQuest($QUEST_JOURNEY_MASTER) Or Leveler_QuestNeedsHandIn($QUEST_JOURNEY_MASTER) Or Leveler_QuestNeedsHandIn($QUEST_ROAD_LESS) Or $l_b_Seitung Then
		$g_ab_StepDone[$LEVELER_STEP_THREAT] = True
		Leveler_MarkQuestDone($QUEST_THREAT_GROWS)
	Else
		$g_ab_StepDone[$LEVELER_STEP_THREAT] = Leveler_IsQuestDone($QUEST_THREAT_GROWS) Or Leveler_QuestFinished($QUEST_THREAT_GROWS)
	EndIf
	If Leveler_QuestNeedsHandIn($QUEST_ROAD_LESS) Or Leveler_HasQuest($QUEST_JOURNEY_MASTER) Then
		$g_ab_StepDone[$LEVELER_STEP_ROAD] = False
	Else
		$g_ab_StepDone[$LEVELER_STEP_ROAD] = Leveler_RoadLessTraveledDone()
	EndIf
	$g_ab_StepDone[$LEVELER_STEP_SEITUNG] = Leveler_ArmorSetEquipped(Leveler_GetSeitungPieces()) Or $l_b_MaxArmor
	If Not $g_ab_StepDone[$LEVELER_STEP_SEITUNG] And $g_ab_StepDone[$LEVELER_STEP_ROAD] Then
		Out("[Status] Road is handed in. Next armor craft is Seitung Harbor, not monastery.")
	EndIf
	$g_ab_StepDone[$LEVELER_STEP_DESTROY_MON] = $l_b_SeitungArmor And (Not Leveler_HasMonasteryArmor() Or $l_b_ZenOp Or $l_b_ToZenPath)
	$g_ab_StepDone[$LEVELER_STEP_TO_ZEN] = $l_b_ZenOp Or $l_b_ToZenPath
	$g_ab_StepDone[$LEVELER_STEP_ZEN_MISSION] = $l_b_Marketplace Or ($l_b_ZenOp And $l_i_Map = $MAP_SEITUNG And Map_GetInstanceInfo("IsOutpost") And Not $l_b_ToZenPath)
	$g_ab_StepDone[$LEVELER_STEP_TO_MARKET] = (Map_IsMapUnlocked($MAP_MARKETPLACE) Or $l_i_Map = $MAP_MARKETPLACE Or $l_b_Kaineng Or $l_i_Map = $MAP_BUKDEK Or $l_i_Map = $MAP_WAJJUN) And $l_i_Map <> $MAP_KAINENG_DOCKS
	$g_ab_StepDone[$LEVELER_STEP_TO_KC] = $l_b_Kaineng
	; Michiko in Kaineng Center. Zhao Di Leech Signet (61) must not skip this.
	$g_ab_StepDone[$LEVELER_STEP_SKILLS2] = Leveler_Skills2Unlocked()
	$g_ab_StepDone[$LEVELER_STEP_MAX_ARMOR] = Leveler_ArmorSetEquipped(Leveler_GetMaxArmorPieces())
	$g_ab_StepDone[$LEVELER_STEP_DESTROY_SEITUNG] = $l_b_MaxArmor And (Not $l_b_SeitungArmor Or Leveler_IsQuestDone($QUEST_SEARCH_CURE) Or Leveler_HasQuest($QUEST_SEARCH_CURE) Or Leveler_IsQuestDone($QUEST_MASTERS_BURDEN))
	$g_ab_StepDone[$LEVELER_STEP_CURE] = Leveler_IsQuestDone($QUEST_SEARCH_CURE) Or Leveler_HasQuest($QUEST_BROTHER_TOSAI) Or Leveler_IsQuestDone($QUEST_MASTERS_BURDEN)
	$g_ab_StepDone[$LEVELER_STEP_BURDEN] = Leveler_IsQuestDone($QUEST_MASTERS_BURDEN) And Not Leveler_HasIncompleteQuest($QUEST_MASTERS_BURDEN)
	$g_ab_StepDone[$LEVELER_STEP_UNLOCK_MOX] = $l_b_Boreal
	$g_ab_StepDone[$LEVELER_STEP_TO_BOREAL] = (Map_IsMapUnlocked($MAP_BOREAL) Or $l_i_Map = $MAP_BOREAL Or $l_i_Map = $MAP_ICE_CLIFF Or $l_b_Eotn) And $l_i_Map <> $MAP_TUNNELS
	$g_ab_StepDone[$LEVELER_STEP_TO_EOTN] = $l_b_Eotn And $l_i_Map <> $MAP_ICE_CLIFF
	$g_ab_StepDone[$LEVELER_STEP_EOTN_POOL] = $l_b_Hom Or Leveler_HasKeiranBow()
	$g_ab_StepDone[$LEVELER_STEP_FARM_20] = $l_i_Level >= 20
	$g_ab_StepDone[$LEVELER_STEP_ATTR_2] = Leveler_IsQuestDone($QUEST_UNWELCOME) And Not Leveler_HasIncompleteQuest($QUEST_UNWELCOME)
	$g_ab_StepDone[$LEVELER_STEP_TO_GUNNAR] = $l_b_Gunnar And $l_i_Map <> $MAP_ICE_CLIFF
	$g_ab_StepDone[$LEVELER_STEP_KILROY] = Leveler_IsQuestDone($QUEST_PUNCH_CLOWN) And Not Leveler_HasIncompleteQuest($QUEST_PUNCH_CLOWN)
	$g_ab_StepDone[$LEVELER_STEP_TO_LA] = $l_b_Lions And $l_i_Map <> $MAP_BEJUNKAN
	$g_ab_StepDone[$LEVELER_STEP_TO_KAMADAN] = $l_b_Kamadan
	$g_ab_StepDone[$LEVELER_STEP_TO_DOCKS] = $l_b_Docks
	$g_ab_StepDone[$LEVELER_STEP_UNLOCK_OLIAS] = Leveler_IsQuestDone($QUEST_OLIAS) And Not Leveler_HasIncompleteQuest($QUEST_OLIAS)
	$g_ab_StepDone[$LEVELER_STEP_UNLOCK_PROFS] = $l_b_Longeye Or $l_b_Jaga
	$g_ab_StepDone[$LEVELER_STEP_UNLOCK_MERCS] = $l_b_Longeye Or $l_b_Jaga
	$g_ab_StepDone[$LEVELER_STEP_TO_LONGEYE] = $l_b_Longeye And $l_i_Map <> $MAP_NORRHART
	$g_ab_StepDone[$LEVELER_STEP_VAETTIR] = $l_b_Jaga
	$g_ab_StepDone[$LEVELER_STEP_DONE] = $l_b_Jaga

	; Account skills / storage / courtyard unlocks still do not skip a fresh
	; monastery character. Current-map and later story-quest progress do:
	; standing at Zen Daijun (213) must not jump back to Forming A Party.
	Leveler_ApplyStoryMonotonicity($l_i_Map)

	Local $l_i_Next = Leveler_FirstIncompleteStep()
	Out("[Status] Map " & $l_i_Map & " current " & $l_i_Live & "  Next step: " & $l_i_Next & " — " & $g_as_StepNames[$l_i_Next])
	Leveler_RefreshStepList($l_i_Next)
	Return $l_i_Next
EndFunc

Func Leveler_LogActiveQuests()
	Local $l_ai_Ids[8] = [$QUEST_FORMING_A_PARTY, $QUEST_SECONDARY, $QUEST_FORMAL_INTRO, $QUEST_LOST_TREASURE, $QUEST_WARNING_TENGU, $QUEST_THREAT_GROWS, $QUEST_JOURNEY_MASTER, $QUEST_ROAD_LESS]
	Local $l_as_Names[8] = ["Forming A Party", "Choose Secondary", "Formal Introduction", "Lost Treasure", "Warning the Tengu", "The Threat Grows", "Journey of the Master", "The Road Less Traveled"]
	Local $i
	Local $l_b_Any = False
	For $i = 0 To 7
		If Leveler_QuestInLog($l_ai_Ids[$i]) Then
			If Not $l_b_Any Then Out("[Status] Quests still in the log:")
			$l_b_Any = True
			Leveler_LogQuestState($l_ai_Ids[$i], $l_as_Names[$i])
		EndIf
	Next
	If Not $l_b_Any Then Out("[Status] No Phase 1 quests are in the log")
EndFunc

Func Leveler_FirstIncompleteStep()
	For $i = 0 To $LEVELER_STEP_COUNT - 1
		If $g_ab_StepDone[$i] Then ContinueLoop
		If ($i = $LEVELER_STEP_TO_LONGEYE Or $i = $LEVELER_STEP_VAETTIR) And Not Leveler_NeedsVaettirPath() Then ContinueLoop
		Return $i
	Next
	Return $LEVELER_STEP_DONE
EndFunc

Func Leveler_MarkStepsThrough($a_i_LastDone)
	If $a_i_LastDone < 0 Then Return
	For $i = 0 To $a_i_LastDone
		If $i < $LEVELER_STEP_COUNT Then $g_ab_StepDone[$i] = True
	Next
	Leveler_RefreshStepList($g_i_Step)
EndFunc
