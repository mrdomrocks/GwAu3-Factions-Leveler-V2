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
; A leftover Engine E9 that has never ticked is restored (8B EC D9 45 08) and
; replaced with one fresh JMP on a new VirtualAlloc page (7ccd322 walk path).
; Leftover SkillTimer/GWA2/Scene E9s are restored to original bytes on Start
; (tail 8B D8 8B 47 08 / 8B CE / 8B 01) so a retest does not need a manual
; restore before the pattern scan. SkillTimer ticks live on the MainProc page
; while WPM to QueueBase (64KB earlier) is invisible to that thread
; (195ad24: ticks rose, drainSeen stayed 0, slot 0 written). PendingMove is
; a same-page CommandMove ptr + xyz; MainProc consumes it with `call ebx`
; (195ad24 already had that). Do not put E8/E9-to-Move in MainProc — Wine
; followed 745157e's E8 and f1bb311's `E9 B1000000` trampoline and never
; translated `inc EngineTicks`.

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
If Not IsDeclared("g_h_WineMoveLog") Then Global $g_h_WineMoveLog = 0
If Not IsDeclared("g_h_WineRefreshAt") Then Global $g_h_WineRefreshAt = 0
If Not IsDeclared("g_i_WineTicksLast") Then Global $g_i_WineTicksLast = -1
If Not IsDeclared("g_h_WineTicksAt") Then Global $g_h_WineTicksAt = 0
If Not IsDeclared("g_p_WineEngineHook") Then Global $g_p_WineEngineHook = 0
If Not IsDeclared("g_b_WineEngineProven") Then Global $g_b_WineEngineProven = False
If Not IsDeclared("g_i_WineRelocateN") Then Global $g_i_WineRelocateN = 0
If Not IsDeclared("g_h_WineRelocateAt") Then Global $g_h_WineRelocateAt = 0
If Not IsDeclared("g_s_WineDrainKind") Then Global $g_s_WineDrainKind = "none"
If Not IsDeclared("g_s_WineAsmExit") Then Global $g_s_WineAsmExit = "engine"
If Not IsDeclared("g_p_WineDeadHook") Then Global $g_p_WineDeadHook = 0
If Not IsDeclared("g_s_WineHookSaved") Then Global $g_s_WineHookSaved = ""
If Not IsDeclared("g_p_WineHookSaved") Then Global $g_p_WineHookSaved = 0
If Not IsDeclared("g_p_WineWndProcOld") Then Global $g_p_WineWndProcOld = 0
If Not IsDeclared("g_b_WineReuseBlocked") Then Global $g_b_WineReuseBlocked = False
If Not IsDeclared("g_p_WineCleanEpi") Then Global $g_p_WineCleanEpi = 0
If Not IsDeclared("g_h_WineVerifyAt") Then Global $g_h_WineVerifyAt = 0
If Not IsDeclared("g_h_WineGwHwnd") Then Global $g_h_WineGwHwnd = 0
If Not IsDeclared("g_s_WineExitReplay") Then Global $g_s_WineExitReplay = ""
If Not IsDeclared("g_i_WineDrainSeenLast") Then Global $g_i_WineDrainSeenLast = 0
If Not IsDeclared("g_h_WineEnterMissAt") Then Global $g_h_WineEnterMissAt = 0

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
	Local $h = Wine_DiscoverGwWindow(0)
	If $h = 0 Then Return 0
	Return Wine_HwndPid($h)
EndFunc

Func Wine_HwndPid($a_h)
	If $a_h = 0 Then Return 0
	Local $a = DllCall("user32.dll", "dword", "GetWindowThreadProcessId", "hwnd", $a_h, "dword*", 0)
	If IsArray($a) And Number($a[2]) > 0 Then Return Number($a[2])
	Local $i = Number(WinGetProcess($a_h))
	If $i > 0 Then Return $i
	Return 0
EndFunc

Func Wine_PidIsGw($a_i_Pid)
	If $a_i_Pid <= 0 Then Return False
	If Number($g_i_GWProcessId) > 0 And Number($a_i_Pid) = Number($g_i_GWProcessId) Then Return True
	Local $aList = ProcessList("gw.exe")
	If Not IsArray($aList) Then Return False
	Local $i = 1
	For $i = 1 To Number($aList[0][0])
		If Number($aList[$i][1]) = Number($a_i_Pid) Then Return True
	Next
	Return False
EndFunc

Func Wine_HwndIsGame($a_h)
	If $a_h = 0 Then Return False
	Local $sClass = Wine_WindowClass($a_h)
	Local $sTitle = WinGetTitle($a_h)
	If $sClass = $GC_S_CLASS_DX_WINDOW Then Return True
	If StringInStr($sTitle, "Guild Wars") Or StringInStr($sTitle, "Reforged") Then Return True
	Return False
EndFunc

Func Wine_HwndIsStub($a_h)
	If $a_h = 0 Then Return True
	Local $sClass = Wine_WindowClass($a_h)
	Local $sTitle = WinGetTitle($a_h)
	If StringInStr($sClass, "IoLookup") Or StringInStr($sTitle, "IoLookup") Then Return True
	If StringInStr($sClass, "IME") Or StringInStr($sTitle, "IME") Then Return True
	If StringInStr($sClass, "MSCTF") Then Return True
	If Wine_HwndIsGame($a_h) Then Return False
	Local $iW = 0, $iH = 0
	Wine_HwndClientWH($a_h, $iW, $iH)
	If $iW <= 16 And $iH <= 16 Then Return True
	If $sTitle = "" And ($iW < 400 Or $iH < 300) Then Return True
	Return False
EndFunc

Func Wine_HwndClientWH($a_h, ByRef $a_i_W, ByRef $a_i_H)
	$a_i_W = 0
	$a_i_H = 0
	If $a_h = 0 Then Return
	Local $d = DllStructCreate("long left;long top;long right;long bottom")
	Local $a = DllCall("user32.dll", "int", "GetClientRect", "hwnd", $a_h, "ptr", DllStructGetPtr($d))
	If IsArray($a) And $a[0] Then
		$a_i_W = Number(DllStructGetData($d, "right")) - Number(DllStructGetData($d, "left"))
		$a_i_H = Number(DllStructGetData($d, "bottom")) - Number(DllStructGetData($d, "top"))
	EndIf
	If $a_i_W < 1 Or $a_i_H < 1 Then
		Local $aPos = WinGetPos($a_h)
		If IsArray($aPos) Then
			If $a_i_W < 1 Then $a_i_W = Number($aPos[2])
			If $a_i_H < 1 Then $a_i_H = Number($aPos[3])
		EndIf
	EndIf
EndFunc

Func Wine_HwndWndProc($a_h)
	If $a_h = 0 Then Return 0
	Local $a = DllCall("user32.dll", "int", "GetWindowLongA", "hwnd", $a_h, "int", -4)
	If IsArray($a) And Number($a[0]) <> 0 Then Return Number($a[0])
	Local $aW = DllCall("user32.dll", "int", "GetWindowLongW", "hwnd", $a_h, "int", -4)
	If IsArray($aW) And Number($aW[0]) <> 0 Then Return Number($aW[0])
	Local $aCl = DllCall("user32.dll", "int", "GetClassLongA", "hwnd", $a_h, "int", -24)
	If IsArray($aCl) And Number($aCl[0]) <> 0 Then Return Number($aCl[0])
	Return 0
EndFunc

; Prefer ArenaNet_Dx_Window_Class / "Guild Wars" / "Reforged", then the largest
; non-stub client. Skip IoLookupWnd, Default IME, 1x1, and untitled stubs.
Func Wine_HwndScore($a_h)
	If $a_h = 0 Or Wine_HwndIsStub($a_h) Then Return -1
	Local $sClass = Wine_WindowClass($a_h)
	Local $sTitle = WinGetTitle($a_h)
	Local $iW = 0, $iH = 0
	Wine_HwndClientWH($a_h, $iW, $iH)
	Local $iScore = 0
	If $sClass = $GC_S_CLASS_DX_WINDOW Then $iScore += 10000
	If StringInStr($sTitle, "Guild Wars") Then $iScore += 8000
	If StringInStr($sTitle, "Reforged") Then $iScore += 4000
	If $sClass = "gw.exe" Then $iScore += 2000
	If Wine_HwndWndProc($a_h) <> 0 Then $iScore += 3000
	If $iW >= 640 And $iH >= 400 Then
		$iScore += 500
		$iScore += Int(($iW * $iH) / 1000)
	ElseIf $iW >= 400 And $iH >= 300 Then
		$iScore += Int(($iW * $iH) / 2000)
	EndIf
	Return $iScore
EndFunc

Func Wine_HwndVisibleSize($a_h)
	Local $iW = 0, $iH = 0
	Wine_HwndClientWH($a_h, $iW, $iH)
	Return $iW * $iH
EndFunc

Func Wine_HwndCacheOk($a_i_Pid)
	If $g_h_WineGwHwnd = 0 Then Return False
	If Wine_HwndIsStub($g_h_WineGwHwnd) Then
		$g_h_WineGwHwnd = 0
		Return False
	EndIf
	Local $aOk = DllCall("user32.dll", "int", "IsWindow", "hwnd", $g_h_WineGwHwnd)
	If Not IsArray($aOk) Or Not $aOk[0] Then
		$g_h_WineGwHwnd = 0
		Return False
	EndIf
	If $a_i_Pid > 0 And Wine_HwndPid($g_h_WineGwHwnd) <> $a_i_Pid Then Return False
	If Wine_HwndScore($g_h_WineGwHwnd) < 0 Then
		$g_h_WineGwHwnd = 0
		Return False
	EndIf
	Return True
EndFunc

; Wine WinList often has empty titles even when X11 shows "Guild Wars Reforged".
; Do not skip large untitled windows; skip IoLookupWnd / IME / 1x1 stubs.
Func Wine_DiscoverGwWindow($a_i_Pid = 0)
	If Wine_HwndCacheOk($a_i_Pid) Then Return $g_h_WineGwHwnd

	Local $hBest = 0
	Local $iBest = -1
	Local $sSeen = ""
	If $g_h_GWWindow <> 0 Then Wine_ConsiderHwnd($g_h_GWWindow, $a_i_Pid, $hBest, $iBest, $sSeen)

	Local $hDx = 0
	Local $nDx = 0
	While $nDx < 8
		Local $aEx = DllCall("user32.dll", "hwnd", "FindWindowExA", "hwnd", 0, "hwnd", $hDx, "str", $GC_S_CLASS_DX_WINDOW, "ptr", 0)
		If Not IsArray($aEx) Or $aEx[0] = 0 Then ExitLoop
		If $aEx[0] = $hDx Then ExitLoop
		$hDx = $aEx[0]
		Wine_ConsiderHwnd($hDx, $a_i_Pid, $hBest, $iBest, $sSeen)
		$nDx += 1
	WEnd
	Local $aFw = DllCall("user32.dll", "hwnd", "FindWindowA", "str", $GC_S_CLASS_DX_WINDOW, "ptr", 0)
	If IsArray($aFw) And $aFw[0] <> 0 Then Wine_ConsiderHwnd($aFw[0], $a_i_Pid, $hBest, $iBest, $sSeen)

	Local $aClass = WinList("[CLASS:" & $GC_S_CLASS_DX_WINDOW & "]")
	If IsArray($aClass) Then
		Local $c = 1
		For $c = 1 To Number($aClass[0][0])
			Wine_ConsiderHwnd($aClass[$c][1], $a_i_Pid, $hBest, $iBest, $sSeen)
		Next
	EndIf

	Local $asTitle[4] = ["Guild Wars Reforged", "Guild Wars", "Guild Wars - ", "Guild Wars Reforged "]
	Local $t = 0
	For $t = 0 To 3
		Local $aT = DllCall("user32.dll", "hwnd", "FindWindowA", "ptr", 0, "str", $asTitle[$t])
		If IsArray($aT) And $aT[0] <> 0 Then Wine_ConsiderHwnd($aT[0], $a_i_Pid, $hBest, $iBest, $sSeen)
		Local $aTw = DllCall("user32.dll", "hwnd", "FindWindowW", "ptr", 0, "wstr", $asTitle[$t])
		If IsArray($aTw) And $aTw[0] <> 0 Then Wine_ConsiderHwnd($aTw[0], $a_i_Pid, $hBest, $iBest, $sSeen)
	Next

	Local $aWins = WinList()
	If IsArray($aWins) Then
		Local $j = 1
		For $j = 1 To $aWins[0][0]
			Wine_ConsiderHwnd($aWins[$j][1], $a_i_Pid, $hBest, $iBest, $sSeen)
		Next
	EndIf

	Local $aDesk = DllCall("user32.dll", "hwnd", "GetDesktopWindow")
	If IsArray($aDesk) And $aDesk[0] <> 0 Then
		Local $aChild = DllCall("user32.dll", "hwnd", "GetWindow", "hwnd", $aDesk[0], "uint", 5)
		Local $hWalk = 0
		If IsArray($aChild) Then $hWalk = $aChild[0]
		Local $n = 0
		While $hWalk <> 0 And $n < 400
			Wine_ConsiderHwnd($hWalk, $a_i_Pid, $hBest, $iBest, $sSeen)
			Local $aNext = DllCall("user32.dll", "hwnd", "GetWindow", "hwnd", $hWalk, "uint", 2)
			If Not IsArray($aNext) Then ExitLoop
			$hWalk = $aNext[0]
			$n += 1
		WEnd
	EndIf

	If $hBest <> 0 Then $hBest = Wine_PreferDxChild($hBest, $a_i_Pid)
	If $hBest <> 0 And Wine_HwndIsStub($hBest) Then $hBest = 0
	$g_h_WineGwHwnd = $hBest
	If $g_h_WineGwHwnd <> 0 Then
		Local $iW = 0, $iH = 0
		Wine_HwndClientWH($g_h_WineGwHwnd, $iW, $iH)
		Out("Wine hwnd: using " & $g_h_WineGwHwnd & " class=" & Wine_WindowClass($g_h_WineGwHwnd) & _
				" title=[" & WinGetTitle($g_h_WineGwHwnd) & "] pid=" & Wine_HwndPid($g_h_WineGwHwnd) & _
				" client=" & $iW & "x" & $iH & " score=" & Wine_HwndScore($g_h_WineGwHwnd))
	Else
		Out("Wine hwnd: none for pid=" & $a_i_Pid & " (WinList/FindWindow/desktop walk empty)")
	EndIf
	Return $g_h_WineGwHwnd
EndFunc

Func Wine_ConsiderHwnd($a_h, $a_i_Pid, ByRef $a_h_Best, ByRef $a_i_Best, ByRef $a_s_Seen)
	If $a_h = 0 Then Return
	Local $sKey = "|" & String($a_h) & "|"
	If StringInStr($a_s_Seen, $sKey) Then Return
	$a_s_Seen &= $sKey
	Local $iPid = Wine_HwndPid($a_h)
	If $a_i_Pid > 0 Then
		If $iPid <> $a_i_Pid Then Return
	Else
		If Not Wine_PidIsGw($iPid) And Not Wine_HwndIsGame($a_h) Then Return
	EndIf
	Local $hUse = Wine_PreferDxChild($a_h, $a_i_Pid)
	If $hUse <> 0 And $hUse <> $a_h Then
		Local $sChild = "|" & String($hUse) & "|"
		If Not StringInStr($a_s_Seen, $sChild) Then
			$a_s_Seen &= $sChild
			Wine_LogHwndCandidate($hUse, $iPid)
			Wine_KeepBestHwnd($hUse, $a_h_Best, $a_i_Best)
		EndIf
	EndIf
	Wine_LogHwndCandidate($a_h, $iPid)
	Wine_KeepBestHwnd($a_h, $a_h_Best, $a_i_Best)
EndFunc

Func Wine_LogHwndCandidate($a_h, $a_i_Pid)
	Local $sClass = Wine_WindowClass($a_h)
	Local $sTitle = WinGetTitle($a_h)
	Local $iW = 0, $iH = 0
	Wine_HwndClientWH($a_h, $iW, $iH)
	If Wine_HwndIsStub($a_h) Then
		Out("Wine hwnd skip " & $a_h & " pid=" & $a_i_Pid & " class=" & $sClass & " title=[" & $sTitle & "] client=" & $iW & "x" & $iH)
		Return
	EndIf
	Out("Wine hwnd cand " & $a_h & " pid=" & $a_i_Pid & " class=" & $sClass & " title=[" & $sTitle & "] client=" & $iW & "x" & $iH & " score=" & Wine_HwndScore($a_h) & " wndproc=" & Wine_HexPtr(Wine_HwndWndProc($a_h)))
EndFunc

