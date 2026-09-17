#include-once

; Load the Pathfinder DLL only. Skip Pathfinder_Initialize() so we do not block
; on the GitHub maps.rar check / download during Start.
Func Leveler_EnsurePathfinder()
	If $DLL_PATH = "" Then
		$DLL_PATH = @ScriptDir & "\..\..\API\Plugins\Pathfinder\GWPathfinder.dll"
	EndIf
	If $g_hPathfinderDLL <> 0 And $g_hPathfinderDLL <> -1 Then Return True

	If Not FileExists($DLL_PATH) Then
		Out("[Move] Pathfinder DLL missing; using direct Map_Move fallback.")
		Return False
	EndIf

	$g_hPathfinderDLL = DllOpen($DLL_PATH)
	If $g_hPathfinderDLL = -1 Then
		Out("[Move] Pathfinder DLL failed to load; using direct Map_Move fallback.")
		Return False
	EndIf

	Local $l_av_Init = DllCall($g_hPathfinderDLL, "int:cdecl", "Initialize")
	If @error Or Not IsArray($l_av_Init) Then
		Out("[Move] Pathfinder Initialize call failed; using direct Map_Move fallback.")
		Return False
	EndIf
	If $l_av_Init[0] = 2 Then
		Out("[Move] Pathfinder maps.rar not found yet; using direct Map_Move until maps are present.")
	ElseIf $l_av_Init[0] = 0 Then
		Out("[Move] Pathfinder Initialize returned 0; using direct Map_Move fallback.")
		Return False
	EndIf
	Return True
EndFunc

; Fight in explorables. Stay pacifist in outposts. Return False for a map ID
; here only when Dominic says that explorable should not fight.
Func Leveler_ShouldFightHere()
	If Leveler_InMissionInstance() Then Return True
	If Map_GetInstanceInfo("IsLoading") And Leveler_InstanceInfoTrusted() Then Return False
	If Leveler_IsOutpost() Then Return False
	If Leveler_InstanceInfoTrusted() Then Return Map_GetInstanceInfo("IsExplorable") = True
	Return Number(Map_GetCharacterInfo("IsExplorable")) Or Number(Map_GetCharacterInfo("CurrentMapType")) = 1
EndFunc

; $a_b_Combat True = fight while walking. False is ignored in explorables.
; Outposts never fight. Returns True if we arrived or the map changed.
Func Leveler_MoveTo($a_f_X, $a_f_Y, $a_b_Combat = False)
	If $g_b_LevelerPaused Then Return False
	If Leveler_IsWiped() Then Return False

	If Leveler_ShouldFightHere() Then
		$a_b_Combat = True
		$g_b_CombatMode = True
	ElseIf Map_GetInstanceInfo("IsOutpost") Then
		$a_b_Combat = False
	EndIf

	Local $l_i_StartMap = Map_GetMapID()
	If Wine_IsWine() Then
		If Wine_MapIsLoading() Then
			Out("[Move] Map is loading; not injecting or walking yet")
			Return False
		EndIf
		If Not Wine_EnsureCommandQueue() Then Wine_LogCommandGap()
	EndIf
	; Wine mid-mission: Pathfinder_MoveTo infinite-waits when Agent X,Y are 0,
	; and Initialize can block the GUI thread. Always Map_Move.
	If Not (Wine_IsWine() And Leveler_InMissionInstance()) Then
		Leveler_EnsurePathfinder()
	EndIf

	Local $l_v_Obstacles = 0
	Local $l_i_Aggro = 0
	If $a_b_Combat And Not (Wine_IsWine() And Leveler_InMissionInstance()) Then
		Leveler_PrepareCombatAI()
		$l_v_Obstacles = "Leveler_GetObstacles"
		$l_i_Aggro = $LEVELER_AGGRO
	EndIf

	Local $l_s_Callback = ""
	If $g_b_SpiritRiftWatch Then $l_s_Callback = "Leveler_InterruptSpiritRifts"

	Local $l_b_Ok = False
	; Wine: never Pathfinder_MoveTo. Agent X,Y=0 makes it wait forever and blacks the GUI.
	If Wine_IsWine() Then
		Out("[Move] Wine Map_Move to " & Round($a_f_X) & "," & Round($a_f_Y) & " QueueBase=" & Wine_HexPtr($g_p_QueueBase))
		$l_b_Ok = Leveler_MoveDirect($a_f_X, $a_f_Y, 30000, $a_b_Combat)
	ElseIf Map_GetInstanceInfo("IsOutpost") Or Not Pathfinder_IsMapAvailable($l_i_StartMap) Then
		$l_b_Ok = Leveler_MoveDirect($a_f_X, $a_f_Y, 30000, $a_b_Combat)
	Else
		$l_b_Ok = Pathfinder_MoveTo($a_f_X, $a_f_Y, -1, $l_v_Obstacles, $l_i_Aggro, $LEVELER_FIGHT_RANGE_OUT, 0, $l_s_Callback)
	EndIf

	If Map_GetMapID() <> $l_i_StartMap Then Return True
	If Leveler_IsWiped() Then Return False
	If $g_b_SpiritRiftWatch Then
		Local $l_f_Hx = 0, $l_f_Hy = 0
		Leveler_LiveXY($l_f_Hx, $l_f_Hy)
		If Wine_IsWine() And $l_f_Hx = 0 And $l_f_Hy = 0 Then
			; Agent pos unread — do not block 45s on HoldForTogo from (0,0).
		ElseIf Wine_IsWine() And Leveler_DistToXY($a_f_X, $a_f_Y) >= $LEVELER_ARRIVE_RANGE Then
			; Missed the walk — do not sit in WaitOutOfCombat while pos is frozen.
		Else
			If Not Leveler_WaitOutOfCombat(45000) Then Return False
			If Not Leveler_HoldForTogo() Then Return False
		EndIf
	EndIf
	If Leveler_DistToXY($a_f_X, $a_f_Y) < $LEVELER_ARRIVE_RANGE Then Return True
	If Wine_IsWine() And $l_b_Ok Then Return True
	Return $l_b_Ok
EndFunc

; First non-zero of agent -2, MyID, camera, living Togo. Returns the source name.
Func Leveler_LiveXY(ByRef $a_f_X, ByRef $a_f_Y)
	$a_f_X = Number(Agent_GetAgentInfo(-2, "X"))
	$a_f_Y = Number(Agent_GetAgentInfo(-2, "Y"))
	If $a_f_X <> 0 Or $a_f_Y <> 0 Then Return "agent-2"
	Local $l_i_Me = Number(Agent_GetMyID())
	If $l_i_Me > 0 Then
		$a_f_X = Number(Agent_GetAgentInfo($l_i_Me, "X"))
		$a_f_Y = Number(Agent_GetAgentInfo($l_i_Me, "Y"))
		If $a_f_X <> 0 Or $a_f_Y <> 0 Then Return "agent-myid"
	EndIf
	If IsDeclared("g_p_SceneContext") And Number($g_p_SceneContext) <> 0 Then
		$a_f_X = Number(Camera_GetCameraInfo("X"))
		$a_f_Y = Number(Camera_GetCameraInfo("Y"))
		If $a_f_X <> 0 Or $a_f_Y <> 0 Then Return "camera"
	EndIf
	Local $l_i_Togo = Leveler_FindLivingZenTogoAgent()
	If $l_i_Togo <> 0 Then
		$a_f_X = Number(Agent_GetAgentInfo($l_i_Togo, "X"))
		$a_f_Y = Number(Agent_GetAgentInfo($l_i_Togo, "Y"))
		If $a_f_X <> 0 Or $a_f_Y <> 0 Then Return "togo"
	EndIf
	$a_f_X = 0
	$a_f_Y = 0
	Return "none"
EndFunc

Func Leveler_DistToXY($a_f_X, $a_f_Y)
	Local $l_f_X = 0, $l_f_Y = 0
	Leveler_LiveXY($l_f_X, $l_f_Y)
	If $l_f_X = 0 And $l_f_Y = 0 Then Return 999999
	Local $l_f_Dx = $l_f_X - $a_f_X
	Local $l_f_Dy = $l_f_Y - $a_f_Y
	Return Sqrt($l_f_Dx * $l_f_Dx + $l_f_Dy * $l_f_Dy)
EndFunc

; When a direct Map_Move does not close (collision or a dead stub), walk a
; short hop toward the dest. After a second freeze, step sideways.
Func Leveler_WineStepToward($a_f_DestX, $a_f_DestY, ByRef $a_f_GoX, ByRef $a_f_GoY, $a_i_HopRound)
	$a_f_GoX = $a_f_DestX
	$a_f_GoY = $a_f_DestY
	If $a_i_HopRound < 1 Then Return
	Local $l_f_X = 0, $l_f_Y = 0
	Leveler_LiveXY($l_f_X, $l_f_Y)
	If $l_f_X = 0 And $l_f_Y = 0 Then Return
	Local $l_f_Dx = $a_f_DestX - $l_f_X
	Local $l_f_Dy = $a_f_DestY - $l_f_Y
	Local $l_f_Dist = Sqrt($l_f_Dx * $l_f_Dx + $l_f_Dy * $l_f_Dy)
	If $l_f_Dist <= 650 Then Return
	Local $l_f_Step = 650
	If $a_i_HopRound >= 2 And $l_f_Dist > 0 Then
		Local $l_f_Nx = -$l_f_Dy / $l_f_Dist * 500
		Local $l_f_Ny = $l_f_Dx / $l_f_Dist * 500
		$a_f_GoX = $l_f_X + $l_f_Dx * 0.35 + $l_f_Nx
		$a_f_GoY = $l_f_Y + $l_f_Dy * 0.35 + $l_f_Ny
		Return
	EndIf
	$a_f_GoX = $l_f_X + $l_f_Dx * ($l_f_Step / $l_f_Dist)
	$a_f_GoY = $l_f_Y + $l_f_Dy * ($l_f_Step / $l_f_Dist)
