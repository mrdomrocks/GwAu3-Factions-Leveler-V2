#include-once

; Profession tables from the Py4GW Factions Character Leveler.
; Mid and level-20 bars assume Mesmer secondary (Domination / Inspiration).
; Equipment piece IDs live in Leveler_Craft.au3 and already match that file.

Global Const $LEVELER_BAR_STARTER = 0
Global Const $LEVELER_BAR_INTERRUPT = 1
Global Const $LEVELER_BAR_INSPIRE = 2
; A/Me bar used from Zen Daijun. Set slot-by-slot; do not Skill_LoadSkillBar.
Global Const $LEVELER_BAR_ZEN = 3

Func Leveler_ProfessionSkillBar($a_i_Kind, $a_i_Prof = 0)
	If $a_i_Prof = 0 Then $a_i_Prof = Leveler_PrimaryProfession()
	Switch $a_i_Kind
		Case $LEVELER_BAR_STARTER
			Switch $a_i_Prof
				Case $GC_I_PROFESSION_WARRIOR
					Return "OQAAAAAAAAAAAAAA"
				Case $GC_I_PROFESSION_RANGER
					Return "OgAAAAAAAAAAAAAA"
				Case $GC_I_PROFESSION_MONK
					Return "OwAAAAAAAAAAAAAA"
				Case $GC_I_PROFESSION_NECROMANCER
					Return "OABAAAAAAAAAAAAA"
				Case $GC_I_PROFESSION_MESMER
					Return "OQBAAAAAAAAAAAAA"
				Case $GC_I_PROFESSION_ELEMENTALIST
					Return "OgBAAAAAAAAAAAAA"
				Case $GC_I_PROFESSION_RITUALIST
					Return "OACAAAAAAAAAAAAA"
				Case $GC_I_PROFESSION_ASSASSIN
					Return "OwBAAAAAAAAAAAAA"
			EndSwitch
			Return "OQAAAAAAAAAAAAAA"
		Case $LEVELER_BAR_INTERRUPT
			; Domination 12: Cry of Frustration, Power Drain, Signet of Disruption
			Switch $a_i_Prof
				Case $GC_I_PROFESSION_WARRIOR
					Return "OQUBIskDcdG0DaAKUECA"
				Case $GC_I_PROFESSION_RANGER
					Return "OgUBIskDcdG0DaAKUECA"
				Case $GC_I_PROFESSION_MONK
					Return "OwUBIskDcdG0DaAKUECA"
				Case $GC_I_PROFESSION_NECROMANCER
					Return "OAVBIskDcdG0DaAKUECA"
				Case $GC_I_PROFESSION_MESMER
					Return "OQBBIskDcdG0DaAKUECA"
				Case $GC_I_PROFESSION_ELEMENTALIST
					Return "OgVBIskDcdG0DaAKUECA"
				Case $GC_I_PROFESSION_RITUALIST
					Return "OAWBIskDcdG0DaAKUECA"
				Case $GC_I_PROFESSION_ASSASSIN
					; Python copies the Ritualist mid code (OAWB...). That fails
					; primary-profession validation. OwVB is the Assassin mid form
					; of the same Domination-12 bar (matches OwVC at level 20).
					Return "OwVBIskDcdG0DaAKUECA"
			EndSwitch
			Return "OQUBIskDcdG0DaAKUECA"
		Case $LEVELER_BAR_INSPIRE
			; Adds Inspiration for energy
			Switch $a_i_Prof
				Case $GC_I_PROFESSION_WARRIOR
					Return "OQUCErwSOw1ZQPoBoQRIA"
				Case $GC_I_PROFESSION_RANGER
					Return "OgUCErwSOw1ZQPoBoQRIA"
				Case $GC_I_PROFESSION_MONK
					Return "OwUCErwSOw1ZQPoBoQRIA"
				Case $GC_I_PROFESSION_NECROMANCER
					Return "OAVCErwSOw1ZQPoBoQRIA"
				Case $GC_I_PROFESSION_MESMER
					Return "OQBCErwSOw1ZQPoBoQRIA"
				Case $GC_I_PROFESSION_ELEMENTALIST
					Return "OgVCErwSOw1ZQPoBoQRIA"
				Case $GC_I_PROFESSION_RITUALIST
					Return "OAWCErwSOw1ZQPoBoQRIA"
				Case $GC_I_PROFESSION_ASSASSIN
					Return "OwVCErwSOw1ZQPoBoQRIA"
			EndSwitch
			Return "OQUCErwSOw1ZQPoBoQRIA"
	EndSwitch
	Return ""
