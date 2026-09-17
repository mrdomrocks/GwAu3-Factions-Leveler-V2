#include-once

; Wine / Linux (wine-gw prefix) compatibility helpers for attach + GUI.
; Native Windows stays on the same code paths unless ForceWineCompat=1.
;
; The patched GwAu3 API (GwAu3_Core_Scanner.au3 / GwAu3_Core.au3) reads:
;   $g_b_IsWine, $g_b_ForceWineCompat, $g_b_ScannerUseLocal, $g_i_ScannerTimeoutMs
; Set those before any Scanner_* / Core_Initialize call.
;
; Start stays stock Core_Initialize. The first Leveler_ExecuteStep / Map_Move
; calls Wine_EnsureCommandQueue: 4KB-scan .text, one Engine JMP, CommandMove
; page. Mid-mission Zen must not re-click Enter Mission when Type reads 0.
; It never calls Assembler_ModifyMemory (no five-JMP path).

If Not IsDeclared("g_b_IsWine") Then Global $g_b_IsWine = False
If Not IsDeclared("g_b_WineChecked") Then Global $g_b_WineChecked = False
If Not IsDeclared("g_s_WineVersion") Then Global $g_s_WineVersion = ""
If Not IsDeclared("g_b_ForceWineCompat") Then Global $g_b_ForceWineCompat = False
If Not IsDeclared("g_b_ScannerUseLocal") Then Global $g_b_ScannerUseLocal = False
If Not IsDeclared("g_i_ScannerTimeoutMs") Then Global $g_i_ScannerTimeoutMs = 15000
If Not IsDeclared("g_b_SkipUpdater") Then Global $g_b_SkipUpdater = True
If Not IsDeclared("g_s_ResumeIni") Then Global $g_s_ResumeIni = @ScriptDir & "\Config\leveler.ini"
If Not IsDeclared("g_b_WineQueueAttempted") Then Global $g_b_WineQueueAttempted = False
If Not IsDeclared("g_b_WineMinimalHook") Then Global $g_b_WineMinimalHook = False
If Not IsDeclared("g_b_WineQueueGapLogged") Then Global $g_b_WineQueueGapLogged = False
If Not IsDeclared("g_p_WineAsmAlloc") Then Global $g_p_WineAsmAlloc = 0
If Not IsDeclared("g_p_WineExistingE9") Then Global $g_p_WineExistingE9 = 0
If Not IsDeclared("g_b_WineEnterSent") Then Global $g_b_WineEnterSent = False
If Not IsDeclared("g_h_WineQueueLastTry") Then Global $g_h_WineQueueLastTry = 0

Func Wine_IsWine()
	If $g_b_WineChecked Then Return $g_b_IsWine
	$g_b_WineChecked = True
	$g_b_IsWine = False

	If $g_b_ForceWineCompat Then
		$g_b_IsWine = True
		Return True
	EndIf

	Local $aVer = DllCall("ntdll.dll", "str", "wine_get_version")
	If Not @error And IsArray($aVer) And $aVer[0] <> "" Then
		$g_b_IsWine = True
		$g_s_WineVersion = $aVer[0]
		Return True
	EndIf

	RegRead("HKCU\Software\Wine", "")
	If Not @error Then
		$g_b_IsWine = True
		Return True
	EndIf

	If EnvGet("WINEPREFIX") <> "" Then
		$g_b_IsWine = True
		Return True
	EndIf

	Return False
EndFunc

Func Wine_LoadConfig()
	$g_b_ForceWineCompat = (IniRead($g_s_ResumeIni, "Wine", "ForceWineCompat", "0") = "1")
	$g_b_SkipUpdater = (IniRead($g_s_ResumeIni, "Wine", "SkipUpdater", "1") = "1")
	$g_i_ScannerTimeoutMs = Number(IniRead($g_s_ResumeIni, "Wine", "ScannerTimeoutMs", "15000"))
	If $g_i_ScannerTimeoutMs < 1000 Then $g_i_ScannerTimeoutMs = 15000

	Wine_IsWine()

	If $g_b_SkipUpdater Or $g_b_IsWine Then
		If IsDeclared("g_b_AutoUpdate") Then $g_b_AutoUpdate = False
		If IsDeclared("g_b_Verbose") Then $g_b_Verbose = False
	EndIf

	If $g_b_IsWine Then
		$g_b_ScannerUseLocal = True
		If IsDeclared("g_b_AutoUpdate") Then $g_b_AutoUpdate = False
		If IsDeclared("g_b_Verbose") Then $g_b_Verbose = False
	EndIf
EndFunc

Func Wine_ApplyRuntimeGuards()
	Wine_LoadConfig()
	If $g_b_SkipUpdater Or $g_b_IsWine Then
		If IsDeclared("g_b_AutoUpdate") Then $g_b_AutoUpdate = False
		If IsDeclared("g_b_Verbose") Then $g_b_Verbose = False
	EndIf
EndFunc

Func Wine_RuntimeLabel()
	If Wine_IsWine() Then
		If $g_s_WineVersion <> "" Then Return "Wine " & $g_s_WineVersion
		Return "Wine"
	EndIf
	If $g_b_ForceWineCompat Then Return "Wine-compat (forced)"
	Return "Windows"
EndFunc

; Prefer the process that owns a Guild Wars window (often "Guild Wars Reforged").
; ProcessList("gw.exe") PIDs are valid under Wine but can disagree with WinGetProcess.
Func Wine_FindGwPid()
	Local $iWinPid = Wine_PidFromGwWindow()
	Local $aList = ProcessList("gw.exe")
	Local $iListPid = 0
	If Not @error And IsArray($aList) And $aList[0][0] >= 1 Then $iListPid = Number($aList[1][1])
	If $iListPid = 0 Then $iListPid = Number(ProcessExists("gw.exe"))

	If $iWinPid > 0 Then Return $iWinPid
	If $iListPid > 0 Then Return $iListPid
	Return 0
EndFunc

Func Wine_PidFromGwWindow()
	Local $aClassWins = WinList("[CLASS:" & $GC_S_CLASS_DX_WINDOW & "]")
	If IsArray($aClassWins) Then
		Local $i = 1
		For $i = 1 To $aClassWins[0][0]
			Local $iPid = Number(WinGetProcess($aClassWins[$i][1]))
			If $iPid > 0 Then Return $iPid
		Next
	EndIf

	Local $aWins = WinList()
	If Not IsArray($aWins) Then Return 0
	Local $j = 1
	For $j = 1 To $aWins[0][0]
		If $aWins[$j][0] = "" Then ContinueLoop
		If Not StringInStr($aWins[$j][0], "Guild Wars") Then ContinueLoop
		Local $iPid2 = Number(WinGetProcess($aWins[$j][1]))
		If $iPid2 > 0 Then Return $iPid2
	Next
	Return 0
EndFunc

Func Wine_FindGwHwnd($a_i_Pid)
	If $a_i_Pid <= 0 Then Return 0

	Local $aClassWins = WinList("[CLASS:" & $GC_S_CLASS_DX_WINDOW & "]")
	If IsArray($aClassWins) Then
		Local $i = 1
		For $i = 1 To $aClassWins[0][0]
			If WinGetProcess($aClassWins[$i][1]) = $a_i_Pid Then Return $aClassWins[$i][1]
		Next
	EndIf

	Local $aWins = WinList()
	If Not IsArray($aWins) Then Return 0
	Local $hAny = 0
	Local $j = 1
	For $j = 1 To $aWins[0][0]
		If $aWins[$j][0] = "" Then ContinueLoop
		If WinGetProcess($aWins[$j][1]) <> $a_i_Pid Then ContinueLoop
		If StringInStr($aWins[$j][0], "Guild Wars") Then Return $aWins[$j][1]
		If $hAny = 0 Then $hAny = $aWins[$j][1]
	Next
	Return $hAny
EndFunc

; Memory_SetValue always appends; Memory_GetValue returns the FIRST match.
; Core_Initialize stores AgentBase/Move/MainStart/QueueBase as 0 after a 4/78
; scan, so a later SetValue is invisible. Replace the first row in place.
Func Wine_ReplaceValue($a_s_Key, $a_v_Value)
	If Not IsDeclared("g_amx2_Labels") Then Return Memory_SetValue($a_s_Key, $a_v_Value)
	Local $i = 1
	For $i = 1 To $g_amx2_Labels[0][0]
		If $g_amx2_Labels[$i][0] = $a_s_Key Then
			$g_amx2_Labels[$i][1] = $a_v_Value
			Return True
		EndIf
	Next
	Return Memory_SetValue($a_s_Key, $a_v_Value)
EndFunc

; _('Label/size') appends Label_* after Core_Initialize already converted the
; first Label_* rows to QueueBase/MainProc=0. Promote the new offsets onto the
; FIRST name match so Assembler_CompleteASMCode encodes the new page, not 0.
Func Wine_PromoteNewLabels()
	If Not IsDeclared("g_amx2_Labels") Then Return
	Local $i = 1
	For $i = 1 To $g_amx2_Labels[0][0]
		If StringLeft($g_amx2_Labels[$i][0], 6) <> "Label_" Then ContinueLoop
		Local $sName = StringTrimLeft($g_amx2_Labels[$i][0], 6)
		Local $pAddr = $g_p_ASMMemory + $g_amx2_Labels[$i][1]
		Wine_ReplaceValue($sName, $pAddr)
		$g_amx2_Labels[$i][0] = "WineLabel_" & $sName
		$g_amx2_Labels[$i][1] = $pAddr
	Next
