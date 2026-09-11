#include-once

Func Leveler_PrimaryProfession()
	Local $l_i_Prof = Agent_GetAgentInfo(-2, "Primary")
	If $l_i_Prof = 0 Then $l_i_Prof = Party_GetPartyProfessionInfo(-2, "Primary")
	Return $l_i_Prof
EndFunc

Func Leveler_IsMesmer()
	Return Leveler_PrimaryProfession() = $GC_I_PROFESSION_MESMER
EndFunc

Func Leveler_NeedsVaettirPath()
	Local $l_i_Prof = Leveler_PrimaryProfession()
	Return $l_i_Prof = $GC_I_PROFESSION_ASSASSIN Or $l_i_Prof = $GC_I_PROFESSION_MESMER
EndFunc

; Gwen / Vekk / Ogden / MOX with the Python StandardHeroTeam bars, then Guard.
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
		Sleep(200)
	Next
	Sleep(1000)
	For $i = 0 To 3
		Attribute_LoadSkillTemplate($l_as_Bars[$i], $i + 1)
		Sleep(400)
		Party_SetHeroAggression($i + 1, 1)
	Next
	Out("[Party] Added Gwen, Vekk, Ogden, MOX")
	Return True
EndFunc

Func Leveler_AddHenchmanList(ByRef $a_ai_Hench)
	Local $i
	For $i = 0 To UBound($a_ai_Hench) - 1
		Party_AddNpc($a_ai_Hench[$i])
		Sleep(200)
	Next
	Sleep(600)
	Return True
EndFunc

Func Leveler_PrepareHeroTeam($a_ai_Hench = 0)
	$g_b_CombatMode = True
	Leveler_EquipSkillBar()
	Party_LeaveGroup(True)
	Sleep(400)
	Leveler_AddHeroTeam()
	If IsArray($a_ai_Hench) Then Leveler_AddHenchmanList($a_ai_Hench)
	Leveler_RestockConsumables()
	Return True
EndFunc

Func Leveler_PrepareForBattle()
	$g_b_CombatMode = True
	Leveler_EquipSkillBar()
	Party_LeaveGroup(True)
	Sleep(400)
	Leveler_AddHenchmen()
	Leveler_RestockConsumables()
	Return True
EndFunc

Func Leveler_SetPacifist()
	$g_b_CombatMode = False
	Return True
EndFunc

Func Leveler_AddHenchmen()
	Local $l_i_Map = Map_GetMapID()
	Local $l_i_Max = Map_GetCurrentAreaInfo("MaxPartySize")
	Local $l_ai_Hench
	If $l_i_Max <= 4 Then
		Local $l_ai_Small[3] = [2, 5, 1]
		$l_ai_Hench = $l_ai_Small
	ElseIf $l_i_Map = $MAP_SEITUNG Then
		Local $l_ai_Seitung[5] = [2, 3, 1, 6, 5]
		$l_ai_Hench = $l_ai_Seitung
	ElseIf $l_i_Map = $MAP_ZEN_OP Then
		Local $l_ai_Zen[5] = [2, 3, 1, 8, 5]
		$l_ai_Hench = $l_ai_Zen
	ElseIf $l_i_Map = $MAP_MARKETPLACE Then
		Local $l_ai_Market[7] = [6, 9, 5, 1, 4, 7, 3]
		$l_ai_Hench = $l_ai_Market
	ElseIf $l_i_Map = $MAP_KAINENG Then
		Local $l_ai_Kc[7] = [2, 10, 4, 8, 7, 9, 12]
		$l_ai_Hench = $l_ai_Kc
	ElseIf $l_i_Map = $MAP_BOREAL Then
		Local $l_ai_Boreal[7] = [7, 9, 2, 3, 4, 6, 5]
		$l_ai_Hench = $l_ai_Boreal
	ElseIf $l_i_Map = $MAP_EOTN Or $l_i_Map = $MAP_HOM Then
		Local $l_ai_Eotn[7] = [2, 3, 5, 6, 7, 9, 10]
		$l_ai_Hench = $l_ai_Eotn
	ElseIf $l_i_Map = $MAP_GUNNAR Or $l_i_Map = $MAP_LONGEYE Then
		Local $l_ai_Gunnar[3] = [4, 5, 6]
		$l_ai_Hench = $l_ai_Gunnar
	ElseIf $l_i_Map = $MAP_LIONS_ARCH Then
		Local $l_ai_La[1] = [1]
		$l_ai_Hench = $l_ai_La
	ElseIf $l_i_Map = $MAP_KAMADAN Then
		Local $l_ai_Kamadan[3] = [2, 12, 9]
		$l_ai_Hench = $l_ai_Kamadan
	ElseIf $l_i_Max > 4 Then
		Local $l_ai_Large[7] = [2, 3, 5, 6, 7, 9, 10]
		$l_ai_Hench = $l_ai_Large
	Else
		Local $l_ai_Default[3] = [2, 5, 1]
		$l_ai_Hench = $l_ai_Default
	EndIf

	For $i = 0 To UBound($l_ai_Hench) - 1
		Party_AddNpc($l_ai_Hench[$i])
		Sleep(200)
	Next
	Sleep(800)
	Local $l_s_List = ""
	For $i = 0 To UBound($l_ai_Hench) - 1
		If $i > 0 Then $l_s_List &= ", "
		$l_s_List &= $l_ai_Hench[$i]
	Next
	Out("[Party] Added henchmen " & $l_s_List)
	Return True