EndFunc

Func Leveler_MoveDirect($a_f_X, $a_f_Y, $a_i_Timeout = 30000, $a_b_Combat = False)
	If Wine_IsWine() And $a_i_Timeout < 45000 Then $a_i_Timeout = 45000
	Local $l_i_StartMap = Map_GetMapID()
	Local $l_h_Timer = TimerInit()
	Local $l_i_LastLog = -5000
	Local $l_i_Moves = 0
	Local $l_f_LastX = 0, $l_f_LastY = 0
	Local $l_b_HavePos = False
	Local $l_h_Stuck = 0
	Local $l_i_HopRound = 0
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Leveler_IsWiped() Then Return False
		If Map_GetMapID() <> $l_i_StartMap Then Return True
		If Leveler_DistToXY($a_f_X, $a_f_Y) < $LEVELER_ARRIVE_RANGE Then Return True
		Local $l_f_X = 0, $l_f_Y = 0
		Local $l_s_Src = Leveler_LiveXY($l_f_X, $l_f_Y)
		If TimerDiff($l_h_Timer) - $l_i_LastLog >= 5000 Then
			Out("[Move] walking map " & $l_i_StartMap & " pos " & Round($l_f_X) & "," & Round($l_f_Y) & _
					" src=" & $l_s_Src & " toward " & Round($a_f_X) & "," & Round($a_f_Y) & _
					" ticks=" & Wine_EngineTickCount())
			If Wine_IsWine() And $l_b_HavePos And Abs($l_f_X - $l_f_LastX) < 40 And Abs($l_f_Y - $l_f_LastY) < 40 Then
				Wine_RefreshCommandMove("pos unchanged across walk logs at " & Round($l_f_X) & "," & Round($l_f_Y))
			EndIf
			$l_i_LastLog = TimerDiff($l_h_Timer)
		EndIf
		; Wine: Agent 0,0 never shrinks distance. After ~12s of live QueueBase moves, count as arrived.
		If Wine_IsWine() And $l_f_X = 0 And $l_f_Y = 0 And TimerDiff($l_h_Timer) >= 12000 And Wine_QueueWalkReady() Then
			Out("[Move] Wine: pos still 0,0 after QueueBase-live moves; treating waypoint as arrived")
			Return True
		EndIf
		If Wine_IsWine() And ($l_f_X <> 0 Or $l_f_Y <> 0) Then
			If Not $l_b_HavePos Then
				$l_h_Stuck = TimerInit()
			Else
				Local $l_f_Stay = Sqrt(($l_f_X - $l_f_LastX) * ($l_f_X - $l_f_LastX) + ($l_f_Y - $l_f_LastY) * ($l_f_Y - $l_f_LastY))
				If $l_f_Stay < 40 Then
					If $l_h_Stuck = 0 Then $l_h_Stuck = TimerInit()
					If TimerDiff($l_h_Stuck) >= 5000 Then
						$l_i_HopRound += 1
						Wine_RefreshCommandMove("pos frozen at " & Round($l_f_X) & "," & Round($l_f_Y) & " for " & $l_i_HopRound)
						$l_h_Stuck = TimerInit()
					EndIf
				Else
					$l_h_Stuck = TimerInit()
					If Leveler_DistToXY($a_f_X, $a_f_Y) < 400 Then $l_i_HopRound = 0
				EndIf
			EndIf
			$l_f_LastX = $l_f_X
			$l_f_LastY = $l_f_Y
			$l_b_HavePos = True
		EndIf
		If $g_b_SpiritRiftWatch And Leveler_TogoNeedsHelp() Then
			Leveler_FightWithTogo()
			; Wine: still enqueue the waypoint. ContinueLoop used to skip Map_Move
			; while standing on Togo, so pos froze at spawn (14283,8757).
			If Not Wine_IsWine() Then
				Sleep(250)
				ContinueLoop
			EndIf
		EndIf
		If $a_b_Combat Then Leveler_CombatTick()
		If Wine_IsWine() Then
			Local $l_f_GoX = $a_f_X, $l_f_GoY = $a_f_Y
			Leveler_WineStepToward($a_f_X, $a_f_Y, $l_f_GoX, $l_f_GoY, $l_i_HopRound)
			If $l_i_HopRound >= 1 And (Round($l_f_GoX) <> Round($a_f_X) Or Round($l_f_GoY) <> Round($a_f_Y)) Then
				If TimerDiff($l_h_Timer) - $l_i_LastLog >= 4000 Then
					Out("[Move] hop " & Round($l_f_GoX) & "," & Round($l_f_GoY) & " toward " & Round($a_f_X) & "," & Round($a_f_Y))
				EndIf
			EndIf
			If Wine_MapMove($l_f_GoX, $l_f_GoY, 20) Then $l_i_Moves += 1
		Else
			Map_Move($a_f_X, $a_f_Y, 20)
			$l_i_Moves += 1
		EndIf
		Sleep(250)
	WEnd
	; Live pos that never closed is a CommandMove/pathing miss, not an arrival.
	Return Leveler_DistToXY($a_f_X, $a_f_Y) < $LEVELER_ARRIVE_RANGE
EndFunc

Func Leveler_MoveAndDialog($a_f_X, $a_f_Y, $a_i_Dialog, $a_b_Combat = False, $a_i_NpcModel = 0)
	Local $l_i_StartMap = Map_GetMapID()
	If Not Leveler_MoveTo($a_f_X, $a_f_Y, $a_b_Combat) And Map_GetMapID() = $l_i_StartMap Then Return False
	If Map_GetMapID() <> $l_i_StartMap Then Return True

	Local $l_i_Npc = Leveler_ResolveTalkNpc($a_f_X, $a_f_Y, $a_i_NpcModel)
	If $l_i_Npc = 0 Then
		Out("[Move] No NPC near " & Round($a_f_X) & ", " & Round($a_f_Y))
		Return False
	EndIf

	Return Leveler_TalkAndDialog($l_i_Npc, $a_i_Dialog)
EndFunc

; Target the living NPC, walk into talk range, then send the dialog.
Func Leveler_TalkAndDialog($a_i_Npc, $a_i_Dialog)
	If $a_i_Npc = 0 Then Return False
	Agent_ChangeTarget($a_i_Npc)
	Sleep(150)
	Agent_GoNPC($a_i_Npc)

	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < 5000
		If Agent_GetDistance($a_i_Npc) < $LEVELER_ARRIVE_RANGE Then ExitLoop
		Sleep(100)
	WEnd
	If Agent_GetDistance($a_i_Npc) >= $LEVELER_ARRIVE_RANGE Then
		Out("[Move] Could not reach NPC model " & Agent_GetAgentInfo($a_i_Npc, "PlayerNumber"))
		Return False
	EndIf

	Sleep(500)
	Ui_Dialog($a_i_Dialog)
	Sleep(600)
	Return True
EndFunc

Func Leveler_MoveAndExit($a_f_X, $a_f_Y, $a_i_MapID, $a_b_Combat = False)
	Local $l_i_StartMap = Map_GetMapID()
	Leveler_MoveTo($a_f_X, $a_f_Y, $a_b_Combat)
	If Map_GetMapID() = $l_i_StartMap Then
		Map_Move($a_f_X, $a_f_Y, 10)
		Sleep(1500)
	EndIf
	Return Map_WaitMapLoading($a_i_MapID)
EndFunc

; Walk the Lost Treasure entrance portal back to Ran Musu. Used when a completed
; Lost Treasure restart dumped the character in Cho explorable with Tengu still open.
Func Leveler_LeaveChoExplorableToRanMusu()
	If Map_GetMapID() = $MAP_RAN_MUSU Then Return True
	If Map_GetMapID() <> $MAP_CHO_EXPLORABLE Then Return True
	If Not Leveler_WaitUntilMapReady() Then Return False
	Out("[Recover] Pathing Lost Treasure exit to Ran Musu Gardens")
	If Not Leveler_EquipTrainerSkills(False) Then Return False
	Sleep(1500)
	$g_b_UAIReady = False
	If Not Leveler_PrepareCombatAI() Then Return False
	If Not Leveler_MoveTo(-17979.38, -493.08, True) Then
		If Map_GetMapID() <> $MAP_CHO_EXPLORABLE Then Return Map_GetMapID() = $MAP_RAN_MUSU
		Out("[Recover] Could not reach the Cho explorable portal")
		Return False
	EndIf
	If Not Leveler_MoveAndExit(-17979.38, -493.08, $MAP_RAN_MUSU, True) Then Return False
	Return Leveler_WaitUntilMapReady()
EndFunc