Func Wine_KeepBestHwnd($a_h, ByRef $a_h_Best, ByRef $a_i_Best)
	Local $iScore = Wine_HwndScore($a_h)
	If $iScore < 0 Then Return
	If $iScore > $a_i_Best Then
		$a_i_Best = $iScore
		$a_h_Best = $a_h
	EndIf
EndFunc

Func Wine_PreferDxChild($a_h, $a_i_Pid)
	If $a_h = 0 Then Return 0
	If Wine_WindowClass($a_h) = $GC_S_CLASS_DX_WINDOW Then Return $a_h
	Local $aChild = DllCall("user32.dll", "hwnd", "FindWindowExA", "hwnd", $a_h, "hwnd", 0, "str", $GC_S_CLASS_DX_WINDOW, "ptr", 0)
	If IsArray($aChild) And $aChild[0] <> 0 Then Return $aChild[0]
	Local $aC = DllCall("user32.dll", "hwnd", "GetWindow", "hwnd", $a_h, "uint", 5)
	Local $hC = 0
	If IsArray($aC) Then $hC = $aC[0]
	Local $n = 0
	While $hC <> 0 And $n < 40
		If Wine_WindowClass($hC) = $GC_S_CLASS_DX_WINDOW Then Return $hC
		If $a_i_Pid <= 0 Or Wine_HwndPid($hC) = $a_i_Pid Then
			If Wine_WindowClass($hC) = $GC_S_CLASS_DX_WINDOW Then Return $hC
		EndIf
		Local $aN = DllCall("user32.dll", "hwnd", "GetWindow", "hwnd", $hC, "uint", 2)
		If Not IsArray($aN) Then ExitLoop
		$hC = $aN[0]
		$n += 1
	WEnd
	Return $a_h
EndFunc

Func Wine_FindGwHwnd($a_i_Pid)
	If $a_i_Pid <= 0 Then $a_i_Pid = Number($g_i_GWProcessId)
	Return Wine_DiscoverGwWindow($a_i_Pid)
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

Func Wine_PtrsEq($a_p_A, $a_p_B)
	Return BitAND(Number($a_p_A), 0xFFFFFFFF) = BitAND(Number($a_p_B), 0xFFFFFFFF)
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
	Local $hDx = Wine_PreferDxChild($a_h_Wnd, Number(WinGetProcess($a_h_Wnd)))
	If Wine_WindowClass($hDx) = $GC_S_CLASS_DX_WINDOW Then Return $hDx
	Local $iPid = Number(WinGetProcess($a_h_Wnd))
	Local $aClass = WinList("[CLASS:" & $GC_S_CLASS_DX_WINDOW & "]")
	If IsArray($aClass) Then
		Local $i = 1
		For $i = 1 To $aClass[0][0]
			If $iPid > 0 And WinGetProcess($aClass[$i][1]) <> $iPid Then ContinueLoop
			Return $aClass[$i][1]
		Next
	EndIf
	If Wine_HwndIsStub($a_h_Wnd) Then Return Wine_DiscoverGwWindow($iPid)
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
; Togo+Vhang party allies mean the instance even when map/current stay 213.
Func Wine_EnterMapEvidence($a_i_StartMap)
	Local $iMap = Map_GetMapID()
	Local $iCur = Number(Map_GetCharacterInfo("CurrentMapID"))
	If $iMap = 246 Or $iCur = 246 Then Return True
	If $iMap = 245 Or $iCur = 245 Then Return True
	If $iMap > 0 And $iMap <> $a_i_StartMap And $iMap <> 213 And $iMap <> 214 Then Return True
	If $iCur > 0 And $iCur <> $a_i_StartMap And $iCur <> 213 And $iCur <> 214 Then Return True
	If Leveler_WineZenPartyAlliesTogether() Then Return True
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

Func Wine_EnterLatchSuccess($a_s_How)
	$g_b_WineEnterSent = True
	$g_h_WineEnterMissAt = 0
	Local $sDetect = ""
	If IsDeclared("g_s_ZenAllyDetect") And $g_s_ZenAllyDetect <> "" Then $sDetect = " " & $g_s_ZenAllyDetect
	Out("Wine enter: " & $a_s_How & " (map " & Map_GetMapID() & " current " & Number(Map_GetCharacterInfo("CurrentMapID")) & $sDetect & ")")
	Return True
EndFunc

; Dismiss covering UI so the outpost Enter Mission pill can show, then open party.
Func Wine_EnterRevealMissionUi($a_h_Wnd, $a_b_ToggleParty = False)
	ControlSend($a_h_Wnd, "", "", "{ESC}")
	Sleep(250)
	If $a_b_ToggleParty Then
		ControlSend($a_h_Wnd, "", "", "p")
		Sleep(400)
	EndIf
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
	; No Enter Mission button mid-instance. Togo+Vhang (or held 246) is already-inside.
	If Leveler_WineZenPartyAlliesTogether() Then
		Return Wine_EnterLatchSuccess("already inside; Togo+Vhang allies, not clicking")
	EndIf
	If Wine_EnterMapEvidence($iNow) And Wine_WaitEnterEvidence($iNow, 2000) Then
		Return Wine_EnterLatchSuccess("already inside the mission")
	EndIf
	If $g_b_WineEnterSent Then
		If Wine_EnterMapEvidence($iNow) Then
			Out("Wine enter: mission load already started this attach; not clicking again.")
			Return True
		EndIf
		Out("Wine enter: previous latch was stale (still map " & $iNow & "); retrying clicks.")
		$g_b_WineEnterSent = False
	EndIf
	If $g_h_WineEnterMissAt <> 0 And TimerDiff($g_h_WineEnterMissAt) < 15000 Then
		If Wine_EnterMapEvidence($iNow) Then Return Wine_EnterLatchSuccess("already inside after missed clicks")
		Out("Wine enter: Enter Mission was not on screen; not repeating the click sweep (" & _
				Int(TimerDiff($g_h_WineEnterMissAt) / 1000) & "s ago).")
		Return False
	EndIf
	Leveler_WineLogZenAllyScan("before Enter clicks")

	Local $hWnd = $g_h_GWWindow
	If $hWnd = 0 Then $hWnd = Wine_FindGwHwnd($g_i_GWProcessId)
	If $hWnd = 0 Then
		Out("Wine enter: no Gw window for Enter Mission click")
		Return False
	EndIf

	Local $iStart = Map_GetMapID()
	Local $hCli = Wine_GwClientHwnd($hWnd)
	If $hCli <> 0 Then $hWnd = $hCli
	Local $bRetry = ($g_h_WineEnterMissAt <> 0)
	Wine_LevelerOverlayHold()
	WinSetOnTop($hWnd, "", 1)
	WinActivate($hWnd)
	WinWaitActive($hWnd, "", 2)
	DllCall("user32.dll", "bool", "SetForegroundWindow", "hwnd", $hWnd)
	DllCall("user32.dll", "bool", "BringWindowToTop", "hwnd", $hWnd)
	Sleep(400)
	; Outpost: dismiss covering UI so Enter Mission can show. Retry also toggles party.
	Wine_EnterRevealMissionUi($hWnd, $bRetry)
	If Leveler_WineZenPartyAlliesTogether() Then
		WinSetOnTop($hWnd, "", 0)
		Wine_LevelerOverlayRestore()
		Return Wine_EnterLatchSuccess("already inside after UI reveal; not clicking")
	EndIf

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
		WinSetOnTop($hWnd, "", 0)
		Wine_LevelerOverlayRestore()
		Return Wine_EnterLatchSuccess("{ENTER} loaded")
	EndIf
	; {ENTER} often starts the load while map is still 213. More PostMessage /
	; MouseClick during DX reset crashes Gw. Stop input and wait for held 246.
	If Wine_WaitLoadHint($iStart, 1200) Then
		Out("Wine enter: load started after {ENTER}; waiting for held 246 / Togo+Vhang (no more clicks)")
		If Wine_WaitEnterEvidence($iStart, 45000) Then
			WinSetOnTop($hWnd, "", 0)
			Wine_LevelerOverlayRestore()
			Return Wine_EnterLatchSuccess("held after {ENTER}")
		EndIf
		WinSetOnTop($hWnd, "", 0)
		Wine_LevelerOverlayRestore()
		Out("Wine enter: load started but 246/allies did not hold. Not latching.")
		Return False
	EndIf

	Local $aiY[6] = [22, 32, 42, 54, 68, 80]
	Local $aiXOff[3] = [0, -40, 40]
	Local $iYMax = 5
	Local $iXMax = 2
	If $bRetry Then
		; Button was missing last sweep. Fewer clicks after party toggle; do not storm 18.
		$iYMax = 2
		$iXMax = 0
		$aiY[0] = 22
		$aiY[1] = 42
		$aiY[2] = 68
		Out("Wine enter: retry after reveal; short click strip (not a full sweep)")
	EndIf
	Local $iY = 0
	Local $iX = 0
	For $iY = 0 To $iYMax
		For $iX = 0 To $iXMax
			If Wine_EnterMapEvidence($iStart) Or Wine_EnterLoadStarted($iStart) Or Wine_MapIsLoading() Then ExitLoop 2
			Wine_ClientClick($hWnd, $iCx + $aiXOff[$iX], $aiY[$iY])
			If Wine_WaitEnterEvidence($iStart, 1600) Then
				WinSetOnTop($hWnd, "", 0)
				Wine_LevelerOverlayRestore()
				Return Wine_EnterLatchSuccess("click loaded")
			EndIf
			If Wine_EnterMapEvidence($iStart) Or Wine_EnterLoadStarted($iStart) Or Wine_WaitLoadHint($iStart, 400) Then ExitLoop 2
		Next
	Next
	If Wine_EnterLoadStarted($iStart) Or Wine_MapIsLoading() Or Wine_EnterMapEvidence($iStart) Then
		Out("Wine enter: load started; waiting for held 246 / Togo+Vhang (no more clicks)")
		If Wine_WaitEnterEvidence($iStart, 45000) Then
			WinSetOnTop($hWnd, "", 0)
			Wine_LevelerOverlayRestore()
			Return Wine_EnterLatchSuccess("held after clicks")
		EndIf
		WinSetOnTop($hWnd, "", 0)
		Wine_LevelerOverlayRestore()
		Out("Wine enter: load started but 246/allies did not hold. Not latching.")
		Return False
	EndIf
	ControlSend($hWnd, "", "", "{ENTER}")
	If Wine_WaitEnterEvidence($iStart, 2500) Then
		WinSetOnTop($hWnd, "", 0)
		Wine_LevelerOverlayRestore()
		Return Wine_EnterLatchSuccess("{ENTER} loaded")
	EndIf
	WinSetOnTop($hWnd, "", 0)
	Wine_LevelerOverlayRestore()
	If Wine_EnterMapEvidence($iStart) Or Leveler_WineZenPartyAlliesTogether() Then
		Return Wine_EnterLatchSuccess("already inside after sweep (no button)")
	EndIf
	$g_h_WineEnterMissAt = TimerInit()
	Out("Wine enter: no Enter Mission button and no durable map change (still " & Map_GetMapID() & _
			" current " & Number(Map_GetCharacterInfo("CurrentMapID")) & "). Not latching. Will not re-sweep for 15s.")
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
; A leftover E9 that has never ticked is not a drain.
Func Wine_QueueWalkReady()
	If Not Wine_CommandsReady() Then Return False
	If Wine_LabelUserPtr("CommandMove") = 0 Then Return False
	If $g_b_WineEngineProven And Wine_EngineHookLive() Then Return True
	If Wine_EngineHookLive() And Not $g_b_WineReuseBlocked Then Return True
	If $g_p_WineExistingE9 <> 0 And Not $g_b_WineReuseBlocked And $g_b_WineEngineProven Then Return True
	If $g_s_WineDrainKind = "wndproc" And $g_p_WineWndProcOld <> 0 Then Return True
	If Wine_DrainIsReplay() And Wine_EngineHookLive() Then Return True
	If Wine_EngineHookLive() Then Return True
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
; A leftover E9 from an older AutoIt session is not "live" until ticks rise.
Func Wine_QueueAlreadyLive()
	If Not Wine_CommandsReady() Then Return False
	If $g_b_WineReuseBlocked Then Return False
	If $g_b_WineEngineProven And Wine_EngineHookLive() Then Return True
	If Wine_EngineHookLive() And $g_b_WineMinimalHook And $g_s_WineDrainKind <> "none" Then Return True
	If $g_p_WineExistingE9 <> 0 And $g_b_WineEngineProven Then Return True
	If $g_b_WineMinimalHook And ($g_s_WineDrainKind = "wndproc" Or Wine_DrainIsReplay()) Then Return True
	If $g_p_WineAsmAlloc <> 0 And $g_s_WineDrainKind <> "none" And Not $g_b_WineReuseBlocked Then Return True
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

; Engine reads dword[QueueCounter] as the slot index. After a stub rewrite
; AutoIt used to force $g_i_QueueCounter=0 while memory stayed mid-queue, so
; Map_Move wrote slot 0 and Engine drained an empty slot — a silent no-op.
Func Wine_SyncQueueCounter()
	Local $pQC = Wine_LabelUserPtr("QueueCounter")
	If $pQC = 0 Then Return
	Local $iMem = Number(Memory_Read($pQC))
	If $iMem < 0 Or $iMem > Number($g_i_QueueSize) Then $iMem = 0
	If Number($g_i_QueueCounter) <> $iMem Then
		If $g_h_WineMoveLog = 0 Or TimerDiff($g_h_WineMoveLog) >= 5000 Then
			Out("[Move] QueueCounter AutoIt=" & $g_i_QueueCounter & " mem=" & $iMem & "; writing the slot Engine reads")
		EndIf
		$g_i_QueueCounter = $iMem
	EndIf
EndFunc

Func Wine_ResetQueueHead()
	Local $pQC = Wine_LabelUserPtr("QueueCounter")
	If $pQC <> 0 Then Memory_Write($pQC, 0)
	$g_i_QueueCounter = 0
EndFunc

Func Wine_EngineTickCount()
	Local $p = Wine_LabelUserPtr("EngineTicks")
	If $p = 0 Then Return -1
	Local $i = Number(Memory_Read($p))
	If $i > 0 Then $g_b_WineEngineProven = True
	Return $i
EndFunc

Func Wine_ReadDrainSeen()
	Local $pSeen = Wine_LabelUserPtr("DrainSeen")
	If $pSeen = 0 Then Return 0
	Return Number(Memory_Read($pSeen))
EndFunc

Func Wine_ReadPendingMove()
	Local $pPend = Wine_LabelUserPtr("PendingMove")
	If $pPend = 0 Then Return 0
	Return Number(Memory_Read($pPend))
EndFunc

Func Wine_ReadMemQC()
	Local $pQC = Wine_LabelUserPtr("QueueCounter")
	If $pQC = 0 Then Return 0
	Return Number(Memory_Read($pQC))
EndFunc

; PendingMove on the EngineTicks page is the live Move path (pos changes even
; when enqueue still prints drainSeen=0 — that read is pre-consume).
Func Wine_MovePathName($a_i_Pend, $a_i_Seen, $a_i_SeenBefore = -1)
	If $a_i_Pend <> 0 Then Return "PendingMove-armed"
	If $a_i_SeenBefore >= 0 Then
		If $a_i_Seen > $a_i_SeenBefore Then Return "PendingMove"
		Return "PendingMove (flag cleared; drainSeen still " & $a_i_Seen & ")"
	EndIf
	If $a_i_Seen > 0 Then Return "PendingMove"
	Return "RegularFlow-or-idle"
EndFunc

Func Wine_DrainStateLine($a_s_When = "", $a_i_SeenBefore = -1)
	If Not Wine_IsWine() Then Return ""
	Local $iSeen = Wine_ReadDrainSeen()
	Local $iPend = Wine_ReadPendingMove()
	Local $iMem = Wine_ReadMemQC()
	Local $sPath = Wine_MovePathName($iPend, $iSeen, $a_i_SeenBefore)
	Local $sWhen = $a_s_When
	If $sWhen <> "" Then $sWhen = $sWhen & " "
	Return " " & $sWhen & "drainSeen=" & $iSeen & " pending=" & Wine_HexPtr($iPend) & _
			" memQC=" & $iMem & " path=" & $sPath
EndFunc

