#include-once

#Region Henchmen

Func Leveler_HenchmanCount()
	Local $l_i_Count = Party_GetPartyContextInfo("HenchmenCount")
	If $l_i_Count > 0 Then Return $l_i_Count
	$l_i_Count = Party_GetMyPartyInfo("ArrayHenchmanPartyMemberSize")
	If $l_i_Count > 0 Then Return $l_i_Count
	If Party_GetMyPartyHenchmanInfo(1, "AgentID") <> 0 Then Return 1
	Return 0
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

; $a_b_LeaveFirst False before Enter Challenge — LeaveGroup + Enter disconnects.
Func Leveler_EnsureFormingPartyHenchmen($a_b_LeaveFirst = True)
	If Leveler_HasFormingPartyHenchmen() Then
		Out("[Party] Forming A Party henchmen are already in the party (" & Leveler_HenchmanCount() & ")")
		Return True
	EndIf
	Local $l_ai_Hench = Leveler_FormingPartyHenchIDs()
	If $a_b_LeaveFirst Then
		Party_LeaveGroup(True)
		Sleep(500)
	EndIf
	Leveler_AddHenchmanList($l_ai_Hench)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < 5000
		If Leveler_HasFormingPartyHenchmen() Then ExitLoop
		Sleep(250)
	WEnd
	If Leveler_HasFormingPartyHenchmen() Then
		Out("[Party] Forming A Party henchmen ready (" & Leveler_HenchmanCount() & ")")
		Return True
	EndIf
	Out("[Party] Forming A Party needs 3 henchmen (2, 5, 1); have " & Leveler_HenchmanCount() & ". Retrying.")
	Return False
EndFunc

; Always LeaveParty, then AddHenchmen for this map.
; Skipping Leave when HenchmanCount looks full left new characters without henchmen
; when the count API was stale, which breaks Forming A Party.
Func Leveler_PrepareForBattle()
	$g_b_CombatMode = True
	$g_b_UAIReady = False
	Leveler_EquipSkillBar()
	Ui_SetDifficulty(False)

	Local $l_ai_Want = Leveler_HenchmenForMap()
	Party_LeaveGroup(True)
	Sleep(800)
	Leveler_AddHenchmanList($l_ai_Want)
	Out("[Party] Henchmen in party: " & Leveler_HenchmanCount() & "/" & UBound($l_ai_Want))

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
	Return True
EndFunc

#EndRegion Henchmen
