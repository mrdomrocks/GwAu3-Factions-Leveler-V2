#include-once

Func Leveler_PrimaryProfession()
	Local $l_i_Prof = Agent_GetAgentInfo(-2, "Primary")
	If $l_i_Prof = 0 Then $l_i_Prof = Party_GetPartyProfessionInfo(-2, "Primary")
	Return $l_i_Prof
EndFunc

Func Leveler_SecondaryProfession()
	Local $l_i_Prof = Agent_GetAgentInfo(-2, "Secondary")
	If $l_i_Prof >= 1 And $l_i_Prof <= 10 Then Return $l_i_Prof
	If $l_i_Prof = 0 Then Return 0
	Local $l_i_PartyProf = Party_GetPartyProfessionInfo(-2, "Secondary")
	If $l_i_PartyProf >= 1 And $l_i_PartyProf <= 10 Then Return $l_i_PartyProf
	Return 0
EndFunc

; A secondary ID of 1-10 means the profession was assigned. It does not mean
; Choose Your Secondary Profession (#317) has been turned in for the gold reward.
Func Leveler_HasSecondaryProfession()
	Local $l_i_Prof = Leveler_SecondaryProfession()
	Return $l_i_Prof >= 1 And $l_i_Prof <= 10
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

; Same trio Forming A Party uses in Shing Jea (party size 4).
Func Leveler_FormingPartyHenchIDs()
	Local $l_ai_Hench[3] = [2, 5, 1]
	Return $l_ai_Hench
EndFunc

Func Leveler_HenchmanCount()
	Return Party_GetMyPartyInfo("ArrayHenchmanPartyMemberSize")
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
	Local $i
	For $i = 0 To UBound($l_ai_Hench) - 1
		Party_AddNpc($l_ai_Hench[$i])
		Sleep(300)
	Next
	Sleep(1000)
	If Not Leveler_HasFormingPartyHenchmen() Then
		Out("[Party] Need henchmen 2, 5, 1 before leaving for Cho's Estate (have " & Leveler_HenchmanCount() & ")")
		Return False
	EndIf
	Out("[Party] Added Forming A Party henchmen 2, 5, 1")
	Return True
EndFunc

Func Leveler_SkillIsLearnt($a_i_SkillID)
	If World_IsSkillLearnt($a_i_SkillID) Then Return True
	If Account_IsSkillUnlocked($a_i_SkillID) Then Return True
	Return False
EndFunc

Func Leveler_WaitSkillLearnt($a_i_SkillID)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < 8000
		If Leveler_SkillIsLearnt($a_i_SkillID) Then Return True
		Sleep(250)
	WEnd
	Return Leveler_SkillIsLearnt($a_i_SkillID)
EndFunc

Func Leveler_BarHasSkill($a_i_SkillID)
	Return Skill_GetSkillbarInfo($a_i_SkillID, "HasSkillID") = True
EndFunc

; One slot at a time. GW drops later SetSkillbar packets if they are sent together.
Func Leveler_PutSkillOnBar($a_i_Slot, $a_i_SkillID)
	If $a_i_SkillID = 0 Then Return True
	If Skill_GetSkillbarInfo($a_i_Slot, "SkillID") = $a_i_SkillID Then Return True
	If Not Leveler_WaitSkillLearnt($a_i_SkillID) Then
		Out("[Step] Skill " & $a_i_SkillID & " is not learnt yet; cannot put it on the bar")
		Return False
	EndIf
	Local $i
	For $i = 1 To 6
		If Skill_GetSkillbarInfo($a_i_Slot, "SkillID") = $a_i_SkillID Then
			Out("[Step] Slot " & $a_i_Slot & " already has skill " & $a_i_SkillID)
			Return True
		EndIf
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
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < 8000
		If World_IsSkillLearnt($a_i_SkillID) Then Return True
		Sleep(250)
	WEnd
	If World_IsSkillLearnt($a_i_SkillID) Then Return True
	Out("[Step] Could not learn skill " & $a_i_SkillID)
	Return False
EndFunc

; After secondary: empty starter bar.
; After Zhao Di: Signet of Disruption, Leech Signet, Energy Burn if learnt.
; After Kaineng: Cry of Frustration, Power Drain, Signet of Disruption.
Func Leveler_EquipTrainerSkills()
	Leveler_CloseTrainerWindow()
	If Leveler_TrainerSkillsOnBar() Then
		Out("[Step] Trainer skills are already on the bar")
		Return True
	EndIf
	If Leveler_InterruptSkillsUnlocked() Then
		Local $l_i_Kind = Leveler_CurrentSkillBarKind()
		If $l_i_Kind = $LEVELER_BAR_STARTER Then $l_i_Kind = $LEVELER_BAR_INTERRUPT
		Leveler_LoadProfessionSkillBar($l_i_Kind)
		Sleep(600)
		If Leveler_TrainerSkillsOnBar() Then
			Out("[Step] Profession interrupt bar loaded")
			Return True
		EndIf
		Out("[Step] Putting Kaineng interrupt skills on the bar")
		Leveler_PutSkillOnBar(1, $SKILL_CRY_OF_FRUSTRATION)
		Leveler_PutSkillOnBar(2, $SKILL_POWER_DRAIN)
		Leveler_PutSkillOnBar(3, $SKILL_SIGNET_OF_DISRUPTION)
		If Leveler_TrainerSkillsOnBar() Then
			Out("[Step] Equipped Cry of Frustration, Power Drain, Signet of Disruption")
			Return True
		EndIf
		Out("[Step] Interrupt skills are learnt but not all on the bar yet")
		Return False
	EndIf
	Out("[Step] Putting learnt Zhao Di skills on the bar")
	Local $l_i_Slot = 1
	If World_IsSkillLearnt($SKILL_SIGNET_OF_DISRUPTION) Then
		Leveler_PutSkillOnBar($l_i_Slot, $SKILL_SIGNET_OF_DISRUPTION)
		$l_i_Slot += 1
	EndIf
	If World_IsSkillLearnt($SKILL_LEECH_SIGNET) Then
		Leveler_PutSkillOnBar($l_i_Slot, $SKILL_LEECH_SIGNET)
		$l_i_Slot += 1
	EndIf
	If World_IsSkillLearnt($SKILL_ENERGY_BURN) Then
		Leveler_PutSkillOnBar($l_i_Slot, $SKILL_ENERGY_BURN)
	EndIf
	If Leveler_TrainerSkillsOnBar() Then
		Out("[Step] Equipped Signet of Disruption and Leech Signet")
		Return True
	EndIf
	If World_IsSkillLearnt($SKILL_SIGNET_OF_DISRUPTION) And World_IsSkillLearnt($SKILL_LEECH_SIGNET) Then
		Out("[Step] Zhao Di skills are learnt; advancing even if a slot did not stick")
		Return True
	EndIf
	Out("[Step] Zhao Di skills are not all on the bar yet")
	Return False
EndFunc

Func Leveler_EquipSkillBar()
	If Leveler_TrainerSkillsOnBar() Then
		Out("[Party] Trainer skills already on the bar; not reloading a template")
		Return True
	EndIf
	If Leveler_InterruptSkillsUnlocked() Then
		Leveler_LoadProfessionSkillBar()
		If Not Leveler_TrainerSkillsOnBar() Then Leveler_EquipTrainerSkills()
		Return True
	EndIf
	If Leveler_ZhaoDiSkillsUnlocked() Then
		Out("[Party] Keeping Zhao Di skills; not loading the empty starter bar")
		Return Leveler_EquipTrainerSkills()
	EndIf
	Leveler_LoadProfessionSkillBar($LEVELER_BAR_STARTER)
	Return True
EndFunc

Func Leveler_RestockConsumables()
	; Phase 1 stub: candy apple / honeycomb / war supplies are not required to start.
	Return True
EndFunc