; $a_b_Rezone True = leave and re-enter the outpost so we spawn at the portal
; instead of pathing across town from the last NPC (bag merchant, crafter, ...).
Func Leveler_Travel($a_i_MapID, $a_b_Rezone = False)
	Local $l_i_Now = Map_GetMapID()
	; Wine: already at Zen 213. InstanceInfo explorable flicker must not resign.
	If Wine_IsWine() And $l_i_Now = $a_i_MapID And $a_i_MapID = $MAP_ZEN_OP Then Return True
	If $l_i_Now = $a_i_MapID And Map_GetInstanceInfo("IsOutpost") Then
		If Not $a_b_Rezone Then Return True
		Out("[Move] Rezoning map " & $a_i_MapID & " to reset position")
		If Map_RndTravel($a_i_MapID, True, True) Then Return True
		Out("[Move] Rezone failed; walking from the current position")
		Return True
	EndIf
	If Map_GetInstanceInfo("IsExplorable") Then
		If Wine_IsWine() And $l_i_Now = $a_i_MapID And $a_i_MapID = $MAP_ZEN_OP Then Return True
		Out("[Move] Leaving explorable map " & $l_i_Now & " to travel to " & $a_i_MapID)
		If Map_TravelTo($a_i_MapID) Then
			If Not Leveler_WaitUntilMapReady() Then Return False
			If Map_GetMapID() = $a_i_MapID Then Return True
		EndIf
		Chat_SendChat("resign", "/")
		Sleep(1200)
		If Party_GetPartyContextInfo("IsDefeated") Then Map_ReturnToOutpost(False)
		Map_WaitMapLoading()
		Sleep(800)
		If Not Leveler_WaitUntilMapReady() Then Return False
	EndIf
	Out("[Move] Travel to map " & $a_i_MapID)
	If Not Map_TravelTo($a_i_MapID) Then Return False
	Return Leveler_WaitUntilMapReady() And Map_GetMapID() = $a_i_MapID
EndFunc

; Destination outpost for the step. Prefer an unlocked town over walking there.
Func Leveler_StepOutpost($a_i_Step)
	Switch $a_i_Step
		Case $LEVELER_STEP_PARTY, $LEVELER_STEP_SECONDARY, $LEVELER_STEP_XUNLAI, $LEVELER_STEP_WEAPON, $LEVELER_STEP_ARMOR, $LEVELER_STEP_DESTROY, $LEVELER_STEP_BAGS, $LEVELER_STEP_SKILLS, $LEVELER_STEP_THREAT, $LEVELER_STEP_ROAD
			Return $MAP_SHING_JEA
		Case $LEVELER_STEP_TO_CHO, $LEVELER_STEP_CHO_MISSION
			If Map_IsMapUnlocked($MAP_CHO_OUTPOST) Then Return $MAP_CHO_OUTPOST
			If $a_i_Step = $LEVELER_STEP_TO_CHO Then Return $MAP_SHING_JEA
			Return $MAP_CHO_OUTPOST
		Case $LEVELER_STEP_ATTR_1, $LEVELER_STEP_TENGU
			Return $MAP_RAN_MUSU
		Case $LEVELER_STEP_SEITUNG, $LEVELER_STEP_DESTROY_MON, $LEVELER_STEP_ATTR_2
			Return $MAP_SEITUNG
		Case $LEVELER_STEP_TO_ZEN
			If Map_IsMapUnlocked($MAP_ZEN_OP) Then Return $MAP_ZEN_OP
			Return $MAP_SEITUNG
		Case $LEVELER_STEP_ZEN_MISSION
			Return $MAP_ZEN_OP
		Case $LEVELER_STEP_TO_MARKET
			If Map_IsMapUnlocked($MAP_MARKETPLACE) Then Return $MAP_MARKETPLACE
			Return $MAP_ZEN_OP
		Case $LEVELER_STEP_TO_KC
			If Map_IsMapUnlocked($MAP_KAINENG) Then Return $MAP_KAINENG
			Return $MAP_MARKETPLACE
		Case $LEVELER_STEP_SKILLS2, $LEVELER_STEP_MAX_ARMOR, $LEVELER_STEP_DESTROY_SEITUNG, $LEVELER_STEP_CURE, $LEVELER_STEP_BURDEN, $LEVELER_STEP_UNLOCK_MOX, $LEVELER_STEP_TO_BOREAL
			Return $MAP_KAINENG
		Case $LEVELER_STEP_TO_EOTN
			If Map_IsMapUnlocked($MAP_EOTN) Then Return $MAP_EOTN
			Return $MAP_BOREAL
		Case $LEVELER_STEP_EOTN_POOL, $LEVELER_STEP_FARM_20, $LEVELER_STEP_TO_GUNNAR
			Return $MAP_EOTN
		Case $LEVELER_STEP_KILROY, $LEVELER_STEP_TO_LA, $LEVELER_STEP_TO_LONGEYE
			If $a_i_Step = $LEVELER_STEP_TO_LA And Map_IsMapUnlocked($MAP_LIONS_ARCH) Then Return $MAP_LIONS_ARCH
			If $a_i_Step = $LEVELER_STEP_TO_LONGEYE And Map_IsMapUnlocked($MAP_LONGEYE) Then Return $MAP_LONGEYE
			Return $MAP_GUNNAR
		Case $LEVELER_STEP_TO_KAMADAN
			If Map_IsMapUnlocked($MAP_KAMADAN) Then Return $MAP_KAMADAN
			Return $MAP_LIONS_ARCH
		Case $LEVELER_STEP_TO_DOCKS
			If Map_IsMapUnlocked($MAP_DOCKS) Then Return $MAP_DOCKS
			Return $MAP_KAMADAN
		Case $LEVELER_STEP_UNLOCK_OLIAS
			Return $MAP_DOCKS
		Case $LEVELER_STEP_UNLOCK_PROFS
			Return $MAP_GTOB
		Case $LEVELER_STEP_UNLOCK_MERCS
			Return $MAP_LIONS_ARCH
		Case $LEVELER_STEP_VAETTIR
			If Map_IsMapUnlocked($MAP_JAGA) Then Return $MAP_JAGA
			Return $MAP_LONGEYE
	EndSwitch
	Return 0
EndFunc

; Stay only if already at the destination outpost or inside that step's instance.
; Approach towns (Sunqua, Jaya, ...) are not enough once the dest outpost is unlocked.
Func Leveler_StepAllowsMap($a_i_Step, $a_i_Map)
	Local $l_i_Outpost = Leveler_StepOutpost($a_i_Step)
	If $l_i_Outpost <> 0 And $a_i_Map = $l_i_Outpost Then Return True
	Switch $a_i_Step
		Case $LEVELER_STEP_OVERLOOK
			Return $a_i_Map = $MAP_MONASTERY_OVERLOOK Or $a_i_Map = 285 Or $a_i_Map = 416
		Case $LEVELER_STEP_PARTY
			Return $a_i_Map = $MAP_SUNQUA_VALE
		Case $LEVELER_STEP_SECONDARY
			Return $a_i_Map = $MAP_LINNOK
		Case $LEVELER_STEP_TO_CHO
			If Map_IsMapUnlocked($MAP_CHO_OUTPOST) Then Return $a_i_Map = $MAP_CHO_OUTPOST
			Return $a_i_Map = $MAP_SHING_JEA Or $a_i_Map = $MAP_SUNQUA_VALE
		Case $LEVELER_STEP_CHO_MISSION
			Return $a_i_Map = $MAP_CHO_OUTPOST Or $a_i_Map = $MAP_RAN_MUSU
		Case $LEVELER_STEP_ATTR_1
			Return $a_i_Map = $MAP_CHO_EXPLORABLE Or $a_i_Map = $MAP_KINYA
		Case $LEVELER_STEP_TENGU
			Return $a_i_Map = $MAP_KINYA Or $a_i_Map = $MAP_CHO_EXPLORABLE Or $a_i_Map = $MAP_RAN_MUSU
		Case $LEVELER_STEP_THREAT
			Return $a_i_Map = $MAP_KINYA Or $a_i_Map = $MAP_SUNQUA_VALE Or $a_i_Map = $MAP_TSUMEI Or $a_i_Map = $MAP_PANJIANG
		Case $LEVELER_STEP_ROAD
			Return $a_i_Map = $MAP_LINNOK Or $a_i_Map = $MAP_SAOSHANG Or $a_i_Map = $MAP_SEITUNG
		Case $LEVELER_STEP_SEITUNG
			Return $a_i_Map = $MAP_SHING_JEA Or $a_i_Map = $MAP_SEITUNG
		Case $LEVELER_STEP_TO_ZEN
			If Map_IsMapUnlocked($MAP_ZEN_OP) Then Return $a_i_Map = $MAP_ZEN_OP
			Return $a_i_Map = $MAP_JAYA Or $a_i_Map = $MAP_HAIJU
		Case $LEVELER_STEP_ZEN_MISSION
			Return $a_i_Map = $MAP_ZEN_EXP Or $a_i_Map = $MAP_ZEN_OP
		Case $LEVELER_STEP_TO_MARKET
			If Map_IsMapUnlocked($MAP_MARKETPLACE) Then Return $a_i_Map = $MAP_MARKETPLACE
			Return $a_i_Map = $MAP_KAINENG_DOCKS
		Case $LEVELER_STEP_TO_KC
			If Map_IsMapUnlocked($MAP_KAINENG) Then Return $a_i_Map = $MAP_KAINENG
			Return $a_i_Map = $MAP_BUKDEK Or $a_i_Map = $MAP_WAJJUN
		Case $LEVELER_STEP_UNLOCK_MOX, $LEVELER_STEP_TO_BOREAL
			Return $a_i_Map = $MAP_TUNNELS
		Case $LEVELER_STEP_TO_EOTN
			If Map_IsMapUnlocked($MAP_EOTN) Then Return $a_i_Map = $MAP_EOTN
			Return $a_i_Map = $MAP_ICE_CLIFF
		Case $LEVELER_STEP_EOTN_POOL
			Return $a_i_Map = $MAP_HOM
		Case $LEVELER_STEP_FARM_20
			Return $a_i_Map = $MAP_HOM Or $a_i_Map = $MAP_AB
		Case $LEVELER_STEP_ATTR_2
			Return $a_i_Map = $MAP_ZEN_EXP
		Case $LEVELER_STEP_TO_GUNNAR
			If Map_IsMapUnlocked($MAP_GUNNAR) Then Return $a_i_Map = $MAP_GUNNAR
			Return $a_i_Map = $MAP_NORRHART
		Case $LEVELER_STEP_KILROY
			Return $a_i_Map = $MAP_KILROY
		Case $LEVELER_STEP_TO_LA
			If Map_IsMapUnlocked($MAP_LIONS_ARCH) Then Return $a_i_Map = $MAP_LIONS_ARCH
			Return $a_i_Map = $MAP_BEJUNKAN Or $a_i_Map = $MAP_LIONS_GATE
		Case $LEVELER_STEP_TO_KAMADAN
			If Map_IsMapUnlocked($MAP_KAMADAN) Then Return $a_i_Map = $MAP_KAMADAN
			Return $a_i_Map = $MAP_KC_SUNSPEARS
		Case $LEVELER_STEP_TO_DOCKS
			If Map_IsMapUnlocked($MAP_DOCKS) Then Return $a_i_Map = $MAP_DOCKS
			Return $a_i_Map = $MAP_SUN_DOCKS Or $a_i_Map = $MAP_CONSULATE
		Case $LEVELER_STEP_UNLOCK_OLIAS
			Return $a_i_Map = $MAP_BLOODSTONE_FEN
		Case $LEVELER_STEP_TO_LONGEYE
			If Map_IsMapUnlocked($MAP_LONGEYE) Then Return $a_i_Map = $MAP_LONGEYE
			Return False
		Case $LEVELER_STEP_VAETTIR
			Return $a_i_Map = $MAP_BJORA Or $a_i_Map = $MAP_JAGA
	EndSwitch
	Return False