EndFunc

Func Wine_HexPtr($a_p)
	Local $p = BitAND(Number($a_p), 0xFFFFFFFF)
	Return Hex($p, 8)
EndFunc

Func Wine_IsUserPtr($a_p)
	Local $p = BitAND(Number($a_p), 0xFFFFFFFF)
	If $p < 0x00400000 Then Return False
	If $p > 0x7FFEFFFF Then Return False
	Return True
EndFunc

Func Wine_ReadBytesHex($a_p_Addr, $a_i_Count)
	If $g_h_GWProcess = 0 Or $a_p_Addr = 0 Or $a_i_Count < 1 Then Return ""
	If Not Wine_IsUserPtr($a_p_Addr) Then Return ""
	Local $dBuf = DllStructCreate("byte[" & $a_i_Count & "]")
	If @error Then Return ""
	Local $av = DllCall($g_h_Kernel32, "int", "ReadProcessMemory", _
			"int", $g_h_GWProcess, _
			"int", $a_p_Addr, _
			"ptr", DllStructGetPtr($dBuf), _
			"int", $a_i_Count, _
			"int", "")
	If @error Or Not IsArray($av) Or $av[0] = 0 Then Return ""
	Local $sHex = ""
	Local $k = 1
	For $k = 1 To $a_i_Count
		If $sHex <> "" Then $sHex &= " "
		$sHex &= Hex(DllStructGetData($dBuf, 1, $k), 2)
	Next
	Return $sHex
EndFunc

Func Wine_CompactHex($a_s_Hex)
	Return StringUpper(StringReplace(StringStripWS(String($a_s_Hex), 8), " ", ""))
EndFunc

Func Wine_PatternMatchesHex($a_s_Hay, $a_s_Pat)
	Local $sHay = Wine_CompactHex($a_s_Hay)
	Local $sPat = Wine_CompactHex($a_s_Pat)
	If $sHay = "" Or $sPat = "" Then Return False
	If Mod(StringLen($sPat), 2) = 1 Then Return False
	If StringLen($sHay) < StringLen($sPat) Then Return False
	Local $i = 1
	For $i = 1 To StringLen($sPat) Step 2
		Local $sWant = StringMid($sPat, $i, 2)
		If $sWant = "00" Then ContinueLoop
		If StringMid($sHay, $i, 2) <> $sWant Then Return False
	Next
	Return True
EndFunc

Func Wine_TextFirst8Live()
	Local $pText0 = 0
	If IsDeclared("g_ai2_Sections") And IsArray($g_ai2_Sections) Then
		$pText0 = $g_ai2_Sections[$GC_I_SECTION_TEXT][0]
	EndIf
	If $pText0 = 0 Then Return False
	Local $sBytes = Wine_ReadBytesHex($pText0, 8)
	If $sBytes = "" Then Return False
	If StringReplace(StringReplace($sBytes, "00", ""), " ", "") = "" Then Return False
	Return True
EndFunc

Func Wine_EnsureGwOpen($a_i_Pid = 0)
	If $a_i_Pid <= 0 Then $a_i_Pid = Number($g_i_GWProcessId)
	If $g_h_GWProcess = 0 Then
		If $a_i_Pid <= 0 Then Return False
		Memory_Open($a_i_Pid)
		$g_i_GWProcessId = $a_i_Pid
	EndIf
	If $g_h_GWProcess = 0 Then Return False
	If Not $g_b_SectionsInitialized Then
		If Not Scanner_InitializeSections() Then Return False
	EndIf
	Return True
EndFunc

Func Wine_ReadLivePtr($a_p_Site)
	If $a_p_Site = 0 Then Return 0
	Local $d = 0
	For $d = 0 To 1
		Local $p = Memory_Read($a_p_Site - $d)
		If Wine_IsUserPtr($p) Then Return $p
	Next
	Return 0
EndFunc

Func Wine_ResolveFuncStart($a_p_Site)
	If $a_p_Site = 0 Then Return 0
	Local $aiOff[3] = [0, -1, 1]
	Local $i = 0
	For $i = 0 To 2
		Local $p = $a_p_Site + $aiOff[$i]
		If Wine_CompactHex(Wine_ReadBytesHex($p, 3)) = "558BEC" Then Return $p
	Next
	If Wine_IsUserPtr($a_p_Site) Then Return $a_p_Site
	Return 0
EndFunc

Func Wine_ResolveCallTarget($a_p_Site)
	If $a_p_Site = 0 Then Return 0
	; ASM GetScannedAddress is P-1+offset. Prefer site-1, then a 558BEC target.
	Local $aiOff[3] = [-1, 0, 1]
	Local $pFallback = 0
	Local $i = 0
	For $i = 0 To 2
		Local $p = $a_p_Site + $aiOff[$i]
		If Wine_CompactHex(Wine_ReadBytesHex($p, 1)) <> "E8" Then ContinueLoop
		Local $pT = Scanner_GetCallTargetAddress($p)
		If Not Wine_IsUserPtr($pT) Then ContinueLoop
		If Wine_CompactHex(Wine_ReadBytesHex($pT, 3)) = "558BEC" Then
			Out("Wine call target " & Wine_HexPtr($pT) & " from " & Wine_HexPtr($p) & " (d=" & $aiOff[$i] & ", prologue 558BEC)")
			Return $pT
		EndIf
		If $pFallback = 0 Then $pFallback = $pT
	Next
	If $pFallback <> 0 Then Out("Wine call target " & Wine_HexPtr($pFallback) & " (no 558BEC prologue)")
	Return $pFallback
EndFunc

; Queue enters (Ui_EnterChallenge / PARTY_ENTER_CHALLENGE 0xA5) both started
; a load then dumped this wine-gw client to character select. Click the
; visible Enter Mission button instead — no PacketSend, no EnterMission stub.
;
; wine-gw: ClientToScreen(636,22) -> (636,52) landed ABOVE the Gw window
; (xdotool X=5 Y=59 1272x713). Do not trust ClientToScreen; post client
; WM_LBUTTON* / ControlClick, and only MouseClick a point inside WinGetPos.

Func Wine_WindowClass($a_h_Wnd)
	If $a_h_Wnd = 0 Then Return ""
	Local $a = DllCall("user32.dll", "int", "GetClassNameA", "hwnd", $a_h_Wnd, "str", "", "int", 256)
	If IsArray($a) Then Return $a[2]
	Return ""
EndFunc

; Outer "Guild Wars Reforged" frame (xdotool Y=59). DX child WinGetPos
; can sit higher (~Y=30) so child-based screen Y=54 is above the frame.
Func Wine_GwFrameHwnd($a_h_Wnd)
	Local $iPid = 0
	If $a_h_Wnd <> 0 Then $iPid = Number(WinGetProcess($a_h_Wnd))
	If $iPid <= 0 Then $iPid = Number($g_i_GWProcessId)
	Local $aWins = WinList()
	If IsArray($aWins) Then
		Local $i = 1
		For $i = 1 To $aWins[0][0]
			If $aWins[$i][0] = "" Then ContinueLoop
			If Not StringInStr($aWins[$i][0], "Guild Wars") Then ContinueLoop
			If $iPid > 0 And Number(WinGetProcess($aWins[$i][1])) <> $iPid Then ContinueLoop
			Return $aWins[$i][1]
		Next
	EndIf
	Local $h = $a_h_Wnd
	Local $n = 0
	While $h <> 0 And $n < 6
		If StringInStr(WinGetTitle($h), "Guild Wars") Then Return $h
		Local $aPar = DllCall("user32.dll", "hwnd", "GetParent", "hwnd", $h)
		If Not IsArray($aPar) Or $aPar[0] = 0 Then ExitLoop
		$h = $aPar[0]
		$n += 1
	WEnd
	Return $a_h_Wnd
EndFunc

; Prefer ArenaNet_Dx_Window_Class (the game client), not the frame.
Func Wine_GwClientHwnd($a_h_Wnd)
	If $a_h_Wnd = 0 Then $a_h_Wnd = $g_h_GWWindow
	If $a_h_Wnd = 0 Then $a_h_Wnd = Wine_FindGwHwnd($g_i_GWProcessId)
	If $a_h_Wnd = 0 Then Return 0
	If Wine_WindowClass($a_h_Wnd) = $GC_S_CLASS_DX_WINDOW Then Return $a_h_Wnd
	Local $iPid = Number(WinGetProcess($a_h_Wnd))
	Local $aClass = WinList("[CLASS:" & $GC_S_CLASS_DX_WINDOW & "]")
	If IsArray($aClass) Then
		Local $i = 1
		For $i = 1 To $aClass[0][0]
			If $iPid > 0 And WinGetProcess($aClass[$i][1]) <> $iPid Then ContinueLoop
			Return $aClass[$i][1]
		Next
	EndIf
	Return $a_h_Wnd
