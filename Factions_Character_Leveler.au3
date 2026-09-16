#RequireAdmin
Opt("GUIOnEventMode", True)
Opt("GUICloseOnESC", False)
Opt("ExpandVarStrings", 1)

#include "../../API/_GwAu3.au3"
#include "WineCompat.au3"
#include "Leveler_Const.au3"
#include "Leveler_Move.au3"
#include "Leveler_Quest.au3"
#include "Leveler_Prof.au3"
#include "Leveler_Party.au3"
#include "Leveler_Craft.au3"
#include "Leveler_Status.au3"
#include "Leveler_Steps.au3"

Global Const $GC_B_LOAD_LOGGED_CHARS = True

$DLL_PATH = @ScriptDir & "\..\..\API\Plugins\Pathfinder\GWPathfinder.dll"
Wine_ApplyRuntimeGuards()

#Region Declarations
Global $g_i_ProcessID = ""
Global $g_i_Timer = TimerInit()
Global $g_b_BotRunning = False
Global $g_b_BotCoreInitialized = False
Global Const $GC_S_BOT_TITLE = "Factions Character Leveler"

$g_b_AutoStart = False
$g_s_MainCharName = ""
#EndRegion Declaration

For $i = 1 To $CmdLine[0]
	If $CmdLine[$i] = "-character" And $i < $CmdLine[0] Then
		$g_s_MainCharName = $CmdLine[$i + 1]
		$g_b_AutoStart = True
		$g_bAutoStart = True
		ExitLoop
	EndIf
Next

#Region GUI
$g_h_MainGui = GUICreate($GC_S_BOT_TITLE, 640, 480, -1, -1, -1, BitOR($WS_EX_TOPMOST, $WS_EX_WINDOWEDGE))
GUISetBkColor(0xEAEAEA, $g_h_MainGui)
GUICtrlCreateGroup("Factions Leveler  -  Phase 1-5 (through Vaettir NPC)", 8, 8, 624, 464)