Func Wine_ResolveEngineHookSite($a_b_Scan = True)
	If $g_p_WineEngineHook <> 0 Then
		Local $sCached = Wine_CompactHex(Wine_ReadBytesHex($g_p_WineEngineHook, 5))
		If StringLeft($sCached, 2) = "E9" Or $sCached = "8BECD94508" Then Return $g_p_WineEngineHook
		$g_p_WineEngineHook = 0
	EndIf
	Local $p = Wine_LabelUserPtr("MainStart")
	If $p <> 0 Then
		Local $sMain = Wine_CompactHex(Wine_ReadBytesHex($p, 5))
		If StringLeft($sMain, 2) = "E9" Or $sMain = "8BECD94508" Then
			$g_p_WineEngineHook = $p
			Return $p
		EndIf
	EndIf
	If $g_p_WineExistingE9 <> 0 Then
		If StringLeft(Wine_CompactHex(Wine_ReadBytesHex($g_p_WineExistingE9, 5)), 2) = "E9" Then
			$g_p_WineEngineHook = $g_p_WineExistingE9
			Return $g_p_WineExistingE9
		EndIf
	EndIf
	If Not $a_b_Scan Then Return 0
	Local $pEngine = Wine_ScanEngineOnly()
	$g_p_WineExistingE9 = 0
	Local $pHook = Wine_FindEngineHookSite($pEngine)
	If $pHook = 0 Then $pHook = $g_p_WineExistingE9
	If $pHook <> 0 Then $g_p_WineEngineHook = $pHook
	Return $pHook
EndFunc

Func Wine_EngineJmpTarget()
	Local $pMainStart = Wine_LabelUserPtr("MainStart")
	If $pMainStart <> 0 And StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pMainStart, 5)), 2) = "E9" Then
		Local $pFromMain = Scanner_GetCallTargetAddress($pMainStart)
		If Wine_IsUserPtr($pFromMain) Then Return $pFromMain
	EndIf
	Local $pHook = Wine_ResolveEngineHookSite(False)
	If $pHook = 0 Then
		If $pMainStart <> 0 Then $pHook = $pMainStart
		If $pHook = 0 Then $pHook = $g_p_WineExistingE9
	EndIf
	If $pHook = 0 Then Return 0
	Local $s = Wine_CompactHex(Wine_ReadBytesHex($pHook, 5))
	If StringLeft($s, 2) <> "E9" Then Return 0
	Local $pT = Scanner_GetCallTargetAddress($pHook)
	If Wine_IsUserPtr($pT) Then Return $pT
	Return 0
EndFunc

; Overwrite the existing 5-byte Engine site so it points at THIS MainProc.
; Still one JMP — never plants a second hook address if an E9 is already live.
Func Wine_RepointEngineJmp($a_s_Why = "re-point")
	If Wine_DrainSkipEngineJmp() Then
		Out("[Move] Engine re-point skipped; drain kind=" & $g_s_WineDrainKind)
		Return Wine_EngineHookLive() Or $g_s_WineDrainKind = "wndproc"
	EndIf
	Local $pMain = Wine_LabelUserPtr("MainProc")
	If $pMain = 0 Then
		Out("[Move] Engine re-point skipped: MainProc is not a user ptr")
		Return False
	EndIf
	Local $pHook = Wine_ResolveEngineHookSite(True)
	If $pHook = 0 Then
		Out("[Move] Engine re-point skipped: no hook site")
		Return False
	EndIf
	Local $aiOff[3] = [-1, 1, 0]
	Local $i = 0
	For $i = 0 To 2
		Local $pCand = $pHook + $aiOff[$i]
		If Not Wine_IsUserPtr($pCand) Then ContinueLoop
		If Wine_CompactHex(Wine_ReadBytesHex($pCand, 5)) = "8BECD94508" And Wine_EnginePatternNear($pCand) Then
			If Not Wine_PtrsEq($pCand, $pHook) Then
				Out("[Move] Engine hook " & Wine_HexPtr($pHook) & " is stale; real epilogue at " & Wine_HexPtr($pCand))
			EndIf
			$pHook = $pCand
			ExitLoop
		EndIf
	Next
	Local $sBefore = Wine_ReadBytesHex($pHook, 5)
	Local $sC = Wine_CompactHex($sBefore)
	Local $pCur = 0
	Local $bLate = False
	If StringLeft($sC, 2) = "E9" Then $pCur = Scanner_GetCallTargetAddress($pHook)
	; wine-gw Engine scan can land one byte late (E9 at site+1). Move the one JMP back.
	If StringLeft($sC, 2) = "E9" And Wine_EnginePatternNear($pHook - 1) Then
		If Wine_CompactHex(Wine_ReadBytesHex($pHook - 1, 1)) = "8B" Then
			Out("[Move] Engine E9 at " & Wine_HexPtr($pHook) & " is 1 byte late; moving JMP to " & Wine_HexPtr($pHook - 1))
			$pHook = $pHook - 1
			$sBefore = Wine_ReadBytesHex($pHook, 5)
			$sC = Wine_CompactHex($sBefore)
			$pCur = 0
			$bLate = True
		EndIf
	EndIf
	If StringLeft($sC, 2) = "E9" And Wine_PtrsEq($pCur, $pMain) Then
		Wine_ReplaceValue("MainStart", Ptr($pHook))
		Wine_ReplaceValue("MainReturn", Ptr($pHook + 5))
		$g_p_WineExistingE9 = $pHook
		$g_p_WineEngineHook = $pHook
		Out("[Move] Engine JMP already " & Wine_HexPtr($pHook) & " -> MainProc " & Wine_HexPtr($pMain) & " (" & $a_s_Why & ")")
		Return True
	EndIf
	If StringLeft($sC, 2) <> "E9" And $sC <> "8BECD94508" And Not $bLate Then
		Out("[Move] Engine re-point refused: site " & Wine_HexPtr($pHook) & " bytes=" & $sBefore & " (not E9 or epilogue)")
		Return False
	EndIf
	Out("[Move] re-point Engine JMP " & Wine_HexPtr($pHook) & " bytes=" & $sBefore & _
			" target=" & Wine_HexPtr($pCur) & " -> MainProc " & Wine_HexPtr($pMain) & " (" & $a_s_Why & ")")
	Wine_ReplaceValue("MainStart", Ptr($pHook))
	Wine_ReplaceValue("MainReturn", Ptr($pHook + 5))
	Memory_WriteDetour("MainStart", "MainProc")
	Local $sAfter = Wine_ReadBytesHex($pHook, 5)
	Local $pNew = 0
	If StringLeft(Wine_CompactHex($sAfter), 2) = "E9" Then $pNew = Scanner_GetCallTargetAddress($pHook)
	$g_p_WineExistingE9 = $pHook
	$g_p_WineEngineHook = $pHook
	Out("[Move] Engine JMP after re-point: " & $sAfter & " target=" & Wine_HexPtr($pNew))
	Return Wine_PtrsEq($pNew, $pMain)
EndFunc

Func Wine_WatchEngineTicks()
	Local $iTicks = Wine_EngineTickCount()
	If $iTicks > 0 Then Return
	If $g_h_WineTicksAt = 0 Then
		$g_i_WineTicksLast = $iTicks
		$g_h_WineTicksAt = TimerInit()
		Return
	EndIf
	If TimerDiff($g_h_WineTicksAt) < 500 Then Return
	Out("[Move] Engine ticks stuck at " & $iTicks & " jmp=" & Wine_HexPtr(Wine_EngineJmpTarget()) & _
			" MainProc=" & Wine_HexPtr(Wine_LabelUserPtr("MainProc")) & " kind=" & $g_s_WineDrainKind & " — taking GWA2/SkillTimer")
	$g_h_WineTicksAt = TimerInit()
	Wine_VerifyDrainOrFallback()
EndFunc

; CommandMove stub is lea eax,[eax+4]; push eax; call Move (8D 40 04 50 E8).
Func Wine_CommandMoveReady()
	Local $pCmd = Wine_LabelUserPtr("CommandMove")
	If $pCmd = 0 Then Return False
	If Not Wine_CommandsReady() Then Return False
	Local $sStub = Wine_CompactHex(Wine_ReadBytesHex($pCmd, 5))
	If StringLeft($sStub, 6) <> "8D4004" Then Return False
	If Not Wine_MainProcBytesOk() Then Return False
	If StringMid($sStub, 7, 2) = "E8" Or StringMid($sStub, 9, 2) = "E8" Then
		Local $pCall = $pCmd + 4
		If Wine_CompactHex(Wine_ReadBytesHex($pCall, 1)) = "E8" Then
			Local $pMove = Scanner_GetCallTargetAddress($pCall)
			If Not Wine_IsUserPtr($pMove) Then Return False
		EndIf
	EndIf
	Local $pJmp = Wine_EngineJmpTarget()
	Local $pMain = Wine_LabelUserPtr("MainProc")
	If $g_s_WineDrainKind <> "wndproc" And Not Wine_DrainIsReplay() And $pJmp <> 0 And $pMain <> 0 Then
		If Not Wine_PtrsEq($pJmp, $pMain) Then Return False
	EndIf
	If Wine_DrainIsReplay() And Not Wine_EngineHookLive() Then Return False
	Local $pStruct = DllStructGetData($g_d_Move, 1)
	If BitAND(Number($pStruct), 0xFFFFFFFF) <> BitAND(Number($pCmd), 0xFFFFFFFF) Then
		DllStructSetData($g_d_Move, 1, $pCmd)
	EndIf
	Return True
EndFunc

Func Wine_Wpm($a_p_Dest, $a_p_Src, $a_i_Size)
	If $g_h_GWProcess = 0 Or $a_p_Dest = 0 Or $a_p_Src = 0 Or $a_i_Size < 1 Then Return False
	If Not Wine_IsUserPtr($a_p_Dest) Then Return False
	Local $av = DllCall($g_h_Kernel32, "int", "WriteProcessMemory", _
			"int", $g_h_GWProcess, _
			"int", $a_p_Dest, _
			"ptr", $a_p_Src, _
			"int", $a_i_Size, _
			"int", "")
	If @error Or Not IsArray($av) Then Return False
	Return Number($av[0]) <> 0
EndFunc

; Map_Move always returns True and never checks WPM. Wine path reports the
; real enqueue and writes the slot Engine is actually draining.
Func Wine_MapMove($a_f_X, $a_f_Y, $a_f_Randomize = 20)
	If Not Wine_IsWine() Then
		Map_Move($a_f_X, $a_f_Y, $a_f_Randomize)
		Return True
	EndIf
	If Wine_MapIsLoading() Then Return False
	If Not Wine_CommandsReady() Then
		If Not Wine_EnsureCommandQueue() Then
			Wine_LogCommandGap()
			Return False
		EndIf
	EndIf
	Wine_WireCommandStructs()
	Wine_SyncQueueCounter()
	If Not Wine_CommandMoveReady() Then
		If $g_h_WineRefreshAt = 0 Or TimerDiff($g_h_WineRefreshAt) >= 8000 Then
			Wine_RefreshCommandMove("enqueue-not-ready")
		EndIf
		If Not Wine_CommandMoveReady() Then Return False
	EndIf

	If $a_f_Randomize > 0 Then
		$a_f_X += Random(-$a_f_Randomize, $a_f_Randomize)
		$a_f_Y += Random(-$a_f_Randomize, $a_f_Randomize)
	EndIf
	If IsDeclared("g_f_LastMoveX") Then $g_f_LastMoveX = $a_f_X
	If IsDeclared("g_f_LastMoveY") Then $g_f_LastMoveY = $a_f_Y
	DllStructSetData($g_d_Move, 2, $a_f_X)
	DllStructSetData($g_d_Move, 3, $a_f_Y)
	DllStructSetData($g_d_Move, 4, 0)

	Local $iSeenBefore = Wine_ReadDrainSeen()
	Local $bPend = Wine_WritePendingMove($a_f_X, $a_f_Y)
	Local $pCmd = Wine_LabelUserPtr("CommandMove")
	Local $iSlot = Number($g_i_QueueCounter)
	Local $pSlot = $g_p_QueueBase + (256 * $iSlot)
	Local $sBefore = Wine_ReadBytesHex($pSlot, 16)
	; Write X/Y first, then the CommandMove ptr, so Engine never jmps a half-written slot.
	Local $bData = Wine_Wpm($pSlot + 4, $g_p_Move + 4, 12)
	Local $bPtr = Wine_Wpm($pSlot, $g_p_Move, 4)
	Local $bOk = $bData And $bPtr
	If $bOk Then Wine_FlushGw($pSlot, 16)
	Local $sAfter = Wine_ReadBytesHex($pSlot, 16)
	Local $iHead = Number(Memory_Read($pSlot))
	If $bOk Then
		If $g_i_QueueCounter = $g_i_QueueSize Then
			$g_i_QueueCounter = 0
		Else
			$g_i_QueueCounter = $g_i_QueueCounter + 1
		EndIf
	EndIf

	Local $bLog = ($g_h_WineMoveLog = 0)
	If Not $bLog And TimerDiff($g_h_WineMoveLog) >= 5000 Then $bLog = True
	If Not $bOk Then $bLog = True
	If Not $bPend Then $bLog = True
	If $bLog Then
		$g_h_WineMoveLog = TimerInit()
		Out("[Move] enqueue ok=" & Number($bOk) & " slot=" & $iSlot & _
				" cmd=" & Wine_HexPtr($pCmd) & " struct=" & Wine_HexPtr(DllStructGetData($g_d_Move, 1)) & _
				" dest=" & Round($a_f_X) & "," & Round($a_f_Y) & _
				Wine_DrainStateLine("pre-consume") & _
				" head " & $sBefore & " -> " & $sAfter)
		If $bOk And $iHead <> 0 And BitAND($iHead, 0xFFFFFFFF) <> BitAND(Number($pCmd), 0xFFFFFFFF) Then
			Out("[Move] queue head dword " & Wine_HexPtr($iHead) & " is not CommandMove " & Wine_HexPtr($pCmd))
		EndIf
		Sleep(120)
		Local $iSeenAfter = Wine_ReadDrainSeen()
		If $iSeenAfter > $g_i_WineDrainSeenLast Then $g_i_WineDrainSeenLast = $iSeenAfter
		Out("[Move] post-consume ticks=" & Wine_EngineTickCount() & " jmp=" & Wine_HexPtr(Wine_EngineJmpTarget()) & _
				" MainProc=" & Wine_HexPtr(Wine_LabelUserPtr("MainProc")) & _
				Wine_DrainStateLine("post-consume", $iSeenBefore))
	EndIf
	Wine_WatchEngineTicks()
	Return $bOk Or $bPend
EndFunc

; Flag+xyz live on the EngineTicks page (SkillTimer can see this write).
Func Wine_WritePendingMove($a_f_X, $a_f_Y)
	Local $pFlag = Wine_LabelUserPtr("PendingMove")
	Local $pXYZ = Wine_LabelUserPtr("PendingXYZ")
	If $pFlag = 0 Or $pXYZ = 0 Then Return False
	DllStructSetData($g_d_Move, 2, $a_f_X)
	DllStructSetData($g_d_Move, 3, $a_f_Y)
	DllStructSetData($g_d_Move, 4, 0)
	Memory_Write($pFlag, 0)
	If Not Wine_Wpm($pXYZ, $g_p_Move + 4, 12) Then Return False
	Local $pCmd = Wine_LabelUserPtr("CommandMove")
	If $pCmd = 0 Then Return False
	Memory_Write($pFlag, $pCmd)
	Wine_FlushGw($pFlag, 16)
	Return Wine_PtrsEq(Memory_Read($pFlag), $pCmd)
EndFunc

