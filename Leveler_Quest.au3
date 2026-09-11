#include-once

; Port of Python QuestLoop.
; $a_s_Mode: "accept" | "complete" | "step" | "skip"
; Do not halt the bot on failure. The step machine retries the current header.
Func Leveler_QuestLoop($a_i_QuestID, $a_f_X, $a_f_Y, $a_i_Dialog, $a_s_Mode = "accept", $a_i_NpcModel = 0, $a_i_Multi = 0)
	Local $l_i_Attempts = 0
	Local $l_i_StartMap = Map_GetMapID()
	Local $l_f_X = $a_f_X
	Local $l_f_Y = $a_f_Y

	Local $l_b_HadQuest = Leveler_HasQuest($a_i_QuestID)

	If $a_i_QuestID <> 0 And $a_s_Mode = "accept" And $l_b_HadQuest Then
		Ui_ActiveQuest($a_i_QuestID)
		Out("[Quest] Quest #" & $a_i_QuestID & " already in the log")
		Return True
	EndIf
	If $a_i_QuestID <> 0 And $a_s_Mode = "complete" Then
		If $a_i_QuestID = $QUEST_SECONDARY And Leveler_SecondaryRewardTaken() Then
			Leveler_MarkQuestDone($a_i_QuestID)
			Out("[Quest] Quest #317 reward already taken")
			Return True
		EndIf
		If Not $l_b_HadQuest And $a_i_QuestID <> $QUEST_SECONDARY Then
			Out("[Quest] Quest #" & $a_i_QuestID & " is not in the log; cannot complete yet")
			Return False
		EndIf
	EndIf

	If $a_s_Mode = "complete" And $a_i_QuestID <> 0 Then Ui_ActiveQuest($a_i_QuestID)

	While Leveler_QuestLoopCondition($a_i_QuestID, $a_s_Mode, $a_i_NpcModel, $l_i_StartMap) And $l_i_Attempts < 8
		If $g_b_LevelerPaused Then Return False
		If Leveler_IsWiped() Then Return False
		Leveler_ResolveQuestXY($a_i_NpcModel, $l_f_X, $l_f_Y)
		Out("[Quest] Attempt " & ($l_i_Attempts + 1) & " " & $a_s_Mode & " quest #" & $a_i_QuestID)
		If Not Leveler_MoveAndDialog($l_f_X, $l_f_Y, $a_i_Dialog, $g_b_CombatMode, $a_i_NpcModel) Then
			Sleep(600)
		EndIf
		If $a_i_Multi <> 0 Then
			Leveler_MoveAndDialog($l_f_X, $l_f_Y, $a_i_Multi, $g_b_CombatMode, $a_i_NpcModel)
		EndIf
		Sleep(800)
		$l_i_Attempts += 1
	WEnd

	If Leveler_QuestSuccessCondition($a_i_QuestID, $a_s_Mode, $a_i_NpcModel, $l_i_StartMap) Then
		If $a_s_Mode = "accept" And $a_i_QuestID <> 0 Then Ui_ActiveQuest($a_i_QuestID)
		If $a_s_Mode = "complete" And $a_i_QuestID <> 0 Then Leveler_MarkQuestDone($a_i_QuestID)
		Out("[Quest] Successfully finished " & $a_s_Mode & " quest #" & $a_i_QuestID)
		Return True
	EndIf

	Out("[Quest] Failed to " & $a_s_Mode & " quest #" & $a_i_QuestID & ". Retrying step.")
	Return False
EndFunc

Func Leveler_ResolveQuestXY($a_i_NpcModel, ByRef $a_f_X, ByRef $a_f_Y)
	Local $l_i_Npc = 0
	If $a_i_NpcModel <> 0 Then $l_i_Npc = Leveler_GetAgentByModel($a_i_NpcModel)
	If $l_i_Npc = 0 And $a_f_X = 0 And $a_f_Y = 0 Then Return
	If $l_i_Npc = 0 Then $l_i_Npc = Leveler_GetNearestNPCAt($a_f_X, $a_f_Y, 400)
	If $l_i_Npc = 0 Then Return
	$a_f_X = Agent_GetAgentInfo($l_i_Npc, "X")
	$a_f_Y = Agent_GetAgentInfo($l_i_Npc, "Y")
EndFunc