EndFunc

; Map-travel to the step outpost. Stay in the explorable if the step's quest is already in the log.
Func Leveler_EnsureStepOutpost($a_i_Step)
	If $a_i_Step = $LEVELER_STEP_DONE Then Return True
	If Wine_IsWine() And Leveler_InMissionInstance() Then Return True
	If Map_GetInstanceInfo("IsLoading") Then Return Leveler_WaitUntilMapReady()
	If Not Leveler_WaitUntilMapReady() Then Return False
	Local $l_i_Map = Map_GetMapID()
	Local $l_i_Outpost = Leveler_StepOutpost($a_i_Step)
	If $l_i_Outpost = 0 Then Return True
	If $l_i_Map = $l_i_Outpost And Map_GetInstanceInfo("IsOutpost") Then Return True
	If $l_i_Map = $l_i_Outpost And Map_GetInstanceInfo("IsExplorable") Then Return True
	If Leveler_InMissionInstance() And Leveler_StepAllowsMap($a_i_Step, $l_i_Map) Then Return True
	If Leveler_StepAllowsMap($a_i_Step, $l_i_Map) Then Return True
	If $g_b_ExplorableResume And Not Leveler_IsOutpost() And Leveler_StepHasActiveQuest($a_i_Step) And Leveler_StepAllowsMap($a_i_Step, $l_i_Map) Then
		Out("[Move] Restart recovery: quest is in the log on map " & $l_i_Map & ". Resuming '" & $g_as_StepNames[$a_i_Step] & "' from here.")
		Return True
	EndIf
	If Not Map_IsMapUnlocked($l_i_Outpost) Then
		Out("[Move] Need map " & $l_i_Outpost & " for '" & $g_as_StepNames[$a_i_Step] & "' but it is not unlocked yet")
		Return True
	EndIf
	Out("[Move] Map-traveling to " & $l_i_Outpost & " for '" & $g_as_StepNames[$a_i_Step] & "' (was map " & $l_i_Map & ")")
	If Not Leveler_Travel($l_i_Outpost) Then
		Out("[Move] Map travel to " & $l_i_Outpost & " failed")
		Return False
	EndIf
	If Map_GetMapID() <> $l_i_Outpost Then
		Out("[Move] Map travel did not arrive at " & $l_i_Outpost & " (now " & Map_GetMapID() & ")")
		Return False
	EndIf
	Return Leveler_WaitUntilMapReady()
EndFunc

Func Leveler_GetAgentByName($a_s_Name)
	Local $l_i_Max = Agent_GetMaxAgents()
	For $i = 1 To $l_i_Max - 1
		If Not Leveler_IsTalkNpc($i) Then ContinueLoop
		If StringInStr(Agent_GetAgentInfo($i, "Name"), $a_s_Name) Then Return $i
	Next
	Return 0
EndFunc

; Town NPCs only. Skip party henchmen/heroes, who are also IsNPC.
Func Leveler_IsTalkNpc($a_i_Agent)
	If $a_i_Agent = 0 Then Return False
	If Agent_GetAgentPtr($a_i_Agent) = 0 Then Return False
	If Agent_GetAgentInfo($a_i_Agent, "IsDead") Then Return False
	If Not Agent_GetAgentInfo($a_i_Agent, "IsNPC") Then Return False
	If Agent_GetAgentInfo($a_i_Agent, "Allegiance") <> $GC_I_ALLEGIANCE_NPC Then Return False
	Return True
EndFunc

; NPC nearest to the player. Prefer Leveler_GetNearestNPCAt for dialogs.
Func Leveler_GetNearestNPC($a_f_Range = 250)
	Return Leveler_GetNearestNPCAt(Agent_GetAgentInfo(-2, "X"), Agent_GetAgentInfo(-2, "Y"), $a_f_Range)
EndFunc

; NPC nearest to a map coordinate, not to the player.
Func Leveler_GetNearestNPCAt($a_f_X, $a_f_Y, $a_f_Range = 250)
	Local $l_i_Best = 0
	Local $l_f_Best = $a_f_Range
	Local $l_i_Max = Agent_GetMaxAgents()
	For $i = 1 To $l_i_Max - 1
		If Not Leveler_IsTalkNpc($i) Then ContinueLoop
		Local $l_f_Dist = Agent_GetDistanceToXY($a_f_X, $a_f_Y, $i)
		If $l_f_Dist < $l_f_Best Then
			$l_f_Best = $l_f_Dist
			$l_i_Best = $i
		EndIf
	Next
	Return $l_i_Best
EndFunc

Func Leveler_GetAgentByModel($a_i_Model)
	If $a_i_Model = 0 Then Return 0
	Local $l_i_Max = Agent_GetMaxAgents()
	For $i = 1 To $l_i_Max - 1
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
		If Agent_GetAgentInfo($i, "PlayerNumber") = $a_i_Model Then Return $i
	Next
	Return 0
EndFunc

Func Leveler_IsTogoModel($a_i_Model)
	If $a_i_Model = $MODEL_TOGO_1 Then Return True
	If $a_i_Model = $MODEL_TOGO_2 Then Return True
	If $a_i_Model = $MODEL_TOGO_3 Then Return True
	If $a_i_Model = $MODEL_TOGO_4 Then Return True
	Return False
EndFunc

; Escort Togo can change allegiance after the dialog. Do not require town-NPC flags.
Func Leveler_GetTogo($a_f_NearX = 0, $a_f_NearY = 0)
	Local $l_i_Best = 0
	Local $l_f_Best = 999999
	Local $l_i_Max = Agent_GetMaxAgents()
	Local $i
	For $i = 1 To $l_i_Max - 1
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
		Local $l_s_Name = Agent_GetAgentInfo($i, "Name")
		Local $l_i_Model = Agent_GetAgentInfo($i, "PlayerNumber")
		If Not Leveler_IsTogoModel($l_i_Model) And StringInStr($l_s_Name, "Togo") = 0 Then ContinueLoop
		If $a_f_NearX = 0 And $a_f_NearY = 0 Then Return $i
		Local $l_f_Dist = Agent_GetDistanceToXY($a_f_NearX, $a_f_NearY, $i)
		If $l_f_Dist < $l_f_Best Then
			$l_f_Best = $l_f_Dist
			$l_i_Best = $i
		EndIf
	Next
	If $l_i_Best <> 0 Then Return $l_i_Best
	If $a_f_NearX <> 0 Or $a_f_NearY <> 0 Then Return Leveler_GetNearestNPCAt($a_f_NearX, $a_f_NearY, 700)
	Return 0
EndFunc

Func Leveler_TogoModel()
	Local $l_i_Togo = Leveler_GetTogo()
	If $l_i_Togo = 0 Then Return 0
	Return Agent_GetAgentInfo($l_i_Togo, "PlayerNumber")
EndFunc

; Gate guards are not always town-NPC allegiance. Match by name, then any living NPC on the tile.
Func Leveler_GetTsukaro()
	Local $l_i_Best = 0
	Local $l_f_Best = 999999
	Local $l_i_Max = Agent_GetMaxAgents()
	Local $l_i_Me = Agent_GetMyID()
	Local $i
	For $i = 1 To $l_i_Max - 1
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If $i = $l_i_Me Then ContinueLoop
		If Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
		If StringInStr(Agent_GetAgentInfo($i, "Name"), "Tsukaro") = 0 Then ContinueLoop
		Local $l_f_Named = Agent_GetDistanceToXY($TSUKARO_LINNOK_X, $TSUKARO_LINNOK_Y, $i)
		If $l_f_Named < $l_f_Best Then
			$l_f_Best = $l_f_Named
			$l_i_Best = $i
		EndIf
	Next
	If $l_i_Best <> 0 Then Return $l_i_Best
	$l_f_Best = 700
	For $i = 1 To $l_i_Max - 1
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If $i = $l_i_Me Then ContinueLoop
		If Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
		If Not Agent_GetAgentInfo($i, "IsNPC") Then ContinueLoop
		Local $l_f_Dist = Agent_GetDistanceToXY($TSUKARO_LINNOK_X, $TSUKARO_LINNOK_Y, $i)
		If $l_f_Dist < $l_f_Best Then
			$l_f_Best = $l_f_Dist
			$l_i_Best = $i
		EndIf
	Next
	If $l_i_Best <> 0 Then Return $l_i_Best
	Return Leveler_GetNearestNPCAt($TSUKARO_LINNOK_X, $TSUKARO_LINNOK_Y, 700)