; Re-wire CommandMove, rewrite stubs on our Queue page, and re-point the one
; Engine JMP at the current MainProc. A live-looking 8D4004 stub is not enough
; if Engine never runs that page.
Func Wine_RefreshCommandMove($a_s_Why = "stuck")
	If Not Wine_IsWine() Then Return True
	If Wine_MapIsLoading() Then Return False
	If $g_h_WineRefreshAt <> 0 And TimerDiff($g_h_WineRefreshAt) < 4000 Then
		Out("[Move] refresh throttled (" & $a_s_Why & ")")
		Return True
	EndIf
	$g_h_WineRefreshAt = TimerInit()
	Local $pCmd = Wine_LabelUserPtr("CommandMove")
	Local $iTicks = Wine_EngineTickCount()
	Local $pJmp = Wine_EngineJmpTarget()
	Local $pMain = Wine_LabelUserPtr("MainProc")
	Out("[Move] refresh CommandMove (" & $a_s_Why & ") QueueBase=" & Wine_HexPtr($g_p_QueueBase) & _
			" CommandMove=" & Wine_HexPtr($pCmd) & _
			" stub=" & Wine_CompactHex(Wine_ReadBytesHex($pCmd, 8)) & _
			" jmp=" & Wine_HexPtr($pJmp) & _
			" MainProc=" & Wine_HexPtr($pMain) & _
			" ticks=" & $iTicks & _
			" AutoItQC=" & $g_i_QueueCounter)
	Wine_WireCommandStructs()
	Local $bJmpOk = ($pJmp <> 0 And $pMain <> 0 And Wine_PtrsEq($pJmp, $pMain))
	Local $bTicking = ($iTicks > 0 And ($g_i_WineTicksLast < 0 Or $iTicks > $g_i_WineTicksLast))
	If $g_s_WineDrainKind = "wndproc" Or Wine_DrainIsReplay() Then $bJmpOk = Wine_EngineHookLive() Or $g_s_WineDrainKind = "wndproc"
	If Wine_CommandMoveReady() And $bJmpOk And $bTicking Then
		Wine_ResetQueueHead()
		Out("[Move] CommandMove stub live after rewire; Engine ticks=" & $iTicks & "; queue head reset")
		Return True
	EndIf
	If $iTicks <= 0 Then
		Out("[Move] MainProc bytes can be correct while ticks stay 0 — Engine fld JMP is not on the live path")
		Return Wine_VerifyDrainOrFallback()
	EndIf
	If Wine_DrainIsReplay() Then
		Out("[Move] refresh: keeping " & $g_s_WineDrainKind & " JMP (not re-pointing Engine)")
		Wine_ResetQueueHead()
		Return Wine_EngineHookLive()
	EndIf
	If Wine_MainProcBytesOk() And Wine_CommandMoveBytesOk() And $bJmpOk Then
		Wine_ResetQueueHead()
		Out("[Move] MainProc 60 9C and CommandMove 8D4004 already at the JMP target; not rewriting (ticks=" & $iTicks & ")")
		Return True
	EndIf
	Out("[Move] Engine not draining; rewriting stubs on Queue page and re-pointing the one JMP")
	Local $bRew = Wine_RewriteStubsOnExistingPage()
	Wine_RepointEngineJmp($a_s_Why)
	Wine_ResetQueueHead()
	$g_i_WineTicksLast = Wine_EngineTickCount()
	$g_h_WineTicksAt = TimerInit()
	If Wine_CommandMoveReady() Then
		Out("[Move] CommandMove stub live after rewire; queue head reset to 0")
		Return True
	EndIf
	Return $bRew
EndFunc

; Reuse the live Engine E9 page. Same layout as the first install (QueueBase at
; page+12, MainProc at page+65548). Does not VirtualAlloc or WriteDetour.
Func Wine_RewriteStubsOnExistingPage()
	If Wine_MapIsLoading() Then Return False
	Local $pEngine = Wine_ScanEngineOnly()
	$g_p_WineExistingE9 = 0
	Local $pHook = Wine_FindEngineHookSite($pEngine)
	If $pHook = 0 Then $pHook = $g_p_WineExistingE9
	If $pHook = 0 Then
		Local $pMainStart = Wine_LabelUserPtr("MainStart")
		If $pMainStart <> 0 And StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pMainStart, 5)), 2) = "E9" Then
			$pHook = $pMainStart
			$g_p_WineExistingE9 = $pHook
		EndIf
	EndIf
	If $pHook = 0 Then
		Out("[Move] rewrite: no Engine hook site")
		Return False
	EndIf
	Local $pAlloc = 0
	If Wine_IsUserPtr($g_p_QueueBase) Then $pAlloc = BitAND(Number($g_p_QueueBase) - 12, 0xFFFFFFFF)
	If Not Wine_IsUserPtr($pAlloc) Then
		Local $pMainExist = 0
		If StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pHook, 5)), 2) = "E9" Then
			$pMainExist = Scanner_GetCallTargetAddress($pHook)
		EndIf
		If Wine_IsUserPtr($pMainExist) Then $pAlloc = $pMainExist - (4 + 4 + 4 + 256 * 256)
	EndIf
	If Not Wine_IsUserPtr($pAlloc) Then
		Out("[Move] rewrite: no Queue/ASM page")
		Return False
	EndIf
	Out("[Move] rewrite: hook " & Wine_HexPtr($pHook) & " page " & Wine_HexPtr($pAlloc) & " QueueBase=" & Wine_HexPtr($g_p_QueueBase))

	Local $aSave = $g_amx2_Patterns
	Scanner_ClearPatterns()
	Wine_RegisterQueuePatterns()
	Local $aResults = Wine_ScanPatternsChunked()
	Local $aQueuePatterns = $g_amx2_Patterns
	$g_amx2_Patterns = $aQueuePatterns
	If Not IsArray($aResults) Then
		$g_amx2_Patterns = $aSave
		Out("[Move] rewrite: 4KB scan failed")
		Return False
	EndIf
	Local $pMove = Wine_ResolveFuncStart(Scanner_GetScanResult("Move", $aResults, "Func"))
	Local $pPacketSend = Wine_ResolveFuncStart(Scanner_GetScanResult("PacketSend", $aResults, "Func"))
	Local $pPacketLoc = Wine_ReadLivePtr(Scanner_GetScanResult("PacketLocation", $aResults, "Ptr"))
	Local $pDialog = Wine_ResolveCallTarget(Scanner_GetScanResult("Dialog", $aResults, "Func"))
	Local $pInteract = Wine_ResolveCallTarget(Scanner_GetScanResult("Interact", $aResults, "Func"))
	Local $pEnter = Wine_ResolveCallTarget(Scanner_GetScanResult("EnterMission", $aResults, "Func"))
	Local $pUiMsg = Wine_ResolveFuncStart(Scanner_GetScanResult("UIMessage", $aResults, "Func"))
	Wine_BindReadOnlyFromQueue($aResults, $aQueuePatterns)
	$g_amx2_Patterns = $aSave
	If $pMove = 0 Then
		Out("[Move] rewrite: Move func not resolved")
		Return False
	EndIf
	If $pPacketSend <> 0 Then Wine_ReplaceValue("PacketSend", Ptr($pPacketSend))
	If $pPacketLoc <> 0 Then
		Wine_ReplaceValue("PacketLocation", Ptr($pPacketLoc))
		$g_p_PacketLocation = $pPacketLoc
	EndIf
	If $pDialog <> 0 Then Wine_ReplaceValue("Dialog", Ptr($pDialog))
	If $pInteract <> 0 Then Wine_ReplaceValue("Interact", Ptr($pInteract))
	If $pEnter <> 0 Then Wine_ReplaceValue("EnterMission", Ptr($pEnter))
	If Wine_IsUserPtr($pUiMsg) Then Wine_ReplaceValue("UIMessage", Ptr($pUiMsg))
	Wine_ReplaceValue("Move", Ptr($pMove))
	Wine_ReplaceValue("MainStart", Ptr($pHook))
	Wine_ReplaceValue("MainReturn", Ptr($pHook + 5))
	Wine_ReplaceValue("QueueSize", 0x100)

	$g_i_ASMSize = 0
	$g_i_ASMCodeOffset = 0
	$g_s_ASMCode = ""
	$g_s_WineAsmExit = "engine"
	Wine_AssembleMinimalEngine()
	$g_p_WineAsmAlloc = 0
	$g_p_ASMMemory = $pAlloc
	Wine_BindEngineTicks()
	Wine_PromoteNewLabels()
	Assembler_CompleteASMCode()
	If $g_s_ASMCode = "" Then
		Out("[Move] rewrite: Assembler_CompleteASMCode produced no bytes")
		Return False
	EndIf
	Memory_WriteBinary($g_s_ASMCode, $g_p_ASMMemory + $g_i_ASMCodeOffset)

	Local $pQueue = Memory_GetValue("QueueBase")
	Local $pMain = Memory_GetValue("MainProc")
	Local $pCmdMove = Memory_GetValue("CommandMove")
	If Not Wine_IsUserPtr($pQueue) Or Not Wine_IsUserPtr($pMain) Or Not Wine_IsUserPtr($pCmdMove) Then
		Out("[Move] rewrite: QueueBase/MainProc/CommandMove label is not a user ptr")
		Return False
	EndIf
	$g_p_SavedIndex = Memory_GetValue("SavedIndex")
	$g_p_MapIsLoaded = Memory_GetValue("MapIsLoaded")
	$g_i_QueueSize = 0x100 - 1
	$g_p_QueueBase = $pQueue
	Wine_WireCommandStructs()
	Wine_ResetQueueHead()
	$g_b_WineMinimalHook = True
	Wine_RepointEngineJmp("rewrite")
	Out("[Move] rewrite done QueueBase=" & Wine_HexPtr($pQueue) & " MainProc=" & Wine_HexPtr($pMain) & _
			" MainProcBytes=" & Wine_CompactHex(Wine_ReadBytesHex($pMain, 6)) & _
			" CommandMove=" & Wine_HexPtr($pCmdMove) & " stub=" & Wine_CompactHex(Wine_ReadBytesHex($pCmdMove, 8)) & _
			" Move=" & Wine_HexPtr($pMove) & " ticks=" & Wine_EngineTickCount() & _
			" CodeOff=" & $g_i_ASMCodeOffset)
	If Not Wine_MainProcBytesOk() Then
		Out("[Move] rewrite: MainProc does not start 60 9C (pushad/pushfd); write missed the JMP target")
		Return False
	EndIf
	Wine_PatchMainProcHeartbeat()
	Wine_LogMainProcProof("rewrite")
	Return Wine_CommandMoveReady()
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
	Wine_RestoreOrphanReplayHooks()
	Wine_RefreshQueueFromLabels()
	If Wine_QueueWalkReady() Then
		$g_b_WineMinimalHook = True
		Wine_SyncQueueCounter()
		Wine_WireCommandStructs()
		Local $pJmp = Wine_EngineJmpTarget()
		Local $pMain = Wine_LabelUserPtr("MainProc")
		If Not $g_b_WineEngineProven Then
			Out("Wine queue: walk-ready but drain never ticked (kind=" & $g_s_WineDrainKind & "); taking GWA2/SkillTimer")
			Wine_VerifyDrainOrFallback()
		ElseIf Not Wine_CommandMoveReady() Or ($g_s_WineDrainKind <> "wndproc" And ($pJmp = 0 Or $pMain = 0 Or Not Wine_PtrsEq($pJmp, $pMain))) Then
			If $g_h_WineRefreshAt = 0 Or TimerDiff($g_h_WineRefreshAt) >= 8000 Then
				Out("Wine queue: walk-ready but CommandMove/JMP layout is wrong; refreshing (one JMP)")
				Wine_RefreshCommandMove("ensure-engine")
			EndIf
		EndIf
		Return True
	EndIf
	; Map load to 246 must not rewrite Engine JMP / QueueBase. Reuse the page.
	If Wine_QueueAlreadyLive() Then
		Out("Wine queue: QueueBase already live; not re-injecting Engine JMP (map " & Map_GetMapID() & ")")
		Wine_SyncQueueCounter()
		Wine_WireCommandStructs()
		$g_b_WineMinimalHook = True
		If Not Wine_CommandMoveReady() Then
			If $g_h_WineRefreshAt = 0 Or TimerDiff($g_h_WineRefreshAt) >= 8000 Then Wine_RefreshCommandMove("ensure-live-stale")
		EndIf
		Return True
	EndIf
	If Wine_MapIsLoading() Then
		Out("Wine queue: map is loading; not injecting Engine JMP")
		Return False
	EndIf
	If Wine_CommandsReady() And $g_s_WineDrainKind <> "none" Then
		If Not $g_b_WineEngineProven Then
			Out("Wine queue: QueueBase live kind=" & $g_s_WineDrainKind & " ticks=" & Wine_EngineTickCount() & "; not planting Engine JMP, retrying GWA2/SkillTimer")
			Wine_VerifyDrainOrFallback()
		EndIf
		Wine_WireCommandStructs()
		$g_b_WineMinimalHook = True
		Return True
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
		If Not $g_b_WineEngineProven Then Wine_VerifyDrainOrFallback()
		If $g_b_WineEngineProven Then
			Out("Wine queue: live QueueBase=" & Wine_HexPtr($g_p_QueueBase) & _
					" CommandMove=" & Wine_HexPtr(Memory_GetValue("CommandMove")) & _
					" AgentBase=" & Wine_HexPtr($g_p_AgentBase) & _
					" kind=" & $g_s_WineDrainKind & " ticks=" & Wine_EngineTickCount())
		Else
			Out("Wine queue: QueueBase=" & Wine_HexPtr($g_p_QueueBase) & _
					" CommandMove=" & Wine_HexPtr(Memory_GetValue("CommandMove")) & _
					" AgentBase=" & Wine_HexPtr($g_p_AgentBase) & _
					" kind=" & $g_s_WineDrainKind & " ticks=" & Wine_EngineTickCount() & " (drain not proven)")
		EndIf
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

Func Wine_LeHex($a_p)
	Local $s = Wine_HexPtr($a_p)
	Return StringMid($s, 7, 2) & StringMid($s, 5, 2) & StringMid($s, 3, 2) & StringMid($s, 1, 2)
EndFunc

Func Wine_ReadImm32($a_p)
	If $a_p = 0 Then Return 0
	Return BitAND(Number(Memory_Read($a_p)), 0xFFFFFFFF)
EndFunc

Func Wine_TextBounds(ByRef $a_p_Start, ByRef $a_p_End)
	$a_p_Start = 0
	$a_p_End = 0
	If IsDeclared("g_ai2_Sections") And IsArray($g_ai2_Sections) Then
		$a_p_Start = $g_ai2_Sections[$GC_I_SECTION_TEXT][0]
		$a_p_End = $g_ai2_Sections[$GC_I_SECTION_TEXT][1]
	EndIf
	Return ($a_p_Start <> 0 And $a_p_End > $a_p_Start)
EndFunc

Func Wine_FlushGw($a_p, $a_i_Size)
	If $g_h_GWProcess = 0 Or $a_p = 0 Or $a_i_Size < 1 Then Return
	Local $dOld = DllStructCreate("dword")
	DllCall($g_h_Kernel32, "int", "VirtualProtectEx", "int", $g_h_GWProcess, "int", $a_p, "uint", $a_i_Size, "dword", 0x40, "ptr", DllStructGetPtr($dOld))
	DllCall($g_h_Kernel32, "int", "FlushInstructionCache", "int", $g_h_GWProcess, "int", $a_p, "uint", $a_i_Size)
EndFunc

; 4KB scan for every copy of a hex needle (00 = wildcard). Returns [0]=count.
Func Wine_FindPatternHits($a_s_Pat, $a_i_Max = 8)
	Local $aOut[1] = [0]
	Local $pStart = 0, $pEnd = 0
	If Not Wine_TextBounds($pStart, $pEnd) Then Return $aOut
	Local $sPat = Wine_CompactHex($a_s_Pat)
	If $sPat = "" Or Mod(StringLen($sPat), 2) = 1 Then Return $aOut
	Local $iLen = Int(StringLen($sPat) / 2)
	Local $aBytes[$iLen]
	Local $abWild[$iLen]
	Local $sNeedle = ""
	Local $iNeedleAt = 0
	Local $iBest = 0, $iBestAt = 0, $iRun = 0, $iRunAt = 0
	Local $b = 0
	For $b = 0 To $iLen - 1
		$aBytes[$b] = Dec(StringMid($sPat, $b * 2 + 1, 2))
		$abWild[$b] = ($aBytes[$b] = 0)
		If Not $abWild[$b] Then
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
	If $iBest < 1 Then Return $aOut
	Local $n = 0
	For $n = 0 To $iBest - 1
		$sNeedle &= Chr($aBytes[$iBestAt + $n])
	Next
	$iNeedleAt = $iBestAt
	Local $iChunk = 4096
	Local $iOverlap = $iLen
	If $iOverlap < 16 Then $iOverlap = 16
	Local $p = $pStart
	While $p < $pEnd And $aOut[0] < $a_i_Max
		Local $iRead = $iChunk
		If $p + $iRead > $pEnd Then $iRead = $pEnd - $p
		If $iRead < $iLen Then ExitLoop
		Local $dBuf = DllStructCreate("byte[" & $iRead & "]")
		If @error Then ExitLoop
		Local $av = DllCall($g_h_Kernel32, "int", "ReadProcessMemory", _
				"int", $g_h_GWProcess, "int", $p, "ptr", DllStructGetPtr($dBuf), "int", $iRead, "int", "")
		If @error Or Not IsArray($av) Or $av[0] = 0 Then ExitLoop
		Local $sHay = BinaryToString(DllStructGetData($dBuf, 1), 1)
		Local $iPos = 1
		While $aOut[0] < $a_i_Max
			$iPos = StringInStr($sHay, $sNeedle, 1, 1, $iPos)
			If $iPos = 0 Then ExitLoop
			Local $iHit = $iPos - 1 - $iNeedleAt
			If $iHit >= 0 And $iHit + $iLen <= $iRead Then
				Local $bOk = True
				For $b = 0 To $iLen - 1
					If $abWild[$b] Then ContinueLoop
					If DllStructGetData($dBuf, 1, $iHit + $b + 1) <> $aBytes[$b] Then
						$bOk = False
						ExitLoop
					EndIf
				Next
				If $bOk Then
					Local $pHit = $p + $iHit
					Local $bDup = False
					Local $j = 1
					For $j = 1 To $aOut[0]
						If Wine_PtrsEq($aOut[$j], $pHit) Then $bDup = True
					Next
					If Not $bDup Then
						$aOut[0] += 1
						ReDim $aOut[$aOut[0] + 1]
						$aOut[$aOut[0]] = $pHit
					EndIf
				EndIf
			EndIf
			$iPos += 1
		WEnd
		If $p + $iRead >= $pEnd Then ExitLoop
		$p += $iRead - $iOverlap
		If $iOverlap >= $iRead Then ExitLoop
	WEnd
	Return $aOut