EndFunc

; Client (x,y) -> desktop using the OUTER framed window (xdotool Y=59), not
; the DX child's WinGetPos (top ~30). Reject any point above the frame top.
Func Wine_ClientToScreenSafe($a_h_Wnd, $a_i_X, $a_i_Y)
	Local $aOut[2] = [0, 0]
	If $a_h_Wnd = 0 Then Return $aOut
	Local $hFrame = Wine_GwFrameHwnd($a_h_Wnd)
	If $hFrame = 0 Then $hFrame = $a_h_Wnd
	Local $aPos = WinGetPos($hFrame)
	Local $aCli = WinGetClientSize($hFrame)
	Local $iL = 0
	Local $iT = 0
	Local $iW = 0
	Local $iH = 0
	If IsArray($aPos) Then
		$iL = Number($aPos[0])
		$iT = Number($aPos[1])
		$iW = Number($aPos[2])
		$iH = Number($aPos[3])
	EndIf
	Local $iCw = $iW
	Local $iCh = $iH
	If IsArray($aCli) Then
		$iCw = Number($aCli[0])
		$iCh = Number($aCli[1])
	EndIf
	Local $iBorder = 0
	Local $iTitle = 0
	If $iW > $iCw And $iH > $iCh Then
		$iBorder = Int(($iW - $iCw) / 2)
		$iTitle = $iH - $iCh - $iBorder
		If $iTitle < 0 Then $iTitle = 0
	EndIf
	Local $iSx = $iL + $iBorder + $a_i_X
	Local $iSy = $iT + $iTitle + $a_i_Y
	If $iSy < $iT Then $iSy = $iT + $iTitle + $a_i_Y
	If $iW > 0 And ($iSx < $iL Or $iSx >= $iL + $iW Or $iSy < $iT Or $iSy >= $iT + $iH) Then
		Out("Wine enter: frame-mapped " & $iSx & "," & $iSy & " still outside frame " & $iL & "," & $iT & " " & $iW & "x" & $iH)
		Return $aOut
	EndIf
	$aOut[0] = $iSx
	$aOut[1] = $iSy
	Return $aOut
EndFunc

Func Wine_PostClientClick($a_h_Wnd, $a_i_X, $a_i_Y)
	If $a_h_Wnd = 0 Then Return
	Local $iLp = BitOR(BitAND($a_i_X, 0xFFFF), BitShift(BitAND($a_i_Y, 0xFFFF), -16))
	DllCall("user32.dll", "bool", "PostMessage", "hwnd", $a_h_Wnd, "uint", 0x0200, "wparam", 0, "lparam", $iLp)
	DllCall("user32.dll", "bool", "PostMessage", "hwnd", $a_h_Wnd, "uint", 0x0201, "wparam", 1, "lparam", $iLp)
	Sleep(40)
	DllCall("user32.dll", "bool", "PostMessage", "hwnd", $a_h_Wnd, "uint", 0x0202, "wparam", 0, "lparam", $iLp)
EndFunc

Func Wine_ClientClick($a_h_Wnd, $a_i_X, $a_i_Y)
	If $a_h_Wnd = 0 Then Return
	Local $hCli = Wine_GwClientHwnd($a_h_Wnd)
	If $hCli = 0 Then $hCli = $a_h_Wnd
	Out("Wine enter: client click " & $a_i_X & "," & $a_i_Y & " hwnd=" & $hCli & " class=" & Wine_WindowClass($hCli))
	Wine_PostClientClick($hCli, $a_i_X, $a_i_Y)
	ControlClick($hCli, "", "", "left", 1, $a_i_X, $a_i_Y)
	Local $aScr = Wine_ClientToScreenSafe($hCli, $a_i_X, $a_i_Y)
	If $aScr[0] <> 0 Or $aScr[1] <> 0 Then
		Out("Wine enter: frame-mapped screen " & $aScr[0] & "," & $aScr[1] & " (client " & $a_i_X & "," & $a_i_Y & ")")
		Local $iMode = Opt("MouseCoordMode", 1)
		MouseClick("left", $aScr[0], $aScr[1], 1, 0)
		Opt("MouseCoordMode", $iMode)
	EndIf
EndFunc

; Durable enter proof only. Do not use InstanceInfo Type / IsWaitingForMission
; / objectives — those flicker on Wine and falsely latch $g_b_WineEnterSent.
Func Wine_EnterMapEvidence($a_i_StartMap)
	Local $iMap = Map_GetMapID()
	Local $iCur = Number(Map_GetCharacterInfo("CurrentMapID"))
	If $iMap = 246 Or $iCur = 246 Then Return True
	If $iMap = 245 Or $iCur = 245 Then Return True
	If $iMap > 0 And $iMap <> $a_i_StartMap And $iMap <> 213 And $iMap <> 214 Then Return True
	If $iCur > 0 And $iCur <> $a_i_StartMap And $iCur <> 213 And $iCur <> 214 Then Return True
	Return False
EndFunc

; True only if map evidence stays true for ~1.2s (not a one-tick flicker).
; Once 246 is seen, keep waiting out the hold even after $a_i_Timeout.
Func Wine_WaitEnterEvidence($a_i_StartMap, $a_i_Timeout = 2000)
	Local $hAll = TimerInit()
	Local $hHeld = 0
	While True
		If Wine_EnterMapEvidence($a_i_StartMap) Then
			If $hHeld = 0 Then $hHeld = TimerInit()
			If TimerDiff($hHeld) >= 1200 Then Return True
		Else
			$hHeld = 0
			If TimerDiff($hAll) >= $a_i_Timeout Then Return False
		EndIf
		Sleep(200)
	WEnd
	Return False
EndFunc

Func Wine_EnterLooksStarted($a_i_StartMap)
	Return Wine_EnterMapEvidence($a_i_StartMap)
EndFunc

Func Wine_LevelerOverlayHold()
	If Not IsDeclared("g_h_MainGui") Then Return
	If $g_h_MainGui = 0 Then Return
	WinSetOnTop($g_h_MainGui, "", 0)
	WinSetState($g_h_MainGui, "", @SW_HIDE)
EndFunc

Func Wine_LevelerOverlayRestore()
	If Not IsDeclared("g_h_MainGui") Then Return
	If $g_h_MainGui = 0 Then Return
	WinSetState($g_h_MainGui, "", @SW_SHOW)
	If IsDeclared("g_h_OnTopCheckbox") And BitAND(GUICtrlRead($g_h_OnTopCheckbox), $GUI_CHECKED) Then
		WinSetOnTop($g_h_MainGui, "", 1)
	EndIf
EndFunc