EndFunc

; Stay on Master Togo until he stops near Guardsman Zui.
Func Leveler_FollowTogo($a_i_Timeout = 180000)
	Local $l_i_StartMap = Map_GetMapID()
	Local $l_h_Timer = TimerInit()
	Local $l_f_LastX = $TOGO_SUNQUA_X
	Local $l_f_LastY = $TOGO_SUNQUA_Y
	Local $l_h_Moved = TimerInit()
	Local $l_i_Togo = Leveler_GetTogo($l_f_LastX, $l_f_LastY)
	If $l_i_Togo <> 0 Then
		$l_f_LastX = Agent_GetAgentInfo($l_i_Togo, "X")
		$l_f_LastY = Agent_GetAgentInfo($l_i_Togo, "Y")
	EndIf
	Out("[Move] Following Master Togo from " & Round($l_f_LastX) & ", " & Round($l_f_LastY))

	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Leveler_IsWiped() Then Return False
		If Map_GetMapID() <> $l_i_StartMap Or Map_GetMapID() = $MAP_CHO_OUTPOST Then
			Out("[Move] Followed Togo to map " & Map_GetMapID())
			Return True
		EndIf

		$l_i_Togo = Leveler_GetTogo($l_f_LastX, $l_f_LastY)
		If $l_i_Togo = 0 Then
			Map_Move($l_f_LastX, $l_f_LastY, 0)
			Sleep(400)
			ContinueLoop
		EndIf

		Local $l_f_X = Agent_GetAgentInfo($l_i_Togo, "X")
		Local $l_f_Y = Agent_GetAgentInfo($l_i_Togo, "Y")
		Local $l_f_Dist = Agent_GetDistance($l_i_Togo)
		$l_f_LastX = $l_f_X
		$l_f_LastY = $l_f_Y

		If $l_f_Dist > 180 Then
			Map_Move($l_f_X, $l_f_Y, 0)
			If $l_f_Dist > 450 Then Agent_GoNPC($l_i_Togo)
		EndIf

		Local $l_f_Zui = Agent_GetDistanceToXY($ZUI_SUNQUA_X, $ZUI_SUNQUA_Y, $l_i_Togo)
		If $l_f_Zui < 400 And $l_f_Dist < 350 Then
			Out("[Move] Togo reached Guardsman Zui")
			Return True
		EndIf

		If TimerDiff($l_h_Moved) > 4000 Then
			Out("[Move] Togo at " & Round($l_f_X) & ", " & Round($l_f_Y) & " dist " & Round($l_f_Dist))
			$l_h_Moved = TimerInit()
		EndIf
		Sleep(250)
	WEnd

	Out("[Move] Follow Togo timed out on map " & Map_GetMapID())
	Return Agent_GetDistanceToXY($ZUI_SUNQUA_X, $ZUI_SUNQUA_Y) < 500 Or Map_GetMapID() <> $l_i_StartMap
EndFunc

Func Leveler_GetQuestNpcAt($a_f_X, $a_f_Y, $a_f_Range = 500)
	Local $l_i_Best = 0
	Local $l_f_Best = $a_f_Range
	Local $l_i_Marked = 0
	Local $l_f_Marked = $a_f_Range
	Local $l_i_Max = Agent_GetMaxAgents()
	For $i = 1 To $l_i_Max - 1
		If Not Leveler_IsTalkNpc($i) Then ContinueLoop
		Local $l_f_Dist = Agent_GetDistanceToXY($a_f_X, $a_f_Y, $i)
		If $l_f_Dist >= $a_f_Range Then ContinueLoop
		If Agent_GetAgentInfo($i, "HasQuest") And $l_f_Dist < $l_f_Marked Then
			$l_f_Marked = $l_f_Dist
			$l_i_Marked = $i
		EndIf
		If $l_f_Dist < $l_f_Best Then
			$l_f_Best = $l_f_Dist
			$l_i_Best = $i
		EndIf
	Next
	If $l_i_Marked <> 0 Then Return $l_i_Marked
	Return $l_i_Best
EndFunc

Func Leveler_ResolveTalkNpc($a_f_X, $a_f_Y, $a_i_NpcModel = 0)
	Local $l_i_Npc = 0
	If $a_i_NpcModel <> 0 Then $l_i_Npc = Leveler_GetAgentByModel($a_i_NpcModel)
	If $l_i_Npc = 0 Then $l_i_Npc = Leveler_GetQuestNpcAt($a_f_X, $a_f_Y, 500)
	If $l_i_Npc = 0 Then $l_i_Npc = Leveler_GetNearestNPCAt($a_f_X, $a_f_Y, 400)
	Return $l_i_Npc
EndFunc

Func Leveler_InteractNpcAt($a_f_X, $a_f_Y, $a_b_Combat = False)
	If Not Leveler_MoveTo($a_f_X, $a_f_Y, $a_b_Combat) Then Return False
	Local $l_i_Npc = Leveler_ResolveTalkNpc($a_f_X, $a_f_Y)
	If $l_i_Npc = 0 Then Return False
	Agent_ChangeTarget($l_i_Npc)
	Sleep(150)
	Agent_GoNPC($l_i_Npc)
	Sleep(800)
	Return True
EndFunc

Func Leveler_ZenTogoIsDead()
	If Not $g_b_SpiritRiftWatch And Not Leveler_WineLooksInZenMission() Then Return False
	If Not Leveler_AgentMemoryLive() Then Return False
	If Agent_GetAgentInfo(-2, "X") = 0 And Agent_GetAgentInfo(-2, "Y") = 0 Then Return False
	Local $l_i_Max = Agent_GetMaxAgents()
	Local $i
	For $i = 1 To $l_i_Max - 1
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If Not Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
		Local $l_s_Name = Agent_GetAgentInfo($i, "Name")
		Local $l_i_Model = Agent_GetAgentInfo($i, "PlayerNumber")
		If $l_s_Name = "" And Not Leveler_IsTogoModel($l_i_Model) Then ContinueLoop
		If Leveler_IsTogoModel($l_i_Model) Or StringInStr($l_s_Name, "Togo") Then Return True
	Next
	Return False
EndFunc

Func Leveler_IsWiped()
	If Leveler_MapLooksConnecting() Then Return False
	; Wine: living Togo agent or a clearly-alive player is not a wipe.
	; Hench slots are empty in Zen; stale IsDefeated / Party_IsWiped must not resign.
	If Wine_IsWine() Then
		If Leveler_WinePlayerClearlyAlive() Then Return False
		If Leveler_PartyHasZenMissionAllies() Then
			If Not Leveler_AgentMemoryLive() Then Return False
			If Agent_GetAgentInfo(-2, "X") = 0 And Agent_GetAgentInfo(-2, "Y") = 0 Then Return False
			If Not Agent_GetAgentInfo(-2, "IsDead") Then Return False
			If Not Leveler_ZenTogoIsDead() Then Return False
			Return True
		EndIf
		If Not Leveler_AgentMemoryLive() Then Return False
		If Agent_GetAgentInfo(-2, "X") = 0 And Agent_GetAgentInfo(-2, "Y") = 0 Then Return False
	EndIf
	If Not Leveler_AgentMemoryLive() Then Return False
	If Party_GetPartyContextInfo("IsDefeated") Then Return True
	If Party_IsWiped() Then Return True
	If Leveler_ZenTogoIsDead() Then Return True
	Return False
EndFunc

; Dynamic obstacles for Pathfinder_MoveTo. Living enemies in detection range.
Func Leveler_GetObstacles($a_f_Radius = 100, $a_f_DetectionRange = 4000)
	Local $l_i_MyID = Agent_GetMyID()
	Local $l_i_Max = Agent_GetMaxAgents()
	Local $l_i_Count = 0
	Local $l_af_Obs[1][3]
	Local $i
	For $i = 1 To $l_i_Max - 1
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
		If Agent_GetAgentInfo($i, "Allegiance") <> $GC_I_ALLEGIANCE_ENEMY Then ContinueLoop
		If Agent_GetDistance($i, $l_i_MyID) > $a_f_DetectionRange Then ContinueLoop
		ReDim $l_af_Obs[$l_i_Count + 1][3]
		$l_af_Obs[$l_i_Count][0] = Agent_GetAgentInfo($i, "X")
		$l_af_Obs[$l_i_Count][1] = Agent_GetAgentInfo($i, "Y")
		$l_af_Obs[$l_i_Count][2] = $a_f_Radius
		$l_i_Count += 1
	Next
	If $l_i_Count = 0 Then Return 0
	Return $l_af_Obs
EndFunc

; One UtilityAI fight tick at the player's current position.
Func Leveler_CombatTick()
	If Not Leveler_ShouldFightHere() Then Return
	If Not Leveler_PrepareCombatAI() Then Return
	If $g_b_SpiritRiftWatch Then
		Leveler_InterruptSpiritRifts()
		If Leveler_TogoNeedsHelp() Then
			Leveler_FightWithTogo()
			Return
		EndIf
	EndIf
	UAI_Fight(Agent_GetAgentInfo(-2, "X"), Agent_GetAgentInfo(-2, "Y"), $LEVELER_AGGRO, $LEVELER_FIGHT_RANGE_OUT)
EndFunc

Func Leveler_EnemiesNearAgent($a_i_Agent, $a_f_Range = 900)
	If $a_i_Agent = 0 Then Return False
	Local $l_i_Max = Agent_GetMaxAgents()
	Local $i
	For $i = 1 To $l_i_Max - 1
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
		If Agent_GetAgentInfo($i, "Allegiance") <> $GC_I_ALLEGIANCE_ENEMY Then ContinueLoop
		If Agent_GetDistance($i, $a_i_Agent) < $a_f_Range Then Return True
	Next
	Return False
