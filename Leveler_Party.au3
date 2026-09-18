#include-once

#Region Profession

Func Leveler_PrimaryProfession()
	Local $l_i_Prof = Agent_GetAgentInfo(-2, "Primary")
	If $l_i_Prof >= 1 And $l_i_Prof <= 10 Then Return $l_i_Prof
	Return Party_GetPartyProfessionInfo(-2, "Primary")
EndFunc

Func Leveler_SecondaryProfession()
	Local $l_i_Prof = Agent_GetAgentInfo(-2, "Secondary")
	If $l_i_Prof >= 1 And $l_i_Prof <= 10 Then Return $l_i_Prof
	$l_i_Prof = Party_GetPartyProfessionInfo(-2, "Secondary")
	If $l_i_Prof >= 1 And $l_i_Prof <= 10 Then Return $l_i_Prof
	Return 0
EndFunc

; Profession ID 1-10 means it is assigned. #317 may still be in the log.
Func Leveler_HasSecondaryProfession()
	Local $l_i_Prof = Leveler_SecondaryProfession()
	Return $l_i_Prof >= 1 And $l_i_Prof <= 10
EndFunc

Func Leveler_IsMesmer()
	Return Leveler_PrimaryProfession() = $GC_I_PROFESSION_MESMER
EndFunc

Func Leveler_HasMesmer()
	Return Leveler_PrimaryProfession() = $GC_I_PROFESSION_MESMER Or Leveler_SecondaryProfession() = $GC_I_PROFESSION_MESMER
EndFunc

; Bitmask of professions this character can select (PartyProfession.unlocked_professions).
Func Leveler_UnlockedProfessionFlags()
	Local $l_i_MyID = Agent_GetMyID()
	Local $l_i_Primary = Agent_GetAgentInfo(-2, "Primary")
	Local $l_i_Secondary = Agent_GetAgentInfo(-2, "Secondary")
	Local $l_p_Ptr = World_GetWorldInfo("PartyProfessionArray")
	Local $l_i_Size = World_GetWorldInfo("PartyProfessionArraySize")
	If $l_p_Ptr = 0 Then Return 0
	If $l_i_Size <= 0 Then $l_i_Size = 1
	Local $l_i_Fallback = 0
	Local $i
	For $i = 0 To $l_i_Size - 1
		Local $l_p_Entry = $l_p_Ptr + ($i * 0x14)
		Local $l_i_Agent = Memory_Read($l_p_Entry, "dword")
		Local $l_i_Flags = Memory_Read($l_p_Entry + 0xC, "dword")
		If $l_i_Agent = $l_i_MyID Then Return $l_i_Flags
		If Memory_Read($l_p_Entry + 0x4, "dword") = $l_i_Primary And Memory_Read($l_p_Entry + 0x8, "dword") = $l_i_Secondary And $l_i_Flags <> 0 Then $l_i_Fallback = $l_i_Flags
	Next
	Return $l_i_Fallback
EndFunc

; Accept both 1<<profession and 1<<(profession-1) bit layouts.
Func Leveler_ProfessionBitOn($a_i_Flags, $a_i_Prof)
	If $a_i_Prof < $GC_I_PROFESSION_WARRIOR Or $a_i_Prof > $GC_I_PROFESSION_DERVISH Then Return False
	If BitAND($a_i_Flags, BitShift(1, -$a_i_Prof)) <> 0 Then Return True
	If BitAND($a_i_Flags, BitShift(1, -($a_i_Prof - 1))) <> 0 Then Return True
	Return False
EndFunc

Func Leveler_ProfessionUnlockCount($a_i_Flags)
	Local $l_i_Count = 0
	Local $i
	For $i = $GC_I_PROFESSION_WARRIOR To $GC_I_PROFESSION_DERVISH
		If Leveler_ProfessionBitOn($a_i_Flags, $i) Then $l_i_Count += 1
	Next
	Return $l_i_Count
EndFunc

Func Leveler_IsProfessionUnlocked($a_i_Prof)
	Return Leveler_ProfessionBitOn(Leveler_UnlockedProfessionFlags(), $a_i_Prof)
EndFunc