Func Wine_EnterChallenge()
	Local $iNow = Map_GetMapID()
	If Wine_EnterMapEvidence($iNow) And Wine_WaitEnterEvidence($iNow, 2000) Then
		$g_b_WineEnterSent = True
		Out("Wine enter: already inside the mission (map " & Map_GetMapID() & " current " & Number(Map_GetCharacterInfo("CurrentMapID")) & ").")
		Return True
	EndIf
	If $g_b_WineEnterSent Then
		If Wine_EnterMapEvidence($iNow) Then
			Out("Wine enter: mission load already started this attach; not clicking again.")
			Return True
		EndIf
		Out("Wine enter: previous latch was stale (still map " & $iNow & "); retrying clicks.")
		$g_b_WineEnterSent = False
	EndIf

	Local $hWnd = $g_h_GWWindow
	If $hWnd = 0 Then $hWnd = Wine_FindGwHwnd($g_i_GWProcessId)
	If $hWnd = 0 Then
		Out("Wine enter: no Gw window for Enter Mission click")
		Return False
	EndIf

	Local $iStart = Map_GetMapID()
	Local $hCli = Wine_GwClientHwnd($hWnd)
	If $hCli <> 0 Then $hWnd = $hCli
	Wine_LevelerOverlayHold()
	WinSetOnTop($hWnd, "", 1)
	WinActivate($hWnd)
	WinWaitActive($hWnd, "", 2)
	DllCall("user32.dll", "bool", "SetForegroundWindow", "hwnd", $hWnd)
	DllCall("user32.dll", "bool", "BringWindowToTop", "hwnd", $hWnd)
	Sleep(400)

	Local $hFrame = Wine_GwFrameHwnd($hWnd)
	Local $aPos = WinGetPos($hFrame)
	Local $aDx = WinGetPos($hWnd)
	Local $aSz = WinGetClientSize($hWnd)
	Local $iW = 800
	Local $iH = 600
	If IsArray($aSz) Then
		$iW = Number($aSz[0])
		$iH = Number($aSz[1])
	EndIf
	If $iW < 200 Then $iW = 800
	If $iH < 200 Then $iH = 600
	Local $sFrame = "?"
	Local $sDx = "?"
	If IsArray($aPos) Then $sFrame = $aPos[0] & "," & $aPos[1] & " " & $aPos[2] & "x" & $aPos[3]
	If IsArray($aDx) Then $sDx = $aDx[0] & "," & $aDx[1] & " " & $aDx[2] & "x" & $aDx[3]
	Local $iCx = Int($iW / 2)
	Out("Wine enter: dx=" & $hWnd & " class=" & Wine_WindowClass($hWnd) & " dxPos=" & $sDx & " frame=" & $sFrame & " client=" & $iW & "x" & $iH & " (overlay hidden)")

	ControlSend($hWnd, "", "", "{ENTER}")
	If Wine_WaitEnterEvidence($iStart, 2500) Then
		$g_b_WineEnterSent = True
		Out("Wine enter: {ENTER} loaded map " & Map_GetMapID() & " current " & Number(Map_GetCharacterInfo("CurrentMapID")))
		WinSetOnTop($hWnd, "", 0)
		Wine_LevelerOverlayRestore()
		Return True
	EndIf
	; {ENTER} often starts the load while map is still 213. More PostMessage /
	; MouseClick during DX reset crashes Gw. Stop input and wait for held 246.
	If Wine_WaitLoadHint($iStart, 1200) Then
		Out("Wine enter: load started after {ENTER}; waiting for held 246 (no more clicks)")
		If Wine_WaitEnterEvidence($iStart, 45000) Then
			$g_b_WineEnterSent = True
			Out("Wine enter: held map " & Map_GetMapID() & " current " & Number(Map_GetCharacterInfo("CurrentMapID")))
			WinSetOnTop($hWnd, "", 0)
			Wine_LevelerOverlayRestore()
			Return True
		EndIf
		WinSetOnTop($hWnd, "", 0)
		Wine_LevelerOverlayRestore()
		Out("Wine enter: load started but 246 did not hold. Not latching.")
		Return False
	EndIf

	Local $aiY[6] = [22, 32, 42, 54, 68, 80]
	Local $aiXOff[3] = [0, -40, 40]
	Local $iY = 0
	Local $iX = 0
	For $iY = 0 To 5
		For $iX = 0 To 2
			If Wine_EnterLoadStarted($iStart) Or Wine_MapIsLoading() Then ExitLoop 2
			Wine_ClientClick($hWnd, $iCx + $aiXOff[$iX], $aiY[$iY])
			If Wine_WaitEnterEvidence($iStart, 1600) Then
				$g_b_WineEnterSent = True
				Out("Wine enter: click loaded map " & Map_GetMapID() & " current " & Number(Map_GetCharacterInfo("CurrentMapID")))
				WinSetOnTop($hWnd, "", 0)
				Wine_LevelerOverlayRestore()
				Return True
			EndIf
			If Wine_EnterLoadStarted($iStart) Or Wine_WaitLoadHint($iStart, 400) Then ExitLoop 2
		Next
	Next
	If Wine_EnterLoadStarted($iStart) Or Wine_MapIsLoading() Or Wine_EnterMapEvidence($iStart) Then
		Out("Wine enter: load started; waiting for held 246 (no more clicks)")
		If Wine_WaitEnterEvidence($iStart, 45000) Then
			$g_b_WineEnterSent = True
			Out("Wine enter: held map " & Map_GetMapID() & " current " & Number(Map_GetCharacterInfo("CurrentMapID")))
			WinSetOnTop($hWnd, "", 0)
			Wine_LevelerOverlayRestore()
			Return True
		EndIf
		WinSetOnTop($hWnd, "", 0)
		Wine_LevelerOverlayRestore()
		Out("Wine enter: load started but 246 did not hold. Not latching.")
		Return False
	EndIf
	ControlSend($hWnd, "", "", "{ENTER}")
	If Wine_WaitEnterEvidence($iStart, 2500) Then
		$g_b_WineEnterSent = True
		Out("Wine enter: {ENTER} loaded map " & Map_GetMapID() & " current " & Number(Map_GetCharacterInfo("CurrentMapID")))
		WinSetOnTop($hWnd, "", 0)
		Wine_LevelerOverlayRestore()
		Return True
	EndIf
	WinSetOnTop($hWnd, "", 0)
	Wine_LevelerOverlayRestore()
	Out("Wine enter: no durable map change (still " & Map_GetMapID() & " current " & Number(Map_GetCharacterInfo("CurrentMapID")) & "). Not latching.")
	Return False
EndFunc

Func Wine_FreeAsmAlloc($a_p)
	If $a_p = 0 Or $g_h_GWProcess = 0 Then Return
	DllCall($g_h_Kernel32, "bool", "VirtualFreeEx", "handle", $g_h_GWProcess, "ptr", $a_p, "ulong_ptr", 0, "dword", 0x8000)
EndFunc

Func Wine_InjectAbort($a_s_Reason, $a_p_Alloc = 0)
	Out("Wine inject abort: " & $a_s_Reason)
	If $a_p_Alloc <> 0 Then Wine_FreeAsmAlloc($a_p_Alloc)
	$g_p_WineAsmAlloc = 0
	$g_b_WineMinimalHook = False
	Return False
EndFunc

Func Wine_LabelUserPtr($a_s_Key)
	If Not IsDeclared("g_amx2_Labels") Then Return 0
	Local $v = Memory_GetValue($a_s_Key)
	If Wine_IsUserPtr($v) Then Return $v
	Return 0
EndFunc

Func Wine_CommandsReady()
	If Not IsDeclared("g_p_QueueBase") Then Return False
	If Not Wine_IsUserPtr($g_p_QueueBase) Then Return False
	Return True
EndFunc

; Walking only needs QueueBase + CommandMove + an Engine drain (live E9).
Func Wine_QueueWalkReady()
	If Not Wine_CommandsReady() Then Return False
	If Wine_LabelUserPtr("CommandMove") = 0 Then Return False
	If Wine_EngineHookLive() Then Return True
	If $g_p_WineExistingE9 <> 0 Then Return True
	Return False
EndFunc

; Type 2 / map 0 / CurrentMapType 2. Do not inject or write skills here.
Func Wine_MapIsLoading()
	If Map_GetMapID() <= 0 Then Return True
	If Number(Map_GetInstanceInfo("Type")) = 2 Then Return True
	If Number(Map_GetCharacterInfo("CurrentMapType")) = 2 Then Return True
	Return False
EndFunc

; Queue from this attach is still valid. Never plant a second Engine JMP.
Func Wine_QueueAlreadyLive()
	If Not Wine_CommandsReady() Then Return False
	If Wine_EngineHookLive() Then Return True
	If $g_p_WineExistingE9 <> 0 Then Return True
	If $g_b_WineMinimalHook Then Return True
	If $g_p_WineAsmAlloc <> 0 Then Return True
	Return False
EndFunc

; Real map change off the outpost, or durable 246. Not a one-tick Type flicker.
Func Wine_EnterLoadStarted($a_i_StartMap)
	If Wine_EnterMapEvidence($a_i_StartMap) Then Return True
	Local $iMap = Map_GetMapID()
	If $iMap <= 0 Then Return True
	If $iMap <> $a_i_StartMap And $iMap <> 213 And $iMap <> 214 Then Return True
	Return False
EndFunc

; After {ENTER}: 246, left 213, or Type=2 held ~800ms. Used to stop the click storm.
Func Wine_WaitLoadHint($a_i_StartMap, $a_i_Timeout = 2500)
	Local $hAll = TimerInit()
	Local $hT2 = 0
	While TimerDiff($hAll) < $a_i_Timeout
		If Wine_EnterMapEvidence($a_i_StartMap) Then Return True
		If Wine_EnterLoadStarted($a_i_StartMap) Then Return True
		If Wine_MapIsLoading() Then
			If $hT2 = 0 Then $hT2 = TimerInit()
			If TimerDiff($hT2) >= 800 Then Return True
		Else
			$hT2 = 0
		EndIf
		Sleep(200)
	WEnd
	Return Wine_EnterMapEvidence($a_i_StartMap) Or Wine_EnterLoadStarted($a_i_StartMap)
EndFunc

Func Wine_EnterMissionReady()
	Local $pCmd = Wine_LabelUserPtr("CommandEnterMission")
	If $pCmd = 0 Then Return False
	If Not IsDeclared("g_d_EnterMission") Then Return False
	Local $pStruct = DllStructGetData($g_d_EnterMission, 1)
	If Wine_IsUserPtr($pStruct) Then Return True
	Return False
EndFunc

Func Wine_EngineHookLive()
	Local $p = Wine_LabelUserPtr("MainStart")
	If $p = 0 Then Return False
	Return StringLeft(Wine_CompactHex(Wine_ReadBytesHex($p, 5)), 2) = "E9"
EndFunc