EndFunc

; E8/E9 callers in ±32KB. call eax / vtable callers are invisible.
Func Wine_CountNearCallers($a_p_Target)
	If $a_p_Target = 0 Then Return 0
	Local $pText0 = 0, $pText1 = 0
	Wine_TextBounds($pText0, $pText1)
	Local $pStart = $a_p_Target - 0x8000
	Local $pEnd = $a_p_Target + 0x8000
	If $pText0 <> 0 And $pStart < $pText0 Then $pStart = $pText0
	If $pText1 <> 0 And $pEnd > $pText1 Then $pEnd = $pText1
	Local $iN = 0
	Local $p = $pStart
	While $p < $pEnd
		Local $iRead = 4096
		If $p + $iRead > $pEnd Then $iRead = $pEnd - $p
		If $iRead < 6 Then ExitLoop
		Local $dBuf = DllStructCreate("byte[" & $iRead & "]")
		If @error Then ExitLoop
		Local $av = DllCall($g_h_Kernel32, "int", "ReadProcessMemory", _
				"int", $g_h_GWProcess, "int", $p, "ptr", DllStructGetPtr($dBuf), "int", $iRead, "int", "")
		If @error Or Not IsArray($av) Or $av[0] = 0 Then ExitLoop
		Local $i = 1
		For $i = 1 To $iRead - 4
			Local $iOp = DllStructGetData($dBuf, 1, $i)
			If $iOp <> 0xE8 And $iOp <> 0xE9 Then ContinueLoop
			Local $pSite = $p + $i - 1
			Local $pT = Scanner_GetCallTargetAddress($pSite)
			If Wine_PtrsEq($pT, $a_p_Target) Or Wine_PtrsEq($pT, $a_p_Target - 1) Or Wine_PtrsEq($pT, $a_p_Target + 1) Then
				$iN += 1
			EndIf
		Next
		$p += $iRead - 5
	WEnd
	Return $iN
EndFunc

; 32-byte MainProc dump + decoded [EngineTicks] / [QueueCounter] / DrainSeen vs labels.
Func Wine_LogMainProcProof($a_s_Why = "proof", $a_b_Callers = False)
	Local $pMain = Wine_LabelUserPtr("MainProc")
	Local $pTicks = Wine_LabelUserPtr("EngineTicks")
	Local $pQC = Wine_LabelUserPtr("QueueCounter")
	Local $pQB = Wine_LabelUserPtr("QueueBase")
	Local $pSeen = Wine_LabelUserPtr("DrainSeen")
	Local $pHook = Wine_ResolveEngineHookSite(False)
	If $pHook = 0 Then $pHook = $g_p_WineEngineHook
	If $pHook = 0 Then $pHook = Wine_LabelUserPtr("MainStart")
	Local $sMain = Wine_ReadBytesHex($pMain, 96)
	Local $sComp = Wine_CompactHex($sMain)
	Local $sHook = Wine_ReadBytesHex($pHook, 8)
	Local $iInc = 0
	Local $iQcOp = 0
	Local $iQbOp = 0
	Local $iPendOp = 0
	If $pMain <> 0 Then
		If Wine_CompactHex(Wine_ReadBytesHex($pMain + 2, 2)) = "FF05" Then $iInc = Wine_ReadImm32($pMain + 4)
		If Wine_CompactHex(Wine_ReadBytesHex($pMain + 8, 2)) = "8B1D" Then $iPendOp = Wine_ReadImm32($pMain + 10)
		If $iPendOp = 0 And Wine_CompactHex(Wine_ReadBytesHex($pMain + 8, 1)) = "A1" Then $iPendOp = Wine_ReadImm32($pMain + 9)
		Local $iReg = StringInStr($sComp, "8BC8C1E00805")
		If $iReg > 0 Then
			Local $iOff = Int(($iReg - 1) / 2)
			If $iOff >= 5 And Wine_CompactHex(Wine_ReadBytesHex($pMain + $iOff - 5, 1)) = "A1" Then $iQcOp = Wine_ReadImm32($pMain + $iOff - 4)
			If Wine_CompactHex(Wine_ReadBytesHex($pMain + $iOff + 5, 1)) = "05" Then $iQbOp = Wine_ReadImm32($pMain + $iOff + 6)
		EndIf
	EndIf
	Local $iSeen = 0
	If $pSeen <> 0 Then $iSeen = Number(Memory_Read($pSeen))
	Local $pPend = Wine_LabelUserPtr("PendingMove")
	Local $iPend = 0
	If $pPend <> 0 Then $iPend = Number(Memory_Read($pPend))
	Local $sCallers = "skip"
	If $a_b_Callers And $pHook <> 0 Then $sCallers = Wine_CountNearCallers($pHook)
	Out("[Move] MainProc proof (" & $a_s_Why & ") kind=" & $g_s_WineDrainKind & _
			" MainProc=" & Wine_HexPtr($pMain) & " bytes=" & $sComp & _
			" inc=[" & Wine_HexPtr($iInc) & "] EngineTicks=" & Wine_HexPtr($pTicks) & _
			" pendOp=[" & Wine_HexPtr($iPendOp) & "] PendingMove=" & Wine_HexPtr($pPend) & "=" & $iPend & _
			" qcOp=[" & Wine_HexPtr($iQcOp) & "] QueueCounter=" & Wine_HexPtr($pQC) & _
			" qbOp=[" & Wine_HexPtr($iQbOp) & "] QueueBase=" & Wine_HexPtr($pQB) & _
			" drainSeen=" & $iSeen & _
			" ticks=" & Wine_EngineTickCount() & " hook=" & Wine_HexPtr($pHook) & " hookBytes=" & $sHook & _
			" nearCallers=" & $sCallers & " jmp=" & Wine_HexPtr(Wine_EngineJmpTarget()))
	If $pTicks <> 0 And $iInc <> 0 And Not Wine_PtrsEq($iInc, $pTicks) Then
		Out("[Move] MainProc inc target is NOT EngineTicks — patching FF05")
		Wine_PatchMainProcHeartbeat()
	EndIf
	If $pPend <> 0 And $iPendOp <> 0 And Not Wine_PtrsEq($iPendOp, $pPend) Then
		Out("[Move] MainProc PendingMove load is NOT PendingMove — pendOp=" & Wine_HexPtr($iPendOp))
	EndIf
	If $pQB <> 0 And $iQbOp <> 0 And Not Wine_PtrsEq($iQbOp, $pQB) Then
		Out("[Move] MainProc add eax,QueueBase is NOT QueueBase — qbOp=" & Wine_HexPtr($iQbOp))
	EndIf
EndFunc

Func Wine_PatchMainProcHeartbeat()
	Local $pMain = Wine_LabelUserPtr("MainProc")
	Local $pTicks = Wine_LabelUserPtr("EngineTicks")
	If $pMain = 0 Or $pTicks = 0 Then Return False
	If Not Wine_MainProcBytesOk() Then Return False
	Memory_WriteBinary("FF05" & Wine_LeHex($pTicks), $pMain + 2)
	Memory_Write($pTicks, 0)
	Wine_FlushGw($pMain, 16)
	Wine_FlushGw($pTicks, 4)
	Return True
EndFunc

Func Wine_PatchStolenExit()
	If StringLen($g_s_WineExitReplay) <> 10 Then Return False
	Local $pExit = Wine_LabelUserPtr("MainExit")
	If $pExit = 0 Then Return False
	Memory_WriteBinary($g_s_WineExitReplay, $pExit + 2)
	Wine_FlushGw($pExit, 16)
	Out("[Move] MainExit stolen bytes " & $g_s_WineExitReplay & " at " & Wine_HexPtr($pExit + 2))
	Return True
EndFunc

Func Wine_PatchGwa2Exit()
	Local $pExit = Wine_LabelUserPtr("MainExit")
	If $pExit = 0 Then Return False
	; popfd; popad already at MainExit. Overwrite mov ebp,esp / fld [ebp+8]
	; (8B EC D9 45 08) with call eax; add esp,4 (FF D0 83 C4 04). Same 5 bytes.
	Memory_WriteBinary("FFD083C404", $pExit + 2)
	Wine_FlushGw($pExit, 16)
	Out("[Move] GWA2 MainExit patched to call eax; add esp,4 at " & Wine_HexPtr($pExit + 2))
	Return True
EndFunc

; Original 5 bytes for a leftover E9, from saved bytes or the insn tail.
; SkillTimer: E9 over FFD68B4DF0, tail 8BD88B4708. GWA2: E9 over FFD083C404,
; tail 8BCE (and the 56 push esi before the site). Engine: 8BECD94508.
Func Wine_StolenOriginal5($a_p_Hook)
	If $a_p_Hook = 0 Then Return ""
	If $g_p_WineHookSaved <> 0 And Wine_PtrsEq($g_p_WineHookSaved, $a_p_Hook) And StringLen($g_s_WineHookSaved) = 10 Then
		Return $g_s_WineHookSaved
	EndIf
	Local $sNow = Wine_CompactHex(Wine_ReadBytesHex($a_p_Hook, 5))
	Local $sTail = Wine_CompactHex(Wine_ReadBytesHex($a_p_Hook + 5, 5))
	If $sNow = "FFD68B4DF0" Or $sNow = "FFD083C404" Or $sNow = "8BECD94508" Or $sNow = "D9E0D95DFC" Then Return $sNow
	If $sTail = "8BD88B4708" Then Return "FFD68B4DF0"
	If StringLeft($sTail, 4) = "8BCE" And Wine_CompactHex(Wine_ReadBytesHex($a_p_Hook - 1, 1)) = "56" Then Return "FFD083C404"
	If StringLeft($sTail, 4) = "8B01" And ($sNow = "D9E0D95DFC" Or StringLeft($sNow, 2) = "E9") Then
		Local $pScene = 0
		If IsDeclared("g_ap_ScanResults") And IsArray($g_ap_ScanResults) Then $pScene = Scanner_GetScanResult("SceneContext", $g_ap_ScanResults, "Ptr")
		If $pScene <> 0 And Wine_PtrsEq($pScene, $a_p_Hook) Then Return "D9E0D95DFC"
	EndIf
	If Wine_EnginePatternNear($a_p_Hook) Then Return "8BECD94508"
	Return ""
EndFunc

Func Wine_RestoreEngineEpilogue($a_p_Hook)
	If $a_p_Hook = 0 Then Return False
	Local $sNow = Wine_CompactHex(Wine_ReadBytesHex($a_p_Hook, 5))
	Local $sWant = Wine_StolenOriginal5($a_p_Hook)
	If $sWant = "" Then
		Out("[Move] restore refused: " & Wine_HexPtr($a_p_Hook) & " bytes=" & $sNow & " tail=" & Wine_CompactHex(Wine_ReadBytesHex($a_p_Hook + 5, 5)))
		Return False
	EndIf
	If StringLeft($sNow, 2) <> "E9" Then
		If $sNow = $sWant Then
			Out("[Move] hook " & Wine_HexPtr($a_p_Hook) & " already " & $sWant)
			Return True
		EndIf
		Out("[Move] restore refused: " & Wine_HexPtr($a_p_Hook) & " bytes=" & $sNow)
		Return False
	EndIf
	Out("[Move] restoring hook " & Wine_HexPtr($a_p_Hook) & " " & $sNow & " -> " & $sWant)
	Memory_WriteBinary($sWant, $a_p_Hook)
	Wine_FlushGw($a_p_Hook, 8)
	If Wine_PtrsEq($g_p_WineExistingE9, $a_p_Hook) Then $g_p_WineExistingE9 = 0
	If Wine_PtrsEq($g_p_WineEngineHook, $a_p_Hook) Then $g_p_WineEngineHook = 0
	If Wine_PtrsEq(Wine_LabelUserPtr("MainStart"), $a_p_Hook) Then Wine_ReplaceValue("MainStart", Ptr(0))
	Return Wine_CompactHex(Wine_ReadBytesHex($a_p_Hook, 5)) = $sWant
EndFunc

Func Wine_RestoreOurHooks()
	Wine_RestoreGwWndProc()
	Local $pMainStart = Wine_LabelUserPtr("MainStart")
	If $pMainStart <> 0 And StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pMainStart, 5)), 2) = "E9" Then
		Wine_RestoreEngineEpilogue($pMainStart)
	EndIf
	If $g_p_WineEngineHook <> 0 And Not Wine_PtrsEq($g_p_WineEngineHook, $pMainStart) Then
		If StringLeft(Wine_CompactHex(Wine_ReadBytesHex($g_p_WineEngineHook, 5)), 2) = "E9" Then
			Wine_RestoreEngineEpilogue($g_p_WineEngineHook)
		EndIf
	EndIf
	If $g_p_WineExistingE9 <> 0 And Not Wine_PtrsEq($g_p_WineExistingE9, $pMainStart) Then
		If StringLeft(Wine_CompactHex(Wine_ReadBytesHex($g_p_WineExistingE9, 5)), 2) = "E9" Then
			Wine_RestoreEngineEpilogue($g_p_WineExistingE9)
		EndIf
	EndIf
	If $g_p_WineDeadHook <> 0 Then
		If StringLeft(Wine_CompactHex(Wine_ReadBytesHex($g_p_WineDeadHook, 5)), 2) = "E9" Then
			Wine_RestoreEngineEpilogue($g_p_WineDeadHook)
		EndIf
	EndIf
	Wine_RestoreOrphanReplayHooks()
EndFunc

; After AutoIt restart, session pointers are 0 but Gw still has leftover E9s
; (Start A: SkillTimer 0047F7EC stayed E9, pattern FFD68B4DF0 vanished).
; Restore original 5 bytes so the next plant can scan and keep one hook.
Func Wine_RestoreOrphanReplayHooks()
	If Not Wine_IsWine() Then Return
	Local $pLive = Wine_LabelUserPtr("MainStart")
	Local $i = 1
	Local $aSt = Wine_FindPatternHits("8BD88B4708", 8)
	For $i = 1 To $aSt[0]
		Local $pSt = $aSt[$i] - 5
		If Not Wine_IsUserPtr($pSt) Then ContinueLoop
		If $pLive <> 0 And Wine_PtrsEq($pSt, $pLive) Then ContinueLoop
		If $g_p_WineEngineHook <> 0 And Wine_PtrsEq($pSt, $g_p_WineEngineHook) Then ContinueLoop
		If $g_p_WineExistingE9 <> 0 And Wine_PtrsEq($pSt, $g_p_WineExistingE9) Then ContinueLoop
		If StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pSt, 5)), 2) <> "E9" Then ContinueLoop
		Local $pTgt = Scanner_GetCallTargetAddress($pSt)
		Local $sTgt = Wine_CompactHex(Wine_ReadBytesHex($pTgt, 2))
		If $sTgt = "609C" Then
			Out("Wine SkillTimer leftover E9 at " & Wine_HexPtr($pSt) & " -> MainProc " & Wine_HexPtr($pTgt) & " (60 9C); restoring FFD68B4DF0 so the next plant is a clean call-esi")
		Else
			Out("Wine SkillTimer leftover E9 at " & Wine_HexPtr($pSt) & " -> " & Wine_HexPtr($pTgt) & "; restoring FFD68B4DF0")
		EndIf
		Wine_RestoreEngineEpilogue($pSt)
	Next
	Local $aEpi = Wine_FindPatternHits("8BECD94508", 12)
	For $i = 1 To $aEpi[0]
		Local $pGwaNear = $aEpi[$i] + 0x6C
		If Not Wine_IsUserPtr($pGwaNear) Then ContinueLoop
		If $pLive <> 0 And Wine_PtrsEq($pGwaNear, $pLive) Then ContinueLoop
		If StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pGwaNear, 5)), 2) <> "E9" Then ContinueLoop
		If Wine_CompactHex(Wine_ReadBytesHex($pGwaNear - 1, 1)) <> "56" Then ContinueLoop
		Out("Wine GWA2 leftover E9 at " & Wine_HexPtr($pGwaNear) & " (Engine epi+0x6C); restoring FFD083C404")
		Wine_RestoreEngineEpilogue($pGwaNear)
	Next
	Local $aGw = Wine_FindPatternHits("8BCEE8", 24)
	For $i = 1 To $aGw[0]
		Local $pGw = $aGw[$i] - 5
		If Not Wine_IsUserPtr($pGw) Then ContinueLoop
		If $pLive <> 0 And Wine_PtrsEq($pGw, $pLive) Then ContinueLoop
		If $g_p_WineEngineHook <> 0 And Wine_PtrsEq($pGw, $g_p_WineEngineHook) Then ContinueLoop
		If StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pGw, 5)), 2) <> "E9" Then ContinueLoop
		If Wine_CompactHex(Wine_ReadBytesHex($pGw - 1, 1)) <> "56" Then ContinueLoop
		Out("Wine GWA2 leftover E9 at " & Wine_HexPtr($pGw) & "; restoring FFD083C404")
		Wine_RestoreEngineEpilogue($pGw)
	Next
	If IsDeclared("g_ap_ScanResults") And IsArray($g_ap_ScanResults) Then
		Local $pScene = Scanner_GetScanResult("SceneContext", $g_ap_ScanResults, "Ptr")
		If $pScene <> 0 And StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pScene, 5)), 2) = "E9" Then
			If StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pScene + 5, 2)), 4) = "8B01" Then
				Out("Wine Scene leftover E9 at " & Wine_HexPtr($pScene) & "; restoring D9E0D95DFC")
				Memory_WriteBinary("D9E0D95DFC", $pScene)
				Wine_FlushGw($pScene, 8)
			EndIf
		EndIf
	EndIf