; GToB trainers unlock every secondary, including Paragon and Dervish.
Func Leveler_RemainingSecondariesUnlocked()
	If $g_b_SecondaryProfsTalked Then Return True
	Local $l_i_Flags = Leveler_UnlockedProfessionFlags()
	If $l_i_Flags = 0 Then Return False
	Local $i
	For $i = $GC_I_PROFESSION_WARRIOR To $GC_I_PROFESSION_DERVISH
		If Not Leveler_ProfessionBitOn($l_i_Flags, $i) Then Return False
	Next
	$g_b_SecondaryProfsTalked = True
	Return True
EndFunc

#EndRegion Profession

#Region Party

Func Leveler_HenchmanCount()
	Local $l_i_Count = Party_GetPartyContextInfo("HenchmenCount")
	If $l_i_Count > 0 Then Return $l_i_Count
	$l_i_Count = Party_GetMyPartyInfo("ArrayHenchmanPartyMemberSize")
	If $l_i_Count > 0 Then Return $l_i_Count
	If Party_GetMyPartyHenchmanInfo(1, "AgentID") <> 0 Then Return 1
	Return 0
EndFunc

Func Leveler_HeroCount()
	Local $l_i_Count = Party_GetPartyContextInfo("HeroCount")
	If $l_i_Count > 0 Then Return $l_i_Count
	Return Party_GetMyPartyInfo("ArrayHeroPartyMemberSize")
EndFunc

Func Leveler_PartyHasHero($a_i_HeroID)
	If $a_i_HeroID <= 0 Then Return False
	Local $l_i_Count = Leveler_HeroCount()
	Local $i
	For $i = 1 To $l_i_Count
		If Party_GetMyPartyHeroInfo($i, "HeroID") = $a_i_HeroID Then Return True
	Next
	Return False
EndFunc

; True if Mox is in the party, can be added, or this character already reached EotN.
Func Leveler_HasMoxUnlocked()
	If $g_b_MoxUnlocked Then Return True
	If Leveler_PartyHasHero($GC_I_HERO_ID_MOX) Then
		$g_b_MoxUnlocked = True
		Return True
	EndIf
	If Leveler_IsOutpost() Then
		Party_AddHero($GC_I_HERO_ID_MOX)
		Sleep(800)
		If Leveler_PartyHasHero($GC_I_HERO_ID_MOX) Then
			$g_b_MoxUnlocked = True
			Return True
		EndIf
	EndIf
	Local $l_i_Map = Map_GetMapID()
	If Map_IsMapUnlocked($MAP_EOTN) Or $l_i_Map = $MAP_EOTN Or $l_i_Map = $MAP_HOM Or $l_i_Map = $MAP_BOREAL Or $l_i_Map = $MAP_ICE_CLIFF Then
		$g_b_MoxUnlocked = True
		Return True
	EndIf
	If Leveler_HasIncompleteQuest($QUEST_AGAINST_DESTROYERS) Then
		$g_b_MoxUnlocked = True
		Return True
	EndIf
	Return False
EndFunc

; Add Mox. Stay False if the Bukdek dialog did not unlock him.
Func Leveler_ConfirmMoxInHeroList()
	If Leveler_HasMoxUnlocked() Then
		Out("[Step] Mox is already on the hero list")
		Return True
	EndIf
	Party_LeaveGroup(True)
	Sleep(500)
	Party_AddHero($GC_I_HERO_ID_MOX)
	Sleep(1500)
	If Leveler_PartyHasHero($GC_I_HERO_ID_MOX) Then
		$g_b_MoxUnlocked = True
		Out("[Step] Mox is in the hero list")
		Return True
	EndIf
	Out("[Step] Mox is not in the hero list after the unlock dialog")
	Return False
EndFunc

; True if Olias is already in the party or can be added in this outpost.
Func Leveler_HasOliasUnlocked()
	If $g_b_OliasUnlocked Then Return True
	If Leveler_PartyHasHero($GC_I_HERO_ID_OLIAS) Then
		$g_b_OliasUnlocked = True
		Return True
	EndIf
	If Not Leveler_IsOutpost() Then Return False
	Party_AddHero($GC_I_HERO_ID_OLIAS)
	Sleep(800)
	If Leveler_PartyHasHero($GC_I_HERO_ID_OLIAS) Then
		$g_b_OliasUnlocked = True
		Return True
	EndIf
	Return False
EndFunc