; Pull live pointers Core_Initialize already wrote into labels but left in
; $g_p_QueueBase / command structs as 0. No process writes.
Func Wine_RefreshQueueFromLabels()
	Local $pQueue = Wine_LabelUserPtr("QueueBase")
	If $pQueue <> 0 Then $g_p_QueueBase = $pQueue
	Local $pAgent = Wine_LabelUserPtr("AgentBase")
	If $pAgent <> 0 Then
		$g_p_AgentBase = $pAgent
		If IsDeclared("g_i_MaxAgents") Then $g_i_MaxAgents = $pAgent + 0x8
	EndIf
	Local $pMy = Wine_LabelUserPtr("MyID")
	If $pMy <> 0 Then $g_i_MyID = $pMy
	Local $pBase = Wine_LabelUserPtr("BasePointer")
	If $pBase <> 0 Then $g_p_BasePointer = $pBase
	Local $pPkt = Wine_LabelUserPtr("PacketLocation")
	If $pPkt <> 0 Then $g_p_PacketLocation = $pPkt
	Local $pSaved = Wine_LabelUserPtr("SavedIndex")
	If $pSaved <> 0 Then $g_p_SavedIndex = $pSaved
	Local $pMap = Wine_LabelUserPtr("MapIsLoaded")
	If $pMap <> 0 Then $g_p_MapIsLoaded = $pMap
	If Wine_IsUserPtr(Memory_GetValue("QueueSize")) Or Number(Memory_GetValue("QueueSize")) > 0 Then
		$g_i_QueueSize = Number(Memory_GetValue("QueueSize")) - 1
		If $g_i_QueueSize < 1 Then $g_i_QueueSize = 0x100 - 1
	EndIf
	Wine_WireCommandStructs()
EndFunc

Func Wine_WireCommandStructs()
	Local $pPkt = Wine_LabelUserPtr("CommandPacketSend")
	If $pPkt <> 0 Then
		DllStructSetData($g_d_Packet, 1, $pPkt)
		DllStructSetData($g_d_InviteGuild, 1, $pPkt)
	EndIf
	Local $pMove = Wine_LabelUserPtr("CommandMove")
	If $pMove <> 0 Then DllStructSetData($g_d_Move, 1, $pMove)
	Local $pDlg = Wine_LabelUserPtr("CommandDialog")
	If $pDlg <> 0 Then DllStructSetData($g_d_Dialog, 1, $pDlg)
	Local $pInt = Wine_LabelUserPtr("CommandInteract")
	If $pInt <> 0 Then DllStructSetData($g_d_Interact, 1, $pInt)
	Local $pEnt = Wine_LabelUserPtr("CommandEnterMission")
	If $pEnt <> 0 Then DllStructSetData($g_d_EnterMission, 1, $pEnt)
	Local $pUi = Wine_LabelUserPtr("CommandUIMsg")
	If $pUi <> 0 Then
		DllStructSetData($g_d_MoveMap, 1, $pUi)
		DllStructSetData($g_d_EquipItem, 1, $pUi)
		DllStructSetData($g_d_Xunlai, 1, $pUi)
		DllStructSetData($g_d_CloseDialog, 1, $pUi)
	EndIf
EndFunc

; Called from the first Leveler_ExecuteStep / Map_Move, not from Start.
; Prefers a live QueueBase Core already allocated; otherwise one Engine JMP
; and a small command page (CommandMove / CommandEnterMission / ...).
; Retries while QueueBase is still dead so a missed first step can recover.
Func Wine_EnsureCommandQueue()
	If Not Wine_IsWine() Then Return True
	If Not Wine_EnsureGwOpen() Then
		Out("Wine queue: no Gw process handle")
		Return False
	EndIf
	Wine_RefreshQueueFromLabels()
	If Wine_QueueWalkReady() Then
		$g_b_WineMinimalHook = True
		Return True
	EndIf
	; Map load to 246 must not rewrite Engine JMP / QueueBase. Reuse the page.
	If Wine_QueueAlreadyLive() Then
		Out("Wine queue: QueueBase already live; not re-injecting Engine JMP (map " & Map_GetMapID() & ")")
		Wine_WireCommandStructs()
		$g_b_WineMinimalHook = True
		Return True
	EndIf
	If Wine_MapIsLoading() Then
		Out("Wine queue: map is loading; not injecting Engine JMP")
		Return False
	EndIf
	If Wine_CommandsReady() Then
		If Wine_PlantEngineJmpOnly() Then Return True
		If Wine_EngineHookLive() Then
			Wine_WireCommandStructs()
			$g_b_WineMinimalHook = True
			Return True
		EndIf
	EndIf
	If $g_b_WineQueueAttempted Then
		If $g_h_WineQueueLastTry <> 0 And TimerDiff($g_h_WineQueueLastTry) < 8000 Then
			Return Wine_QueueWalkReady()
		EndIf
		Out("Wine queue: QueueBase still " & Wine_HexPtr($g_p_QueueBase) & " after last install; retrying.")
	EndIf
	$g_b_WineQueueAttempted = True
	$g_h_WineQueueLastTry = TimerInit()
	Out("Wine queue: Core_Initialize left QueueBase=" & Wine_HexPtr($g_p_QueueBase) & _
			" CommandMove=" & Wine_HexPtr(Memory_GetValue("CommandMove")) & _
			" CommandEnterMission=" & Wine_HexPtr(Memory_GetValue("CommandEnterMission")) & _
			" MainStart=" & Wine_HexPtr(Memory_GetValue("MainStart")) & ". Installing lazily.")
	If Not Wine_TextFirst8Live() Then
		Return Wine_InjectAbort("refusing scan; .text first8 is not live")
	EndIf
	If Wine_CommandsReady() Then
		If Wine_PlantEngineJmpOnly() Then Return True
		If Wine_EngineHookLive() Then Return True
		Out("Wine queue: existing command page could not be hooked; trying a new page.")
	EndIf
	Local $b_Ok = Wine_InstallCommandQueue()
	Wine_RefreshQueueFromLabels()
	If $b_Ok And Wine_CommandsReady() Then
		Out("Wine queue: live QueueBase=" & Wine_HexPtr($g_p_QueueBase) & _
				" CommandMove=" & Wine_HexPtr(Memory_GetValue("CommandMove")) & _
				" AgentBase=" & Wine_HexPtr($g_p_AgentBase))
		Return True
	EndIf
	Out("Wine queue: install finished with QueueBase=" & Wine_HexPtr($g_p_QueueBase) & " (walk not ready)")
	Return $b_Ok
EndFunc

Func Wine_LogCommandGap()
	If $g_b_WineQueueGapLogged Then Return
	$g_b_WineQueueGapLogged = True
	Out("Wine command queue is not live. Enter Mission / Map_Move / dialogs / packets will no-op.")
	Out("Restart Gw.exe if the Engine site is already E9 from an older inject, then Start again.")
EndFunc

Func Wine_RegisterQueuePatterns()
	Scanner_AddPattern("BasePointer", "506A0F6A00FF35", 0x8, "Ptr")
	Scanner_AddPattern("AgentBase", "8B0C9085C97419", -0x3, "Ptr")
	Scanner_AddPattern("MyID", "83EC08568BF13B15", -0x3, "Ptr")
	Scanner_AddPattern("Move", "558BEC83EC208D45F0", 0x1, "Func")
	Scanner_AddPattern("Engine", "568B3085F67478EB038D4900D9460C", -0x22, "Hook")
	Scanner_AddPattern("PacketSend", "C747540000000081E6", -0x4F, "Func")
	Scanner_AddPattern("PacketLocation", "83C40433C08BE55DC3A1", 0xB, "Ptr")
	Scanner_AddPattern("Dialog", "894B248B4B2883E900", 0x16, "Func")
	Scanner_AddPattern("Interact", "894B248B4B2883E900", 0x26, "Func")
	Scanner_AddPattern("EnterMission", "83C902890A5D", 0x24, "Func")
	Scanner_AddPattern("UIMessage", "B900000000E8000000005DC3894508", -0x14, "Func")
	Scanner_AddPattern("InstanceInfo", "6A2C50E80000000083C408C7", 0xE, "Ptr")
	Scanner_AddPattern("Region", "6A548D46248908", -0x3, "Ptr")
EndFunc

Func Wine_BindReadOnlyFromQueue($aResults, $a_amx2_Patterns)
	Local $aSave = $g_amx2_Patterns
	$g_amx2_Patterns = $a_amx2_Patterns
	Local $pBaseSite = Scanner_GetScanResult("BasePointer", $aResults, "Ptr")
	Local $pAgentSite = Scanner_GetScanResult("AgentBase", $aResults, "Ptr")
	Local $pMySite = Scanner_GetScanResult("MyID", $aResults, "Ptr")
	$g_amx2_Patterns = $aSave

	Local $pBase = Wine_ReadLivePtr($pBaseSite)
	Local $pAgent = Wine_ReadLivePtr($pAgentSite)
	Local $pMy = Wine_ReadLivePtr($pMySite)
	If $pBase <> 0 Then
		$g_p_BasePointer = $pBase
		Wine_ReplaceValue("BasePointer", Ptr($pBase))
	EndIf
	If $pAgent <> 0 Then
		$g_p_AgentBase = $pAgent
		If IsDeclared("g_i_MaxAgents") Then $g_i_MaxAgents = $pAgent + 0x8
		Wine_ReplaceValue("AgentBase", Ptr($pAgent))
		Wine_ReplaceValue("MaxAgents", Ptr($g_i_MaxAgents))
	EndIf
	If $pMy <> 0 Then
		$g_i_MyID = $pMy
		Wine_ReplaceValue("MyID", Ptr($pMy))
	EndIf
	Out("Wine bind: BasePointer=" & Wine_HexPtr($pBase) & " AgentBase=" & Wine_HexPtr($pAgent) & _
			" MyID=" & Wine_HexPtr($pMy) & " (read-only; Enter Mission does not require AgentBase)")
	Return True