EndFunc

Func Leveler_EquipSkillBar()
	Local $l_i_Level = Agent_GetAgentInfo(-2, "Level")
	Local $l_i_Prof = Leveler_PrimaryProfession()
	Local $l_s_Bar = ""

	If $l_i_Level < 3 Then
		Switch $l_i_Prof
			Case $GC_I_PROFESSION_WARRIOR
				$l_s_Bar = "OQAAAAAAAAAAAAAA"
			Case $GC_I_PROFESSION_RANGER
				$l_s_Bar = "OgAAAAAAAAAAAAAA"
			Case $GC_I_PROFESSION_MONK
				$l_s_Bar = "OwAAAAAAAAAAAAAA"
			Case $GC_I_PROFESSION_NECROMANCER
				$l_s_Bar = "OABAAAAAAAAAAAAA"
			Case $GC_I_PROFESSION_MESMER
				$l_s_Bar = "OQBAAAAAAAAAAAAA"
			Case $GC_I_PROFESSION_ELEMENTALIST
				$l_s_Bar = "OgBAAAAAAAAAAAAA"
			Case $GC_I_PROFESSION_RITUALIST
				$l_s_Bar = "OACAAAAAAAAAAAAA"
			Case $GC_I_PROFESSION_ASSASSIN
				$l_s_Bar = "OwBAAAAAAAAAAAAA"
			Case Else
				$l_s_Bar = "OQAAAAAAAAAAAAAA"
		EndSwitch
	Else
		Switch $l_i_Prof
			Case $GC_I_PROFESSION_WARRIOR
				$l_s_Bar = "OQUBIskDcdG0DaAKUECA"
			Case $GC_I_PROFESSION_RANGER
				$l_s_Bar = "OgUBIskDcdG0DaAKUECA"
			Case $GC_I_PROFESSION_MONK
				$l_s_Bar = "OwUBIskDcdG0DaAKUECA"
			Case $GC_I_PROFESSION_NECROMANCER
				$l_s_Bar = "OAVBIskDcdG0DaAKUECA"
			Case $GC_I_PROFESSION_MESMER
				$l_s_Bar = "OQBBIskDcdG0DaAKUECA"
			Case $GC_I_PROFESSION_ELEMENTALIST
				$l_s_Bar = "OgVBIskDcdG0DaAKUECA"
			Case $GC_I_PROFESSION_RITUALIST
				$l_s_Bar = "OAWBIskDcdG0DaAKUECA"
			Case $GC_I_PROFESSION_ASSASSIN
				$l_s_Bar = "OAWBIskDcdG0DaAKUECA"
			Case Else
				$l_s_Bar = "OQUBIskDcdG0DaAKUECA"
		EndSwitch
	EndIf

	If $l_s_Bar <> "" Then
		Attribute_LoadSkillTemplate($l_s_Bar)
		Sleep(400)
		Out("[Party] Loaded skill template for profession " & $l_i_Prof)
	EndIf
	Return True
EndFunc

Func Leveler_RestockConsumables()
	; Phase 1 stub: candy apple / honeycomb / war supplies are not required to start.
	Return True
EndFunc