; Add Olias. Stay False if the Kamadan reward did not unlock him.
Func Leveler_ConfirmOliasInHeroList()
	If Leveler_HasOliasUnlocked() Then
		Out("[Step] Olias is already on the hero list")
		Return True
	EndIf
	If Not Leveler_IsOutpost() Then Return False
	Party_LeaveGroup(True)
	Sleep(500)
	Party_AddHero($GC_I_HERO_ID_OLIAS)
	Sleep(1500)
	If Leveler_PartyHasHero($GC_I_HERO_ID_OLIAS) Then
		$g_b_OliasUnlocked = True
		Out("[Step] Olias is in the hero list")
		Return True
	EndIf
	Out("[Step] Olias is not in the hero list after the unlock dialog")
	Return False
EndFunc

Func Leveler_FormingPartyHenchIDs()
	Local $l_ai_Hench[3] = [2, 5, 1]
	Return $l_ai_Hench
EndFunc

Func Leveler_HenchmenForMap($a_i_Map = 0)
	If $a_i_Map = 0 Then $a_i_Map = Map_GetMapID()
	Local $l_i_Max = Map_GetCurrentAreaInfo("MaxPartySize")

	If $a_i_Map = $MAP_SEITUNG Then
		Local $l_ai_Seitung[5] = [2, 3, 1, 6, 5]
		Return $l_ai_Seitung
	EndIf
	If $a_i_Map = $MAP_ZEN_OP Then
		Local $l_ai_Zen[5] = [2, 3, 1, 8, 5]
		Return $l_ai_Zen
	EndIf
	If $a_i_Map = $MAP_MARKETPLACE Then
		Local $l_ai_Market[7] = [6, 9, 5, 1, 4, 7, 3]
		Return $l_ai_Market
	EndIf
	If $a_i_Map = $MAP_KAINENG Then
		Local $l_ai_Kc[7] = [2, 10, 4, 8, 7, 9, 12]
		Return $l_ai_Kc
	EndIf
	If $a_i_Map = $MAP_BOREAL Then
		Local $l_ai_Boreal[7] = [7, 9, 2, 3, 4, 6, 5]
		Return $l_ai_Boreal
	EndIf
	If $a_i_Map = $MAP_EOTN Or $a_i_Map = $MAP_HOM Then
		Local $l_ai_Eotn[7] = [2, 3, 5, 6, 7, 9, 10]
		Return $l_ai_Eotn
	EndIf
	If $a_i_Map = $MAP_GUNNAR Then
		Local $l_ai_Gunnar[3] = [4, 5, 6]
		Return $l_ai_Gunnar
	EndIf
	; EotN hench order: 1 Devona, 2 Talon, 3 Aidan, 4 Zho, 5 Lina, 6 Mhenlo, 7 Eve, 8 Lo Sha, 9 Cynn, 10 Herta
	If $a_i_Map = $MAP_LONGEYE Then
		Local $l_ai_Longeye[3] = [6, 4, 8]
		Return $l_ai_Longeye
	EndIf
	If $a_i_Map = $MAP_LIONS_ARCH Then
		Local $l_ai_La[1] = [1]
		Return $l_ai_La
	EndIf
	If $a_i_Map = $MAP_KAMADAN Then
		Local $l_ai_Kamadan[3] = [2, 12, 9]
		Return $l_ai_Kamadan
	EndIf
	If $l_i_Max > 4 Then
		Local $l_ai_Large[7] = [2, 3, 5, 6, 7, 9, 10]
		Return $l_ai_Large
	EndIf

	Local $l_ai_Small[3] = [2, 5, 1]
	Return $l_ai_Small
EndFunc

Func Leveler_AddHenchmanList(ByRef $a_ai_Hench)
	Local $i
	Local $l_s_List = ""
	For $i = 0 To UBound($a_ai_Hench) - 1
		If $i > 0 Then $l_s_List &= ", "
		$l_s_List &= $a_ai_Hench[$i]
		Party_AddNpc($a_ai_Hench[$i])
		Sleep(250)
	Next
	Sleep(500)
	Out("[Party] Invited henchmen " & $l_s_List)
	Return True
EndFunc

Func Leveler_HasFormingPartyHenchmen()
	Return Leveler_HenchmanCount() >= 3
EndFunc