EndFunc

; Wine 4KB uses match+offset (no ASM P-1). On wine-gw the Engine needle
; landed one byte late: site was EC D9 45 08, real hook is 8B EC D9 45 08
; at site-1, with the needle at hook+0x23. Accept hook+0x21/22/23.
Func Wine_EnginePatternNear($a_p_Hook)
	If $a_p_Hook = 0 Then Return False
	Local Const $sPat = "568B3085F67478EB038D4900D9460C"
	Local $aiOff[3] = [0, -1, 1]
	Local $i = 0
	For $i = 0 To 2
		If Wine_PatternMatchesHex(Wine_ReadBytesHex($a_p_Hook + 0x22 + $aiOff[$i], 15), $sPat) Then Return True
	Next
	Return False
EndFunc

; Prefer the MainExit epilogue 8B EC D9 45 08 near the scan result.
; Do not plant if that site (or the 1-byte-late match) already starts with E9.
Func Wine_FindEngineHookSite($a_p_Engine)
	If $a_p_Engine = 0 Then Return 0
	Local Const $sEpi = "8BECD94508"
	Local $aiOff[7] = [0, -1, 1, -2, 2, -3, 3]
	Local $pE9 = 0
	Local $pLate = 0
	Local $sLate = ""
	Local $i = 0
	For $i = 0 To 6
		Local $pCand = $a_p_Engine + $aiOff[$i]
		If Not Wine_IsUserPtr($pCand) Then ContinueLoop
		Local $sFive = Wine_ReadBytesHex($pCand, 5)
		Local $sFiveC = Wine_CompactHex($sFive)
		Local $bNear = Wine_EnginePatternNear($pCand)
		Out("Wine Engine candidate " & Wine_HexPtr($pCand) & " d=" & $aiOff[$i] & " site5=" & $sFive & " near=" & $bNear)
		If StringLeft($sFiveC, 2) = "E9" And $bNear Then
			If $pE9 = 0 Then $pE9 = $pCand
			ContinueLoop
		EndIf
		If $sFiveC = $sEpi And $bNear Then
			If $aiOff[$i] <> 0 Then
				Out("Wine Engine: using " & Wine_HexPtr($pCand) & " (scan offset " & $aiOff[$i] & ", epilogue 8B EC D9 45 08)")
			EndIf
			Return $pCand
		EndIf
		If $bNear And $pLate = 0 Then
			$pLate = $pCand
			$sLate = $sFive
		EndIf
	Next
	If $pE9 <> 0 Then
		$g_p_WineExistingE9 = $pE9
		Out("Wine Engine: site already E9 at " & Wine_HexPtr($pE9) & "; will reuse that page, not plant a second JMP")
		Return 0
	EndIf
	If $pLate <> 0 Then
		Out("Wine inject abort: Engine pattern near " & Wine_HexPtr($pLate) & " but site 5 bytes are " & $sLate & " (expected 8B EC D9 45 08)")
		Return 0
	EndIf
	Out("Wine inject abort: Engine pattern 568B3085F67478... / epilogue 8B EC D9 45 08 not found near " & Wine_HexPtr($a_p_Engine))
	Return 0
EndFunc

Func Wine_AssembleMinimalEngine()
	_("SavedIndex/4")
	_("QueueCounter/4")
	_("MapIsLoaded/4")
	_("QueueBase/" & (256 * 256))

	_("MainProc:")
	_("pushad")
	_("pushfd")
	_("RegularFlow:")
	_("mov eax,dword[QueueCounter]")
	_("mov ecx,eax")
	_("shl eax,8")
	_("add eax,QueueBase")
	_("mov ebx,dword[eax]")
	_("test ebx,ebx")
	_("jz MainExit")
	_("mov dword[SavedIndex],ecx")
	_("mov dword[eax],0")
	_("jmp ebx")

	_("CommandReturn:")
	_("mov ecx,dword[SavedIndex]")
	_("mov edx,dword[QueueCounter]")
	_("cmp edx,ecx")
	_("jnz MainExit")
	_("mov eax,ecx")
	_("inc eax")
	_("cmp eax,QueueSize")
	_("jnz MainSkipReset")
	_("xor eax,eax")
	_("MainSkipReset:")
	_("mov dword[QueueCounter],eax")

	_("MainExit:")
	_("popfd")
	_("popad")
	_("mov ebp,esp")
	_("fld st(0),dword[ebp+8]")
	_("ljmp MainReturn")

	_("CommandPacketSend:")
	_("lea edx,dword[eax+8]")
	_("push edx")
	_("mov ebx,dword[eax+4]")
	_("push ebx")
	_("mov eax,dword[PacketLocation]")
	_("push eax")
	_("call PacketSend")
	_("pop eax")
	_("pop ebx")
	_("pop edx")
	_("ljmp CommandReturn")

	_("CommandMove:")
	_("lea eax,dword[eax+4]")
	_("push eax")
	_("call Move")
	_("pop eax")
	_("ljmp CommandReturn")

	_("CommandDialog:")
	_("push dword[eax+4]")
	_("call Dialog")
	_("add esp,4")
	_("ljmp CommandReturn")

	_("CommandInteract:")
	_("push dword[eax+4]")
	_("call Interact")
	_("add esp,4")
	_("ljmp CommandReturn")

	_("CommandEnterMission:")
	_("push dword[eax+4]")
	_("call EnterMission")
	_("add esp,4")
	_("ljmp CommandReturn")

	_("CommandUIMsg:")
	_("push 0")
	_("mov edx,eax")
	_("add edx,8")
	_("push edx")
	_("push dword[eax+4]")
	_("call UIMessage")
	_("add esp,C")
	_("ljmp CommandReturn")
EndFunc

Func Wine_ScanEngineOnly()
	Local $aSave = $g_amx2_Patterns
	Scanner_ClearPatterns()
	Scanner_AddPattern("Engine", "568B3085F67478EB038D4900D9460C", -0x22, "Hook")
	Local $aResults = Wine_ScanPatternsChunked()
	Local $pEngine = 0
	If IsArray($aResults) Then $pEngine = Scanner_GetScanResult("Engine", $aResults, "Hook")
	$g_amx2_Patterns = $aSave
	Return $pEngine
EndFunc

; Core already allocated QueueBase + CommandEnterMission. Plant the missing
; Engine JMP only (MainStart was 0 so Assembler_ModifyMemory wrote at null).
Func Wine_PlantEngineJmpOnly()
	If Wine_QueueAlreadyLive() Then Return True
	If Wine_MapIsLoading() Then Return False
	Local $pMain = Wine_LabelUserPtr("MainProc")
	If $pMain = 0 Then Return Wine_InjectAbort("JMP-only: MainProc label is not a user ptr")
	Local $pEngine = Wine_ScanEngineOnly()
	Local $pHook = Wine_FindEngineHookSite($pEngine)
	If $pHook = 0 Then Return False
	Local $sBefore = Wine_ReadBytesHex($pHook, 5)
	Out("Wine JMP-only: Engine site " & Wine_HexPtr($pHook) & " bytes=" & $sBefore & " MainProc=" & Wine_HexPtr($pMain))
	Wine_ReplaceValue("MainStart", Ptr($pHook))
	Wine_ReplaceValue("MainReturn", Ptr($pHook + 5))
	Memory_WriteDetour("MainStart", "MainProc")
	Local $sAfter = Wine_ReadBytesHex($pHook, 5)
	Out("Wine JMP-only after: " & $sAfter)
	If StringLeft(Wine_CompactHex($sAfter), 2) <> "E9" Then
		If Wine_CompactHex($sBefore) <> "" Then Memory_WriteBinary(Wine_CompactHex($sBefore), $pHook)
		Return Wine_InjectAbort("JMP-only did not stick; restored original site bytes")
	EndIf
	Wine_RefreshQueueFromLabels()
	$g_b_WineMinimalHook = True
	Out("Wine: reused Core command page. QueueBase=" & Wine_HexPtr($g_p_QueueBase) & " MainStart=" & Wine_HexPtr($pHook))
	Return True
EndFunc

