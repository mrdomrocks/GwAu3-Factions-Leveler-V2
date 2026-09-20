#include-once

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

; Poll until the mission instance is explorable. Stay silent while loading.
; Do not use Map_WaitMapLoading: it skips cinematics during the load.
Func Leveler_WaitMissionExplorable($a_i_MapID, $a_i_StartMap, $a_i_Timeout = 90000)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Map_GetInstanceInfo("IsLoading") Then
			Sleep(250)
			ContinueLoop
		EndIf
		If Leveler_InMissionInstance($a_i_MapID) Then
			$g_i_EnterMissionMap = 0
			Return True
		EndIf
		If Map_GetInstanceInfo("IsExplorable") Then
			Local $l_i_Map = Map_GetMapID()
			If $l_i_Map = $a_i_StartMap Or $l_i_Map = $a_i_MapID Then
				$g_i_EnterMissionMap = 0
				Return True
			EndIf
		EndIf
		Sleep(250)
	WEnd
	Return Leveler_InMissionInstance($a_i_MapID)
EndFunc

Func Leveler_MarkMissionPrepQuiet()
	$g_h_MissionPrepQuiet = TimerInit()
EndFunc

; Skillbar / hench packets stacked with Enter can disconnect. Drain them first.
Func Leveler_WaitMissionEnterQuiet($a_i_QuietMs = 4500)
	If $g_h_MissionPrepQuiet = 0 Then
		Sleep($a_i_QuietMs)
		Return True
	EndIf
	Local $l_i_Left = $a_i_QuietMs - TimerDiff($g_h_MissionPrepQuiet)
	If $l_i_Left > 0 Then
		Out("[Step] Waiting " & Int($l_i_Left) & " ms so party/skill packets settle before Enter")
		Sleep($l_i_Left)
	EndIf
	Return True
EndFunc

Func Leveler_EnterMission($a_s_Name, $a_i_MapID)
	Local $l_i_StartMap = Map_GetMapID()
	If Leveler_InMissionInstance($a_i_MapID) Then
		$g_i_EnterMissionMap = 0
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

	If $g_i_EnterMissionMap = $l_i_StartMap Then
		Out("[Step] Enter Challenge already sent on this outpost. Waiting for the instance.")
		If Not Leveler_WaitMissionExplorable($a_i_MapID, $l_i_StartMap) Then Return False
		Sleep(2000)
		Return True
	EndIf

	If Not Map_GetInstanceInfo("IsOutpost") Then
		Out("[Step] Cannot enter " & $a_s_Name & " from map " & $l_i_StartMap & " type " & Map_GetInstanceInfo("Type"))
		Return False
	EndIf

	; Do not CancelAction, LeaveGroup, or reload the skill bar here.
	; After a wipe recover, quiet timer is fresh — wait the full drain before Enter.
	Leveler_WaitMissionEnterQuiet(4500)

	If Not Map_GetInstanceInfo("IsOutpost") Or Map_GetInstanceInfo("IsLoading") Then
		Out("[Step] Outpost not ready for Enter Challenge (map " & Map_GetMapID() & ", type " & Map_GetInstanceInfo("Type") & ")")
		Return False
	EndIf
	If Party_GetPartyContextInfo("IsDefeated") Or Party_GetPartyContextInfo("IsWaitingForMission") Then
		Out("[Step] Party still defeated or waiting for mission. Not sending Enter Challenge.")
		Return False
	EndIf

	Out("Let's do " & $a_s_Name)
	Out("Exiting Outpost")
	; Native Factions character on Cho / Zen. Wait ourselves so a timeout cannot resend Enter.
	Ui_EnterChallenge(False, False)
	$g_i_EnterMissionMap = $l_i_StartMap
	$g_h_MissionPrepQuiet = 0
	Sleep(1500)
	If Not Leveler_WaitMissionExplorable($a_i_MapID, $l_i_StartMap) Then
		If Map_GetInstanceInfo("IsLoading") Or Party_GetPartyContextInfo("IsWaitingForMission") Then
			Out("[Step] Mission is still loading. Not sending Enter Challenge again.")
			Return False
		EndIf
		Out("[Step] Mission map did not become explorable (map " & Map_GetMapID() & ", type " & Map_GetInstanceInfo("Type") & ")")
		Return False
	EndIf
	Sleep(2000)
	Out("[Step] Mission instance loaded on map " & Map_GetMapID())
	Return True
EndFunc

#EndRegion Mission