Func Leveler_EnsureFormingPartyHenchmen()
	If Leveler_HasFormingPartyHenchmen() Then
		Out("[Party] Forming A Party henchmen are already in the party")
		Return True
	EndIf
	Local $l_ai_Hench = Leveler_FormingPartyHenchIDs()
	Leveler_AddHenchmanList($l_ai_Hench)
	If Leveler_HasFormingPartyHenchmen() Then Return True
	Out("[Party] Invited henchmen 2, 5, 1 (count " & Leveler_HenchmanCount() & "). Continuing to Linnok.")
	Return True
EndFunc

Func Leveler_AddHeroTeam($a_b_Olias = False)
	Local $l_i_Fourth = $GC_I_HERO_ID_MOX
	Local $l_s_FourthBar = "OgCikys8wchuD4xb5VAAAAAA"
	Local $l_s_FourthName = "MOX"
	If $a_b_Olias Then
		$l_i_Fourth = $GC_I_HERO_ID_OLIAS
		$l_s_FourthBar = "OAhjQoGYIP3hhWVVaO5EeDTqNA"
		$l_s_FourthName = "Olias"
	EndIf
	Local $l_ai_Heroes[4] = [$GC_I_HERO_ID_GWEN, $GC_I_HERO_ID_VEKK, $GC_I_HERO_ID_OGDEN_STONEHEALER, $l_i_Fourth]
	Local $l_as_Bars[4] = [ _
			"OQhkAsC8gFKgGckjHFRUGCA", _
			"OgVDI8gsCawROeUEtZIA", _
			"OwUUMsG/E4GgMnZskzkIZQAA", _
			$l_s_FourthBar _
			]
	Local $i
	For $i = 0 To 3
		Party_AddHero($l_ai_Heroes[$i])
		Sleep(250)
	Next
	Sleep(800)
	For $i = 0 To 3
		Attribute_LoadSkillTemplate($l_as_Bars[$i], $i + 1)
		Sleep(400)
		Party_SetHeroAggression($i + 1, 1)
	Next
	Out("[Party] Added Gwen, Vekk, Ogden, " & $l_s_FourthName)
	Return True
EndFunc

Func Leveler_PrepareHeroTeam($a_ai_Hench = 0, $a_b_Olias = False)
	$g_b_CombatMode = True
	$g_b_UAIReady = False
	Leveler_EquipSkillBar()
	Party_LeaveGroup(True)
	Sleep(400)
	Leveler_AddHeroTeam($a_b_Olias)
	If IsArray($a_ai_Hench) Then Leveler_AddHenchmanList($a_ai_Hench)
	Return True
EndFunc

Func Leveler_PrepareForBattle()
	$g_b_CombatMode = True
	$g_b_UAIReady = False
	Leveler_EquipSkillBar()
	Ui_SetDifficulty(False)

	Local $l_ai_Want = Leveler_HenchmenForMap()
	If Leveler_HenchmanCount() >= UBound($l_ai_Want) Then
		Out("[Party] Henchmen already in the party")
	Else
		If Leveler_HenchmanCount() > 0 Or Leveler_HeroCount() > 0 Then
			Party_LeaveGroup(True)
			Sleep(800)
		EndIf
		Leveler_AddHenchmanList($l_ai_Want)
	EndIf

	Leveler_PrepareCombatAI()
	Return True
EndFunc

Func Leveler_PrepareMissionParty()
	$g_b_CombatMode = True
	Local $l_ai_Want = Leveler_HenchmenForMap()
	Local $l_i_Want = UBound($l_ai_Want)
	If Leveler_HenchmanCount() < $l_i_Want Then
		; Do not LeaveGroup here. Kick + Enter Mission disconnects.
		Leveler_AddHenchmanList($l_ai_Want)
		Local $l_h_Timer = TimerInit()
		While TimerDiff($l_h_Timer) < 5000
			If Leveler_HenchmanCount() >= $l_i_Want Then ExitLoop
			Sleep(250)
		WEnd
		Out("[Party] Henchmen in party: " & Leveler_HenchmanCount() & "/" & $l_i_Want)
	Else
		Out("[Party] Mission henchmen already in the party")
	EndIf
	; Invite packets must drain before Enter Challenge. Same-second invite+enter
	; is the Wine Cho disconnect (still IsLoading / type 2 when the wait gives up).
	Sleep(2500)
	Return True
EndFunc

#EndRegion Party

#Region Mission