EndFunc

; Togo must survive Zen. Stay on him when he is pulled, low, or left behind.
Func Leveler_TogoNeedsHelp()
	Local $l_i_Togo = Leveler_GetTogo()
	If $l_i_Togo = 0 Then Return False
	Local $l_f_HP = Number(Agent_GetAgentInfo($l_i_Togo, "HP"))
	If $l_f_HP > 0 And $l_f_HP <= 0.65 Then Return True
	Local $l_f_Mx = 0, $l_f_My = 0
	Leveler_LiveXY($l_f_Mx, $l_f_My)
	If $l_f_Mx = 0 And $l_f_My = 0 Then Return Leveler_EnemiesNearAgent($l_i_Togo, 900)
	If Agent_GetDistance($l_i_Togo) > 850 Then Return True
	Return Leveler_EnemiesNearAgent($l_i_Togo, 900)
EndFunc

Func Leveler_FightWithTogo()
	If Not Leveler_ShouldFightHere() Then Return
	If Not Leveler_PrepareCombatAI() Then Return
	Leveler_InterruptSpiritRifts()
	Local $l_i_Togo = Leveler_GetTogo()
	Local $l_f_X = Agent_GetAgentInfo(-2, "X")
	Local $l_f_Y = Agent_GetAgentInfo(-2, "Y")
	If $l_i_Togo <> 0 Then
		$l_f_X = Agent_GetAgentInfo($l_i_Togo, "X")
		$l_f_Y = Agent_GetAgentInfo($l_i_Togo, "Y")
		If Agent_GetDistance($l_i_Togo) > 400 Then
			If Wine_IsWine() Then
				Wine_MapMove($l_f_X, $l_f_Y, 20)
			Else
				Map_Move($l_f_X, $l_f_Y, 20)
			EndIf
		EndIf
	EndIf
	UAI_Fight($l_f_X, $l_f_Y, $LEVELER_AGGRO, $LEVELER_FIGHT_RANGE_OUT)
EndFunc

Func Leveler_HoldForTogo($a_i_Timeout = 25000)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Leveler_IsWiped() Then Return False
		Local $l_i_Togo = Leveler_GetTogo()
		If $l_i_Togo = 0 Then Return True
		If Agent_GetDistance($l_i_Togo) < 700 And Not Leveler_TogoNeedsHelp() And Not Leveler_InDanger($LEVELER_AGGRO) Then Return True
		Leveler_FightWithTogo()
		Sleep(250)
	WEnd
	Return Not Leveler_IsWiped()
EndFunc

Func Leveler_WaitCombat($a_i_Ms)
	If Not Leveler_ShouldFightHere() Then
		Sleep($a_i_Ms)
		Return True
	EndIf
	Leveler_PrepareCombatAI()
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Ms
		If $g_b_LevelerPaused Then Return False
		If Leveler_IsWiped() Then Return False
		Leveler_CombatTick()
		Sleep(50)
	WEnd
	Return True
EndFunc

Func Leveler_InDanger($a_f_Range = $LEVELER_AGGRO)
	Local $l_i_MyID = Agent_GetMyID()
	Local $l_i_Max = Agent_GetMaxAgents()
	For $i = 1 To $l_i_Max - 1
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
		If Agent_GetAgentInfo($i, "Allegiance") <> $GC_I_ALLEGIANCE_ENEMY Then ContinueLoop
		If Agent_GetDistance($i, $l_i_MyID) < $a_f_Range Then Return True
	Next
	Return False
EndFunc

Func Leveler_WaitOutOfCombat($a_i_Timeout = 120000)
	Local $l_h_Timer = TimerInit()
	Local $l_h_Clear = 0
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Leveler_IsWiped() Then Return False
		If $g_b_SpiritRiftWatch Then Leveler_InterruptSpiritRifts()
		If Not Leveler_InDanger($LEVELER_AGGRO) Then
			If $l_h_Clear = 0 Then $l_h_Clear = TimerInit()
			If TimerDiff($l_h_Clear) >= 2000 Then Return True
		Else
			$l_h_Clear = 0
			Leveler_CombatTick()
		EndIf
		Sleep(250)
	WEnd
	Return Not Leveler_InDanger($LEVELER_AGGRO)
EndFunc

Func Leveler_WaitUntilModelHasQuest($a_i_Model, $a_i_Timeout = 180000)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Leveler_IsWiped() Then Return False
		Local $l_i_Npc = Leveler_GetAgentByModel($a_i_Model)
		If $l_i_Npc <> 0 And Agent_GetAgentInfo($l_i_Npc, "HasQuest") Then Return True
		Sleep(400)
	WEnd
	Out("[Move] Timed out waiting for model " & $a_i_Model & " quest marker")
	Return False
EndFunc

Func Leveler_LostTreasureAtRouteEnd($a_i_Npc = 0)
	If Leveler_InDanger($LEVELER_SPIRIT_RANGE) Then Return False
	If Agent_GetDistanceToXY($LOST_CHO_END_X, $LOST_CHO_END_Y) < 800 Then Return True
	If $a_i_Npc = 0 Then $a_i_Npc = Leveler_GetAgentByModel($MODEL_LOST_TREASURE_GUARD)
	If $a_i_Npc = 0 Then Return False
	Local $l_f_NpcX = Agent_GetAgentInfo($a_i_Npc, "X")
	Local $l_f_NpcY = Agent_GetAgentInfo($a_i_Npc, "Y")
	If Sqrt(($l_f_NpcX - $LOST_CHO_END_X) ^ 2 + ($l_f_NpcY - $LOST_CHO_END_Y) ^ 2) < 800 Then Return True
	Return False
EndFunc

; True if this character is already at Raitahn Nem's hand-in after a disconnect or script stop.
Func Leveler_NearLostTreasureHandIn($a_f_Range = $LOST_CHO_END_RANGE)
	If Map_GetMapID() <> $MAP_CHO_EXPLORABLE Then Return False
	If Agent_GetDistanceToXY($LOST_CHO_END_X, $LOST_CHO_END_Y) < $a_f_Range Then Return True
	Local $l_i_Npc = Leveler_GetAgentByModel($MODEL_LOST_TREASURE_GUARD)
	If $l_i_Npc = 0 Then Return False
	Local $l_f_NpcX = Agent_GetAgentInfo($l_i_Npc, "X")
	Local $l_f_NpcY = Agent_GetAgentInfo($l_i_Npc, "Y")
	If Sqrt(($l_f_NpcX - $LOST_CHO_END_X) ^ 2 + ($l_f_NpcY - $LOST_CHO_END_Y) ^ 2) >= 800 Then Return False
	Return Agent_GetDistance($l_i_Npc) < $a_f_Range
EndFunc

; Follow Raitahn Nem to 20660.90, -9207.07. Do not stop for pickup, start dialog, or a mid-route pause.
Func Leveler_FollowLostTreasurePath($a_i_Timeout = 600000)
	Out("[Path] Follow Raitahn Nem to " & Round($LOST_CHO_END_X) & ", " & Round($LOST_CHO_END_Y))
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Leveler_IsWiped() Then Return False
		Local $l_i_Npc = Leveler_GetAgentByModel($MODEL_LOST_TREASURE_GUARD)
		If Leveler_LostTreasureAtRouteEnd($l_i_Npc) Then
			Out("[Path] Reached Raitahn Nem's final location")
			Return True
		EndIf
		If $l_i_Npc = 0 Then
			If Leveler_ShouldFightHere() Then
				If Not Leveler_PrepareCombatAI() Then Return False
				UAI_UseSkills(Agent_GetAgentInfo(-2, "X"), Agent_GetAgentInfo(-2, "Y"), $LEVELER_AGGRO, $LEVELER_FIGHT_RANGE_OUT)
			EndIf
			Map_Move($LOST_CHO_END_X, $LOST_CHO_END_Y, 20)
			Sleep(400)
			ContinueLoop
		EndIf
		If Agent_GetDistance($l_i_Npc) > $LEVELER_AREA_RANGE Then
			If Leveler_ShouldFightHere() Then
				If Not Leveler_PrepareCombatAI() Then Return False
				UAI_UseSkills(Agent_GetAgentInfo(-2, "X"), Agent_GetAgentInfo(-2, "Y"), $LEVELER_AGGRO, $LEVELER_FIGHT_RANGE_OUT)
			EndIf
			Map_Move(Agent_GetAgentInfo($l_i_Npc, "X"), Agent_GetAgentInfo($l_i_Npc, "Y"), 20)
		Else
			Leveler_CombatTick()
		EndIf
		Sleep(250)
	WEnd
	Out("[Path] Follow timed out. Moving to Raitahn Nem's final location.")
	Return True
EndFunc

Func Leveler_GetNearestGadget($a_f_Range = 400)
	Local $l_i_MyID = Agent_GetMyID()
	Local $l_i_Best = 0
	Local $l_f_Best = $a_f_Range
	Local $l_i_Max = Agent_GetMaxAgents()
	For $i = 1 To $l_i_Max - 1
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If Not Agent_GetAgentInfo($i, "IsGadgetType") Then ContinueLoop
		Local $l_f_Dist = Agent_GetDistance($i, $l_i_MyID)
		If $l_f_Dist < $l_f_Best Then
			$l_f_Best = $l_f_Dist
			$l_i_Best = $i
		EndIf
	Next
	Return $l_i_Best
EndFunc

Func Leveler_InteractGadgetAt($a_f_X, $a_f_Y, $a_b_Combat = False)
	If Not Leveler_MoveTo($a_f_X, $a_f_Y, $a_b_Combat) Then Return False
	Local $l_i_Gadget = Leveler_GetNearestGadget(400)
	If $l_i_Gadget = 0 Then
		Out("[Move] No gadget near " & Round($a_f_X) & ", " & Round($a_f_Y))
		Return False
	EndIf
	Agent_GoSignpost($l_i_Gadget)
	Sleep(800)
	Return True