EndFunc

Func Wine_GwWndProcHwnd()
	If $g_h_WineGwHwnd <> 0 And Wine_HwndIsStub($g_h_WineGwHwnd) Then $g_h_WineGwHwnd = 0
	Local $iPid = Number($g_i_GWProcessId)
	Local $h = Wine_DiscoverGwWindow($iPid)
	If $h = 0 And $iPid > 0 Then $h = Wine_DiscoverGwWindow(0)
	If $h <> 0 Then $h = Wine_PreferDxChild($h, $iPid)
	If Wine_HwndIsStub($h) Then
		$g_h_WineGwHwnd = 0
		Return 0
	EndIf
	If $h <> 0 Then $g_h_WineGwHwnd = $h
	Return $h
EndFunc

Func Wine_GwWndProcCurrent()
	Return Wine_HwndWndProc(Wine_GwWndProcHwnd())
EndFunc

Func Wine_PokeGwWindow()
	Local $h = Wine_GwWndProcHwnd()
	If $h = 0 Then Return
	DllCall("user32.dll", "bool", "PostMessageA", "hwnd", $h, "uint", 0, "wparam", 0, "lparam", 0)
	DllCall("user32.dll", "bool", "PostMessageA", "hwnd", $h, "uint", 0x000F, "wparam", 0, "lparam", 0)
	DllCall("user32.dll", "bool", "PostMessageA", "hwnd", $h, "uint", 0x0113, "wparam", 1, "lparam", 0)
	DllCall("user32.dll", "bool", "PostMessageA", "hwnd", $h, "uint", 0x0200, "wparam", 0, "lparam", 0)
EndFunc

Func Wine_WaitDrainTicks($a_i_Ms)
	Local $iStart = Wine_EngineTickCount()
	If $iStart < 0 Then $iStart = 0
	Local $h = TimerInit()
	Local $iNow = $iStart
	While TimerDiff($h) < $a_i_Ms
		$iNow = Wine_EngineTickCount()
		If $iNow > $iStart Then
			Out("Wine: drain proven ticks=" & $iStart & "->" & $iNow & " kind=" & $g_s_WineDrainKind)
			Wine_LogMainProcProof("drain-live")
			Return True
		EndIf
		Sleep(50)
	WEnd
	Out("Wine: drain still ticks=" & Wine_EngineTickCount() & " kind=" & $g_s_WineDrainKind & " after " & $a_i_Ms & "ms (not rising)")
	Return False
EndFunc

Func Wine_DrainIsReplay($a_s = "")
	If $a_s = "" Then $a_s = $g_s_WineDrainKind
	Return $a_s = "skilltimer" Or $a_s = "scene" Or $a_s = "uimsg" Or $a_s = "render"
EndFunc

Func Wine_DrainSkipEngineJmp()
	Return $g_s_WineDrainKind = "gwa2" Or $g_s_WineDrainKind = "wndproc" Or Wine_DrainIsReplay()
EndFunc

; 5 bytes that can be JMP-stolen and replayed (no rel8/rel32).
; Rejects the wine-gw Render -0x68 hit `C4 04 83 3D 9C` (tail of add esp,4).
Func Wine_BytesAreHookable5($a_s)
	Local $s = StringLeft(Wine_CompactHex($a_s), 10)
	If StringLen($s) < 10 Then Return False
	Local $b0 = StringLeft($s, 2)
	If $b0 = "E8" Or $b0 = "E9" Or $b0 = "EB" Or $b0 = "0F" Then Return False
	Local $i0 = Dec($b0)
	If $i0 >= 112 And $i0 <= 127 Then Return False
	If $b0 = "C4" Or $b0 = "C5" Or $b0 = "04" Or $b0 = "00" Then Return False
	If StringLeft($s, 4) = "C404" Or StringLeft($s, 4) = "833D" Then Return False
	If $s = "FFD68B4DF0" Or $s = "FFD083C404" Or $s = "8BECD94508" Then Return True
	If $s = "8BFF558BEC" Or StringLeft($s, 8) = "D9E0D95D" Then Return True
	If $b0 = "68" Then Return True
	If $i0 >= 184 And $i0 <= 191 Then Return True
	If $b0 = "FF" Then
		Local $i1 = Dec(StringMid($s, 3, 2))
		If $i1 >= 208 And $i1 <= 215 Then
			Local $b2 = StringMid($s, 5, 2)
			If $b2 = "8B" Or $b2 = "83" Then Return True
		EndIf
	EndIf
	Return False
EndFunc

; After Engine then GWA2 fail, plant SkillTimer (call esi). Do not plant the
; stock Render -0x68 site: on this Wine/Gw it is mid-`add esp,4` (C4 04…).
; If SkillTimer never ticks, try SceneContext then UIMessage. One hook.
Func Wine_VerifyDrainOrFallback()
	If Not Wine_IsWine() Then Return True
	If $g_b_WineEngineProven Then Return True
	If Wine_MapIsLoading() Then Return False
	If Wine_EngineTickCount() > 0 Then Return True

	If $g_s_WineDrainKind = "engine" Or $g_s_WineDrainKind = "none" Then
		If $g_s_WineDrainKind = "none" Then $g_s_WineDrainKind = "engine"
		If $g_h_WineVerifyAt <> 0 And TimerDiff($g_h_WineVerifyAt) < 4000 Then Return False
		$g_h_WineVerifyAt = TimerInit()
		If Wine_WaitDrainTicks(800) Then Return True
		Out("Wine: Engine fld site never ticked after 800ms (nearCallers=0; 7ccd322 left this JMP but later retests never entered it). Restoring 8B EC D9 45 08 and planting one GWA2 call-eax hook.")
		$g_h_WineRelocateAt = 0
		If Not Wine_RelocateDeadEngine("engine-never-ticks") Then
			Out("Wine: GWA2 plant failed; trying SkillTimer")
			$g_h_WineRelocateAt = 0
			$g_s_WineDrainKind = "gwa2"
			Wine_RelocateDeadEngine("gwa2-plant-failed")
		EndIf
	EndIf

	If $g_s_WineDrainKind = "gwa2" Then
		If Wine_WaitDrainTicks(800) Then Return True
		Out("Wine: GWA2 hook never ticked (same function as Engine fld). No Win32 hwnd — skipping WndProc. Render -0x68 is mid-instruction on this Gw; planting SkillTimer call-esi.")
		$g_h_WineRelocateAt = 0
		If Not Wine_RelocateDeadEngine("gwa2-never-ticks") Then Return False
	EndIf

	If $g_s_WineDrainKind = "render" Then
		If Wine_WaitDrainTicks(800) Then Return True
		Out("Wine: Render never ticked (hook site not on the live path). Restoring and planting SkillTimer.")
		$g_h_WineRelocateAt = 0
		If Not Wine_RelocateDeadEngine("render-never-ticks") Then Return False
	EndIf

	If $g_s_WineDrainKind = "skilltimer" Then
		If Wine_WaitDrainTicks(800) Then Return True
		Out("Wine: SkillTimer never ticked. Planting SceneContext fchs/fstp.")
		$g_h_WineRelocateAt = 0
		If Not Wine_RelocateDeadEngine("skilltimer-never-ticks") Then Return False
	EndIf

	If $g_s_WineDrainKind = "scene" Then
		If Wine_WaitDrainTicks(800) Then Return True
		Out("Wine: SceneContext never ticked. Planting UIMessage.")
		$g_h_WineRelocateAt = 0
		If Not Wine_RelocateDeadEngine("scene-never-ticks") Then Return False
	EndIf

	If $g_s_WineDrainKind = "uimsg" Then
		If Wine_WaitDrainTicks(800) Then Return True
		Out("Wine: UIMessage never ticked. Trying aligned Render last.")
		$g_h_WineRelocateAt = 0
		If Not Wine_RelocateDeadEngine("uimsg-never-ticks") Then Return False
	EndIf
	Return $g_b_WineEngineProven
EndFunc

Func Wine_RestoreGwWndProc()
	If $g_p_WineWndProcOld = 0 Then Return True
	Local $h = Wine_GwWndProcHwnd()
	If $h = 0 Then Return False
	Local $pCur = Wine_GwWndProcCurrent()
	Local $pMain = Wine_LabelUserPtr("MainProc")
	If $pMain = 0 Or Not Wine_PtrsEq($pCur, $pMain) Then Return True
	DllCall("user32.dll", "int", "SetWindowLongA", "hwnd", $h, "int", -4, "int", $g_p_WineWndProcOld)
	Out("[Move] WndProc restored to " & Wine_HexPtr($g_p_WineWndProcOld))
	Return True
EndFunc

Func Wine_FindCleanEngineEpilogue()
	If $g_p_WineCleanEpi <> 0 Then
		If Wine_CompactHex(Wine_ReadBytesHex($g_p_WineCleanEpi, 5)) = "8BECD94508" Then Return $g_p_WineCleanEpi
		$g_p_WineCleanEpi = 0
	EndIf
	Local $aEpi = Wine_FindPatternHits("8BECD94508", 12)
	Local $pBest = 0
	Local $i = 1
	For $i = 1 To $aEpi[0]
		Local $p = $aEpi[$i]
		Local $bNear = Wine_EnginePatternNear($p)
		Local $iCall = 0
		If $bNear Then $iCall = Wine_CountNearCallers($p)
		Out("Wine Engine epilogue " & Wine_HexPtr($p) & " near=" & $bNear & " nearCallers=" & $iCall)
		If $bNear And $pBest = 0 Then $pBest = $p
		If $bNear And $iCall > 0 Then
			$g_p_WineCleanEpi = $p
			Return $p
		EndIf
	Next
	If $pBest <> 0 Then
		$g_p_WineCleanEpi = $pBest
		Return $pBest
	EndIf
	Local $aNeedles = Wine_FindPatternHits("568B3085F67478EB038D4900D9460C", 8)
	For $i = 1 To $aNeedles[0]
		Local $pNeedle = $aNeedles[$i]
		Out("Wine Engine needle copy " & Wine_HexPtr($pNeedle))
		Local $d = 0
		For $d = 0 To 2
			Local $pHook = $pNeedle - 0x22 - $d
			If Wine_CompactHex(Wine_ReadBytesHex($pHook, 5)) = "8BECD94508" Then
				Out("Wine Engine clean epilogue at " & Wine_HexPtr($pHook) & " from needle " & Wine_HexPtr($pNeedle))
				$g_p_WineCleanEpi = $pHook
				Return $pHook
			EndIf
		Next
	Next
	Return 0
EndFunc

Func Wine_FindGwa2HookSite()
	; GWA2 ScanEngine: 56 FF D0 83 C4 04 8B CE E8 97... Hook the 5-byte
	; `call eax; add esp,4` at +1 so the boundary is exact.
	Local $aLeft = Wine_FindPatternHits("8BCEE8", 24)
	Local $k = 1
	For $k = 1 To $aLeft[0]
		Local $pLeft = $aLeft[$k] - 5
		If Not Wine_IsUserPtr($pLeft) Then ContinueLoop
		If StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pLeft, 5)), 2) <> "E9" Then ContinueLoop
		If Wine_CompactHex(Wine_ReadBytesHex($pLeft - 1, 1)) <> "56" Then ContinueLoop
		Out("Wine GWA2 leftover E9 at " & Wine_HexPtr($pLeft) & " bytes=" & Wine_ReadBytesHex($pLeft, 8) & "; restoring FFD083C404")
		If Wine_RestoreEngineEpilogue($pLeft) Then
			Out("Wine GWA2 live Engine " & Wine_HexPtr($pLeft) & " (restored call eax; add esp,4)")
			Return $pLeft
		EndIf
	Next
	Local $aNeedles[3] = ["56FFD083C4048BCE", "56FFD083C404", "FFD083C4048BCE"]
	Local $n = 0
	For $n = 0 To 2
		Local $a = Wine_FindPatternHits($aNeedles[$n], 6)
		Local $i = 1
		For $i = 1 To $a[0]
			Local $pHit = $a[$i]
			Local $pHook = $pHit
			If Wine_CompactHex(Wine_ReadBytesHex($pHit, 1)) = "56" Then $pHook = $pHit + 1
			Local $s = Wine_CompactHex(Wine_ReadBytesHex($pHook, 5))
			Out("Wine GWA2 hit " & Wine_HexPtr($pHit) & " hook=" & Wine_HexPtr($pHook) & " bytes=" & Wine_ReadBytesHex($pHook, 8) & " needle=" & $aNeedles[$n])
			If $s = "FFD083C404" Then
				Out("Wine GWA2 live Engine " & Wine_HexPtr($pHook) & " (call eax; add esp,4)")
				Return $pHook
			EndIf
			If StringLeft($s, 2) = "E9" And Wine_CompactHex(Wine_ReadBytesHex($pHook - 1, 1)) = "56" Then
				Out("Wine GWA2 leftover E9 at " & Wine_HexPtr($pHook) & " bytes=" & Wine_ReadBytesHex($pHook, 8) & "; restoring FFD083C404")
				If Wine_RestoreEngineEpilogue($pHook) Then
					Out("Wine GWA2 live Engine " & Wine_HexPtr($pHook) & " (restored call eax; add esp,4)")
					Return $pHook
				EndIf
			EndIf
		Next
	Next
	Out("Wine GWA2 Engine needle 56FFD083C4048BCE not found")
	Return 0
EndFunc

; GwAu3 Render landmark F6C401741C68. Stock uses hook=hit-0x68, but on this
; Wine/Gw that is mid-`add esp,4` (`C4 04 83 3D 9C`, nearCallers=0). Only
; return a site whose 5 bytes are position-independent and complete.
Func Wine_FindRenderHookSite()
	Local $a = Wine_FindPatternHits("F6C401741C68", 8)
	Local $pBest = 0
	Local $i = 1
	For $i = 1 To $a[0]
		Local $pHit = $a[$i]
		Local $pStock = $pHit - 0x68
		Local $sStock = Wine_ReadBytesHex($pStock, 16)
		Local $sFive = Wine_CompactHex(Wine_ReadBytesHex($pStock, 5))
		Local $iCall = Wine_CountNearCallers($pStock)
		Out("Wine Render hit " & Wine_HexPtr($pHit) & " stock-0x68=" & Wine_HexPtr($pStock) & " site16=" & $sStock & " nearCallers=" & $iCall)
		If Not Wine_BytesAreHookable5($sFive) Then
			Out("Wine Render skip " & Wine_HexPtr($pStock) & " bytes=" & $sFive & " (not a 5-byte instruction; wine-gw -0x68 is mid-add-esp)")
			Local $pPush = $pHit + 5
			Local $sPush = Wine_CompactHex(Wine_ReadBytesHex($pPush, 5))
			If StringLeft($sPush, 2) = "68" And Wine_BytesAreHookable5($sPush) Then
				Out("Wine Render using push-imm after test/jz " & Wine_HexPtr($pPush) & " bytes=" & $sPush)
				Return $pPush
			EndIf
			ContinueLoop
		EndIf
		If $iCall > 0 Or $pBest = 0 Then $pBest = $pStock
		If $iCall > 0 Then Return $pStock
	Next
	If $pBest <> 0 Then
		Out("Wine Render aligned hook " & Wine_HexPtr($pBest))
		Return $pBest
	EndIf
	Out("Wine Render: no aligned 5-byte site (will use SkillTimer)")
	Return 0