Func Leveler_InMissionInstance($a_i_MapID = 0)
	If Map_GetInstanceInfo("IsLoading") Then Return False
	If Map_GetInstanceInfo("IsOutpost") Then Return False
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False
	If $a_i_MapID <> 0 And Map_GetMapID() = $a_i_MapID Then Return True
	; Cho and Zen keep the outpost map ID when the mission instance loads.
	If Map_GetMapID() = $MAP_CHO_OUTPOST Then Return True
	If Map_GetMapID() = $MAP_ZEN_OP Then Return True
	If Map_GetMapID() = $MAP_ZEN_EXP Then Return True
	Return False
EndFunc

; GwAu3 Map_GetInstanceInfo("Type"): 0 = outpost, 1 = explorable, 2 = loading.
Func Leveler_InstanceTypeName($a_i_Type = -1)
	If $a_i_Type < 0 Then $a_i_Type = Map_GetInstanceInfo("Type")
	Switch $a_i_Type
		Case 0
			Return "outpost"
		Case 1
			Return "explorable"
		Case 2
			Return "loading"
	EndSwitch
	Return "type " & $a_i_Type
EndFunc

; Do not use Map_WaitMapLoading for mission enter. That helper:
; - treats type 2 (loading) as a miss and times out after 30s + 45s
; - sends Cinematic_Skip (0x63) whenever IsCinematic is set, including while loading
; Both match the Wine Cho failure: enter starts load, 76s later still type 2, then char select.
Func Leveler_WaitMissionExplorable($a_i_MapID, $a_i_StartMap, $a_i_Timeout = 180000)
	Local $l_h_Timer = TimerInit()
	Local $l_i_LastType = -1
	Local $l_b_SawLoading = False
	Local $l_b_LoggedReady = False
	Local $l_i_CinematicSkips = 0

	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False

		Local $l_i_Type = Map_GetInstanceInfo("Type")
		Local $l_i_Map = Map_GetMapID()
		If $l_i_Type <> $l_i_LastType Then
			Out("[Step] Mission load: map " & $l_i_Map & " " & Leveler_InstanceTypeName($l_i_Type) & " (want explorable)")
			$l_i_LastType = $l_i_Type
		EndIf

		If Map_GetInstanceInfo("IsLoading") Or $l_i_Type = 2 Then
			$l_b_SawLoading = True
			Sleep(250)
			ContinueLoop
		EndIf

		If Leveler_InMissionInstance($a_i_MapID) Or (Map_GetInstanceInfo("IsExplorable") And ($l_i_Map = $a_i_StartMap Or $l_i_Map = $a_i_MapID)) Then
			If Not $l_b_LoggedReady Then
				Out("[Step] Mission instance is explorable on map " & $l_i_Map)
				$l_b_LoggedReady = True
			EndIf
			If Game_GetGameInfo("IsCinematic") Then
				If $l_i_CinematicSkips < 3 Then
					Cinematic_SkipCinematic()
					$l_i_CinematicSkips += 1
				EndIf
				Sleep(800)
				ContinueLoop
			EndIf
			If Leveler_ClientIsReady() Then Return True
		EndIf

		If Not $l_b_SawLoading And Map_GetInstanceInfo("IsOutpost") And TimerDiff($l_h_Timer) > 15000 Then
			Out("[Step] Enter Challenge did not start loading (still outpost after 15s)")
			Return False
		EndIf

		If Leveler_ClientDisconnected() And Not Map_GetInstanceInfo("IsLoading") Then
			Out("[Step] Client dropped during mission enter (map " & $l_i_Map & ", " & Leveler_InstanceTypeName($l_i_Type) & ")")
			Return False
		EndIf

		Sleep(250)
	WEnd

	If Map_GetInstanceInfo("IsLoading") Then
		Out("[Step] Mission still loading after " & $a_i_Timeout & " ms")
	ElseIf Not $l_b_SawLoading Then
		Out("[Step] Enter Challenge never started a map load")
	EndIf
	Return Leveler_InMissionInstance($a_i_MapID) And Leveler_ClientIsReady()
EndFunc

; Quiet period after skillbar / hench invite packets. Do not send Enter Challenge
; in the same second as Party_AddNpc (Wine Cho log: invite then Exiting Outpost).
Func Leveler_WaitMissionEnterReady()
	If Map_GetInstanceInfo("IsLoading") Or Party_GetPartyContextInfo("IsWaitingForMission") Then Return True
	Agent_CancelAction()
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < 4000
		If $g_b_LevelerPaused Then Return False
		If Map_GetInstanceInfo("IsLoading") Or Party_GetPartyContextInfo("IsWaitingForMission") Then Return True
		If Not Map_GetInstanceInfo("IsOutpost") Then Return True
		Sleep(250)
	WEnd
	Sleep(1500)
	Return True