EndFunc

Func Leveler_GetGroundItemByModel($a_i_Model, $a_f_Range = 2500)
	Local $l_i_MyID = Agent_GetMyID()
	Local $l_i_Best = 0
	Local $l_f_Best = $a_f_Range
	Local $l_i_Max = Agent_GetMaxAgents()
	For $i = 1 To $l_i_Max - 1
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If Not Agent_GetAgentInfo($i, "IsItemType") Then ContinueLoop
		If Not Agent_GetAgentInfo($i, "CanPickUp") Then ContinueLoop
		Local $l_i_ItemID = Agent_GetAgentInfo($i, "ItemID")
		If $l_i_ItemID = 0 Then ContinueLoop
		If $a_i_Model <> 0 And Item_GetItemInfoByItemID($l_i_ItemID, "ModelID") <> $a_i_Model Then ContinueLoop
		Local $l_f_Dist = Agent_GetDistance($i, $l_i_MyID)
		If $l_f_Dist < $l_f_Best Then
			$l_f_Best = $l_f_Dist
			$l_i_Best = $i
		EndIf
	Next
	Return $l_i_Best
EndFunc

Func Leveler_LootNearby($a_i_Model = 0, $a_f_Range = 2000, $a_i_Timeout = 10000)
	Local $l_h_Timer = TimerInit()
	Local $l_i_Picked = 0
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If Leveler_IsWiped() Then Return False
		Local $l_i_Agent = Leveler_GetGroundItemByModel($a_i_Model, $a_f_Range)
		If $l_i_Agent = 0 Then ExitLoop
		If Agent_GetDistance($l_i_Agent) > $LEVELER_ARRIVE_RANGE Then
			Map_Move(Agent_GetAgentInfo($l_i_Agent, "X"), Agent_GetAgentInfo($l_i_Agent, "Y"), 20)
			Sleep(250)
		EndIf
		Item_PickUpItem($l_i_Agent)
		Sleep(400)
		$l_i_Picked += 1
	WEnd
	If $l_i_Picked > 0 Then Out("[Move] Looted " & $l_i_Picked & " item(s)")
	Return True
EndFunc

Func Leveler_InterruptSpiritRifts()
	If Map_GetMapID() <> $MAP_ZEN_OP And Leveler_LiveMapID() <> $MAP_ZEN_EXP And Map_GetMapID() <> $MAP_ZEN_EXP Then Return
	If $g_h_RiftCooldown <> 0 And TimerDiff($g_h_RiftCooldown) < 1000 Then Return

	Local $l_i_Max = Agent_GetMaxAgents()
	For $i = 1 To $l_i_Max - 1
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
		If Agent_GetAgentInfo($i, "Allegiance") <> $GC_I_ALLEGIANCE_ENEMY Then ContinueLoop
		If Agent_GetAgentInfo($i, "Skill") <> $SKILL_SPIRIT_RIFT Then ContinueLoop

		Local $l_ai_Skills[4] = [$SKILL_CRY_OF_FRUSTRATION, $SKILL_POWER_DRAIN, $SKILL_SIGNET_OF_DISRUPTION, $SKILL_LEECH_SIGNET]
		For $s = 0 To 3
			Local $l_i_Slot = Skill_GetSlotByID($l_ai_Skills[$s])
			If $l_i_Slot > 0 Then
				Agent_ChangeTarget($i)
				Skill_UseSkill($l_i_Slot, $i)
				$g_h_RiftCooldown = TimerInit()
				Return
			EndIf
		Next
	Next
EndFunc

Func Leveler_TalkModel($a_i_Model, $a_i_Dialog)
	Local $l_i_Npc = Leveler_GetAgentByModel($a_i_Model)
	If $l_i_Npc = 0 Then $l_i_Npc = Leveler_GetNearestNPC(400)
	If $l_i_Npc = 0 Then
		Out("[Move] No NPC for model " & $a_i_Model)
		Return False
	EndIf
	Agent_GoNPC($l_i_Npc)
	Sleep(800)
	Ui_Dialog($a_i_Dialog)
	Sleep(600)
	Return True
EndFunc

Func Leveler_WaitUntilInCombat($a_i_Timeout = 60000)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Leveler_IsWiped() Then Return False
		If Leveler_InDanger($LEVELER_AGGRO) Then Return True
		Sleep(250)
	WEnd
	Return Leveler_InDanger($LEVELER_AGGRO)
EndFunc

Func Leveler_WaitCinematic($a_i_Timeout = 30000)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If Game_GetGameInfo("IsCinematic") Then
			Sleep(500)
			ContinueLoop
		EndIf
		If TimerDiff($l_h_Timer) > 1500 Then Return True
		Sleep(200)
	WEnd
	Return True
EndFunc

Func Leveler_HasKeiranBow()
	If Item_FindItemByModelID($MODEL_KEIRAN_BOW) <> 0 Then Return True
	If Item_GetInventoryInfo("WeaponSet0WeaponModelID") = $MODEL_KEIRAN_BOW Then Return True
	If Item_GetInventoryInfo("WeaponSet1WeaponModelID") = $MODEL_KEIRAN_BOW Then Return True
	Return False
EndFunc

Func Leveler_EquipKeiranBow()
	If Not Leveler_HasKeiranBow() Then
		Out("[Farm] Getting Keiran's Bow from Gwen")
		If Not Leveler_MoveAndDialog(-6583.00, 6672.00, $DIALOG_KEIRAN_BOW, False) Then Return False
		Sleep(800)
	EndIf
	Local $l_i_Bow = Item_FindItemByModelID($MODEL_KEIRAN_BOW)
	If $l_i_Bow <> 0 Then Item_EquipItem($l_i_Bow)
	Sleep(400)
	Return True
EndFunc

; Open Keiran's HotN dialog and enter Auspicious Beginnings (first button + 0xE).
Func Leveler_EnterAbQuest()
	Local $l_i_Attempt
	For $l_i_Attempt = 1 To 4
		If Map_GetMapID() = $MAP_AB Then Return True
		If Not Leveler_InteractNpcAt(-6662.00, 6584.00, False) Then
			Sleep(400)
			ContinueLoop
		EndIf
		Sleep(700)
		; Prefer the documented first-button + 0xE pattern, then nearby IDs.
		Local $l_ai_Dialogs[8] = [0x98, 0x8F, 0x97, 0x99, 0x9A, 0x8E, 0x90, 0x81]
		Local $d
		For $d = 0 To UBound($l_ai_Dialogs) - 1
			Ui_Dialog($l_ai_Dialogs[$d])
			Sleep(600)
			If Map_GetMapID() <> $MAP_HOM Then ExitLoop
		Next
		If Map_WaitMapLoading($MAP_AB, -1, 15000) Then Return True
	Next
	Out("[Farm] Failed to enter Auspicious Beginnings")
	Return False
EndFunc

Func Leveler_PlayerLevel()
	Local $l_i_Level = Agent_GetAgentInfo(-2, "Level")
	If $l_i_Level = 0 Then $l_i_Level = Party_GetPartyProfessionInfo(-2, "Level")
	Return $l_i_Level
EndFunc

Func Leveler_FollowCoords(ByRef $a_af_Path, $a_b_Combat = False)
	Local $l_i_StartMap = Map_GetMapID()
	Local $i
	For $i = 0 To UBound($a_af_Path) - 1
		If $g_b_LevelerPaused Then Return False
		If Leveler_IsWiped() Then Return False
		If $g_b_KilroyMode Then Leveler_HandleKilroyDeath()
		If Map_GetMapID() <> $l_i_StartMap Then Return True
		Leveler_MoveTo($a_af_Path[$i][0], $a_af_Path[$i][1], $a_b_Combat)
	Next
	Return Not Leveler_IsWiped()
EndFunc

Func Leveler_WaitMs($a_i_Ms)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Ms
		If $g_b_LevelerPaused Then Return False
		If Leveler_IsWiped() Then Return False
		If $g_b_KilroyMode Then Leveler_HandleKilroyDeath()
		Sleep(250)
	WEnd
	Return True
EndFunc

Func Leveler_CombatBurst($a_i_Ms)
	$g_b_CombatMode = True
	Return Leveler_WaitMs($a_i_Ms)
EndFunc

Func Leveler_WaitUntilOutpost($a_i_Timeout = 180000)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If $g_b_KilroyMode Then Leveler_HandleKilroyDeath()
		If Map_GetInstanceInfo("IsOutpost") Then Return True
		If Leveler_IsWiped() And Not $g_b_KilroyMode Then Return False
		Sleep(400)
	WEnd
	Return Map_GetInstanceInfo("IsOutpost")
EndFunc

Func Leveler_WaitForMap($a_i_MapID, $a_i_Timeout = 45000)
	If Map_GetMapID() = $a_i_MapID Then Return True
	Return Map_WaitMapLoading($a_i_MapID, -1, $a_i_Timeout)
EndFunc

; After a disconnect the client can sit on a loading / zero map. Wait until we can act.
Func Leveler_ClientIsReady()
	If Map_GetMapID() <= 0 Then Return False
	If Leveler_MapLooksConnecting() Then Return False
	If Map_GetInstanceInfo("IsLoading") And Leveler_InstanceInfoTrusted() Then Return False
	If Wine_IsWine() Then
		If Leveler_InMissionInstance() Then Return True
		If Map_GetInstanceInfo("IsOutpost") Or Map_GetInstanceInfo("IsExplorable") Then Return True
		; Partial Core_Initialize: a live map id is enough. AgentBase=0 is not a DC.
		Return True
	EndIf
	If Agent_GetAgentPtr(-2) = 0 Then Return False
	If Agent_GetAgentInfo(-2, "X") = 0 And Agent_GetAgentInfo(-2, "Y") = 0 Then Return False
	Return True
