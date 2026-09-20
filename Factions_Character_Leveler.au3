#RequireAdmin
Opt("GUIOnEventMode", True)
Opt("GUICloseOnESC", False)
Opt("ExpandVarStrings", 1)
Opt("TrayAutoPause", 0)
Opt("TrayMenuMode", 1)

#include "../../API/_GwAu3.au3"
#include "Leveler_Const.au3"
#include "Leveler_Move.au3"
#include "Leveler_Quest.au3"
#include "Leveler_Prof.au3"
#include "Leveler_Mission.au3"
#include "Leveler_Henchman.au3"
#include "Leveler_Party.au3"
#include "Leveler_Craft.au3"
#include "Leveler_Status.au3"
#include "Leveler_Steps.au3"

Global Const $GC_B_LOAD_LOGGED_CHARS = True

$DLL_PATH = @ScriptDir & "\..\..\API\Plugins\Pathfinder\GWPathfinder.dll"

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
GUICtrlCreateGroup("Factions Leveler  -  through remaining secondary professions", 8, 8, 624, 464)

Global $g_h_NameCombo
If $GC_B_LOAD_LOGGED_CHARS Then
	$g_h_NameCombo = GUICtrlCreateCombo($g_s_MainCharName, 24, 32, 180, 25, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
	GUICtrlSetData(-1, Scanner_GetLoggedCharNames())
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
; Keep Enter from activating Pause once Start is disabled.
Global $g_h_DummyDefault = GUICtrlCreateButton("", -200, -200, 1, 1)
GUICtrlSetState($g_h_DummyDefault, BitOR($GUI_HIDE, $GUI_DEFBUTTON))

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

Out("Factions Character Leveler")
Out("Factions leveler through remaining secondary professions.")
Out("Pathing: GwAu3 Pathfinder plugin + GWPathfinder.dll")
Out("Run AutoIt3 x86 on Windows with Guild Wars launched.")
Out("")

Core_AutoStart()

While 1
	Sleep(80)
	If $g_b_BotCoreInitialized And $g_b_BotRunning And Not $g_b_LevelerPaused Then
		If $g_b_NeedStatusCheck Then
			$g_i_Step = Leveler_StatusCheck()
			$g_b_NeedStatusCheck = False
			Out("Starting at step: " & $g_i_Step & " — " & $g_as_StepNames[$g_i_Step])
		ElseIf $g_i_Step >= $LEVELER_STEP_DONE Then
			Out("Remaining secondary professions unlocked. Leveler is done.")
			$g_b_BotRunning = False
			GUICtrlSetData($g_h_StartButton, "Start")
			GUICtrlSetState($g_h_PauseButton, $GUI_DISABLE)
		Else
			If Not Leveler_ExecuteStep($g_i_Step) Then Sleep(500)
		EndIf
	EndIf
WEnd

Func StartBot()
	Local $l_s_MainCharName = GUICtrlRead($g_h_NameCombo)
	If $l_s_MainCharName = "" Then
		If Core_Initialize(ProcessExists("gw.exe"), True) = 0 Then
			MsgBox(0, "Error", "Guild Wars is not running.")
			_Exit()
		EndIf
	ElseIf $g_i_ProcessID Then
		Local $l_i_ProcIdInt = Number($g_i_ProcessID, 2)
		If Core_Initialize($l_i_ProcIdInt, True) = 0 Then
			MsgBox(0, "Error", "Could not find that process ID.")
			_Exit()
		EndIf
	Else
		If Core_Initialize($l_s_MainCharName, True) = 0 Then
			MsgBox(0, "Error", "Could not find a Guild Wars client named '" & $l_s_MainCharName & "'")
			_Exit()
		EndIf
	EndIf

	GUICtrlSetState($g_h_NameCombo, $GUI_DISABLE)
	GUICtrlSetState($g_h_RefreshButton, $GUI_DISABLE)
	GUICtrlSetState($g_h_PauseButton, $GUI_ENABLE)
	GUICtrlSetData($g_h_StartButton, "Running")
	GUICtrlSetState($g_h_StartButton, $GUI_DISABLE)

	WinSetTitle($g_h_MainGui, "", Player_GetCharName() & " - " & $GC_S_BOT_TITLE)
	GUICtrlSetState($g_h_DummyDefault, $GUI_DEFBUTTON)
	ControlFocus($g_h_MainGui, "", $g_h_DummyDefault)
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
		GUICtrlSetState($g_h_DummyDefault, $GUI_DEFBUTTON)
		ControlFocus($g_h_MainGui, "", $g_h_DummyDefault)
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
				GUICtrlSetState($g_h_DummyDefault, $GUI_DEFBUTTON)
				ControlFocus($g_h_MainGui, "", $g_h_DummyDefault)
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
			GUICtrlSetData($g_h_NameCombo, "")
			GUICtrlSetData($g_h_NameCombo, Scanner_GetLoggedCharNames())

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
