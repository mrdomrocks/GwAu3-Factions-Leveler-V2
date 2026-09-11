#include-once

Func Leveler_QuestFinished($a_i_QuestID)
	If Quest_GetQuestInfo($a_i_QuestID, "IsCompleted") Then Return True
	Return False
EndFunc

Func Leveler_OnOverlook()
	Local $l_i_Map = Map_GetMapID()
	Return $l_i_Map = 212 Or $l_i_Map = 285 Or $l_i_Map = 416
EndFunc

Func Leveler_HasStorageAccess()
	If Item_GetBagPtr($GC_I_INVENTORY_STORAGE1) <> 0 Then Return True
	If Item_GetInventoryInfo("Storage1Ptr") <> 0 Then Return True
	Return False
EndFunc

Func Leveler_SkillsUnlocked()
	If Not Account_IsSkillUnlocked($SKILL_CRY_OF_PAIN) Then Return False
	If Not Account_IsSkillUnlocked($SKILL_POWER_DRAIN) Then Return False
	If Not Account_IsSkillUnlocked($SKILL_SIGNET_OF_DISRUPTION) Then Return False
	Return True
EndFunc

Func Leveler_Skills2Unlocked()
	If Not Account_IsSkillUnlocked($SKILL_POWER_SPIKE) Then Return False
	If Leveler_IsMesmer() And Not Account_IsSkillUnlocked($SKILL_BACKFIRE) Then Return False
	Return True
EndFunc

Func Leveler_HasLaterQuest()
	If Leveler_HasQuest($QUEST_WARNING_TENGU) Then Return True
	If Leveler_HasQuest($QUEST_THREAT_GROWS) Then Return True
	If Leveler_HasQuest($QUEST_JOURNEY_MASTER) Then Return True
	If Leveler_HasQuest($QUEST_ROAD_LESS) Then Return True
	Return False
EndFunc

