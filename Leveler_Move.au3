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

; $a_b_Combat True = fight while walking (explorable). False = pacifist (towns).
; Returns True if we arrived or the map changed (portal / instance).
Func Leveler_MoveTo($a_f_X, $a_f_Y, $a_b_Combat = False)
	If $g_b_LevelerPaused Then Return False
	If Leveler_IsWiped() Then Return False

	Local $l_i_StartMap = Map_GetMapID()
	Leveler_EnsurePathfinder()

	Local $l_v_Obstacles = 0
	Local $l_i_Aggro = 0
	If $a_b_Combat Then
		$l_v_Obstacles = "UAI_GetObstacles"
		$l_i_Aggro = $LEVELER_AGGRO
	EndIf

	Local $l_s_Callback = ""
	If $g_b_SpiritRiftWatch Then $l_s_Callback = "Leveler_InterruptSpiritRifts"

	Local $l_b_Ok = False
	If Pathfinder_IsMapAvailable($l_i_StartMap) Then
		$l_b_Ok = Pathfinder_MoveTo($a_f_X, $a_f_Y, -1, $l_v_Obstacles, $l_i_Aggro, $LEVELER_FIGHT_RANGE_OUT, 0, $l_s_Callback)
	Else
		$l_b_Ok = Leveler_MoveDirect($a_f_X, $a_f_Y)
	EndIf

	If Map_GetMapID() <> $l_i_StartMap Then Return True
	If Leveler_IsWiped() Then Return False
	If Agent_GetDistanceToXY($a_f_X, $a_f_Y) < $LEVELER_ARRIVE_RANGE Then Return True
	Return $l_b_Ok
EndFunc

Func Leveler_MoveDirect($a_f_X, $a_f_Y, $a_i_Timeout = 30000)
	Local $l_i_StartMap = Map_GetMapID()
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If Leveler_IsWiped() Then Return False
		If Map_GetMapID() <> $l_i_StartMap Then Return True
		If Agent_GetDistanceToXY($a_f_X, $a_f_Y) < $LEVELER_ARRIVE_RANGE Then Return True
		Map_Move($a_f_X, $a_f_Y, 20)
		Sleep(250)
	WEnd
	Return Agent_GetDistanceToXY($a_f_X, $a_f_Y) < $LEVELER_ARRIVE_RANGE
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

Func Leveler_Travel($a_i_MapID)
	If Map_GetMapID() = $a_i_MapID And Map_GetInstanceInfo("IsOutpost") Then Return True
	Out("[Move] Travel to map " & $a_i_MapID)
	Return Map_TravelTo($a_i_MapID)
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

Func Leveler_GetTogo()
	Local $l_i_Npc = Leveler_GetAgentByModel($MODEL_TOGO_1)
	If $l_i_Npc <> 0 Then Return $l_i_Npc
	$l_i_Npc = Leveler_GetAgentByModel($MODEL_TOGO_2)
	If $l_i_Npc <> 0 Then Return $l_i_Npc
	$l_i_Npc = Leveler_GetAgentByModel($MODEL_TOGO_3)
	If $l_i_Npc <> 0 Then Return $l_i_Npc
	Return Leveler_GetAgentByModel($MODEL_TOGO_4)
EndFunc

Func Leveler_TogoModel()
	Local $l_i_Togo = Leveler_GetTogo()
	If $l_i_Togo = 0 Then Return 0
	Return Agent_GetAgentInfo($l_i_Togo, "PlayerNumber")
EndFunc

Func Leveler_ResolveTalkNpc($a_f_X, $a_f_Y, $a_i_NpcModel = 0)
	Local $l_i_Npc = 0
	If $a_i_NpcModel <> 0 Then $l_i_Npc = Leveler_GetAgentByModel($a_i_NpcModel)
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

Func Leveler_IsWiped()
	If Party_GetPartyContextInfo("IsDefeated") Then Return True
	If Party_IsWiped() Then Return True
	Return False
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

; Follow an NPC by model ID until not in spirit-range danger and the NPC has a quest marker.
Func Leveler_FollowModel($a_i_Model, $a_f_FollowRange = $LEVELER_AREA_RANGE, $a_i_Timeout = 180000)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Leveler_IsWiped() Then Return False
		Local $l_i_Npc = Leveler_GetAgentByModel($a_i_Model)
		If $l_i_Npc = 0 Then
			Sleep(400)
			ContinueLoop
		EndIf
		If Not Leveler_InDanger($LEVELER_SPIRIT_RANGE) And Agent_GetAgentInfo($l_i_Npc, "HasQuest") Then
			Out("[Move] FollowModel " & $a_i_Model & " finished")
			Return True
		EndIf
		If Agent_GetDistance($l_i_Npc) > $a_f_FollowRange Then
			Map_Move(Agent_GetAgentInfo($l_i_Npc, "X"), Agent_GetAgentInfo($l_i_Npc, "Y"), 20)
		EndIf
		Sleep(250)
	WEnd
	Local $l_i_NpcEnd = Leveler_GetAgentByModel($a_i_Model)
	If $l_i_NpcEnd <> 0 And Agent_GetAgentInfo($l_i_NpcEnd, "HasQuest") Then Return True
	Out("[Move] FollowModel timed out for model " & $a_i_Model)
	Return False
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
	If Map_GetMapID() <> $MAP_ZEN_OP Then Return
	If $g_h_RiftCooldown <> 0 And TimerDiff($g_h_RiftCooldown) < 1000 Then Return

	Local $l_i_Max = Agent_GetMaxAgents()
	For $i = 1 To $l_i_Max - 1
		If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
		If Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
		If Agent_GetAgentInfo($i, "Allegiance") <> $GC_I_ALLEGIANCE_ENEMY Then ContinueLoop
		If Agent_GetAgentInfo($i, "Skill") <> $SKILL_SPIRIT_RIFT Then ContinueLoop

		Local $l_ai_Skills[3] = [$SKILL_CRY_OF_PAIN, $SKILL_POWER_DRAIN, $SKILL_SIGNET_OF_DISRUPTION]
		For $s = 0 To 2
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

	Out("[Recover] Party wiped or dead. Resigning and returning to outpost.")
	Chat_SendChat("resign", "/")
	Sleep(1200)

	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < 60000
		If Map_GetInstanceInfo("IsOutpost") Then ExitLoop
		If Party_GetPartyContextInfo("IsDefeated") Then Map_ReturnToOutpost(False)
		Sleep(500)
	WEnd

	Map_WaitMapLoading()
	Sleep(1000)
	If Map_GetInstanceInfo("IsOutpost") Then
		Out("[Recover] Back in outpost. Retrying: " & $g_s_CurrentHeader)
		Return True
	EndIf
	Out("[Recover] Failed to reach an outpost.")
	Return False
EndFunc