EndFunc

Func Leveler_EnterMission($a_s_Name, $a_i_MapID)
	Local $l_i_StartMap = Map_GetMapID()
	If Leveler_InMissionInstance($a_i_MapID) Then
		Out("[Step] Already inside " & $a_s_Name & " (map " & $l_i_StartMap & ")")
		Return True
	EndIf

	; Engine already accepted Enter Challenge. Do not send it again.
	If Map_GetInstanceInfo("IsLoading") Or Party_GetPartyContextInfo("IsWaitingForMission") Then
		Out("[Step] Mission is already starting; waiting for the map to load")
		If Not Leveler_WaitMissionExplorable($a_i_MapID, $l_i_StartMap) Then Return False
		Sleep(2000)
		Return True
	EndIf

	If Not Map_GetInstanceInfo("IsOutpost") Then
		Out("[Step] Cannot enter " & $a_s_Name & " from map " & $l_i_StartMap & " " & Leveler_InstanceTypeName())
		Return False
	EndIf

	If Not Leveler_WaitMissionEnterReady() Then Return False
	If Leveler_InMissionInstance($a_i_MapID) Then Return True
	If Map_GetInstanceInfo("IsLoading") Or Party_GetPartyContextInfo("IsWaitingForMission") Then
		Out("[Step] Mission is already starting; waiting for the map to load")
		If Not Leveler_WaitMissionExplorable($a_i_MapID, $l_i_StartMap) Then Return False
		Sleep(2000)
		Return True
	EndIf

	Out("Let's do " & $a_s_Name)
	Out("[Step] Enter " & $a_s_Name & ": map " & $l_i_StartMap & " " & Leveler_InstanceTypeName() & ", hench " & Leveler_HenchmanCount() & ", waiting=" & Party_GetPartyContextInfo("IsWaitingForMission"))
	Out("Exiting Outpost")
	; Ui_EnterChallenge($a_b_Foreign, $a_b_WaitMapIsLoaded):
	; False = native character, True = foreign character.
	; Factions chars on Canthan missions (Cho, Zen Daijun) must use native enter.
	; Foreign enter (True) disconnects. WaitMapIsLoaded=False so this wait owns the load
	; and Map_WaitMapLoading cannot spam cinematic-skip during IsLoading.
	Ui_EnterChallenge(False, False)
	If Not Leveler_WaitMissionExplorable($a_i_MapID, $l_i_StartMap) Then
		Out("[Step] Mission map did not become explorable (map " & Map_GetMapID() & ", " & Leveler_InstanceTypeName() & ")")
		Return False
	EndIf
	Sleep(2000)
	Out("[Step] Mission instance loaded on map " & Map_GetMapID())
	Return True
EndFunc

#EndRegion Mission

#Region Combat

Func Leveler_PrepareCombatAI()
	$g_b_CombatMode = True
	Local $l_i_Map = Map_GetMapID()
	If $l_i_Map <> $g_i_LastUAIMap Then $g_b_UAIReady = False
	If Not Leveler_ShouldFightHere() Then
		$g_b_UAIReady = False
		Return True
	EndIf
	If $g_b_UAIReady And $g_i_LastUAIMap = $l_i_Map Then Return True
	If Not Leveler_CacheSkillBarNow() Then
		Out("[Combat] Cache_SkillBar failed on map " & $l_i_Map)
		Return False
	EndIf
	$g_i_LastUAIMap = $l_i_Map
	$g_b_UAIReady = True
	Out("[Combat] UtilityAI skill bar cached on map " & $l_i_Map)
	Return True
EndFunc