Func Wine_InstallCommandQueue()
	If Wine_QueueAlreadyLive() Then
		Out("Wine inject: QueueBase already live; skipping a second Engine JMP")
		Return True
	EndIf
	If Wine_MapIsLoading() Then Return False
	Out("Wine inject: 4KB scan for Engine/Move/EnterMission/PacketSend/Dialog (read-only).")
	Local $aSave = $g_amx2_Patterns
	Scanner_ClearPatterns()
	Wine_RegisterQueuePatterns()
	Local $aResults = Wine_ScanPatternsChunked()
	Local $aQueuePatterns = $g_amx2_Patterns
	$g_amx2_Patterns = $aQueuePatterns
	If Not IsArray($aResults) Then
		$g_amx2_Patterns = $aSave
		Return Wine_InjectAbort("4KB queue scan failed")
	EndIf

	Local $pMove = Wine_ResolveFuncStart(Scanner_GetScanResult("Move", $aResults, "Func"))
	Local $pPacketSend = Wine_ResolveFuncStart(Scanner_GetScanResult("PacketSend", $aResults, "Func"))
	Local $pPacketLoc = Wine_ReadLivePtr(Scanner_GetScanResult("PacketLocation", $aResults, "Ptr"))
	Local $pDialog = Wine_ResolveCallTarget(Scanner_GetScanResult("Dialog", $aResults, "Func"))
	Local $pInteract = Wine_ResolveCallTarget(Scanner_GetScanResult("Interact", $aResults, "Func"))
	Local $pEnter = Wine_ResolveCallTarget(Scanner_GetScanResult("EnterMission", $aResults, "Func"))
	Local $pUiMsg = Wine_ResolveFuncStart(Scanner_GetScanResult("UIMessage", $aResults, "Func"))
	Local $pInst = Wine_ReadLivePtr(Scanner_GetScanResult("InstanceInfo", $aResults, "Ptr"))
	Local $pRegion = Wine_ReadLivePtr(Scanner_GetScanResult("Region", $aResults, "Ptr"))
	Local $pEngine = Scanner_GetScanResult("Engine", $aResults, "Hook")
	Wine_BindReadOnlyFromQueue($aResults, $aQueuePatterns)
	$g_amx2_Patterns = $aSave

	Out("Wine inject targets: Move=" & Wine_HexPtr($pMove) & " PacketSend=" & Wine_HexPtr($pPacketSend) & _
			" PacketLocation=" & Wine_HexPtr($pPacketLoc) & " Dialog=" & Wine_HexPtr($pDialog) & _
			" Interact=" & Wine_HexPtr($pInteract) & " EnterMission=" & Wine_HexPtr($pEnter) & _
			" UIMessage=" & Wine_HexPtr($pUiMsg))

	If $pMove = 0 Then Return Wine_InjectAbort("Move func not resolved")
	If $pPacketSend = 0 Then Return Wine_InjectAbort("PacketSend func not resolved")
	If $pPacketLoc = 0 Then Return Wine_InjectAbort("PacketLocation ptr not resolved")
	If $pDialog = 0 Then Return Wine_InjectAbort("Dialog call target not resolved")
	If $pInteract = 0 Then Return Wine_InjectAbort("Interact call target not resolved")
	If $pEnter = 0 Then Return Wine_InjectAbort("EnterMission call target not resolved")

	If $pInst <> 0 Then
		$g_p_InstanceInfo = $pInst
		Wine_ReplaceValue("InstanceInfo", Ptr($pInst))
		Out("Wine inject: InstanceInfo=" & Wine_HexPtr($pInst))
	Else
		Out("Wine inject: InstanceInfo not found (map-type reads may be wrong; not aborting)")
	EndIf
	If $pRegion <> 0 Then
		$g_p_Region = $pRegion
		Wine_ReplaceValue("Region", Ptr($pRegion))
	EndIf
	If $pUiMsg = 0 Then Out("Wine inject: UIMessage not resolved; travel/UIMsg may no-op after Enter Mission")

	Out("Wine Engine scan result=" & Wine_HexPtr($pEngine))
	$g_p_WineExistingE9 = 0
	Local $pHook = Wine_FindEngineHookSite($pEngine)
	Local $bReuse = False
	Local $pAlloc = 0
	If $pHook = 0 And $g_p_WineExistingE9 <> 0 Then
		$pHook = $g_p_WineExistingE9
		Local $pMainExist = Scanner_GetCallTargetAddress($pHook)
		$pAlloc = $pMainExist - (4 + 4 + 4 + 256 * 256)
		If Not Wine_IsUserPtr($pAlloc) Or Not Wine_IsUserPtr($pMainExist) Then
			Return Wine_InjectAbort("existing Engine JMP target is not a user page; restart Gw.exe")
		EndIf
		$bReuse = True
		Out("Wine: reusing Engine JMP " & Wine_HexPtr($pHook) & " -> MainProc " & Wine_HexPtr($pMainExist) & " page " & Wine_HexPtr($pAlloc))
	EndIf
	If $pHook = 0 Then Return False

	Local $sBefore = Wine_ReadBytesHex($pHook, 5)
	Out("Wine Engine site before JMP: " & Wine_HexPtr($pHook) & " bytes=" & $sBefore)
	If (Not $bReuse) And StringLeft(Wine_CompactHex($sBefore), 2) = "E9" Then
		Return Wine_InjectAbort("Engine site already starts with E9 at " & Wine_HexPtr($pHook) & "; QueueBase was not live. Restart Gw.exe.")
	EndIf

	Wine_ReplaceValue("Move", Ptr($pMove))
	Wine_ReplaceValue("PacketSend", Ptr($pPacketSend))
	Wine_ReplaceValue("PacketLocation", Ptr($pPacketLoc))
	Wine_ReplaceValue("Dialog", Ptr($pDialog))
	Wine_ReplaceValue("Interact", Ptr($pInteract))
	Wine_ReplaceValue("EnterMission", Ptr($pEnter))
	If Wine_IsUserPtr($pUiMsg) Then Wine_ReplaceValue("UIMessage", Ptr($pUiMsg))
	Wine_ReplaceValue("MainStart", Ptr($pHook))
	Wine_ReplaceValue("MainReturn", Ptr($pHook + 5))
	Wine_ReplaceValue("QueueSize", 0x100)
	$g_p_PacketLocation = $pPacketLoc

	$g_i_ASMSize = 0
	$g_i_ASMCodeOffset = 0
	$g_s_ASMCode = ""
	Wine_AssembleMinimalEngine()
	If $bReuse Then
		$g_p_WineAsmAlloc = 0
		$g_p_ASMMemory = $pAlloc
		Out("Wine inject: rewriting stubs on existing Queue/ASM page " & Wine_HexPtr($pAlloc))
	Else
		Local $iAlloc = Int($g_i_ASMSize) + 0x1000
		If $iAlloc < 0x11000 Then $iAlloc = 0x11000
		Out("Wine inject: VirtualAllocEx " & $iAlloc & " bytes RWX for queue+EnterMission (ASMSize=" & Int($g_i_ASMSize) & ")")

		Local $avAlloc = DllCall($g_h_Kernel32, "ptr", "VirtualAllocEx", _
				"handle", $g_h_GWProcess, _
				"ptr", 0, _
				"ulong_ptr", $iAlloc, _
				"dword", 0x3000, _
				"dword", 0x40)
		If @error Or Not IsArray($avAlloc) Or $avAlloc[0] = 0 Then
			Return Wine_InjectAbort("VirtualAllocEx failed")
		EndIf
		$pAlloc = $avAlloc[0]
		If Not Wine_IsUserPtr($pAlloc) Then Return Wine_InjectAbort("VirtualAllocEx returned non-user ptr " & Wine_HexPtr($pAlloc), $pAlloc)
		$g_p_WineAsmAlloc = $pAlloc
		$g_p_ASMMemory = $pAlloc
		Out("Wine inject: Queue/ASM page at " & Wine_HexPtr($pAlloc))
	EndIf

	Wine_PromoteNewLabels()
	Assembler_CompleteASMCode()
	If $g_s_ASMCode = "" Then
		If $bReuse Then Return Wine_InjectAbort("Assembler_CompleteASMCode produced no bytes")
		Return Wine_InjectAbort("Assembler_CompleteASMCode produced no bytes", $pAlloc)
	EndIf
	Memory_WriteBinary($g_s_ASMCode, $g_p_ASMMemory + $g_i_ASMCodeOffset)

	Local $pQueue = Memory_GetValue("QueueBase")
	Local $pMain = Memory_GetValue("MainProc")
	Local $pCmdMove = Memory_GetValue("CommandMove")
	Local $pCmdPkt = Memory_GetValue("CommandPacketSend")
	Local $pCmdDlg = Memory_GetValue("CommandDialog")
	Local $pCmdEnt = Memory_GetValue("CommandEnterMission")
	Local $pFreeOnAbort = 0
	If Not $bReuse Then $pFreeOnAbort = $pAlloc
	If Not Wine_IsUserPtr($pQueue) Then Return Wine_InjectAbort("QueueBase label is not a user ptr", $pFreeOnAbort)
	If Not Wine_IsUserPtr($pMain) Then Return Wine_InjectAbort("MainProc label is not a user ptr", $pFreeOnAbort)
	If Not Wine_IsUserPtr($pCmdMove) Then Return Wine_InjectAbort("CommandMove label is not a user ptr", $pFreeOnAbort)
	If Not Wine_IsUserPtr($pCmdPkt) Then Return Wine_InjectAbort("CommandPacketSend label is not a user ptr", $pFreeOnAbort)
	If Not Wine_IsUserPtr($pCmdDlg) Then Return Wine_InjectAbort("CommandDialog label is not a user ptr", $pFreeOnAbort)
	If Not Wine_IsUserPtr($pCmdEnt) Then Return Wine_InjectAbort("CommandEnterMission label is not a user ptr", $pFreeOnAbort)
	Out("Wine inject: QueueBase=" & Wine_HexPtr($pQueue) & " MainProc=" & Wine_HexPtr($pMain) & _
			" CommandEnterMission=" & Wine_HexPtr($pCmdEnt))

	If Not $bReuse Then
		Local $sMid = Wine_ReadBytesHex($pHook, 5)
		If Wine_CompactHex($sMid) <> Wine_CompactHex($sBefore) Then
			Return Wine_InjectAbort("Engine site bytes changed before JMP (have " & $sMid & ", want " & $sBefore & ")", $pAlloc)
		EndIf
		If Not Wine_EnginePatternNear($pHook) Then
			Return Wine_InjectAbort("Engine needle no longer near hook site; not planting JMP", $pAlloc)
		EndIf

		Memory_WriteDetour("MainStart", "MainProc")
		Local $sAfter = Wine_ReadBytesHex($pHook, 5)
		Out("Wine Engine site after JMP: " & Wine_HexPtr($pHook) & " bytes=" & $sAfter)
		If StringLeft(Wine_CompactHex($sAfter), 2) <> "E9" Then
			If Wine_CompactHex($sBefore) <> "" Then Memory_WriteBinary(Wine_CompactHex($sBefore), $pHook)
			Return Wine_InjectAbort("JMP did not stick (after=" & $sAfter & "); restored original site bytes", $pAlloc)
		EndIf
	Else
		If StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pHook, 5)), 2) <> "E9" Then
			Return Wine_InjectAbort("reused Engine site lost its E9")
		EndIf
		Out("Wine: left existing Engine JMP in place; stubs rewritten on " & Wine_HexPtr($pAlloc))
	EndIf

	$g_p_SavedIndex = Memory_GetValue("SavedIndex")
	$g_p_MapIsLoaded = Memory_GetValue("MapIsLoaded")
	$g_i_QueueCounter = 0
	$g_i_QueueSize = 0x100 - 1
	$g_p_QueueBase = $pQueue
	Wine_WireCommandStructs()
	$g_b_WineMinimalHook = True
	If $bReuse Then
		Out("Wine: reused Engine JMP. QueueBase=" & Wine_HexPtr($g_p_QueueBase) & _
				" MainStart=" & Wine_HexPtr($pHook) & " MainProc=" & Wine_HexPtr($pMain) & _
				" CommandPacketSend=" & Wine_HexPtr($pCmdPkt))
	Else
		Out("Wine: single Engine JMP planted. QueueBase=" & Wine_HexPtr($g_p_QueueBase) & _
				" MainStart=" & Wine_HexPtr($pHook) & " MainProc=" & Wine_HexPtr($pMain) & _
				" CommandEnterMission=" & Wine_HexPtr($pCmdEnt))
	EndIf
	Out("Wine: skipped Render/LoadFinished/Trader/TradePartner detours (not Assembler_ModifyMemory).")
	Return True
