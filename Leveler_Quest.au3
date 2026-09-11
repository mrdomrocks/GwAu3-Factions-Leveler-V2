#include-once

; Port of Python QuestLoop.
; $a_s_Mode: "accept" | "complete" | "step" | "skip"
Func Leveler_QuestLoop($a_i_QuestID, $a_f_X, $a_f_Y, $a_i_Dialog, $a_s_Mode = "accept", $a_i_NpcModel = 0, $a_i_Multi = 0)
	Local $l_i_Attempts = 0
	Local $l_i_StartMap = Map_GetMapID()
	Local $l_f_X = $a_f_X
	Local $l_f_Y = $a_f_Y
	Local $l_i_Npc = 0

	If $a_i_NpcModel <> 0 And $l_f_X = 0 And $l_f_Y = 0 Then
		$l_i_Npc = Leveler_GetAgentByModel($a_i_NpcModel)
		If $l_i_Npc <> 0 Then
			$l_f_X = Agent_GetAgentInfo($l_i_Npc, "X")
			$l_f_Y = Agent_GetAgentInfo($l_i_Npc, "Y")
		EndIf
	EndIf

	While Leveler_QuestLoopCondition($a_i_QuestID, $a_s_Mode, $a_i_NpcModel, $l_i_StartMap) And $l_i_Attempts < 5
		If Leveler_IsWiped() Then Return False
		Out("[Quest] Attempt " & ($l_i_Attempts + 1) & " " & $a_s_Mode & " quest #" & $a_i_QuestID)
		If Not Leveler_MoveAndDialog($l_f_X, $l_f_Y, $a_i_Dialog, $g_b_CombatMode, $a_i_NpcModel) Then
			Sleep(400)
		EndIf
		If $a_i_Multi <> 0 Then
			Leveler_MoveAndDialog($l_f_X, $l_f_Y, $a_i_Multi, $g_b_CombatMode, $a_i_NpcModel)
		EndIf
		Sleep(500)
		$l_i_Attempts += 1
	WEnd

	If Leveler_QuestSuccessCondition($a_i_QuestID, $a_s_Mode, $a_i_NpcModel, $l_i_StartMap) Then
		Out("[Quest] Successfully finished " & $a_s_Mode & " quest #" & $a_i_QuestID)
		Return True
	EndIf

	Out("[Quest] Failed to " & $a_s_Mode & " quest #" & $a_i_QuestID & ". Pausing.")
	$g_b_LevelerPaused = True
	$g_b_LevelerFailed = True
	Return False
EndFunc

Func Leveler_HasQuest($a_i_QuestID)
	Return Quest_GetQuestInfo($a_i_QuestID, "HasQuest") = True
EndFunc

Func Leveler_IsCurrentQuest($a_i_QuestID)
	Return Quest_GetQuestInfo($a_i_QuestID, "IsCurrentQuest") = True
EndFunc

Func Leveler_QuestLoopCondition($a_i_QuestID, $a_s_Mode, $a_i_NpcModel, $a_i_StartMap)
	Switch $a_s_Mode
		Case "complete"
			Return Leveler_HasQuest($a_i_QuestID)
		Case "step"
			Return Leveler_NpcHasQuestMarker($a_i_NpcModel)
		Case "skip"
			Return Map_GetMapID() = $a_i_StartMap
		Case Else
			Return Not Leveler_HasQuest($a_i_QuestID)
	EndSwitch
EndFunc

Func Leveler_QuestSuccessCondition($a_i_QuestID, $a_s_Mode, $a_i_NpcModel, $a_i_StartMap)
	Switch $a_s_Mode
		Case "complete"
			Return Not Leveler_HasQuest($a_i_QuestID)
		Case "step", "skip"
			If Map_GetMapID() <> $a_i_StartMap Then Return True
			Return Not Leveler_NpcHasQuestMarker($a_i_NpcModel)
		Case Else
			Return Leveler_HasQuest($a_i_QuestID)
	EndSwitch
EndFunc

Func Leveler_NpcHasQuestMarker($a_i_NpcModel)
	Local $l_i_Npc = 0
	If $a_i_NpcModel <> 0 Then
		$l_i_Npc = Leveler_GetAgentByModel($a_i_NpcModel)
	EndIf
	If $l_i_Npc = 0 Then $l_i_Npc = Leveler_GetNearestNPC(400)
	If $l_i_Npc = 0 Then Return False
	Return Agent_GetAgentInfo($l_i_Npc, "HasQuest")
EndFunc