; After a map load the old instance cache is invalid. Wait until this map can fight, then recache.
Func Leveler_CacheUtilityAIForMap($a_i_MapID)
	$g_b_CombatMode = True
	$g_b_UAIReady = False
	$g_i_LastUAIMap = 0
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < 15000
		If $g_b_LevelerPaused Then Return False
		If Map_GetMapID() = $a_i_MapID And Not Map_GetInstanceInfo("IsLoading") And Leveler_ShouldFightHere() Then ExitLoop
		Sleep(200)
	WEnd
	If Map_GetMapID() <> $a_i_MapID Then
		Out("[Combat] Wanted map " & $a_i_MapID & " for UtilityAI, now " & Map_GetMapID())
		Return False
	EndIf
	If Not Leveler_ShouldFightHere() Then
		Out("[Combat] Map " & $a_i_MapID & " is not ready for UtilityAI yet")
		Return False
	EndIf
	If Not Leveler_CacheSkillBarNow() Then
		Out("[Combat] Cache_SkillBar failed on map " & $a_i_MapID)
		Return False
	EndIf
	$g_i_LastUAIMap = $a_i_MapID
	$g_b_UAIReady = True
	Out("[Combat] UtilityAI skill bar cached on map " & $a_i_MapID)
	Return True
EndFunc

; Fronis is a dungeon (instance type is not always Explorable). Cache anyway.
Func Leveler_CacheSkillBarNow()
	If Map_GetInstanceInfo("IsLoading") Then Return False
	If Map_GetInstanceInfo("IsExplorable") Then
		If Cache_SkillBar() Then Return True
	EndIf
	If Not Leveler_IsPunchoutMap() Then Return False
	UAI_CacheSkillBar()
	Local $i
	For $i = 1 To 8
		$g_as_BestTargetCache[$i] = UAI_GetBestTargetFunc($i)
		$g_as_CanUseCache[$i] = UAI_GetCanUseFunc($i)
	Next
	If $g_b_CacheWeaponSet Then UAI_DetermineWeaponSets()
	Return True
EndFunc

Func Leveler_ConfigureAggressiveEnv()
	Return Leveler_PrepareCombatAI()
EndFunc

Func Leveler_SetPacifist()
	$g_b_CombatMode = False
	Return True
EndFunc

#EndRegion Combat

#Region Skills

Func Leveler_SkillIsLearnt($a_i_SkillID)
	If World_IsSkillLearnt($a_i_SkillID) Then Return True
	Return Account_IsSkillUnlocked($a_i_SkillID)
EndFunc

Func Leveler_WaitSkillLearnt($a_i_SkillID)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < 8000
		If Leveler_SkillIsLearnt($a_i_SkillID) Then Return True
		Sleep(250)
	WEnd
	Return Leveler_SkillIsLearnt($a_i_SkillID)
EndFunc

; Skill_GetSkillbarInfo only accepts slots 1-8, not skill IDs.
Func Leveler_BarHasSkill($a_i_SkillID)
	Local $i
	For $i = 1 To 8
		If Skill_GetSkillbarInfo($i, "SkillID") = $a_i_SkillID Then Return True
	Next
	Return False
EndFunc

Func Leveler_PutSkillOnBar($a_i_Slot, $a_i_SkillID)
	If $a_i_SkillID = 0 Then Return True
	If Skill_GetSkillbarInfo($a_i_Slot, "SkillID") = $a_i_SkillID Then Return True
	If Not Leveler_WaitSkillLearnt($a_i_SkillID) Then
		Out("[Step] Skill " & $a_i_SkillID & " is not learnt yet")
		Return False
	EndIf
	Local $i
	For $i = 1 To 6
		If Skill_GetSkillbarInfo($a_i_Slot, "SkillID") = $a_i_SkillID Then Return True
		Skill_SetSkillbarSkill($a_i_Slot, $a_i_SkillID)
		Local $l_h_Timer = TimerInit()
		While TimerDiff($l_h_Timer) < 2000
			Sleep(200)
			If Skill_GetSkillbarInfo($a_i_Slot, "SkillID") = $a_i_SkillID Then
				Out("[Step] Slot " & $a_i_Slot & " = skill " & $a_i_SkillID)
				Return True
			EndIf
		WEnd
	Next
	Out("[Step] Slot " & $a_i_Slot & " is " & Skill_GetSkillbarInfo($a_i_Slot, "SkillID") & ", wanted " & $a_i_SkillID)
	Return False
EndFunc

Func Leveler_CloseTrainerWindow()
	Agent_CancelAction()
	Sleep(300)
	Local $l_f_X = Agent_GetAgentInfo(-2, "X")
	Local $l_f_Y = Agent_GetAgentInfo(-2, "Y")
	Map_Move($l_f_X + 80, $l_f_Y + 80, 20)
	Sleep(700)
	Agent_CancelAction()
	Sleep(200)
EndFunc