EndFunc

; SkillTimer `call esi; mov ecx,[ebp-10]` runs when the skill clock updates.
; Steal those 5 bytes and replay them after MainProc (no Win32 hwnd).
; GwAu3 scan is pattern-0x3 (pointer); the call esi is at that result + 3.
; Leftover E9 hides FFD68B4DF0; find tail 8BD88B4708 at +5 and restore/reuse.
Func Wine_FindSkillTimerHookSite()
	Local $pLeft = Wine_FindLeftoverSkillTimerE9()
	If $pLeft <> 0 Then
		Local $pTgt = Scanner_GetCallTargetAddress($pLeft)
		Local $sTgt = Wine_CompactHex(Wine_ReadBytesHex($pTgt, 2))
		If $sTgt = "609C" Then
			Out("Wine SkillTimer leftover E9 at " & Wine_HexPtr($pLeft) & " -> live MainProc " & Wine_HexPtr($pTgt) & "; restoring FFD68B4DF0 then planting this site")
		Else
			Out("Wine SkillTimer leftover E9 at " & Wine_HexPtr($pLeft) & " bytes=" & Wine_ReadBytesHex($pLeft, 10) & "; restoring FFD68B4DF0")
		EndIf
		If Wine_RestoreEngineEpilogue($pLeft) Then
			Out("Wine SkillTimer live hook " & Wine_HexPtr($pLeft) & " (restored call esi; mov ecx,[ebp-10])")
			Return $pLeft
		EndIf
	EndIf
	If IsDeclared("g_ap_ScanResults") And IsArray($g_ap_ScanResults) Then
		Local $pCore = Scanner_GetScanResult("SkillTimer", $g_ap_ScanResults, "Ptr")
		If $pCore <> 0 Then
			Local $pHook = $pCore + 3
			Local $sCore = Wine_CompactHex(Wine_ReadBytesHex($pHook, 5))
			Out("Wine SkillTimer Core scan " & Wine_HexPtr($pCore) & " hook=" & Wine_HexPtr($pHook) & " bytes=" & Wine_ReadBytesHex($pHook, 10))
			If $sCore = "FFD68B4DF0" And Wine_IsUserPtr($pHook) Then
				Out("Wine SkillTimer live hook " & Wine_HexPtr($pHook) & " (Core call esi; mov ecx,[ebp-10])")
				Return $pHook
			EndIf
			If StringLeft($sCore, 2) = "E9" And Wine_CompactHex(Wine_ReadBytesHex($pHook + 5, 5)) = "8BD88B4708" Then
				Out("Wine SkillTimer Core leftover E9 at " & Wine_HexPtr($pHook) & "; restoring FFD68B4DF0")
				If Wine_RestoreEngineEpilogue($pHook) Then Return $pHook
			EndIf
		EndIf
	EndIf
	Local $a = Wine_FindPatternHits("FFD68B4DF08BD88B4708", 8)
	Local $pBest = 0
	Local $iBestCall = -1
	Local $i = 1
	For $i = 1 To $a[0]
		Local $pHit = $a[$i]
		Local $s = Wine_CompactHex(Wine_ReadBytesHex($pHit, 5))
		Local $iCall = Wine_CountNearCallers($pHit)
		Out("Wine SkillTimer hit " & Wine_HexPtr($pHit) & " bytes=" & Wine_ReadBytesHex($pHit, 10) & " nearCallers=" & $iCall)
		If $s <> "FFD68B4DF0" Then ContinueLoop
		If Not Wine_IsUserPtr($pHit) Then ContinueLoop
		If $iCall > $iBestCall Then
			$iBestCall = $iCall
			$pBest = $pHit
		EndIf
		If $pBest = 0 Then $pBest = $pHit
	Next
	If $pBest <> 0 Then
		Out("Wine SkillTimer live hook " & Wine_HexPtr($pBest) & " (call esi; mov ecx,[ebp-10]) nearCallers=" & $iBestCall)
		Return $pBest
	EndIf
	Out("Wine SkillTimer pattern FFD68B4DF08BD88B4708 not found")
	Return 0
EndFunc

; Leftover SkillTimer JMP: E9 xx xx xx xx 8B D8 8B 47 08 (original FF D6 8B 4D F0).
Func Wine_FindLeftoverSkillTimerE9()
	Local $pLive = Wine_LabelUserPtr("MainStart")
	Local $a = Wine_FindPatternHits("8BD88B4708", 8)
	Local $i = 1
	For $i = 1 To $a[0]
		Local $pHook = $a[$i] - 5
		If Not Wine_IsUserPtr($pHook) Then ContinueLoop
		If $pLive <> 0 And Wine_PtrsEq($pHook, $pLive) Then ContinueLoop
		If $g_p_WineEngineHook <> 0 And Wine_PtrsEq($pHook, $g_p_WineEngineHook) Then ContinueLoop
		If StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pHook, 5)), 2) <> "E9" Then ContinueLoop
		Return $pHook
	Next
	Return 0
EndFunc

; SceneContext landmark: fchs; fstp [ebp-4]; mov eax,[ecx]. Steal the 5 PI bytes.
Func Wine_FindSceneHookSite()
	If IsDeclared("g_ap_ScanResults") And IsArray($g_ap_ScanResults) Then
		Local $pCore = Scanner_GetScanResult("SceneContext", $g_ap_ScanResults, "Ptr")
		If $pCore <> 0 Then
			Local $sCore = Wine_CompactHex(Wine_ReadBytesHex($pCore, 5))
			Out("Wine Scene Core scan " & Wine_HexPtr($pCore) & " bytes=" & Wine_ReadBytesHex($pCore, 8))
			If $sCore = "D9E0D95DFC" And Wine_BytesAreHookable5($sCore) And Wine_IsUserPtr($pCore) Then
				Out("Wine Scene live hook " & Wine_HexPtr($pCore) & " (Core fchs; fstp [ebp-4])")
				Return $pCore
			EndIf
			If StringLeft($sCore, 2) = "E9" And StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pCore + 5, 2)), 4) = "8B01" Then
				Out("Wine Scene Core leftover E9 at " & Wine_HexPtr($pCore) & "; restoring D9E0D95DFC")
				Memory_WriteBinary("D9E0D95DFC", $pCore)
				Wine_FlushGw($pCore, 8)
				If Wine_CompactHex(Wine_ReadBytesHex($pCore, 5)) = "D9E0D95DFC" Then Return $pCore
			EndIf
		EndIf
	EndIf
	Local $a = Wine_FindPatternHits("D9E0D95DFC8B01", 6)
	Local $i = 1
	For $i = 1 To $a[0]
		Local $pHit = $a[$i]
		Local $s = Wine_CompactHex(Wine_ReadBytesHex($pHit, 5))
		Out("Wine Scene hit " & Wine_HexPtr($pHit) & " bytes=" & Wine_ReadBytesHex($pHit, 8))
		If $s = "D9E0D95DFC" And Wine_BytesAreHookable5($s) Then
			Out("Wine Scene live hook " & Wine_HexPtr($pHit) & " (fchs; fstp [ebp-4])")
			Return $pHit
		EndIf
	Next
	Out("Wine SceneContext pattern D9E0D95DFC8B01 not found")
	Return 0
EndFunc

Func Wine_FindUiMsgHookSite()
	Local $p = Wine_LabelUserPtr("UIMessage")
	If $p = 0 Then $p = Memory_GetValue("UIMessage")
	If Not Wine_IsUserPtr($p) Then
		Out("Wine UIMessage hook: label not a user ptr")
		Return 0
	EndIf
	Local $sFive = Wine_CompactHex(Wine_ReadBytesHex($p, 5))
	Out("Wine UIMessage site " & Wine_HexPtr($p) & " bytes=" & Wine_ReadBytesHex($p, 8))
	If Not Wine_BytesAreHookable5($sFive) Then
		Out("Wine UIMessage skip " & Wine_HexPtr($p) & " bytes=" & $sFive & " (not a replayable 5-byte insn)")
		Return 0
	EndIf
	Out("Wine UIMessage live hook " & Wine_HexPtr($p))
	Return $p
EndFunc

Func Wine_AllocQueuePage()
	Local $iAlloc = 0x11000
	Local $avAlloc = DllCall($g_h_Kernel32, "ptr", "VirtualAllocEx", _
			"handle", $g_h_GWProcess, _
			"ptr", 0, _
			"ulong_ptr", $iAlloc, _
			"dword", 0x3000, _
			"dword", 0x40)
	If @error Or Not IsArray($avAlloc) Or $avAlloc[0] = 0 Then Return 0
	If Not Wine_IsUserPtr($avAlloc[0]) Then
		Wine_FreeAsmAlloc($avAlloc[0])
		Return 0
	EndIf
	Return $avAlloc[0]
EndFunc

; Write stubs on $a_p_Alloc and plant ONE hook of $a_s_Kind (engine / gwa2 / wndproc).
Func Wine_CommitFreshDrain($a_p_Alloc, $a_p_Hook, $a_s_Kind)
	If Not Wine_IsUserPtr($a_p_Alloc) Then Return False
	$g_s_WineAsmExit = $a_s_Kind
	If $a_s_Kind = "wndproc" Then
		If $g_h_WineGwHwnd <> 0 And Wine_HwndIsStub($g_h_WineGwHwnd) Then $g_h_WineGwHwnd = 0
		Local $hPre = Wine_GwWndProcHwnd()
		If $hPre = 0 Then
			Out("[Move] WndProc: no Gw hwnd (pid=" & $g_i_GWProcessId & " g_h_GWWindow=" & $g_h_GWWindow & ")")
			Return False
		EndIf
		If Wine_HwndIsStub($hPre) Then
			Out("[Move] WndProc: refusing stub hwnd=" & $hPre & " class=" & Wine_WindowClass($hPre) & " title=[" & WinGetTitle($hPre) & "]")
			$g_h_WineGwHwnd = 0
			Return False
		EndIf
		Local $pOld = Wine_HwndWndProc($hPre)
		If $pOld = 0 And Not Wine_HwndIsGame($hPre) Then
			Out("[Move] WndProc: GetWindowLong=0 on helper hwnd=" & $hPre & " class=" & Wine_WindowClass($hPre) & " title=[" & WinGetTitle($hPre) & "]; not using AutoIt DefWindowProcA")
			$g_h_WineGwHwnd = 0
			Return False
		EndIf
		If $pOld = 0 Then
			Local $aMod = DllCall("kernel32.dll", "handle", "GetModuleHandleA", "str", "user32.dll")
			If IsArray($aMod) And $aMod[0] <> 0 Then
				Local $aProc = DllCall("kernel32.dll", "ptr", "GetProcAddress", "handle", $aMod[0], "str", "DefWindowProcA")
				If IsArray($aProc) Then $pOld = Number($aProc[0])
			EndIf
			Out("[Move] WndProc: GetWindowLong=0 hwnd=" & $hPre & " class=" & Wine_WindowClass($hPre) & " title=[" & WinGetTitle($hPre) & "]; using DefWindowProcA " & Wine_HexPtr($pOld))
		EndIf
		If $pOld = 0 Then
			Out("[Move] WndProc: no OldWndProc for hwnd=" & $hPre)
			Return False
		EndIf
		If $g_p_WineWndProcOld = 0 Then $g_p_WineWndProcOld = $pOld
		Wine_ReplaceValue("MainReturn", Ptr($g_p_WineWndProcOld))
		Wine_ReplaceValue("MainStart", Ptr($a_p_Alloc))
	Else
		If $a_p_Hook = 0 Then Return False
		$g_s_WineHookSaved = Wine_CompactHex(Wine_ReadBytesHex($a_p_Hook, 5))
		$g_p_WineHookSaved = $a_p_Hook
		$g_s_WineExitReplay = ""
		If Wine_DrainIsReplay($a_s_Kind) Then $g_s_WineExitReplay = $g_s_WineHookSaved
		Wine_ReplaceValue("MainStart", Ptr($a_p_Hook))
		Wine_ReplaceValue("MainReturn", Ptr($a_p_Hook + 5))
	EndIf
	Wine_ReplaceValue("QueueSize", 0x100)
	$g_i_ASMSize = 0
	$g_i_ASMCodeOffset = 0
	$g_s_ASMCode = ""
	Wine_AssembleMinimalEngine()
	$g_p_WineAsmAlloc = $a_p_Alloc
	$g_p_ASMMemory = $a_p_Alloc
	Wine_BindEngineTicks()
	Wine_PromoteNewLabels()
	Assembler_CompleteASMCode()
	If $g_s_ASMCode = "" Then Return False
	Memory_WriteBinary($g_s_ASMCode, $g_p_ASMMemory + $g_i_ASMCodeOffset)
	Wine_PatchMainProcHeartbeat()
	If $a_s_Kind = "gwa2" Then Wine_PatchGwa2Exit()
	If Wine_DrainIsReplay($a_s_Kind) Then Wine_PatchStolenExit()
	Local $pQueue = Memory_GetValue("QueueBase")
	Local $pMain = Memory_GetValue("MainProc")
	Local $pCmdMove = Memory_GetValue("CommandMove")
	If Not Wine_IsUserPtr($pQueue) Or Not Wine_IsUserPtr($pMain) Or Not Wine_IsUserPtr($pCmdMove) Then Return False
	$g_p_SavedIndex = Memory_GetValue("SavedIndex")
	$g_p_MapIsLoaded = Memory_GetValue("MapIsLoaded")
	$g_i_QueueSize = 0x100 - 1
	$g_p_QueueBase = $pQueue
	Wine_WireCommandStructs()
	Wine_ResetQueueHead()
	Wine_FlushGw($a_p_Alloc, $g_i_ASMSize + 32)
	If $a_s_Kind = "wndproc" Then
		Local $h = Wine_GwWndProcHwnd()
		If $h = 0 Then
			Out("[Move] WndProc: no Gw client hwnd")
			Return False
		EndIf
		If Wine_HwndIsStub($h) Then
			Out("[Move] WndProc: plant hwnd became a stub class=" & Wine_WindowClass($h) & " title=[" & WinGetTitle($h) & "]")
			$g_h_WineGwHwnd = 0
			Return False
		EndIf
		DllCall("user32.dll", "int", "SetWindowLongA", "hwnd", $h, "int", -4, "int", $pMain)
		Out("[Move] WndProc drain planted hwnd=" & $h & " class=" & Wine_WindowClass($h) & " title=[" & WinGetTitle($h) & "] old=" & Wine_HexPtr($g_p_WineWndProcOld) & " new=" & Wine_HexPtr($pMain))
		Wine_PokeGwWindow()
	Else
		Local $sBefore = Wine_ReadBytesHex($a_p_Hook, 5)
		If $a_s_Kind = "engine" And Wine_CompactHex($sBefore) <> "8BECD94508" Then
			Out("[Move] plant refused: engine site " & Wine_HexPtr($a_p_Hook) & " is " & $sBefore)
			Return False
		EndIf
		If $a_s_Kind = "gwa2" And Wine_CompactHex($sBefore) <> "FFD083C404" Then
			Out("[Move] plant refused: GWA2 site " & Wine_HexPtr($a_p_Hook) & " is " & $sBefore)
			Return False
		EndIf
		If ($a_s_Kind = "render" Or Wine_DrainIsReplay($a_s_Kind)) And StringLeft(Wine_CompactHex($sBefore), 2) = "E9" Then
			Out("[Move] plant refused: " & $a_s_Kind & " site " & Wine_HexPtr($a_p_Hook) & " already E9 " & $sBefore)
			Return False
		EndIf
		If Wine_DrainIsReplay($a_s_Kind) And Not Wine_BytesAreHookable5($sBefore) Then
			Out("[Move] plant refused: " & $a_s_Kind & " site " & Wine_HexPtr($a_p_Hook) & " bytes=" & $sBefore & " not a replayable 5-byte insn")
			Return False
		EndIf
		Memory_WriteDetour("MainStart", "MainProc")
		Wine_FlushGw($a_p_Hook, 16)
		Local $sAfter = Wine_ReadBytesHex($a_p_Hook, 5)
		If StringLeft(Wine_CompactHex($sAfter), 2) <> "E9" Then
			Memory_WriteBinary($sBefore, $a_p_Hook)
			Out("[Move] fresh JMP did not stick; restored " & $sBefore)
			Return False
		EndIf
		$g_p_WineExistingE9 = $a_p_Hook
		$g_p_WineEngineHook = $a_p_Hook
		Local $sRet = " +5"
		Out("[Move] planted one " & $a_s_Kind & " JMP " & Wine_HexPtr($a_p_Hook) & " " & $sBefore & " -> " & $sAfter & _
				" MainProc=" & Wine_HexPtr($pMain) & " return" & $sRet)
	EndIf
	$g_b_WineMinimalHook = True
	$g_b_WineReuseBlocked = False
	$g_s_WineDrainKind = $a_s_Kind
	$g_i_WineTicksLast = 0
	$g_h_WineTicksAt = TimerInit()
	$g_h_WineVerifyAt = 0
	Wine_LogMainProcProof("plant-" & $a_s_Kind)
	Out("[Move] fresh drain page=" & Wine_HexPtr($a_p_Alloc) & " QueueBase=" & Wine_HexPtr($pQueue) & _
			" CommandMove=" & Wine_HexPtr($pCmdMove) & " stub=" & Wine_CompactHex(Wine_ReadBytesHex($pCmdMove, 8)))
	Return True
