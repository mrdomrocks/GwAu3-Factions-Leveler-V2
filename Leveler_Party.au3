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

Func Leveler_NeedsVaettirPath()
	Local $l_i_Prof = Leveler_PrimaryProfession()
	Return $l_i_Prof = $GC_I_PROFESSION_ASSASSIN Or $l_i_Prof = $GC_I_PROFESSION_MESMER
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
	If $a_i_Map = $MAP_GUNNAR Or $a_i_Map = $MAP_LONGEYE Then
		Local $l_ai_Gunnar[3] = [4, 5, 6]
		Return $l_ai_Gunnar
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
		If Wine_IsWine() Then
			Wine_InviteHench($a_ai_Hench[$i])
		Else
			Party_AddNpc($a_ai_Hench[$i])
		EndIf
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

Func Leveler_AddHeroTeam()
	Local $l_ai_Heroes[4] = [$GC_I_HERO_ID_GWEN, $GC_I_HERO_ID_VEKK, $GC_I_HERO_ID_OGDEN_STONEHEALER, $GC_I_HERO_ID_MOX]
	Local $l_as_Bars[4] = [ _
			"OQhkAsC8gFKgGckjHFRUGCA", _
			"OgVDI8gsCawROeUEtZIA", _
			"OwUUMsG/E4GgMnZskzkIZQAA", _
			"OgCikys8wchuD4xb5VAAAAAA" _
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
	Out("[Party] Added Gwen, Vekk, Ogden, MOX")
	Return True
EndFunc

Func Leveler_PrepareHeroTeam($a_ai_Hench = 0)
	$g_b_CombatMode = True
	$g_b_UAIReady = False
	Leveler_EquipSkillBar()
	Party_LeaveGroup(True)
	Sleep(400)
	Leveler_AddHeroTeam()
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

Func Leveler_PrepareMissionParty($a_i_Map = 0)
	$g_b_CombatMode = True
	; Mid-mission (246 or Togo+Vhang) cannot add henches. Outpost 213 only.
	If Wine_IsWine() And Leveler_WineHeldZenExplorable() Then
		Out("[Party] Wine: already in Zen; not inviting henches")
		Return True
	EndIf
	If $a_i_Map = 0 Then $a_i_Map = Map_GetMapID()
	If Wine_IsWine() And Leveler_WineAtZenOutpost() Then $a_i_Map = $MAP_ZEN_OP
	Local $l_ai_Want = Leveler_HenchmenForMap($a_i_Map)
	Local $l_i_Want = UBound($l_ai_Want)
	If Leveler_HenchmanCount() < $l_i_Want Then
		; Do not LeaveGroup here. Kick + Enter Mission disconnects.
		Out("[Party] Inviting mission henchmen for map " & $a_i_Map)
		Leveler_AddHenchmanList($l_ai_Want)
		Local $l_h_Timer = TimerInit()
		While TimerDiff($l_h_Timer) < 5000
			If Leveler_HenchmanCount() >= $l_i_Want Then ExitLoop
			Sleep(250)
		WEnd
		Out("[Party] Henchmen in party: " & Leveler_HenchmanCount() & "/" & $l_i_Want)
	Else
		Out("[Party] Mission henchmen already in the party")
		Out("[Party] Henchmen in party: " & Leveler_HenchmanCount() & "/" & $l_i_Want)
	EndIf
	Sleep(1500)
	Return True
EndFunc

#EndRegion Party

#Region Mission

; g_p_InstanceInfo=0 reads Type=0, which the API treats as outpost. Do not
; trust that when the pointer is dead.
Func Leveler_InstanceInfoTrusted()
	If Not IsDeclared("g_p_InstanceInfo") Then Return False
	If Wine_IsWine() Then
		If Not Wine_IsUserPtr($g_p_InstanceInfo) Then Return False
	ElseIf Number($g_p_InstanceInfo) = 0 Then
		Return False
	EndIf
	Local $l_i_Type = Number(Map_GetInstanceInfo("Type"))
	If $l_i_Type < 0 Or $l_i_Type > 2 Then Return False
	Return True
EndFunc

; CharacterContext CurrentMapID is the real instance (246 in Zen) even when
; Map_GetMapID stays on the outpost id (213).
Func Leveler_LiveMapID()
	Local $l_i_Cur = Number(Map_GetCharacterInfo("CurrentMapID"))
	If $l_i_Cur > 0 Then Return $l_i_Cur
	Return Map_GetMapID()
EndFunc

Func Leveler_HasMissionObjectives()
	Return Number(World_GetWorldInfo("MissionObjectiveArraySize")) > 0
EndFunc

; Master Togo / Vhang are mission allies, not hired hench. Hench count is 0 in Zen.
; Wine often leaves Agent Name empty (26a90ef logged agent-togo-rt, not "Togo").
; Loose scan is for wipe / town Togo. Held-Zen uses Leveler_FindZenMissionTogoAgent.
Func Leveler_FindLivingZenTogoAgent()
	If Not Leveler_AgentMemoryLive() Then Return 0
	Local $l_i_Me = Number(Agent_GetMyID())
	Local $l_i_Max = Agent_GetMaxAgents()
	Local $i
	For $i = 1 To $l_i_Max - 1
		If $l_i_Me <> 0 And Number($i) = $l_i_Me Then ContinueLoop
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
		Local $l_s_Name = String(Agent_GetAgentInfo($i, "Name"))
		Local $l_i_Model = Number(Agent_GetAgentInfo($i, "PlayerNumber"))
		If Leveler_IsTogoModel($l_i_Model) Then Return $i
		If StringInStr($l_s_Name, "Togo") Then Return $i
		If StringInStr($l_s_Name, "Vhang") Then ContinueLoop
		Local $l_i_Lvl = Number(Agent_GetAgentInfo($i, "Level"))
		Local $l_i_Prof = Number(Agent_GetAgentInfo($i, "Primary"))
		Local $l_i_All = Number(Agent_GetAgentInfo($i, "Allegiance"))
		If $l_i_Lvl >= 16 And $l_i_Prof = $GC_I_PROFESSION_RITUALIST Then
			If $l_i_All = $GC_I_ALLEGIANCE_NPC Or $l_i_All = $GC_I_ALLEGIANCE_ALLY Then Return $i
		EndIf
	Next
	Return 0
EndFunc

; Mission Togo is Rt20. Do not return the outpost Togo model or a random lv16 Ritualist.
Func Leveler_FindZenMissionTogoAgent()
	If Not Leveler_AgentMemoryLive() Then Return 0
	Local $l_i_Me = Number(Agent_GetMyID())
	Local $l_i_Max = Agent_GetMaxAgents()
	Local $i
	For $i = 1 To $l_i_Max - 1
		If $l_i_Me <> 0 And Number($i) = $l_i_Me Then ContinueLoop
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
		Local $l_s_Name = String(Agent_GetAgentInfo($i, "Name"))
		Local $l_i_Model = Number(Agent_GetAgentInfo($i, "PlayerNumber"))
		Local $l_i_Lvl = Number(Agent_GetAgentInfo($i, "Level"))
		Local $l_i_Prof = Number(Agent_GetAgentInfo($i, "Primary"))
		If StringInStr($l_s_Name, "Vhang") Then ContinueLoop
		If StringInStr($l_s_Name, "Togo") Or Leveler_IsTogoModel($l_i_Model) Then
			If $l_i_Lvl >= 19 Then Return $i
			ContinueLoop
		EndIf
		If $l_i_Lvl = 20 And $l_i_Prof = $GC_I_PROFESSION_RITUALIST Then Return $i
	Next
	Return 0
EndFunc

; Headmaster Vhang is E15. Outpost false-positive was lv16 Elementalist (all=1).
Func Leveler_FindLivingZenVhangAgent()
	If Not Leveler_AgentMemoryLive() Then Return 0
	Local $l_i_Me = Number(Agent_GetMyID())
	Local $l_i_Max = Agent_GetMaxAgents()
	Local $i
	For $i = 1 To $l_i_Max - 1
		If $l_i_Me <> 0 And Number($i) = $l_i_Me Then ContinueLoop
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
		Local $l_s_Name = String(Agent_GetAgentInfo($i, "Name"))
		Local $l_i_Lvl = Number(Agent_GetAgentInfo($i, "Level"))
		Local $l_i_Prof = Number(Agent_GetAgentInfo($i, "Primary"))
		If StringInStr($l_s_Name, "Vhang") Then
			If $l_i_Lvl = 0 Or ($l_i_Lvl >= 14 And $l_i_Lvl <= 15) Then Return $i
			ContinueLoop
		EndIf
		If StringInStr($l_s_Name, "Togo") Then ContinueLoop
		If Leveler_IsTogoModel(Number(Agent_GetAgentInfo($i, "PlayerNumber"))) Then ContinueLoop
		If $l_i_Lvl >= 14 And $l_i_Lvl <= 15 And $l_i_Prof = $GC_I_PROFESSION_ELEMENTALIST Then Return $i
	Next
	Return 0
EndFunc

Func Leveler_PartyOthersContains($a_i_Agent)
	If $a_i_Agent = 0 Then Return False
	Local $l_p_Others = Party_GetMyPartyInfo("ArrayOthersPartyMember")
	Local $l_i_Size = Number(Party_GetMyPartyInfo("ArrayOthersPartyMemberSize"))
	If $l_p_Others = 0 Or $l_i_Size <= 0 Then Return False
	If $l_i_Size > 32 Then $l_i_Size = 32
	Local $i
	For $i = 0 To $l_i_Size - 1
		If Number(Memory_Read($l_p_Others + ($i * 4), "dword")) = Number($a_i_Agent) Then Return True
	Next
	Return False
EndFunc

Func Leveler_WineZenAllyAgentBrief($a_i_Agent)
	If $a_i_Agent = 0 Then Return "0"
	Local $l_s_Name = String(Agent_GetAgentInfo($a_i_Agent, "Name"))
	If $l_s_Name = "" Then $l_s_Name = "-"
	Return $a_i_Agent & " lv=" & Number(Agent_GetAgentInfo($a_i_Agent, "Level")) & _
			" prof=" & Number(Agent_GetAgentInfo($a_i_Agent, "Primary")) & _
			" all=" & Number(Agent_GetAgentInfo($a_i_Agent, "Allegiance")) & _
			" name=" & $l_s_Name
EndFunc

Func Leveler_WineZenAllyScanText()
	Local $l_i_Togo = Leveler_FindZenMissionTogoAgent()
	Local $l_i_Vhang = Leveler_FindLivingZenVhangAgent()
	Local $l_i_Others = Number(Party_GetMyPartyInfo("ArrayOthersPartyMemberSize"))
	Local $l_i_Hench = Leveler_HenchmanCount()
	Return "togo=" & Leveler_WineZenAllyAgentBrief($l_i_Togo) & " vhang=" & Leveler_WineZenAllyAgentBrief($l_i_Vhang) & _
			" others=" & $l_i_Others & " hench=" & $l_i_Hench
EndFunc

; Party 1/6 at the outpost: no henches, no mission Others. World NPCs must not count.
Func Leveler_WineZenSoloParty()
	If Leveler_HenchmanCount() > 0 Then Return False
	If Number(Party_GetMyPartyInfo("ArrayOthersPartyMemberSize")) > 0 Then Return False
	If Number(Party_GetPartyContextInfo("OtherCount")) > 0 Then Return False
	Return True
EndFunc

; True only for real mission Togo (Rt20) + Vhang (E14-15).
; lv16 Rt + lv16 E with Allegiance=1 at outpost 213 is NOT in-mission (54e2209).
; Party 1/6 (others=0) is never in-mission unless those exact mission levels are live
; (Wine ArrayOthers can stay 0 while Togo20+Vhang15 are in the party UI).
Func Leveler_WineZenPartyAlliesTogether()
	If Not Wine_IsWine() Then Return False
	If $g_b_ZenAllyCache And $g_h_ZenAllyCacheAt <> 0 And TimerDiff($g_h_ZenAllyCacheAt) < 400 Then
		$g_s_ZenAllyDetect = $g_s_ZenAllyCacheDetect
		Return True
	EndIf
	If Not Leveler_AgentMemoryLive() Then Return False
	Local $l_i_Togo = Leveler_FindZenMissionTogoAgent()
	If $l_i_Togo = 0 Then Return False
	Local $l_i_Vhang = Leveler_FindLivingZenVhangAgent()
	If $l_i_Vhang = 0 Or $l_i_Vhang = $l_i_Togo Then Return False
	Local $l_i_TogoLvl = Number(Agent_GetAgentInfo($l_i_Togo, "Level"))
	Local $l_i_VhangLvl = Number(Agent_GetAgentInfo($l_i_Vhang, "Level"))
	Local $l_i_TogoProf = Number(Agent_GetAgentInfo($l_i_Togo, "Primary"))
	Local $l_i_VhangProf = Number(Agent_GetAgentInfo($l_i_Vhang, "Primary"))
	Local $l_s_Togo = String(Agent_GetAgentInfo($l_i_Togo, "Name"))
	Local $l_s_Vhang = String(Agent_GetAgentInfo($l_i_Vhang, "Name"))
	Local $l_b_Named = StringInStr($l_s_Togo, "Togo") And StringInStr($l_s_Vhang, "Vhang")
	Local $l_b_Levels = ($l_i_TogoLvl = 20 And $l_i_TogoProf = $GC_I_PROFESSION_RITUALIST And _
			$l_i_VhangLvl >= 14 And $l_i_VhangLvl <= 15 And $l_i_VhangProf = $GC_I_PROFESSION_ELEMENTALIST)
	Local $l_b_TogoOther = Leveler_PartyOthersContains($l_i_Togo)
	Local $l_b_VhangOther = Leveler_PartyOthersContains($l_i_Vhang)
	; Exact mission levels: in-mission even if ArrayOthers is 0 (lying map 213).
	If $l_b_Levels Then
		If $l_b_TogoOther And $l_b_VhangOther Then
			$g_s_ZenAllyDetect = "togo+vhang-party"
		ElseIf $l_b_Named Then
			$g_s_ZenAllyDetect = "togo+vhang"
		Else
			$g_s_ZenAllyDetect = "togo+vhang-lv"
		EndIf
		$g_h_ZenAllyCacheAt = TimerInit()
		$g_b_ZenAllyCache = True
		$g_s_ZenAllyCacheDetect = $g_s_ZenAllyDetect
		Return True
	EndIf
	; Names / party list without Rt20+E15: never at outpost party 1/6.
	If Leveler_WineZenSoloParty() Then Return False
	If $l_b_TogoOther And $l_b_VhangOther Then
		$g_s_ZenAllyDetect = "togo+vhang-party"
	ElseIf $l_b_Named Then
		$g_s_ZenAllyDetect = "togo+vhang"
	Else
		Return False
	EndIf
	$g_h_ZenAllyCacheAt = TimerInit()
	$g_b_ZenAllyCache = True
	$g_s_ZenAllyCacheDetect = $g_s_ZenAllyDetect
	Return True
EndFunc

Func Leveler_WineLogZenAllyScan($a_s_Why)
	If $g_h_ZenAllyLogAt <> 0 And TimerDiff($g_h_ZenAllyLogAt) < 3000 Then Return
	$g_h_ZenAllyLogAt = TimerInit()
	Out("Wine: Zen ally scan (" & $a_s_Why & "): " & Leveler_WineZenAllyScanText())
EndFunc

Func Leveler_PartyHasZenMissionAllies()
	$g_s_ZenAllyDetect = ""
	If Leveler_WineZenPartyAlliesTogether() Then Return True
	Local $l_i_Hench = Leveler_HenchmanCount()
	Local $l_i_High = 0
	Local $l_i_HighRt = 0
	Local $i = 1
	For $i = 1 To $l_i_Hench
		Local $l_i_Lvl = Number(Party_GetMyPartyHenchmanInfo($i, "Level"))
		Local $l_i_Prof = Number(Party_GetMyPartyHenchmanInfo($i, "Profession"))
		If $l_i_Lvl >= 16 Then
			$l_i_High += 1
			If $l_i_Prof = $GC_I_PROFESSION_RITUALIST Then $l_i_HighRt += 1
		EndIf
	Next
	If $l_i_High >= 1 And $l_i_HighRt >= 1 Then
		$g_s_ZenAllyDetect = "hench"
		Return True
	EndIf
	Local $l_i_Togo = Leveler_FindLivingZenTogoAgent()
	If $l_i_Togo <> 0 Then
		Local $l_s_Name = String(Agent_GetAgentInfo($l_i_Togo, "Name"))
		Local $l_i_Prof = Number(Agent_GetAgentInfo($l_i_Togo, "Primary"))
		If $l_i_Prof = $GC_I_PROFESSION_RITUALIST Then
			$g_s_ZenAllyDetect = "agent-togo-rt"
		ElseIf StringInStr($l_s_Name, "Togo") Then
			$g_s_ZenAllyDetect = "agent-togo"
		Else
			$g_s_ZenAllyDetect = "agent-ally"
		EndIf
		Return True
	EndIf
	Return False
EndFunc

; Wine: AgentBase live, not dead, not the Pos 0,0 attach gap.
Func Leveler_WinePlayerClearlyAlive()
	If Not Wine_IsWine() Then Return False
	If Not Leveler_AgentMemoryLive() Then Return False
	If Agent_GetAgentInfo(-2, "IsDead") Then Return False
	If Agent_GetAgentInfo(-2, "X") = 0 And Agent_GetAgentInfo(-2, "Y") = 0 Then Return False
	Return True
EndFunc

; Connecting / loading (Type 2). Do not treat as in-mission or ready.
Func Leveler_MapLooksConnecting()
	If Map_GetMapID() <= 0 Then Return True
	If Leveler_InstanceInfoTrusted() And Map_GetInstanceInfo("IsLoading") Then Return True
	If Number(Map_GetCharacterInfo("CurrentMapType")) = 2 Then Return True
	Return False
EndFunc

; Held Zen instance: prefer map/CurrentMapID 246. Togo+Vhang party allies
; (Rt20 + E15, in party Others — not lv16 world NPCs) cover lying 213.
Func Leveler_WineHeldZenExplorable()
	If Leveler_MapLooksConnecting() Then
		If Leveler_WineZenPartyAlliesTogether() Then Return True
		Return False
	EndIf
	Local $l_i_Map = Map_GetMapID()
	Local $l_i_Cur = Number(Map_GetCharacterInfo("CurrentMapID"))
	If $l_i_Map = $MAP_ZEN_EXP Or $l_i_Cur = $MAP_ZEN_EXP Then Return True
	Return Leveler_WineZenPartyAlliesTogether()
EndFunc

Func Leveler_WineLooksInZenMission()
	Return Leveler_WineHeldZenExplorable()
EndFunc

; Wine: sitting at Zen 213 and not actually in the instance (no 246, no
; Togo+Vhang allies). InstanceInfo IsOutpost/IsExplorable flicker must not
; count as explorable. Outpost Togo NPC is not proof of the mission.
Func Leveler_WineAtZenOutpost()
	If Not Wine_IsWine() Then Return False
	If Leveler_WineHeldZenExplorable() Then Return False
	If Leveler_MapLooksConnecting() Then Return False
	Local $l_i_Map = Map_GetMapID()
	Local $l_i_Cur = Number(Map_GetCharacterInfo("CurrentMapID"))
	Return $l_i_Map = $MAP_ZEN_OP Or $l_i_Cur = $MAP_ZEN_OP
EndFunc

Func Leveler_InMissionInstance($a_i_MapID = 0)
	; Wine: Togo+Vhang party allies are the instance even if Type flickers 2
	; and Map_GetMapID / CurrentMapID stay 213.
	If Wine_IsWine() And Leveler_WineZenPartyAlliesTogether() Then Return True
	If Leveler_MapLooksConnecting() Then Return False
	If Map_GetInstanceInfo("IsLoading") And Leveler_InstanceInfoTrusted() Then Return False

	Local $l_i_Map = Map_GetMapID()
	Local $l_i_Cur = Number(Map_GetCharacterInfo("CurrentMapID"))
	If $l_i_Cur = $MAP_ZEN_EXP Or $l_i_Map = $MAP_ZEN_EXP Then Return True
	If $l_i_Cur = $MAP_CHO_EXPLORABLE Or $l_i_Map = $MAP_CHO_EXPLORABLE Then Return True

	; Wine: outpost 213 + Togo NPC alone is the outpost, not the mission.
	If Wine_IsWine() Then Return False

	If Leveler_WineLooksInZenMission() Then Return True

	If Not Leveler_InstanceInfoTrusted() Then Return False
	If Map_GetInstanceInfo("IsOutpost") Then Return False
	If Not Map_GetInstanceInfo("IsExplorable") Then Return False
	If $a_i_MapID <> 0 And $l_i_Map = $a_i_MapID Then Return True
	If $l_i_Map = $MAP_ZEN_EXP Then Return True
	If $l_i_Map = $MAP_CHO_EXPLORABLE Then Return True
	Return False
EndFunc

Func Leveler_WaitMissionExplorable($a_i_MapID, $a_i_StartMap, $a_i_Timeout = 45000)
	If Leveler_InMissionInstance($a_i_MapID) Then Return True
	If Map_WaitMapLoading($a_i_StartMap, 1, $a_i_Timeout) Then Return True
	If Leveler_InMissionInstance($a_i_MapID) Then Return True
	If Map_GetInstanceInfo("IsExplorable") Then
		Local $l_i_Map = Map_GetMapID()
		If $l_i_Map = $a_i_StartMap Or $l_i_Map = $a_i_MapID Then Return True
	EndIf
	Return False
EndFunc

Func Leveler_EnterMission($a_s_Name, $a_i_MapID)
	Local $l_i_StartMap = Map_GetMapID()
	Local $l_s_Detect = ""
	If Wine_IsWine() And $g_s_ZenAllyDetect <> "" Then $l_s_Detect = ", " & $g_s_ZenAllyDetect
	If Leveler_InMissionInstance($a_i_MapID) Then
		If Wine_IsWine() Then $g_b_WineEnterSent = True
		Out("[Step] Already inside " & $a_s_Name & " (map " & $l_i_StartMap & _
				" current " & Leveler_LiveMapID() & $l_s_Detect & ")")
		Return True
	EndIf

	; Engine already accepted Enter Challenge. Do not send it again.
	; Wine: IsWaitingForMission / Type flicker is not proof — require 246 or Togo+Vhang.
	If Wine_IsWine() Then
		If Wine_EnterMapEvidence($l_i_StartMap) Then
			Out("[Step] Already inside " & $a_s_Name & " (map " & Map_GetMapID() & " current " & Leveler_LiveMapID() & $l_s_Detect & ")")
			$g_b_WineEnterSent = True
			Return True
		EndIf
	ElseIf (Map_GetInstanceInfo("IsLoading") And Leveler_InstanceInfoTrusted()) Or Party_GetPartyContextInfo("IsWaitingForMission") Then
		Out("[Step] Mission is already starting; waiting for the map to load")
		If Not Leveler_WaitMissionExplorable($a_i_MapID, $l_i_StartMap) Then Return False
		Sleep(2000)
		Return True
	EndIf

	Local $l_b_Outpost = Map_GetInstanceInfo("IsOutpost") And Leveler_InstanceInfoTrusted()
	If Leveler_WineAtZenOutpost() Then $l_b_Outpost = True
	If Not $l_b_Outpost Then
		If Leveler_InstanceInfoTrusted() Or Not ($l_i_StartMap = $MAP_ZEN_OP Or $l_i_StartMap = $MAP_CHO_OUTPOST) Then
			Out("[Step] Cannot enter " & $a_s_Name & " from map " & $l_i_StartMap & " type " & Map_GetInstanceInfo("Type"))
			Return False
		EndIf
	EndIf

	Out("Let's do " & $a_s_Name)
	Out("Exiting Outpost")
	If Wine_IsWine() Then
		If Not Wine_EnterChallenge() Then
			Out("[Step] Cannot enter " & $a_s_Name & ": Enter Mission click did not start a load.")
			Return False
		EndIf
		If Not Leveler_WaitWineMission($a_i_MapID, $l_i_StartMap) Then
			Out("[Step] Mission map did not become explorable (map " & Map_GetMapID() & ", type " & Map_GetInstanceInfo("Type") & ")")
			Return False
		EndIf
	Else
		; Arborstone enter. False = EnterMission(1) and instant-DCs on this client.
		Ui_EnterChallenge(True)
		If Not Map_WaitMapLoading($l_i_StartMap, 1) Then
			If Not Leveler_WaitMissionExplorable($a_i_MapID, $l_i_StartMap) Then
				Out("[Step] Mission map did not become explorable (map " & Map_GetMapID() & ", type " & Map_GetInstanceInfo("Type") & ")")
				Return False
			EndIf
		EndIf
	EndIf
	Sleep(2000)
	Out("[Step] Mission instance loaded on map " & Map_GetMapID())
	$g_i_ZenEscortWp = 0
	If Wine_IsWine() And Not Leveler_WaitWineWorldSettled() Then Return False
	Return True
EndFunc

; After held 246 / Togo+Vhang: wait out the load before skill bar, queue refresh, or Move.
Func Leveler_WaitWineWorldSettled($a_i_Timeout = 25000)
	If Not Wine_IsWine() Then Return True
	; Mid-mission Start: already on 246 or Togo+Vhang allies. Do not block the GUI.
	If Leveler_WineHeldZenExplorable() Then
		Out("[Step] Wine: already in Zen (map " & Map_GetMapID() & " current " & Leveler_LiveMapID() & _
				"); skip settle wait")
		Return True
	EndIf
	Out("[Step] Wine: waiting for the mission world to settle before skill bar / queue / move")
	Local $l_h_Timer = TimerInit()
	Local $l_h_Held = 0
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Wine_MapIsLoading() Or Leveler_MapLooksConnecting() Then
			$l_h_Held = 0
			Sleep(250)
			ContinueLoop
		EndIf
		If Leveler_WineHeldZenExplorable() Then
			If $l_h_Held = 0 Then $l_h_Held = TimerInit()
			If TimerDiff($l_h_Held) >= 2500 Then
				Sleep(1500)
				Out("[Step] Wine: world settled (map " & Map_GetMapID() & " current " & Leveler_LiveMapID() & ")")
				Return True
			EndIf
		Else
			$l_h_Held = 0
		EndIf
		Sleep(250)
	WEnd
	If Leveler_WineHeldZenExplorable() And Not Wine_MapIsLoading() Then
		Out("[Step] Wine: world settle timed out but the instance is up (map " & Map_GetMapID() & ")")
		Return True
	EndIf
	Out("[Step] Wine: world did not settle (map " & Map_GetMapID() & " current " & Leveler_LiveMapID() & ")")
	Return False
EndFunc

; Wine has no LoadFinished hook, so Map_WaitMapIsLoaded never completes.
; Type 2 is LOADING — keep waiting. Wine success is map/CurrentMapID 246 or
; Togo+Vhang party allies, not Type=explorable flicker or Togo NPC on 213.
Func Leveler_WaitWineMission($a_i_MapID, $a_i_StartMap, $a_i_Timeout = 60000)
	Local $l_h_Timer = TimerInit()
	Local $l_b_SawLoad = False
	Local $l_i_ZeroHits = 0
	Local $l_i_LastLog = -5000
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		Local $l_i_Map = Map_GetMapID()
		Local $l_i_Type = Number(Map_GetInstanceInfo("Type"))
		If TimerDiff($l_h_Timer) - $l_i_LastLog >= 5000 Then
			Out("[Step] Mission map id=" & $l_i_Map & ", current " & Leveler_LiveMapID() & _
					", type " & $l_i_Type & ", objectives " & Number(World_GetWorldInfo("MissionObjectiveArraySize")))
			$l_i_LastLog = TimerDiff($l_h_Timer)
		EndIf
		If $l_i_Map <= 0 Then
			$l_i_ZeroHits += 1
			If $l_i_ZeroHits >= 5 Then
				Out("[Step] Client left the world (map " & $l_i_Map & "). Enter dumped to character select.")
				Return False
			EndIf
			Sleep(250)
			ContinueLoop
		EndIf
		$l_i_ZeroHits = 0
		If $l_i_Type = $GC_I_MAP_TYPE_LOADING Then
			If Not $l_b_SawLoad Then
				Out("[Step] Mission is loading (map " & $l_i_Map & ", type 2)")
				$l_b_SawLoad = True
			EndIf
			Sleep(250)
			ContinueLoop
		EndIf
		If Leveler_InMissionInstance($a_i_MapID) Then
			Out("[Step] Mission instance confirmed (map " & $l_i_Map & " current " & Leveler_LiveMapID() & ")")
			Return True
		EndIf
		; Wine: Type=explorable on outpost 213 is a flicker. Require 246 or Togo+Vhang.
		If Wine_IsWine() Then
			If Wine_EnterMapEvidence($a_i_StartMap) Then
				Out("[Step] Mission instance confirmed (map " & $l_i_Map & " current " & Leveler_LiveMapID() & ")")
				Return True
			EndIf
		ElseIf $l_i_Type = $GC_I_MAP_TYPE_EXPLORABLE Then
			If $l_i_Map = $a_i_MapID Or $l_i_Map = $a_i_StartMap Or $l_i_Map = $MAP_ZEN_EXP Then
				Out("[Step] Mission explorable on map " & $l_i_Map)
				Return True
			EndIf
		EndIf
		If $l_b_SawLoad And Leveler_InstanceInfoTrusted() And $l_i_Type = $GC_I_MAP_TYPE_OUTPOST And TimerDiff($l_h_Timer) > 8000 Then
			Out("[Step] Loading bounced back to outpost map " & $l_i_Map)
			Return False
		EndIf
		Sleep(250)
	WEnd
	Return False
EndFunc

#EndRegion Mission

#Region Combat

Func Leveler_PrepareCombatAI()
	$g_b_CombatMode = True
	Local $l_i_Map = Map_GetMapID()
	If $l_i_Map <> $g_i_LastUAIMap Then $g_b_UAIReady = False

	Local $l_b_InWorld = Leveler_InMissionInstance() Or Map_GetInstanceInfo("IsExplorable")
	If Wine_IsWine() And Leveler_WineHeldZenExplorable() Then $l_b_InWorld = True
	If Not $l_b_InWorld Then
		$g_b_UAIReady = False
		Return True
	EndIf
	If $g_b_UAIReady And $g_i_LastUAIMap = $l_i_Map Then Return True

	If Wine_IsWine() Then Return Leveler_WineCacheSkillBar()

	If Not Cache_SkillBar() Then
		Out("[Combat] Cache_SkillBar failed on map " & $l_i_Map)
		Return False
	EndIf
	$g_i_LastUAIMap = $l_i_Map
	$g_b_UAIReady = True
	Out("[Combat] UtilityAI skill bar cached on map " & $l_i_Map)
	Return True
EndFunc

; Stock Cache_SkillBar returns False when InstanceInfo Type is not 1.
; Wine Type often stays 0 inside Zen (held 246 or Togo+Vhang). Cache anyway.
Func Leveler_WineCacheSkillBarForced()
	UAI_CacheSkillBar()
	Local $i
	For $i = 1 To 8
		$g_as_BestTargetCache[$i] = UAI_GetBestTargetFunc($i)
		$g_as_CanUseCache[$i] = UAI_GetCanUseFunc($i)
	Next
	If $g_b_CacheWeaponSet Then UAI_DetermineWeaponSets()
	Return True
EndFunc

Func Leveler_WineCacheSkillBarMarkOk($a_i_Map, $a_s_Extra = "")
	$g_i_LastUAIMap = $a_i_Map
	$g_b_UAIReady = True
	$g_h_WineUAICacheAt = 0
	Out("[Combat] UtilityAI skill bar cached on map " & $a_i_Map & _
			" current " & Leveler_LiveMapID() & $a_s_Extra)
	Return True
EndFunc

Func Leveler_WineCacheSkillBar()
	Local $l_i_Map = Map_GetMapID()
	If Cache_SkillBar() Then Return Leveler_WineCacheSkillBarMarkOk($l_i_Map)

	Local $l_b_First = ($g_h_WineUAICacheAt = 0)
	If $l_b_First Then
		Local $l_h_Retry = TimerInit()
		While TimerDiff($l_h_Retry) < 2500
			If $g_b_LevelerPaused Then Return False
			Sleep(350)
			If Cache_SkillBar() Then Return Leveler_WineCacheSkillBarMarkOk($l_i_Map)
		WEnd
	ElseIf TimerDiff($g_h_WineUAICacheAt) < 4000 Then
		Return True
	EndIf

	If Leveler_WineHeldZenExplorable() Or Leveler_InMissionInstance() Then
		If Leveler_WineCacheSkillBarForced() Then
			Return Leveler_WineCacheSkillBarMarkOk($l_i_Map, " (Type=" & Number(Map_GetInstanceInfo("Type")) & ")")
		EndIf
	EndIf

	$g_h_WineUAICacheAt = TimerInit()
	Out("[Combat] Cache_SkillBar failed on map " & $l_i_Map & " Type=" & Number(Map_GetInstanceInfo("Type")) & _
			"; will retry during escort")
	$g_b_UAIReady = False
	Return True
EndFunc

; After a map load the old instance cache is invalid. Wait until this map is explorable, then recache.
Func Leveler_CacheUtilityAIForMap($a_i_MapID)
	$g_b_CombatMode = True
	$g_b_UAIReady = False
	$g_i_LastUAIMap = 0
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < 15000
		If $g_b_LevelerPaused Then Return False
		If Map_GetMapID() = $a_i_MapID And Map_GetInstanceInfo("IsExplorable") And Not Map_GetInstanceInfo("IsLoading") Then ExitLoop
		Sleep(200)
	WEnd
	If Map_GetMapID() <> $a_i_MapID Then
		Out("[Combat] Wanted map " & $a_i_MapID & " for UtilityAI, now " & Map_GetMapID())
		Return False
	EndIf
	If Wine_IsWine() And (Leveler_WineHeldZenExplorable() Or Leveler_InMissionInstance()) Then
		Return Leveler_WineCacheSkillBar()
	EndIf
	If Not Map_GetInstanceInfo("IsExplorable") Then
		Out("[Combat] Map " & $a_i_MapID & " is not explorable yet")
		Return False
	EndIf
	If Not Cache_SkillBar() Then
		Out("[Combat] Cache_SkillBar failed on map " & $a_i_MapID)
		Return False
	EndIf
	$g_i_LastUAIMap = $a_i_MapID
	$g_b_UAIReady = True
	Out("[Combat] UtilityAI skill bar cached on map " & $a_i_MapID)
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
		If World_IsSkillLearnt($a_i_SkillID) Then Return True
		Sleep(250)
	WEnd
	Return World_IsSkillLearnt($a_i_SkillID)
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
	If Wine_IsWine() Then Wine_BuySkill($a_i_SkillID)
	If Leveler_WaitSkillLearnt($a_i_SkillID) Then
		Out("[Step] Learnt skill " & $a_i_SkillID)
		Return True
	EndIf
	Out("[Step] Could not learn skill " & $a_i_SkillID)
	Return False
EndFunc

Func Leveler_LogMissingTrainerSkills()
	Out("[Step] Trainer skills learnt: SoD=" & Number(World_IsSkillLearnt($SKILL_SIGNET_OF_DISRUPTION)) & _
			" Leech=" & Number(World_IsSkillLearnt($SKILL_LEECH_SIGNET)) & _
			" Burn=" & Number(World_IsSkillLearnt($SKILL_ENERGY_BURN)) & _
			" Cry=" & Number(World_IsSkillLearnt($SKILL_CRY_OF_FRUSTRATION)) & _
			" Drain=" & Number(World_IsSkillLearnt($SKILL_POWER_DRAIN)) & _
			" Backfire=" & Number(World_IsSkillLearnt($SKILL_BACKFIRE)))
EndFunc

Func Leveler_BuyMissingTrainerSkills()
	Local $l_f_X = 0
	Local $l_f_Y = 0
	Local $l_i_Npc = 0
	If Map_GetMapID() = $MAP_KAINENG Then
		Out("[Step] Walk to Michiko npc id " & $MODEL_MICHIKO & " at " & Round($MICHIKO_X) & "," & Round($MICHIKO_Y))
		$l_f_X = $MICHIKO_X
		$l_f_Y = $MICHIKO_Y
		$l_i_Npc = Leveler_FindMichikoAgent()
	ElseIf Map_GetMapID() = $MAP_SHING_JEA Then
		$l_f_X = $ZHAO_DI_X
		$l_f_Y = $ZHAO_DI_Y
		$l_i_Npc = Leveler_FindSkillTrainerAgent()
	Else
		$l_i_Npc = Leveler_FindSkillTrainerAgent()
		If $l_i_Npc = 0 Then Return False
		$l_f_X = Agent_GetAgentInfo($l_i_Npc, "X")
		$l_f_Y = Agent_GetAgentInfo($l_i_Npc, "Y")
	EndIf
	Local $l_i_Model = 0
	If Map_GetMapID() = $MAP_KAINENG Then
		$l_i_Model = $MODEL_MICHIKO
	ElseIf $l_i_Npc <> 0 Then
		$l_i_Model = Agent_GetAgentInfo($l_i_Npc, "PlayerNumber")
	EndIf
	If Not Leveler_MoveAndDialog($l_f_X, $l_f_Y, $DIALOG_GENERIC_TALK, False, $l_i_Model) Then
		If $l_i_Npc = 0 Then $l_i_Npc = Leveler_GetNearestNPCAt($l_f_X, $l_f_Y, 500)
		If $l_i_Npc = 0 Then Return False
		If Not Leveler_TalkAndDialog($l_i_Npc, $DIALOG_GENERIC_TALK) Then Return False
	EndIf
	Sleep(2500)
	Leveler_BuySkillIfNeeded($SKILL_SIGNET_OF_DISRUPTION)
	Sleep(400)
	Leveler_BuySkillIfNeeded($SKILL_LEECH_SIGNET)
	Sleep(400)
	Leveler_BuySkillIfNeeded($SKILL_ENERGY_BURN)
	Sleep(400)
	Leveler_BuySkillIfNeeded($SKILL_CRY_OF_FRUSTRATION)
	Sleep(400)
	Leveler_BuySkillIfNeeded($SKILL_POWER_DRAIN)
	Sleep(400)
	If Leveler_HasMesmer() Then
		Leveler_BuySkillIfNeeded($SKILL_BACKFIRE)
		Sleep(400)
	EndIf
	Leveler_CloseTrainerWindow()
	Leveler_LogMissingTrainerSkills()
	Return Leveler_Skills2Unlocked()
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