Func Leveler_TrainerSkillsOnBar()
	If Leveler_InterruptSkillsUnlocked() Then
		If Not Leveler_BarHasSkill($SKILL_CRY_OF_FRUSTRATION) Then Return False
		If Not Leveler_BarHasSkill($SKILL_POWER_DRAIN) Then Return False
		If Not Leveler_BarHasSkill($SKILL_SIGNET_OF_DISRUPTION) Then Return False
		Return True
	EndIf
	If Not Leveler_BarHasSkill($SKILL_SIGNET_OF_DISRUPTION) Then Return False
	If Not Leveler_BarHasSkill($SKILL_LEECH_SIGNET) Then Return False
	Return True
EndFunc

Func Leveler_BuySkillIfNeeded($a_i_SkillID)
	If World_IsSkillLearnt($a_i_SkillID) Then Return True
	Skill_BuySkillByID($a_i_SkillID)
	If Leveler_WaitSkillLearnt($a_i_SkillID) Then Return True
	Out("[Step] Could not learn skill " & $a_i_SkillID)
	Return False
EndFunc

; Monastery: SoD, Leech Signet, Energy Burn. Kaineng: Cry, Power Drain, SoD.
; $a_b_CloseTrainer False at Cho so we do not walk off Kayao.
Func Leveler_EquipTrainerSkills($a_b_CloseTrainer = True)
	$g_b_UAIReady = False
	If $a_b_CloseTrainer Then Leveler_CloseTrainerWindow()
	If Leveler_TrainerSkillsOnBar() Then
		Out("[Step] Trainer skills are already on the bar")
		Return True
	EndIf

	If Leveler_InterruptSkillsUnlocked() Then
		Local $l_i_Kind = Leveler_CurrentSkillBarKind()
		If $l_i_Kind = $LEVELER_BAR_STARTER Then $l_i_Kind = $LEVELER_BAR_INTERRUPT
		Leveler_LoadProfessionSkillBar($l_i_Kind)
		Sleep(600)
		If Leveler_TrainerSkillsOnBar() Then Return True
		Leveler_PutSkillOnBar(1, $SKILL_CRY_OF_FRUSTRATION)
		Leveler_PutSkillOnBar(2, $SKILL_POWER_DRAIN)
		Leveler_PutSkillOnBar(3, $SKILL_SIGNET_OF_DISRUPTION)
		If Leveler_TrainerSkillsOnBar() Then Return True
		Out("[Step] Interrupt skills are learnt but not all on the bar yet")
		Return False
	EndIf

	Local $l_i_Slot = 1
	If World_IsSkillLearnt($SKILL_SIGNET_OF_DISRUPTION) Then
		Leveler_PutSkillOnBar($l_i_Slot, $SKILL_SIGNET_OF_DISRUPTION)
		$l_i_Slot += 1
	EndIf
	If World_IsSkillLearnt($SKILL_LEECH_SIGNET) Then
		Leveler_PutSkillOnBar($l_i_Slot, $SKILL_LEECH_SIGNET)
		$l_i_Slot += 1
	EndIf
	If World_IsSkillLearnt($SKILL_ENERGY_BURN) Then Leveler_PutSkillOnBar($l_i_Slot, $SKILL_ENERGY_BURN)
	If Leveler_TrainerSkillsOnBar() Then Return True
	Out("[Step] Zhao Di skills are not all on the bar yet. Slots: " & Skill_GetSkillbarInfo(1, "SkillID") & ", " & Skill_GetSkillbarInfo(2, "SkillID") & ", " & Skill_GetSkillbarInfo(3, "SkillID"))
	Return False
EndFunc

Func Leveler_EquipSkillBar()
	If Not Map_GetInstanceInfo("IsOutpost") Then Return True
	If Leveler_InterruptSkillsUnlocked() Then
		Leveler_LoadProfessionSkillBar()
		If Not Leveler_TrainerSkillsOnBar() Then Leveler_EquipTrainerSkills()
		Return True
	EndIf
	If World_IsSkillLearnt($SKILL_BACKFIRE) Then Return Leveler_LoadZenSkillBar()
	If Leveler_ZhaoDiSkillsUnlocked() Then Return Leveler_EquipTrainerSkills()
	Leveler_LoadProfessionSkillBar($LEVELER_BAR_STARTER)
	Return True
EndFunc

#EndRegion Skills