; Walk the live quest log for an exact quest ID. Returns:
; 0 = not in log, 1 = in log (objectives open), 2 = in log (reward ready, not turned in).
; Bit 0x2 means the reward can be taken. It does NOT mean the quest is finished.
Func Leveler_QuestLogMatch($a_i_QuestID)
	If $a_i_QuestID = 0 Then Return 0
	Local $l_p_Log = World_GetWorldInfo("QuestLog")
	Local $l_i_Size = World_GetWorldInfo("QuestLogSize")
	If $l_p_Log = 0 Or $l_i_Size <= 0 Then
		If Quest_GetQuestInfo($a_i_QuestID, "HasQuest") Then
			If Quest_GetQuestInfo($a_i_QuestID, "IsCompleted") Then Return 2
			Return 1
		EndIf
		Return 0
	EndIf
	Local $i
	For $i = 0 To $l_i_Size - 1
		Local $l_p_Entry = $l_p_Log + ($i * 0x34)
		If Memory_Read($l_p_Entry, "long") <> $a_i_QuestID Then ContinueLoop
		Local $l_i_State = Memory_Read($l_p_Entry + 0x4, "long")
		If BitAND($l_i_State, 0x2) <> 0 Then Return 2
		Return 1
	Next
	Return 0
EndFunc

Func Leveler_QuestInLog($a_i_QuestID)
	Return Leveler_QuestLogMatch($a_i_QuestID) <> 0
EndFunc

Func Leveler_QuestReadyForReward($a_i_QuestID)
	Return Leveler_QuestLogMatch($a_i_QuestID) = 2
EndFunc

; Still needs NPC work. Reward-ready (bit 0x2) is not finished for #317.
; #317 stays active while it is in the log, even after a secondary is assigned.
Func Leveler_QuestLogActive($a_i_QuestID)
	If $a_i_QuestID = $QUEST_SECONDARY Then Return Leveler_QuestInLog($a_i_QuestID)
	Return Leveler_QuestLogMatch($a_i_QuestID) = 1
EndFunc

Func Leveler_QuestLogCompleted($a_i_QuestID)
	If $a_i_QuestID = $QUEST_SECONDARY Then Return Leveler_SecondaryRewardTaken()
	Return Leveler_QuestReadyForReward($a_i_QuestID)
EndFunc

Func Leveler_QuestLogStateValue($a_i_QuestID)
	If $a_i_QuestID = 0 Then Return 0
	Local $l_p_Log = World_GetWorldInfo("QuestLog")
	Local $l_i_Size = World_GetWorldInfo("QuestLogSize")
	If $l_p_Log = 0 Or $l_i_Size <= 0 Then Return Quest_GetQuestInfo($a_i_QuestID, "LogState")
	Local $i
	For $i = 0 To $l_i_Size - 1
		Local $l_p_Entry = $l_p_Log + ($i * 0x34)
		If Memory_Read($l_p_Entry, "long") <> $a_i_QuestID Then ContinueLoop
		Return Memory_Read($l_p_Entry + 0x4, "long")
	Next
	Return 0
EndFunc

Func Leveler_LogQuestState($a_i_QuestID, $a_s_Label = "")
	Local $l_i_Match = Leveler_QuestLogMatch($a_i_QuestID)
	Local $l_i_State = Leveler_QuestLogStateValue($a_i_QuestID)
	Local $l_s_State = "not in log"
	If $l_i_Match = 1 Then $l_s_State = "ACTIVE"
	If $l_i_Match = 2 Then $l_s_State = "in log, reward ready (not turned in)"
	If $a_i_QuestID = $QUEST_SECONDARY Then
		If $l_i_Match <> 0 Then
			$l_s_State = "ACTIVE (needs Togo complete, LogState=0x" & Hex($l_i_State, 8) & ")"
		ElseIf Leveler_SecondaryRewardTaken() Then
			$l_s_State = "turned in (secondary " & Leveler_SecondaryProfession() & ")"
		ElseIf Leveler_HasSecondaryProfession() Then
			$l_s_State = "not turned in (secondary " & Leveler_SecondaryProfession() & ", gold " & Leveler_CharacterGold() & ")"
		Else
			$l_s_State = "not in log (secondary still unset)"
		EndIf
	EndIf
	If $a_s_Label = "" Then $a_s_Label = "Quest"
	Out("[QuestLog] " & $a_s_Label & " #" & $a_i_QuestID & " = " & $l_s_State)
	Return $l_i_Match
EndFunc