Global $g_h_NameCombo
If $GC_B_LOAD_LOGGED_CHARS Then
	$g_h_NameCombo = GUICtrlCreateCombo($g_s_MainCharName, 24, 32, 180, 25, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
	; Wine: do not call Scanner_GetLoggedCharNames — it Memory_Close()s and can cache 0/78.
	If Not Wine_IsWine() Then GUICtrlSetData(-1, Scanner_GetLoggedCharNames())
Else
	$g_h_NameCombo = GUICtrlCreateInput($g_s_MainCharName, 24, 32, 180, 25)
EndIf

$g_h_OnTopCheckbox = GUICtrlCreateCheckbox("On Top", 220, 31, 60, 24)
GUICtrlSetState($g_h_OnTopCheckbox, $GUI_CHECKED)
GUICtrlSetOnEvent($g_h_OnTopCheckbox, "GuiButtonHandler")

$g_h_DebugCheckbox = GUICtrlCreateCheckbox("Debug", 286, 31, 56, 24)
GUICtrlSetState($g_h_DebugCheckbox, $GUI_CHECKED)
GUICtrlSetOnEvent($g_h_DebugCheckbox, "GuiButtonHandler")

$g_h_StartButton = GUICtrlCreateButton("Start", 24, 72, 80, 25)
GUICtrlSetOnEvent($g_h_StartButton, "GuiButtonHandler")

$g_h_PauseButton = GUICtrlCreateButton("Pause", 112, 72, 80, 25)
GUICtrlSetOnEvent($g_h_PauseButton, "GuiButtonHandler")
GUICtrlSetState($g_h_PauseButton, $GUI_DISABLE)

$g_h_RefreshButton = GUICtrlCreateButton("Refresh", 200, 72, 80, 25)
GUICtrlSetOnEvent($g_h_RefreshButton, "GuiButtonHandler")

GUICtrlCreateLabel("Progress:", 300, 76, 80, 20)
$g_h_StepList = GUICtrlCreateListView("Step", 384, 72, 230, 388, BitOR($LVS_REPORT, $LVS_SINGLESEL, $LVS_SHOWSELALWAYS, $LVS_NOCOLUMNHEADER, $LVS_NOSORTHEADER), $WS_EX_CLIENTEDGE)
_GUICtrlListView_SetExtendedListViewStyle($g_h_StepList, $LVS_EX_FULLROWSELECT)
_GUICtrlListView_SetColumnWidth($g_h_StepList, 0, 206)
For $i = 0 To $LEVELER_STEP_COUNT - 1
	GUICtrlCreateListViewItem($g_as_StepNames[$i], $g_h_StepList)
	$g_ab_StepDone[$i] = False
Next
_GUICtrlListView_SetItemSelected($g_h_StepList, 0, True, True)
GUICtrlSetOnEvent($g_h_StepList, "GuiButtonHandler")
GUIRegisterMsg($WM_NOTIFY, "Leveler_WM_NOTIFY")

Global Const $LEVELER_TAG_NMLVCUSTOMDRAW = $tagNMHDR & ";dword dwDrawStage;handle hdc;int Left;int Top;int Right;int Bottom;dword_ptr dwItemSpec;uint uItemState;lparam lItemlParam;dword clrText;dword clrTextBk;int iSubItem"

$g_h_EditText = _GUICtrlRichEdit_Create($g_h_MainGui, "", 16, 112, 356, 348, BitOR($ES_AUTOVSCROLL, $ES_MULTILINE, $WS_VSCROLL, $ES_READONLY))
_GUICtrlRichEdit_SetBkColor($g_h_EditText, $COLOR_WHITE)

GUICtrlCreateGroup("", -99, -99, 1, 1)
GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
GUISetState(@SW_SHOW)
#EndRegion GUI

Out("Factions Character Leveler (Phase 1-5)")
Out("Port of the Py4GW Factions bot through attribute quest 2, Kryta, Elona, and Vaettir unlock.")
Out("Pathing: GwAu3 Pathfinder plugin + GWPathfinder.dll")
If Wine_IsWine() Then
	Out("Runtime: " & Wine_RuntimeLabel() & " — attach by Gw.exe PID. Window title is often Guild Wars Reforged.")
	Out("Scanner_GetLoggedCharNames is skipped on Wine so a timed local scan cannot cache 0/78 before Start.")
	Out("Start calls Core_Initialize immediately. Enter Mission / Map_Move install a one-JMP queue on the first step.")
Else
	Out("Run AutoIt3 x86 on Windows with Guild Wars launched.")
EndIf
Out("")

If Wine_IsWine() Then
	If $g_bAutoStart And $g_s_MainCharName <> "" Then
		Sleep(2000)
		StartBot()
	EndIf
Else
	Core_AutoStart()
EndIf

While 1
	Sleep(80)
	If $g_b_BotCoreInitialized And $g_b_BotRunning And Not $g_b_LevelerPaused Then
		If $g_b_NeedStatusCheck Then
			$g_i_Step = Leveler_StatusCheck()
			$g_b_NeedStatusCheck = False
			Out("Starting at step: " & $g_i_Step & " — " & $g_as_StepNames[$g_i_Step])
		ElseIf $g_i_Step >= $LEVELER_STEP_DONE Then
			Out("Phase 1-5 complete. Post-20 unlocks finished (Kilroy, Olias, GToB, Vaettir NPC if A/Me).")
			$g_b_BotRunning = False
			GUICtrlSetData($g_h_StartButton, "Start")
			GUICtrlSetState($g_h_PauseButton, $GUI_DISABLE)
		Else
			If Not Leveler_ExecuteStep($g_i_Step) Then Sleep(500)
		EndIf
	EndIf
WEnd

Func StartBot()
	If Not Leveler_AttachToGw() Then
		If Wine_IsWine() Then
			Out("Attach failed. Leave the character in-world, click Refresh, then Start. Do not Exit so you can retry.")
			Return
		EndIf
		MsgBox(0, "Error", "Could not attach to Guild Wars.")
		_Exit()
	EndIf

	GUICtrlSetState($g_h_NameCombo, $GUI_DISABLE)
	GUICtrlSetState($g_h_RefreshButton, $GUI_DISABLE)
	GUICtrlSetState($g_h_PauseButton, $GUI_ENABLE)
	GUICtrlSetData($g_h_StartButton, "Running")
	GUICtrlSetState($g_h_StartButton, $GUI_DISABLE)

	WinSetTitle($g_h_MainGui, "", Player_GetCharName() & " - " & $GC_S_BOT_TITLE)
	$g_b_BotRunning = True
	$g_b_BotCoreInitialized = True
	$g_b_LevelerPaused = False
	$g_b_LevelerFailed = False
	$g_b_NeedStatusCheck = True
	$g_b_LostTreasureToTenguOnce = False
	$g_b_ExplorableResume = True
	Leveler_RefreshQuestFlags(True)

	Out("Initialized for: " & Player_GetCharName())
	Out("Map: " & Map_GetMapID() & "  Pos: " & Round(Agent_GetAgentInfo(-2, "X")) & ", " & Round(Agent_GetAgentInfo(-2, "Y")))
	If Not Leveler_IsOutpost() Then Out("Restart recovery is on. Will resume the current quest here if it is in the log.")
	Out("Core ready. Returning to the run loop.")
EndFunc

; Attach by character name on Windows. On Wine the client title is often
; "Guild Wars Reforged", so Core_Initialize(name) plus Scanner_GetLoggedCharNames
; can cache a 0/78 local scan; attach by Gw.exe PID instead.
; Start still calls Core_Initialize immediately. The Wine command queue
; (one Engine JMP + CommandEnterMission) is installed lazily on the first step.
Func Leveler_AttachToGw()
	Wine_ApplyRuntimeGuards()
	$g_b_WineQueueAttempted = False
	$g_b_WineQueueGapLogged = False
	$g_b_WineMinimalHook = False
	$g_p_WineAsmAlloc = 0
	Local $l_s_Name = StringStripWS(GUICtrlRead($g_h_NameCombo), 3)
	Local $l_b_ChangeTitle = Not Wine_IsWine()
	Local $l_v_Hwnd = 0

	If $g_i_ProcessID Then
		Out("Initializing and attaching to PID " & $g_i_ProcessID & " (" & Wine_RuntimeLabel() & ")")
		$l_v_Hwnd = Core_Initialize(Number($g_i_ProcessID, 2), $l_b_ChangeTitle)
		Return Leveler_AttachLooksLive($l_v_Hwnd)
	EndIf

	If Not Wine_IsWine() Then
		If $l_s_Name = "" Then
			Local $l_i_Pid = ProcessExists("gw.exe")
			If $l_i_Pid = 0 Then
				Out("Guild Wars is not running.")
				Return False
			EndIf
			$l_v_Hwnd = Core_Initialize($l_i_Pid, $l_b_ChangeTitle)
		Else
			$l_v_Hwnd = Core_Initialize($l_s_Name, $l_b_ChangeTitle)
		EndIf
		If $l_v_Hwnd = 0 Then
			If $l_s_Name <> "" Then
				Out("Could not find a Guild Wars client named '" & $l_s_Name & "'")
			Else
				Out("Guild Wars is not running.")
			EndIf
			Return False
		EndIf
		Return True
	EndIf

	; Wine: PID-first. Do not Core_Initialize(name) first — a failed named
	; attach can record 0/78 and skip the critical rescan.
	Local $l_i_WinPid = Wine_PidFromGwWindow()
	Local $l_a_List = ProcessList("gw.exe")
	Local $l_i_ListCount = 0
	If IsArray($l_a_List) Then $l_i_ListCount = Number($l_a_List[0][0])
	Local $l_i_ListPid = 0
	If $l_i_ListCount >= 1 Then $l_i_ListPid = Number($l_a_List[1][1])
	Out("Wine PID: window=" & $l_i_WinPid & " ProcessList=" & $l_i_ListPid & " (" & Wine_RuntimeLabel() & ")")
	If $l_s_Name <> "" Then Out("Preferring character '" & $l_s_Name & "' when several clients are running.")

	Local $l_ai_Pids[8]
	$l_ai_Pids[0] = 0
	If $l_i_WinPid > 0 Then
		$l_ai_Pids[0] += 1
		$l_ai_Pids[$l_ai_Pids[0]] = $l_i_WinPid
	EndIf
	Local $j = 1
	For $j = 1 To $l_i_ListCount
		Local $l_i_Extra = Number($l_a_List[$j][1])
		If $l_i_Extra <= 0 Then ContinueLoop
		If $l_i_Extra = $l_i_WinPid Then ContinueLoop
		If $l_ai_Pids[0] >= 7 Then ExitLoop
		$l_ai_Pids[0] += 1
		$l_ai_Pids[$l_ai_Pids[0]] = $l_i_Extra
	Next
	If $l_ai_Pids[0] < 1 Then
		Local $l_i_Fallback = Wine_FindGwPid()
		If $l_i_Fallback = 0 Then
			Out("Wine: no Gw.exe process found.")
			Return False
		EndIf
		$l_ai_Pids[0] = 1
		$l_ai_Pids[1] = $l_i_Fallback
	EndIf

	Local $l_i_LivePid = 0
	Local $p = 1
	For $p = 1 To $l_ai_Pids[0]
		Out("Initializing and attaching to PID " & $l_ai_Pids[$p] & " (" & Wine_RuntimeLabel() & ")")
		$l_v_Hwnd = Core_Initialize($l_ai_Pids[$p], $l_b_ChangeTitle)
		If Not Leveler_AttachLooksLive($l_v_Hwnd) Then
			Out("Scanner failed (error " & @error & ") on PID " & $l_ai_Pids[$p])
			ContinueLoop
		EndIf
		Local $l_s_Got = StringStripWS(Player_GetCharName(), 3)
		If $l_s_Name <> "" And $l_s_Got <> "" And StringCompare($l_s_Got, $l_s_Name) <> 0 Then
			Out("PID " & $l_ai_Pids[$p] & " is '" & $l_s_Got & "', not '" & $l_s_Name & "'; trying next.")
			$l_i_LivePid = $l_ai_Pids[$p]
			ContinueLoop
		EndIf
		Return True
	Next

	If $l_i_LivePid <> 0 Then
		Out("No PID matched '" & $l_s_Name & "'; re-attaching to PID " & $l_i_LivePid)
		$l_v_Hwnd = Core_Initialize($l_i_LivePid, $l_b_ChangeTitle)
		Return Leveler_AttachLooksLive($l_v_Hwnd)
	EndIf
	Return False
EndFunc

Func Leveler_AttachLooksLive($a_v_Hwnd)
	If $a_v_Hwnd <> 0 And $a_v_Hwnd <> "" Then Return True
	If Not Wine_IsWine() Then Return False
	; Scanner_GetHwnd can miss Guild Wars Reforged even when memory attach worked.
	If $g_h_GWProcess <> 0 And $g_p_BasePointer Then
		Local $l_h_Win = Wine_FindGwHwnd($g_i_GWProcessId)
		If $l_h_Win <> 0 Then $g_h_GWWindow = $l_h_Win
		Return True
	EndIf
	Return False
EndFunc

; On Wine, Scanner_GetLoggedCharNames Memory_Close()s the process and the local
; scanner can cache 0/78 (AgentBase/MyID/Engine/Move/BasePointer missing).
Func Leveler_RefreshCharCombo()
	Wine_ApplyRuntimeGuards()
	Local $l_s_Keep = StringStripWS(GUICtrlRead($g_h_NameCombo), 3)
	If Wine_IsWine() Then
		Local $l_a_List = ProcessList("gw.exe")
		Local $l_i_Count = 0
		If Not @error And IsArray($l_a_List) Then $l_i_Count = $l_a_List[0][0]
		Out("Wine refresh: " & $l_i_Count & " Gw.exe process(es), window PID " & Wine_PidFromGwWindow() & ". Start calls Core_Initialize by PID.")
		If $l_i_Count >= 1 Then
			For $i = 1 To $l_i_Count
				Local $l_h_Win = Wine_FindGwHwnd(Number($l_a_List[$i][1]))
				Local $l_s_Title = ""
				If $l_h_Win <> 0 Then $l_s_Title = WinGetTitle($l_h_Win)
				Out("  " & $l_a_List[$i][0] & " PID " & $l_a_List[$i][1] & "  " & $l_s_Title)
			Next
		EndIf
		If $l_s_Keep <> "" Then GUICtrlSetData($g_h_NameCombo, $l_s_Keep)
		Return
	EndIf
	GUICtrlSetData($g_h_NameCombo, "")
	GUICtrlSetData($g_h_NameCombo, Scanner_GetLoggedCharNames())
EndFunc

Func TogglePause()
	If Not $g_b_BotCoreInitialized Then Return
	$g_b_LevelerPaused = Not $g_b_LevelerPaused
	If $g_b_LevelerPaused Then
		$g_b_BotRunning = False
		GUICtrlSetData($g_h_PauseButton, "Resume")
		GUICtrlSetState($g_h_StartButton, $GUI_ENABLE)
		GUICtrlSetData($g_h_StartButton, "Start")
		Out("Paused. Use Resume from to pick a step, then Start.")
	Else
		$g_b_BotRunning = True
		$g_b_NeedStatusCheck = True
		GUICtrlSetData($g_h_PauseButton, "Pause")
		GUICtrlSetData($g_h_StartButton, "Running")
		GUICtrlSetState($g_h_StartButton, $GUI_DISABLE)
		Out("Resuming. Status check will run on the next loop tick.")
	EndIf
EndFunc

Func Leveler_GetSelectedStep()
	Local $l_s_Idx = _GUICtrlListView_GetSelectedIndices($g_h_StepList)
	If $l_s_Idx = "" Then Return 0
	Return Number($l_s_Idx)
EndFunc

Func Leveler_UpdateStepCombo()
	If $g_i_Step < 0 Then Return
	If $g_i_Step > 0 Then Leveler_MarkStepsThrough($g_i_Step - 1)
	Leveler_RefreshStepList($g_i_Step)
EndFunc

Func Leveler_RefreshStepList($a_i_Select = -1)
	For $i = 0 To $LEVELER_STEP_COUNT - 1
		Local $l_s_Text = $g_as_StepNames[$i]
		If $g_ab_StepDone[$i] Then $l_s_Text = "x  " & $l_s_Text
		_GUICtrlListView_SetItemText($g_h_StepList, $i, $l_s_Text)
	Next
	If $a_i_Select >= 0 Then
		_GUICtrlListView_SetItemSelected($g_h_StepList, $a_i_Select, True, True)
		_GUICtrlListView_EnsureVisible($g_h_StepList, $a_i_Select)
	EndIf
	_WinAPI_RedrawWindow(GUICtrlGetHandle($g_h_StepList))
EndFunc

Func Leveler_WM_NOTIFY($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $wParam
	Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
	If HWnd(DllStructGetData($tNMHDR, "hWndFrom")) <> GUICtrlGetHandle($g_h_StepList) Then Return $GUI_RUNDEFMSG
	If DllStructGetData($tNMHDR, "Code") <> $NM_CUSTOMDRAW Then Return $GUI_RUNDEFMSG

	Local $tNMLVCD = DllStructCreate($LEVELER_TAG_NMLVCUSTOMDRAW, $lParam)
	Local $iDrawStage = DllStructGetData($tNMLVCD, "dwDrawStage")
	If $iDrawStage = 0x1 Then Return 0x20 ; CDDS_PREPAINT -> CDRF_NOTIFYITEMDRAW
	If $iDrawStage = 0x10001 Then ; CDDS_ITEMPREPAINT
		Local $iItem = DllStructGetData($tNMLVCD, "dwItemSpec")
		If $iItem >= 0 And $iItem < $LEVELER_STEP_COUNT And $g_ab_StepDone[$iItem] Then
			DllStructSetData($tNMLVCD, "clrText", 0x808080)
			DllStructSetData($tNMLVCD, "clrTextBk", 0xEAEAEA)
		EndIf
		Return 0x2 ; CDRF_NEWFONT
	EndIf
	Return $GUI_RUNDEFMSG
EndFunc

Func GuiButtonHandler()
	Switch @GUI_CtrlId
		Case $g_h_StartButton
			If $g_b_BotCoreInitialized Then
				$g_b_LevelerPaused = False
				$g_b_BotRunning = True
				$g_b_NeedStatusCheck = True
				GUICtrlSetData($g_h_StartButton, "Running")
				GUICtrlSetState($g_h_StartButton, $GUI_DISABLE)
				GUICtrlSetData($g_h_PauseButton, "Pause")
				GUICtrlSetState($g_h_PauseButton, $GUI_ENABLE)
				Out("Start pressed. Status check will run on the next loop tick.")
			Else
				StartBot()
			EndIf

		Case $g_h_StepList
			$g_i_Step = Leveler_GetSelectedStep()
			Out("Selected step: " & $g_i_Step & " — " & $g_as_StepNames[$g_i_Step])

		Case $g_h_PauseButton
			TogglePause()

		Case $g_h_RefreshButton
			Leveler_RefreshCharCombo()

		Case $g_h_OnTopCheckbox
			If GetChecked($g_h_OnTopCheckbox) Then
				WinSetOnTop($g_h_MainGui, "", 1)
			Else
				WinSetOnTop($g_h_MainGui, "", 0)
			EndIf

		Case $g_h_DebugCheckbox
			If GetChecked($g_h_DebugCheckbox) Then
				Log_SetDebugMode(True)
			Else
				Log_SetDebugMode(False)
			EndIf

		Case $GUI_EVENT_CLOSE
			_Exit()
	EndSwitch
EndFunc

Func Out($a_s_Text)
	If $g_h_EditText = 0 Then Return
	Local $l_i_TextLen = StringLen($a_s_Text)
	Local $l_i_ConsoleLen = _GUICtrlEdit_GetTextLen($g_h_EditText)
	If $l_i_TextLen + $l_i_ConsoleLen > 30000 Then
		_GUICtrlRichEdit_SetText($g_h_EditText, "")
	EndIf
	_GUICtrlRichEdit_SetCharColor($g_h_EditText, $COLOR_BLACK)
	_GUICtrlEdit_AppendText($g_h_EditText, @CRLF & $a_s_Text)
	_GUICtrlEdit_Scroll($g_h_EditText, $SB_BOTTOM)
EndFunc

Func GetChecked($a_h_Ctrl)
	If BitAND(GUICtrlRead($a_h_Ctrl), $GUI_CHECKED) = $GUI_CHECKED Then
		Return True
	Else
		Return False
	EndIf
EndFunc

Func _Exit()
	Pathfinder_Shutdown()
	Exit
EndFunc