EndFunc

Func Leveler_ClientDisconnected()
	If Map_GetMapID() <= 0 Then Return True
	; Wine: AgentBase=0 with a live map id is a scan gap, not a disconnect.
	If Wine_IsWine() And Map_GetMapID() > 0 Then Return False
	If Agent_GetAgentPtr(-2) = 0 And Not Map_GetInstanceInfo("IsLoading") Then Return True
	Return False
EndFunc

; Drop the old path and continue from the live character XY after a reconnect.
Func Leveler_ResumeFromCurrentPosition()
	Pathfinder_Shutdown()
	$g_b_UAIReady = False
	$g_i_LastUAIMap = 0
	If Not Leveler_ClientIsReady() Then Return False
	Local $l_i_Map = Map_GetMapID()
	Local $l_f_X = Agent_GetAgentInfo(-2, "X")
	Local $l_f_Y = Agent_GetAgentInfo(-2, "Y")
	Out("[Recover] Connection resumed. Map " & $l_i_Map & "  Pos " & Round($l_f_X) & ", " & Round($l_f_Y) & ". Continuing from here.")
	Sleep(2000)
	If Map_GetInstanceInfo("IsExplorable") Then Leveler_PrepareCombatAI()
	$g_b_ConnectionLost = False
	Return True
EndFunc

Func Leveler_WaitUntilMapReady($a_i_Timeout = 45000)
	Local $l_b_Dropped = Leveler_ClientDisconnected()
	If $l_b_Dropped Then $g_b_ConnectionLost = True
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Leveler_ClientDisconnected() Then $g_b_ConnectionLost = True
		If Leveler_ClientIsReady() Then
			If $g_b_ConnectionLost Then Return Leveler_ResumeFromCurrentPosition()
			Return True
		EndIf
		Sleep(250)
	WEnd
	If Leveler_ClientIsReady() Then
		If $g_b_ConnectionLost Then Return Leveler_ResumeFromCurrentPosition()
		Return True
	EndIf
	Return False
EndFunc

Func Leveler_EquipItemByModel($a_i_Model)
	Local $l_i_Item = Item_FindItemByModelID($a_i_Model)
	If $l_i_Item = 0 Then
		Out("[Move] Item model " & $a_i_Model & " not in inventory")
		Return False
	EndIf
	Item_EquipItem($l_i_Item)
	Sleep(400)
	Return True
EndFunc

; Punchout death: refill energy with slot 8 unless max energy is already high, then bail to Gunnar's.
Func Leveler_HandleKilroyDeath()
	If Not $g_b_KilroyMode Then Return False
	If Not Agent_GetAgentInfo(-2, "IsDead") Then Return False

	Local $l_i_MaxEnergy = Agent_GetAgentInfo(-2, "MaxEnergy")
	If $l_i_MaxEnergy >= 80 Then
		Out("[Kilroy] High-energy death. Returning to Gunnar's Hold.")
		$g_b_KilroyMode = False
		Sleep(800)
		If Not Leveler_Travel($MAP_GUNNAR) Then
			Chat_SendChat("resign", "/")
			Sleep(1200)
			If Party_GetPartyContextInfo("IsDefeated") Then Map_ReturnToOutpost(False)
			Map_WaitMapLoading()
		EndIf
		Return True
	EndIf

	Local $l_h_Timer = TimerInit()
	While Agent_GetAgentInfo(-2, "EnergyPercent") < 0.999 And TimerDiff($l_h_Timer) < 20000
		Skill_UseSkill(8)
		Sleep(40)
	WEnd
	Return False
EndFunc

Func Leveler_RecoverWipe()
	$g_b_SpiritRiftWatch = False
	If $g_b_KilroyMode Then
		Out("[Recover] Wiped during Kilroy. Returning to Gunnar's Hold.")
		$g_b_KilroyMode = False
		Sleep(2000)
		If Map_GetMapID() <> $MAP_GUNNAR Then
			If Not Leveler_Travel($MAP_GUNNAR) Then
				Chat_SendChat("resign", "/")
				Sleep(1200)
				If Party_GetPartyContextInfo("IsDefeated") Then Map_ReturnToOutpost(False)
				Map_WaitMapLoading()
			EndIf
		EndIf
		Out("[Recover] Kilroy wipe handled. Retrying Punch the Clown.")
		Return True
	EndIf
	If $g_b_FarmMode Then
		Out("[Recover] Wiped during AB farm. Waiting, then returning to Eye of the North.")
		Sleep(8000)
		If Map_GetMapID() <> $MAP_EOTN And Map_GetMapID() <> $MAP_HOM Then
			If Not Leveler_Travel($MAP_EOTN) Then
				Chat_SendChat("resign", "/")
				Sleep(1200)
				If Party_GetPartyContextInfo("IsDefeated") Then Map_ReturnToOutpost(False)
				Map_WaitMapLoading()
			EndIf
		EndIf
		Out("[Recover] Farm wipe handled. Retrying AB prepare.")
		Return True
	EndIf

	Return Leveler_ReturnWipeToOutpost()
EndFunc

; True once we are sitting in the mission outpost (213 / 214), not Connecting and not still in the instance.
Func Leveler_AtWipeOutpost()
	If Leveler_MapLooksConnecting() Then Return False
	; 213 with Togo is the Zen instance, not the outpost after a wipe.
	If Leveler_PartyHasZenMissionAllies() Or Leveler_InMissionInstance() Then Return False
	Local $l_i_Map = Map_GetMapID()
	If $l_i_Map <= 0 Then Return False
	If Leveler_InstanceInfoTrusted() And Map_GetInstanceInfo("IsOutpost") Then Return True
	If Leveler_InMissionInstance() Then Return False
	If Number(Map_GetCharacterInfo("CurrentMapType")) = 2 Then Return False
	If $l_i_Map = $MAP_ZEN_OP Or $l_i_Map = $MAP_CHO_OUTPOST Or $l_i_Map = $MAP_SEITUNG Then
		If Number(Map_GetCharacterInfo("CurrentMapType")) = 0 Then Return True
		If Number(Map_GetCharacterInfo("IsExplorable")) = 0 And Not Leveler_HasMissionObjectives() Then Return True
	EndIf
	Return False
EndFunc

; Wait for the outpost after a wipe. Do not send travel/return packets here.
Func Leveler_WaitReturnToOutpost($a_i_Timeout = 90000)
	Local $l_h_Timer = TimerInit()
	Local $l_i_LastLog = -8000
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Game_GetGameInfo("IsCinematic") Then
			Cinematic_SkipCinematic()
			Sleep(400)
		EndIf
		If Wine_IsWine() And (Leveler_PartyHasZenMissionAllies() Or Leveler_WinePlayerClearlyAlive()) Then
			$g_b_WipeReturnSent = False
			Out("[Recover] Still in Zen with Togo/alive player (map " & Map_GetMapID() & "); aborting wipe wait.")
			Return False
		EndIf
		If Leveler_AtWipeOutpost() Then
			$g_b_WipeReturnSent = False
			$g_b_WineEnterSent = False
			Out("[Recover] Back in outpost map " & Map_GetMapID() & ". Retrying: " & $g_s_CurrentHeader)
			Return True
		EndIf
		If TimerDiff($l_h_Timer) - $l_i_LastLog >= 8000 Then
			Out("[Recover] Waiting for outpost (map " & Map_GetMapID() & " current " & Leveler_LiveMapID() & _
					" type " & Map_GetInstanceInfo("Type") & " connecting=" & Number(Leveler_MapLooksConnecting()) & ")")
			$l_i_LastLog = TimerDiff($l_h_Timer)
		EndIf
		Sleep(500)
	WEnd
	Out("[Recover] Outpost return timed out. Not sending more return packets.")
	Return False
EndFunc

; Resign once, Return-to-Outpost once, then wait. Repeating 0xA7 while Connecting hangs Gw at 0%.
Func Leveler_ReturnWipeToOutpost()
	If Wine_IsWine() And (Leveler_PartyHasZenMissionAllies() Or Leveler_WinePlayerClearlyAlive()) Then
		$g_b_WipeReturnSent = False
		Out("[Recover] Togo/alive player in Zen; not resigning.")
		Return False
	EndIf
	If Leveler_AtWipeOutpost() Then
		$g_b_WipeReturnSent = False
		$g_b_WineEnterSent = False
		Out("[Recover] Already at the outpost after the wipe.")
		Return True
	EndIf
	If Leveler_MapLooksConnecting() Then
		Out("[Recover] Client is connecting; waiting without sending return packets.")
		Return Leveler_WaitReturnToOutpost()
	EndIf

	If Not $g_b_WipeReturnSent Then
		Out("[Recover] Party wiped or Togo fell. Resigning once, then returning to outpost once.")
		Chat_SendChat("resign", "/")
		Sleep(1500)
		If Party_GetPartyContextInfo("IsDefeated") Or Leveler_InMissionInstance() Or Leveler_HasMissionObjectives() Then
			If Wine_IsWine() Then Wine_EnsureCommandQueue()
			Map_ReturnToOutpost(False)
			$g_b_WipeReturnSent = True
			$g_h_WipeReturnAt = TimerInit()
			Out("[Recover] Sent Return-to-Outpost. Waiting for the outpost (no further packets).")
		EndIf
	Else
		Out("[Recover] Return-to-Outpost already sent this wipe; waiting.")
	EndIf
	Return Leveler_WaitReturnToOutpost()
EndFunc