Func Leveler_StepQuestID($a_i_Step)
	Switch $a_i_Step
		Case $LEVELER_STEP_PARTY
			Return $QUEST_FORMING_A_PARTY
		Case $LEVELER_STEP_SECONDARY
			Return $QUEST_SECONDARY
		Case $LEVELER_STEP_TO_CHO
			Return $QUEST_FORMAL_INTRO
		Case $LEVELER_STEP_ATTR_1
			Return $QUEST_LOST_TREASURE
		Case $LEVELER_STEP_TENGU
			Return $QUEST_WARNING_TENGU
		Case $LEVELER_STEP_THREAT
			Return $QUEST_THREAT_GROWS
		Case $LEVELER_STEP_ROAD
			Return $QUEST_ROAD_LESS
		Case $LEVELER_STEP_CURE
			Return $QUEST_SEARCH_CURE
		Case $LEVELER_STEP_BURDEN
			Return $QUEST_MASTERS_BURDEN
		Case $LEVELER_STEP_ATTR_2
			Return $QUEST_UNWELCOME
		Case $LEVELER_STEP_KILROY
			Return $QUEST_PUNCH_CLOWN
		Case $LEVELER_STEP_TO_LA
			Return $QUEST_CHAOS_KRYTA
		Case $LEVELER_STEP_TO_KAMADAN
			Return $QUEST_SUNSPEARS_CANTHA
		Case $LEVELER_STEP_UNLOCK_OLIAS
			Return $QUEST_OLIAS
	EndSwitch
	Return 0
EndFunc

; True if the quest ID is anywhere in the log, including a turned-in entry.
Func Leveler_HasQuest($a_i_QuestID)
	If Leveler_QuestInLog($a_i_QuestID) Then Return True
	Return Quest_GetQuestInfo($a_i_QuestID, "HasQuest") = True
EndFunc

; True only while the quest is still in progress.
Func Leveler_HasIncompleteQuest($a_i_QuestID)
	If $a_i_QuestID = $QUEST_SECONDARY Then
		If Leveler_QuestInLog($a_i_QuestID) Then Return True
		If Leveler_HasPostXunlaiProgress() Then Return False
		If Leveler_HasSecondaryProfession() And Leveler_CharacterGold() < $XUNLAI_GOLD_COST Then Return True
		Return False
	EndIf
	If Leveler_QuestLogActive($a_i_QuestID) Then Return True
	If Not Leveler_HasQuest($a_i_QuestID) Then Return False
	If Leveler_QuestFinished($a_i_QuestID) Then Return False
	Return True
EndFunc

Func Leveler_IsCurrentQuest($a_i_QuestID)
	Return Quest_GetQuestInfo($a_i_QuestID, "IsCurrentQuest") = True
EndFunc

Func Leveler_QuestLoopCondition($a_i_QuestID, $a_s_Mode, $a_i_NpcModel, $a_i_StartMap)
	Switch $a_s_Mode
		Case "complete"
			Return Leveler_HasIncompleteQuest($a_i_QuestID)
		Case "step"
			If Map_GetMapID() <> $a_i_StartMap Then Return False
			Return Leveler_NpcHasQuestMarker($a_i_NpcModel)
		Case "skip"
			Return Map_GetMapID() = $a_i_StartMap
		Case Else
			Return Not Leveler_HasQuest($a_i_QuestID) And Not Leveler_QuestFinished($a_i_QuestID)
	EndSwitch
EndFunc

Func Leveler_QuestSuccessCondition($a_i_QuestID, $a_s_Mode, $a_i_NpcModel, $a_i_StartMap)
	Switch $a_s_Mode
		Case "complete"
			If $a_i_QuestID = $QUEST_SECONDARY Then Return Leveler_SecondaryRewardTaken()
			If Leveler_QuestFinished($a_i_QuestID) Then Return True
			If Not Leveler_HasQuest($a_i_QuestID) Then Return True
			Return Not Leveler_HasIncompleteQuest($a_i_QuestID)
		Case "step", "skip"
			If Map_GetMapID() <> $a_i_StartMap Then Return True
			Return Not Leveler_NpcHasQuestMarker($a_i_NpcModel)
		Case Else
			Return Leveler_HasQuest($a_i_QuestID) Or Leveler_QuestFinished($a_i_QuestID)
	EndSwitch
EndFunc

Func Leveler_NpcHasQuestMarker($a_i_NpcModel)
	Local $l_i_Npc = 0
	If $a_i_NpcModel <> 0 Then $l_i_Npc = Leveler_GetAgentByModel($a_i_NpcModel)
	If $l_i_Npc = 0 Then $l_i_Npc = Leveler_GetNearestNPC(400)
	If $l_i_Npc = 0 Then Return False
	If Not Leveler_IsTalkNpc($l_i_Npc) Then Return False
	Return Agent_GetAgentInfo($l_i_Npc, "HasQuest")
EndFunc