EndFunc

; Restore the dead JMP and plant ONE SkillTimer / Scene / UIMessage drain.
; Do not plant stock Render -0x68 (mid-instruction on this Wine/Gw).
Func Wine_RelocateDeadEngine($a_s_Why = "dead-hook")
	If Not Wine_IsWine() Then Return False
	If Wine_MapIsLoading() Then Return False
	If $g_b_WineEngineProven Then
		Out("[Move] relocate skipped; ticks already proven")
		Return True
	EndIf
	If $g_h_WineRelocateAt <> 0 And TimerDiff($g_h_WineRelocateAt) < 1500 Then
		Out("[Move] relocate throttled (" & $a_s_Why & ")")
		Return False
	EndIf
	$g_h_WineRelocateAt = TimerInit()
	$g_h_WineRefreshAt = TimerInit()
	$g_i_WineRelocateN += 1
	Wine_LogMainProcProof("pre-relocate " & $a_s_Why, False)
	Wine_RestoreOurHooks()
	$g_b_WineReuseBlocked = True
	$g_p_WineExistingE9 = 0
	$g_b_WineMinimalHook = False

	Local $asTry[5]
	$asTry[0] = 4
	If $g_s_WineDrainKind = "engine" Or $g_s_WineDrainKind = "none" Or $a_s_Why = "engine-never-ticks" Then
		$asTry[1] = "gwa2"
		$asTry[2] = "skilltimer"
		$asTry[3] = "scene"
		$asTry[4] = "uimsg"
	ElseIf $a_s_Why = "skilltimer-never-ticks" Or $g_s_WineDrainKind = "skilltimer" Then
		$asTry[0] = 3
		$asTry[1] = "scene"
		$asTry[2] = "uimsg"
		$asTry[3] = "render"
	ElseIf $a_s_Why = "scene-never-ticks" Or $g_s_WineDrainKind = "scene" Then
		$asTry[0] = 2
		$asTry[1] = "uimsg"
		$asTry[2] = "render"
	ElseIf $a_s_Why = "uimsg-never-ticks" Or $g_s_WineDrainKind = "uimsg" Then
		$asTry[0] = 1
		$asTry[1] = "render"
	Else
		; gwa2 / render / wndproc: skip misaligned Render, go SkillTimer
		$asTry[1] = "skilltimer"
		$asTry[2] = "scene"
		$asTry[3] = "uimsg"
		$asTry[4] = "render"
	EndIf

	Local $pHook = 0
	Local $sKind = ""
	Local $t = 1
	For $t = 1 To Number($asTry[0])
		$sKind = $asTry[$t]
		If $sKind = "gwa2" Then $pHook = Wine_FindGwa2HookSite()
		If $sKind = "skilltimer" Then $pHook = Wine_FindSkillTimerHookSite()
		If $sKind = "scene" Then $pHook = Wine_FindSceneHookSite()
		If $sKind = "uimsg" Then $pHook = Wine_FindUiMsgHookSite()
		If $sKind = "render" Then $pHook = Wine_FindRenderHookSite()
		If $pHook <> 0 Then ExitLoop
		Out("[Move] no " & $sKind & " site; trying next drain")
		$pHook = 0
	Next
	If $pHook = 0 Then
		Out("[Move] no live drain site (GWA2/SkillTimer/Scene/UIMessage/Render)")
		Return False
	EndIf

	Local $pAlloc = Wine_AllocQueuePage()
	If $pAlloc = 0 Then
		Out("[Move] relocate VirtualAllocEx failed")
		Return False
	EndIf
	Out("[Move] relocate " & $sKind & " on NEW page " & Wine_HexPtr($pAlloc) & " hook=" & Wine_HexPtr($pHook) & " (" & $a_s_Why & ")")
	If Not Wine_CommitFreshDrain($pAlloc, $pHook, $sKind) Then
		Wine_FreeAsmAlloc($pAlloc)
		$g_p_WineAsmAlloc = 0
		Out("[Move] relocate commit failed")
		Return False
	EndIf
	Return True
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
		Local $pClean = Wine_FindCleanEngineEpilogue()
		If $pClean <> 0 And Not Wine_PtrsEq($pClean, $pE9) Then
			$g_p_WineDeadHook = $pE9
			$g_b_WineReuseBlocked = True
			Out("Wine Engine: leftover E9 at " & Wine_HexPtr($pE9) & " is not the clean epilogue; will restore it and plant one JMP at " & Wine_HexPtr($pClean))
			Return $pClean
		EndIf
		Local $iTicks = Wine_EngineTickCount()
		Local $iCall = Wine_CountNearCallers($pE9)
		If $iTicks > 0 Then
			$g_p_WineExistingE9 = $pE9
			Out("Wine Engine: site already E9 at " & Wine_HexPtr($pE9) & " ticks=" & $iTicks & " nearCallers=" & $iCall & "; reuse (proven live)")
			Return 0
		EndIf
		$g_p_WineDeadHook = $pE9
		$g_b_WineReuseBlocked = True
		$g_p_WineExistingE9 = 0
		Out("Wine Engine: leftover E9 at " & Wine_HexPtr($pE9) & " has never ticked (ticks=" & $iTicks & " nearCallers=" & $iCall & "); not reusing. 7ccd322 planted a fresh JMP on clean 8B EC D9 45 08 to a new page.")
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
	; Heartbeat at page+ASMSize (set after assemble). Do NOT _("EngineTicks/4")
	; here — a trailing /N bumps $g_i_ASMCodeOffset and writes MainProc 4 bytes
	; late, so the Engine JMP lands on zeros and never ticks.
	_("inc dword[EngineTicks]")
	; 195ad24 MainProc ticked. 745157e (E8 in-block) and f1bb311 (`E9` trampoline
	; to call Move) did not — Wine follows direct E8/E9 and fails the unit.
	; Smallest delta: same-page CommandMove ptr, consume with `call ebx`
	; like RegularFlow (indirect; Wine does not follow).
	_("mov ebx,dword[PendingMove]")
	_("test ebx,ebx")
	_("jz RegularFlow")
	_("mov dword[PendingMove],0")
	_("inc dword[DrainSeen]")
	_("inc dword[QueueCounter]")
	_("mov eax,PendingMove")
	_("call ebx -> FF D3")
	_("jmp MainExit")
	_("RegularFlow:")
	_("mov eax,dword[QueueCounter]")
	_("mov ecx,eax")
	_("shl eax,8")
	_("add eax,QueueBase")
	_("mov ebx,dword[eax]")
	_("test ebx,ebx")
	_("jz MainExit")
	; Consume the slot and bump mem QC BEFORE the command runs. SkillTimer
	; `jmp ebx` never came back through CommandReturn (ticks rose, mem QC
	; stayed 0, pos frozen). call/ret plus QC-first still advances the
	; queue if Move does not return.
	_("inc dword[DrainSeen]")
	_("mov dword[SavedIndex],ecx")
	_("mov dword[eax],0")
	_("mov eax,ecx")
	_("inc eax")
	_("cmp eax,QueueSize")
	_("jnz DrainSkipReset")
	_("xor eax,eax")
	_("DrainSkipReset:")
	_("mov dword[QueueCounter],eax")
	_("mov eax,dword[SavedIndex]")
	_("shl eax,8")
	_("add eax,QueueBase")
	_("call ebx -> FF D3")
	_("jmp MainExit")

	_("CommandReturn:")
	_("jmp MainExit")

	_("MainExit:")
	_("popfd")
	_("popad")
	If $g_s_WineAsmExit = "wndproc" Then
		_("ljmp MainReturn")
	ElseIf Wine_DrainIsReplay($g_s_WineAsmExit) Then
		; 5 nops overwritten with stolen position-independent bytes
		_("nop")
		_("nop")
		_("nop")
		_("nop")
		_("nop")
		_("ljmp MainReturn")
	Else
		; Engine: reconstruct 8B EC D9 45 08. GWA2 overwrites these 5 bytes
		; after write with call eax; add esp,4 (same length).
		_("mov ebp,esp")
		_("fld st(0),dword[ebp+8]")
		_("ljmp MainReturn")
	EndIf

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
	_("retn")

	_("CommandMove:")
	_("lea eax,dword[eax+4]")
	_("push eax")
	_("call Move")
	_("pop eax")
	_("retn")

	_("CommandDialog:")
	_("push dword[eax+4]")
	_("call Dialog")
	_("add esp,4")
	_("retn")

	_("CommandInteract:")
	_("push dword[eax+4]")
	_("call Interact")
	_("add esp,4")
	_("retn")

	_("CommandEnterMission:")
	_("push dword[eax+4]")
	_("call EnterMission")
	_("add esp,4")
	_("retn")

	_("CommandUIMsg:")
	_("push 0")
	_("mov edx,eax")
	_("add edx,8")
	_("push edx")
	_("push dword[eax+4]")
	_("call UIMessage")
	_("add esp,C")
	_("retn")
EndFunc

; EngineTicks is the first dword after the written stubs (still on the RWX page).
; Must run after $g_p_ASMMemory is the live page and before CompleteASMCode.
Func Wine_BindEngineTicks()
	Local $pTicks = $g_p_ASMMemory + $g_i_ASMSize
	If Not Wine_IsUserPtr($pTicks) Then Return 0
	Wine_ReplaceValue("EngineTicks", Ptr($pTicks))
	Memory_Write($pTicks, 0)
	Wine_ReplaceValue("DrainSeen", Ptr($pTicks + 4))
	Memory_Write($pTicks + 4, 0)
	Wine_ReplaceValue("PendingMove", Ptr($pTicks + 8))
	Memory_Write($pTicks + 8, 0)
	Wine_ReplaceValue("PendingXYZ", Ptr($pTicks + 12))
	Memory_Write($pTicks + 12, 0)
	Memory_Write($pTicks + 16, 0)
	Memory_Write($pTicks + 20, 0)
	Wine_FlushGw($pTicks, 24)
	Return $pTicks
EndFunc

Func Wine_MainProcBytesOk()
	Local $pMain = Wine_LabelUserPtr("MainProc")
	If $pMain = 0 Then Return False
	Return StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pMain, 4)), 4) = "609C"
EndFunc

Func Wine_CommandMoveBytesOk()
	Local $pCmd = Wine_LabelUserPtr("CommandMove")
	If $pCmd = 0 Then Return False
	Return StringLeft(Wine_CompactHex(Wine_ReadBytesHex($pCmd, 5)), 6) = "8D4004"
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
	If Wine_DrainSkipEngineJmp() Then Return False
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
	Wine_ResetQueueHead()
	$g_b_WineMinimalHook = True
	Out("Wine: reused Core command page. QueueBase=" & Wine_HexPtr($g_p_QueueBase) & " MainStart=" & Wine_HexPtr($pHook))
	Return True
EndFunc

Func Wine_InstallCommandQueue()
	If Wine_QueueAlreadyLive() Then
		Out("Wine inject: QueueBase already live; skipping a second Engine JMP")
		Return True
	EndIf
	$g_s_WineAsmExit = "engine"
	If Wine_MapIsLoading() Then Return False
	Out("Wine inject: 4KB scan for Engine/Move/EnterMission/PacketSend/Dialog (read-only).")
	Wine_RestoreOrphanReplayHooks()
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
	; Proven-live leftover E9: rewrite stubs on that page (ticks already rising).
	If $pHook = 0 And $g_p_WineExistingE9 <> 0 And $g_b_WineEngineProven And Not $g_b_WineReuseBlocked Then
		$pHook = $g_p_WineExistingE9
		Local $pMainExist = Scanner_GetCallTargetAddress($pHook)
		$pAlloc = $pMainExist - (4 + 4 + 4 + 256 * 256)
		If Not Wine_IsUserPtr($pAlloc) Or Not Wine_IsUserPtr($pMainExist) Then
			Return Wine_InjectAbort("existing Engine JMP target is not a user page; restart Gw.exe")
		EndIf
		$bReuse = True
		Out("Wine: reusing proven Engine JMP " & Wine_HexPtr($pHook) & " -> MainProc " & Wine_HexPtr($pMainExist) & " page " & Wine_HexPtr($pAlloc))
	EndIf
	; Dead leftover E9 (87b468d): restore 8B EC D9 45 08 and plant a FRESH JMP
	; on a NEW page — same path as the 7ccd322 walk (QueueBase=058F000C).
	If $pHook = 0 And $g_p_WineDeadHook <> 0 Then
		Wine_RestoreEngineEpilogue($g_p_WineDeadHook)
		If Wine_CompactHex(Wine_ReadBytesHex($g_p_WineDeadHook, 5)) = "8BECD94508" Then
			$pHook = $g_p_WineDeadHook
			$bReuse = False
			$pAlloc = 0
			Out("Wine: restored leftover E9 at " & Wine_HexPtr($pHook) & " to 8B EC D9 45 08; planting one fresh JMP on a new page")
		EndIf
	EndIf
	If $pHook <> 0 And $g_p_WineDeadHook <> 0 And Not Wine_PtrsEq($pHook, $g_p_WineDeadHook) Then
		Wine_RestoreEngineEpilogue($g_p_WineDeadHook)
		Out("Wine: restored leftover E9 at " & Wine_HexPtr($g_p_WineDeadHook) & " so only one JMP is planted")
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

	Wine_BindEngineTicks()
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
		Wine_RepointEngineJmp("install-reuse")
	EndIf

	$g_p_SavedIndex = Memory_GetValue("SavedIndex")
	$g_p_MapIsLoaded = Memory_GetValue("MapIsLoaded")
	$g_i_QueueSize = 0x100 - 1
	$g_p_QueueBase = $pQueue
	Wine_WireCommandStructs()
	Wine_ResetQueueHead()
	$g_b_WineMinimalHook = True
	$g_s_WineDrainKind = "engine"
	$g_s_WineAsmExit = "engine"
	$g_b_WineReuseBlocked = False
	$g_p_WineHookSaved = $pHook
	$g_s_WineHookSaved = "8BECD94508"
	Wine_PatchMainProcHeartbeat()
	Wine_FlushGw($pHook, 8)
	Wine_FlushGw($pAlloc, 256)
	If $bReuse Then
		Out("Wine: reused proven Engine JMP. QueueBase=" & Wine_HexPtr($g_p_QueueBase) & _
				" MainStart=" & Wine_HexPtr($pHook) & " MainProc=" & Wine_HexPtr($pMain) & _
				" MainProcBytes=" & Wine_CompactHex(Wine_ReadBytesHex($pMain, 14)) & _
				" CommandMove=" & Wine_HexPtr(Memory_GetValue("CommandMove")) & _
				" stub=" & Wine_CompactHex(Wine_ReadBytesHex(Memory_GetValue("CommandMove"), 8)) & _
				" CommandPacketSend=" & Wine_HexPtr($pCmdPkt))
	Else
		Out("Wine: single fresh Engine JMP planted (7ccd322 path). QueueBase=" & Wine_HexPtr($g_p_QueueBase) & _
				" MainStart=" & Wine_HexPtr($pHook) & " MainProc=" & Wine_HexPtr($pMain) & _
				" MainProcBytes=" & Wine_CompactHex(Wine_ReadBytesHex($pMain, 14)) & _
				" CommandEnterMission=" & Wine_HexPtr($pCmdEnt))
	EndIf
	Wine_LogMainProcProof("install")
	Out("Wine: skipped LoadFinished/Trader/TradePartner detours (not Assembler_ModifyMemory). SkillTimer is the fallback when Engine/GWA2 never tick.")
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
		If Mod($iN, 8) = 0 Then Sleep(10)
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
