#include-once

; Mid and level-20 bars assume Mesmer secondary (Domination / Inspiration).
; Equipment piece IDs live in Leveler_Craft.au3.

Global Const $LEVELER_BAR_STARTER = 0
Global Const $LEVELER_BAR_INTERRUPT = 1
Global Const $LEVELER_BAR_INSPIRE = 2
; A/Me bar used from Zen Daijun until Kaineng. Apply the template; do not check slots.
Global Const $LEVELER_BAR_ZEN = 3
Global Const $LEVELER_TEMPLATE_ZEN = "OwVCEnYCX3DfAKoBcwQAAA"

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
		Case $LEVELER_BAR_ZEN
			Return $LEVELER_TEMPLATE_ZEN
	EndSwitch
	Return ""
EndFunc

; Zen Daijun through the walk to Kaineng. Michiko changes the bar after this.
Func Leveler_UsesZenSkillBar()
	If Leveler_InterruptSkillsUnlocked() Then Return False
	If $g_i_Step >= $LEVELER_STEP_ZEN_MISSION And $g_i_Step < $LEVELER_STEP_SKILLS2 Then Return True
	Local $l_i_Map = Map_GetMapID()
	If $l_i_Map = $MAP_ZEN_OP Or $l_i_Map = $MAP_ZEN_EXP Then Return True
	If $l_i_Map = $MAP_MARKETPLACE Or $l_i_Map = $MAP_KAINENG_DOCKS Then Return True
	If $l_i_Map = $MAP_BUKDEK Or $l_i_Map = $MAP_WAJJUN Then Return True
	Return False
EndFunc

Func Leveler_CurrentSkillBarKind()
	Local $l_i_Level = Agent_GetAgentInfo(-2, "Level")
	If Leveler_InterruptSkillsUnlocked() Then
		If $l_i_Level >= 20 And Leveler_Skills2Unlocked() Then Return $LEVELER_BAR_INSPIRE
		Return $LEVELER_BAR_INTERRUPT
	EndIf
	If Leveler_UsesZenSkillBar() Then Return $LEVELER_BAR_ZEN
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
	$g_b_UAIReady = False
	If Not Map_GetInstanceInfo("IsOutpost") Then Return True
	Local $l_i_Map = Map_GetMapID()
	; Skip reload if the template is already on this map.
	If $g_i_ZenBarLoadedMap = $l_i_Map And Skill_GetSkillbarInfo(1, "SkillID") <> 0 Then
		Out("[Party] Zen skill template already loaded on map " & $l_i_Map)
		Return True
	EndIf
	Out("[Party] Loading skill template " & $LEVELER_TEMPLATE_ZEN)
	Attribute_LoadSkillTemplate($LEVELER_TEMPLATE_ZEN)
	$g_i_ZenBarLoadedMap = $l_i_Map
	Sleep(800)
	Return True
EndFunc