; Brief inventory / quest / map check. Greys finished steps and returns the first incomplete one.
Func Leveler_StatusCheck()
	Out("[Status] Checking character progress...")
	Local $l_i_Map = Map_GetMapID()
	Local $l_b_Cho = Map_IsMapUnlocked($MAP_CHO_OUTPOST) Or $l_i_Map = $MAP_CHO_OUTPOST Or $l_i_Map = 257
	Local $l_b_RanMusu = Map_IsMapUnlocked($MAP_RAN_MUSU) Or $l_i_Map = $MAP_RAN_MUSU Or $l_i_Map = $MAP_CHO_EXPLORABLE Or $l_i_Map = $MAP_KINYA
	Local $l_b_Seitung = Map_IsMapUnlocked($MAP_SEITUNG) Or $l_i_Map = $MAP_SEITUNG Or $l_i_Map = $MAP_SAOSHANG Or $l_i_Map = $MAP_JAYA Or $l_i_Map = $MAP_HAIJU Or $l_i_Map = $MAP_ZEN_OP
	Local $l_b_TsumeiPath = $l_i_Map = $MAP_TSUMEI Or $l_i_Map = $MAP_PANJIANG
	Local $l_b_ZenOp = Map_IsMapUnlocked($MAP_ZEN_OP) Or $l_i_Map = $MAP_ZEN_OP
	Local $l_b_ToZenPath = $l_i_Map = $MAP_JAYA Or $l_i_Map = $MAP_HAIJU
	Local $l_b_ShingJea = Map_IsMapUnlocked($MAP_SHING_JEA) Or $l_i_Map = $MAP_SHING_JEA Or $l_b_Cho Or $l_b_RanMusu Or $l_b_Seitung
	Local $l_b_SeitungArmor = Leveler_HasSeitungArmor()
	Local $l_b_Skill61 = Leveler_Skills2Unlocked()
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

	$g_ab_StepDone[$LEVELER_STEP_OVERLOOK] = $l_b_ShingJea And Not Leveler_OnOverlook()
	$g_ab_StepDone[$LEVELER_STEP_PARTY] = Leveler_QuestFinished($QUEST_FORMING_A_PARTY) Or Map_IsMapUnlocked($MAP_LINNOK) Or $l_b_Cho Or $l_b_RanMusu Or $l_b_Seitung
	$g_ab_StepDone[$LEVELER_STEP_SECONDARY] = Leveler_QuestFinished($QUEST_SECONDARY) Or Leveler_HasQuest($QUEST_FORMAL_INTRO) Or Leveler_QuestFinished($QUEST_FORMAL_INTRO) Or $l_b_Cho Or $l_b_RanMusu Or $l_b_Seitung
	$g_ab_StepDone[$LEVELER_STEP_XUNLAI] = Leveler_HasStorageAccess() Or $l_b_Cho Or $l_b_RanMusu Or $l_b_Seitung
	$g_ab_StepDone[$LEVELER_STEP_WEAPON] = Leveler_HasCraftedWeapon() Or $l_b_Cho Or $l_b_RanMusu Or $l_b_Seitung
	$g_ab_StepDone[$LEVELER_STEP_ARMOR] = Leveler_HasMonasteryArmor() Or $l_b_SeitungArmor Or $l_b_Cho Or $l_b_RanMusu Or $l_b_Seitung
	$g_ab_StepDone[$LEVELER_STEP_DESTROY] = (Not Leveler_HasStarterArmor() And (Leveler_HasMonasteryArmor() Or $l_b_SeitungArmor)) Or $l_b_Cho Or $l_b_RanMusu Or $l_b_Seitung
	$g_ab_StepDone[$LEVELER_STEP_BAGS] = Leveler_HasExtendedBags() Or $l_b_Cho Or $l_b_RanMusu Or $l_b_Seitung
	$g_ab_StepDone[$LEVELER_STEP_SKILLS] = Leveler_SkillsUnlocked() Or $l_b_Cho Or $l_b_RanMusu Or $l_b_Seitung
	$g_ab_StepDone[$LEVELER_STEP_TO_CHO] = $l_b_Cho Or $l_b_RanMusu Or $l_b_Seitung
	$g_ab_StepDone[$LEVELER_STEP_CHO_MISSION] = $l_b_RanMusu Or $l_b_Seitung Or $l_b_TsumeiPath

	$g_ab_StepDone[$LEVELER_STEP_ATTR_1] = (Not Leveler_HasQuest($QUEST_LOST_TREASURE) And (Leveler_HasLaterQuest() Or $l_b_Seitung Or $l_b_TsumeiPath Or Leveler_QuestFinished($QUEST_LOST_TREASURE))) And $l_i_Map <> $MAP_CHO_EXPLORABLE
	$g_ab_StepDone[$LEVELER_STEP_TENGU] = Not Leveler_HasQuest($QUEST_WARNING_TENGU) And (Leveler_HasQuest($QUEST_THREAT_GROWS) Or Leveler_HasQuest($QUEST_JOURNEY_MASTER) Or Leveler_HasQuest($QUEST_ROAD_LESS) Or $l_b_Seitung Or $l_b_TsumeiPath Or Leveler_QuestFinished($QUEST_WARNING_TENGU))
	$g_ab_StepDone[$LEVELER_STEP_THREAT] = Not Leveler_HasQuest($QUEST_THREAT_GROWS) And (Leveler_HasQuest($QUEST_JOURNEY_MASTER) Or Leveler_HasQuest($QUEST_ROAD_LESS) Or $l_b_Seitung Or Leveler_QuestFinished($QUEST_THREAT_GROWS)) And $l_i_Map <> $MAP_TSUMEI And $l_i_Map <> $MAP_PANJIANG
	$g_ab_StepDone[$LEVELER_STEP_ROAD] = $l_b_SeitungArmor Or (($l_i_Map = $MAP_SEITUNG Or $l_i_Map = $MAP_JAYA Or $l_i_Map = $MAP_HAIJU Or $l_i_Map = $MAP_ZEN_OP) And Not Leveler_HasQuest($QUEST_ROAD_LESS))
	$g_ab_StepDone[$LEVELER_STEP_SEITUNG] = $l_b_SeitungArmor
	$g_ab_StepDone[$LEVELER_STEP_DESTROY_MON] = $l_b_SeitungArmor And (Not Leveler_HasMonasteryArmor() Or $l_b_ZenOp Or $l_b_ToZenPath)
	$g_ab_StepDone[$LEVELER_STEP_TO_ZEN] = $l_b_ZenOp Or $l_b_ToZenPath
	$g_ab_StepDone[$LEVELER_STEP_SKILLS2] = $l_b_Skill61
	$g_ab_StepDone[$LEVELER_STEP_ZEN_MISSION] = $l_b_Marketplace Or ($l_b_Skill61 And $l_b_ZenOp And $l_i_Map = $MAP_SEITUNG And Map_GetInstanceInfo("IsOutpost"))
	$g_ab_StepDone[$LEVELER_STEP_TO_MARKET] = (Map_IsMapUnlocked($MAP_MARKETPLACE) Or $l_i_Map = $MAP_MARKETPLACE Or $l_b_Kaineng Or $l_i_Map = $MAP_BUKDEK Or $l_i_Map = $MAP_WAJJUN) And $l_i_Map <> $MAP_KAINENG_DOCKS
	$g_ab_StepDone[$LEVELER_STEP_TO_KC] = $l_b_Kaineng
	$g_ab_StepDone[$LEVELER_STEP_MAX_ARMOR] = $l_b_MaxArmor
	$g_ab_StepDone[$LEVELER_STEP_DESTROY_SEITUNG] = $l_b_MaxArmor And (Not $l_b_SeitungArmor Or Leveler_QuestFinished($QUEST_SEARCH_CURE) Or Leveler_HasQuest($QUEST_SEARCH_CURE) Or Leveler_QuestFinished($QUEST_MASTERS_BURDEN))
	$g_ab_StepDone[$LEVELER_STEP_CURE] = Leveler_QuestFinished($QUEST_SEARCH_CURE) Or Leveler_HasQuest($QUEST_BROTHER_TOSAI) Or Leveler_QuestFinished($QUEST_MASTERS_BURDEN)
	$g_ab_StepDone[$LEVELER_STEP_BURDEN] = Leveler_QuestFinished($QUEST_MASTERS_BURDEN) And Not Leveler_HasQuest($QUEST_MASTERS_BURDEN)
	$g_ab_StepDone[$LEVELER_STEP_UNLOCK_MOX] = $l_b_Boreal
	$g_ab_StepDone[$LEVELER_STEP_TO_BOREAL] = (Map_IsMapUnlocked($MAP_BOREAL) Or $l_i_Map = $MAP_BOREAL Or $l_i_Map = $MAP_ICE_CLIFF Or $l_b_Eotn) And $l_i_Map <> $MAP_TUNNELS
	$g_ab_StepDone[$LEVELER_STEP_TO_EOTN] = $l_b_Eotn And $l_i_Map <> $MAP_ICE_CLIFF
	$g_ab_StepDone[$LEVELER_STEP_EOTN_POOL] = $l_b_Hom Or Leveler_HasKeiranBow()
	$g_ab_StepDone[$LEVELER_STEP_FARM_20] = $l_i_Level >= 20
	$g_ab_StepDone[$LEVELER_STEP_ATTR_2] = Leveler_QuestFinished($QUEST_UNWELCOME) And Not Leveler_HasQuest($QUEST_UNWELCOME)
	$g_ab_StepDone[$LEVELER_STEP_TO_GUNNAR] = $l_b_Gunnar And $l_i_Map <> $MAP_ICE_CLIFF
	$g_ab_StepDone[$LEVELER_STEP_KILROY] = Leveler_QuestFinished($QUEST_PUNCH_CLOWN) And Not Leveler_HasQuest($QUEST_PUNCH_CLOWN)
	$g_ab_StepDone[$LEVELER_STEP_TO_LA] = $l_b_Lions And $l_i_Map <> $MAP_BEJUNKAN
	$g_ab_StepDone[$LEVELER_STEP_TO_KAMADAN] = $l_b_Kamadan
	$g_ab_StepDone[$LEVELER_STEP_TO_DOCKS] = $l_b_Docks
	$g_ab_StepDone[$LEVELER_STEP_UNLOCK_OLIAS] = Leveler_QuestFinished($QUEST_OLIAS) And Not Leveler_HasQuest($QUEST_OLIAS)
	$g_ab_StepDone[$LEVELER_STEP_UNLOCK_PROFS] = $l_b_Longeye Or $l_b_Jaga
	$g_ab_StepDone[$LEVELER_STEP_UNLOCK_MERCS] = $l_b_Longeye Or $l_b_Jaga
	$g_ab_StepDone[$LEVELER_STEP_TO_LONGEYE] = $l_b_Longeye And $l_i_Map <> $MAP_NORRHART
	$g_ab_StepDone[$LEVELER_STEP_VAETTIR] = $l_b_Jaga
	$g_ab_StepDone[$LEVELER_STEP_DONE] = $l_b_Jaga

	; Fill earlier Shing Jea / Kaineng / EotN farm steps only. Phase 5 quests stay independent
	; so Gunnar's / Lion's Arch unlocks do not skip An Unwelcome Guest or Punch the Clown.
	Local $l_i_Highest = -1
	For $i = 0 To $LEVELER_STEP_FARM_20
		If $g_ab_StepDone[$i] Then $l_i_Highest = $i
	Next
	If $l_i_Highest >= 0 Then
		For $i = 0 To $l_i_Highest
			$g_ab_StepDone[$i] = True
		Next
	EndIf

	Local $l_i_Next = Leveler_FirstIncompleteStep()
	Out("[Status] Next step: " & $l_i_Next & " — " & $g_as_StepNames[$l_i_Next])
	Leveler_RefreshStepList($l_i_Next)
	Return $l_i_Next
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