EndFunc

Func Wine_ScanPatternsChunked()
	Local $pStart = $g_ai2_Sections[$GC_I_SECTION_TEXT][0]
	Local $pEnd = $g_ai2_Sections[$GC_I_SECTION_TEXT][1]
	Local $iTextSize = $pEnd - $pStart
	Local $iCount = $g_amx2_Patterns[0][0]
	If $iTextSize <= 0 Or $iCount < 1 Or $g_h_GWProcess = 0 Then Return 0

	Local $aResults[$iCount + 1]
	$aResults[0] = $iCount
	Local $aBytes[$iCount + 1][64]
	Local $abWild[$iCount + 1][64]
	Local $aLen[$iCount + 1]
	Local $aOff[$iCount + 1]
	Local $aNeedle[$iCount + 1]
	Local $aNeedleAt[$iCount + 1]
	Local $iUsable = 0
	Local $iMaxPat = 1
	Local $i = 1
	For $i = 1 To $iCount
		$aResults[$i] = 0
		$aOff[$i] = Number($g_amx2_Patterns[$i][2])
		$aNeedle[$i] = ""
		$aNeedleAt[$i] = 0
		Local $sPat = StringStripWS(String($g_amx2_Patterns[$i][1]), 8)
		$sPat = StringReplace($sPat, "??", "00")
		$sPat = StringReplace($sPat, " ", "")
		If $sPat = "" Or StringRegExp($sPat, "[^0-9A-Fa-f]") Then
			$aLen[$i] = 0
			ContinueLoop
		EndIf
		If Mod(StringLen($sPat), 2) = 1 Then $sPat = "0" & $sPat
		Local $iLen = Int(StringLen($sPat) / 2)
		If $iLen > 63 Then $iLen = 63
		$aLen[$i] = $iLen
		If $iLen > $iMaxPat Then $iMaxPat = $iLen
		Local $b = 0
		For $b = 0 To $iLen - 1
			Local $iVal = Dec(StringMid($sPat, $b * 2 + 1, 2))
			$aBytes[$i][$b] = $iVal
			$abWild[$i][$b] = ($iVal = 0)
		Next
		Local $iBest = 0, $iBestAt = 0, $iRun = 0, $iRunAt = 0
		For $b = 0 To $iLen - 1
			If Not $abWild[$i][$b] Then
				If $iRun = 0 Then $iRunAt = $b
				$iRun += 1
				If $iRun > $iBest Then
					$iBest = $iRun
					$iBestAt = $iRunAt
				EndIf
			Else
				$iRun = 0
			EndIf
		Next
		If $iBest > 0 Then
			Local $sNeedle = ""
			Local $n = 0
			For $n = 0 To $iBest - 1
				$sNeedle &= Chr($aBytes[$i][$iBestAt + $n])
			Next
			$aNeedle[$i] = $sNeedle
			$aNeedleAt[$i] = $iBestAt
		EndIf
		$iUsable += 1
	Next

	Out("Wine 4KB scan: .text " & $iTextSize & " bytes, " & $iUsable & " patterns (read-only)")
	Local $hScan = TimerInit()
	Local $iChunk = 4096
	Local $iOverlap = $iMaxPat
	If $iOverlap < 32 Then $iOverlap = 32
	Local $p = $pStart
	Local $iFound = 0
	Local $iN = 0
	While $p < $pEnd And $iFound < $iUsable
		Local $iRead = $iChunk
		If $p + $iRead > $pEnd Then $iRead = $pEnd - $p
		If $iRead <= 0 Then ExitLoop
		Local $dBuf = DllStructCreate("byte[" & $iRead & "]")
		If @error Then ExitLoop
		Local $av = DllCall($g_h_Kernel32, "int", "ReadProcessMemory", _
				"int", $g_h_GWProcess, _
				"int", $p, _
				"ptr", DllStructGetPtr($dBuf), _
				"int", $iRead, _
				"int", "")
		If @error Or Not IsArray($av) Or $av[0] = 0 Then
			Out("Wine 4KB scan: ReadProcessMemory failed at " & Wine_HexPtr($p) & "; stopping.")
			ExitLoop
		EndIf
		Local $sHay = BinaryToString(DllStructGetData($dBuf, 1), 1)
		For $i = 1 To $iCount
			If $aResults[$i] <> 0 Or $aLen[$i] < 1 Or $aNeedle[$i] = "" Then ContinueLoop
			Local $iHit = Wine_MatchInHay($sHay, $i, $aBytes, $abWild, $aLen[$i], $aNeedle[$i], $aNeedleAt[$i])
			If $iHit >= 0 Then
				$aResults[$i] = $p + $iHit + $aOff[$i]
				$iFound += 1
			EndIf
		Next
		$iN += 1
		If Mod($iN, 8) = 0 Then Sleep(1)
		If Mod($p - $pStart, 262144) < $iRead Then
			Out("Wine 4KB scan: " & ($p - $pStart + $iRead) & "/" & $iTextSize & " (" & $iFound & " hits)")
		EndIf
		If $p + $iRead >= $pEnd Then ExitLoop
		$p += $iRead - $iOverlap
		If $iOverlap >= $iRead Then ExitLoop
	WEnd
	Out("Wine 4KB scan: found " & $iFound & "/" & $iCount & " in " & Round(TimerDiff($hScan)) & " ms")
	Return $aResults
EndFunc

Func Wine_MatchInHay($sHay, $iPat, ByRef $aBytes, ByRef $abWild, $iPatLen, $sNeedle, $iNeedleAt)
	If $iPatLen < 1 Or $sNeedle = "" Then Return -1
	Local $iHay = StringLen($sHay)
	If $iHay < $iPatLen Then Return -1
	Local $iPos = 1
	While True
		$iPos = StringInStr($sHay, $sNeedle, 1, 1, $iPos)
		If $iPos = 0 Then Return -1
		Local $iHit = $iPos - 1 - $iNeedleAt
		If $iHit >= 0 And $iHit + $iPatLen <= $iHay Then
			Local $bOk = True
			Local $k = 0
			For $k = 0 To $iPatLen - 1
				If $abWild[$iPat][$k] Then ContinueLoop
				If Asc(StringMid($sHay, $iHit + $k + 1, 1)) <> $aBytes[$iPat][$k] Then
					$bOk = False
					ExitLoop
				EndIf
			Next
			If $bOk Then Return $iHit
		EndIf
		$iPos += 1
	WEnd
	Return -1
EndFunc