EndFunc

Func Leveler_CurrentSkillBarKind()
	Local $l_i_Level = Agent_GetAgentInfo(-2, "Level")
	If Leveler_InterruptSkillsUnlocked() Then
		If $l_i_Level >= 20 And Leveler_Skills2Unlocked() Then Return $LEVELER_BAR_INSPIRE
		Return $LEVELER_BAR_INTERRUPT
	EndIf
	If World_IsSkillLearnt($SKILL_BACKFIRE) Then Return $LEVELER_BAR_ZEN
	Return $LEVELER_BAR_STARTER
EndFunc

Func Leveler_LoadProfessionSkillBar($a_i_Kind = -1)
	If $a_i_Kind < 0 Then $a_i_Kind = Leveler_CurrentSkillBarKind()
	If $a_i_Kind = $LEVELER_BAR_ZEN Then Return Leveler_LoadZenSkillBar()
	; Empty starter is Skill_LoadSkillBar(0,0,...). After Zhao Di that wipes the bar
	; and the SKILLBAR_LOAD packet right before EnterChallenge can disconnect.
	If $a_i_Kind = $LEVELER_BAR_STARTER And Leveler_ZhaoDiSkillsUnlocked() Then
		Out("[Party] Skipping empty starter template; Zhao Di skills would be wiped")
		Return False
	EndIf
	If ($a_i_Kind = $LEVELER_BAR_INTERRUPT Or $a_i_Kind = $LEVELER_BAR_INSPIRE) And Not Leveler_InterruptSkillsUnlocked() Then
		Out("[Party] Skipping interrupt template; Cry of Frustration / Power Drain are not learnt yet")
		Return False
	EndIf
	If Not Map_GetInstanceInfo("IsOutpost") Then
		Out("[Party] Skill template can only be loaded in an outpost")
		Return False
	EndIf
	Local $l_s_Bar = Leveler_ProfessionSkillBar($a_i_Kind)
	If $l_s_Bar = "" Then Return False
	Out("[Party] Loading profession " & Leveler_PrimaryProfession() & " bar kind " & $a_i_Kind)
	Local $l_b_Ok = Attribute_LoadSkillTemplate($l_s_Bar)
	Sleep(800)
	If $l_b_Ok Then Out("[Party] Profession skill template loaded")
	If Not $l_b_Ok Then Out("[Party] Profession skill template failed; will set trainer skills by slot")
	Return $l_b_Ok
EndFunc

Func Leveler_LoadZenSkillBar()
	; Slot-by-slot, not Skill_LoadSkillBar. Safe in the mission as well as the outpost.
	If Wine_IsWine() And Wine_MapIsLoading() Then
		Out("[Party] Skipping Zen bar writes while the map is loading")
		Return True
	EndIf
	$g_b_UAIReady = False
	; OwVCEnYyHw1cQPoBoQRIAA skills. Do not use Skill_LoadSkillBar (0x005D);
	; that packet next to Enter Mission disconnects.
	Local $l_ai_Skills[8] = [31, 860, 28, 61, 26, 40, 69, 2]
	Local $i
	Local $l_b_Same = True
	For $i = 0 To 7
		If Skill_GetSkillbarInfo($i + 1, "SkillID") <> $l_ai_Skills[$i] Then
			$l_b_Same = False
			ExitLoop
		EndIf
	Next
	If $l_b_Same Then
		Out("[Party] Zen Daijun skill bar already set")
		Return True
	EndIf
	Out("[Party] Setting Zen Daijun skill bar by slot")
	For $i = 0 To 7
		If $l_ai_Skills[$i] = 0 Then ContinueLoop
		If Not Leveler_SkillIsLearnt($l_ai_Skills[$i]) Then ContinueLoop
		Leveler_PutSkillOnBar($i + 1, $l_ai_Skills[$i])
	Next
	Sleep(1000)
	Return True
EndFunc
